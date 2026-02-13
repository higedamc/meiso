import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../bridge_generated.dart/api.dart' as rust_api;
import '../services/logger_service.dart';

/// Subscription経由でイベントを受信するコールバック
typedef SubscriptionCallback = void Function(List<rust_api.ReceivedEvent> events);

/// Nostr Subscriptionを管理するサービス
/// 
/// Phase 1最適化: Amethyst風の動的ポーリング間隔
/// - イベント受信時: 100ms（高速レスポンス）
/// - アイドル時: 最大1000ms（省電力）
/// - 指数バックオフで段階的に間隔を延長
class NostrSubscriptionService {
  final Map<String, SubscriptionCallback> _callbacks = {};
  final Map<String, rust_api.SubscriptionInfo> _activeSubscriptions = {};
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  // Phase 1: 動的ポーリング間隔（jokyoの知見を活用）
  static const int _minPollingIntervalMs = 100; // イベント受信時の最小間隔
  static const int _maxPollingIntervalMs = 1000; // アイドル時の最大間隔
  static const int _receiveTimeoutMs = 500; // 受信タイムアウト
  
  // 動的ポーリング状態
  int _currentPollingIntervalMs = _minPollingIntervalMs; // 初期は高速モード
  int _consecutiveEmptyPolls = 0; // 連続した空ポーリング回数
  
  /// Subscriptionを開始
  Future<String> startSubscription({
    required List<Map<String, dynamic>> filters,
    required SubscriptionCallback onEventsReceived,
  }) async {
    try {
      // フィルターをJSON化
      final filtersJson = jsonEncode(filters);
      
      // Rust側でSubscriptionを開始
      final subscriptionInfo = await rust_api.startSubscription(
        filtersJson: filtersJson,
      );
      
      // コールバックを登録
      _callbacks[subscriptionInfo.subscriptionId] = onEventsReceived;
      _activeSubscriptions[subscriptionInfo.subscriptionId] = subscriptionInfo;
      
      AppLogger.debug(' Subscription started: ${subscriptionInfo.subscriptionId}');
      
      // ポーリング開始（まだ開始していなければ）
      _startPolling();
      
      return subscriptionInfo.subscriptionId;
    } catch (e) {
      AppLogger.warning(' Failed to start subscription: $e');
      rethrow;
    }
  }
  
  /// Subscriptionを停止
  Future<void> stopSubscription(String subscriptionId) async {
    try {
      await rust_api.stopSubscription(subscriptionId: subscriptionId);
      _callbacks.remove(subscriptionId);
      _activeSubscriptions.remove(subscriptionId);
      
      AppLogger.debug(' Subscription stopped: $subscriptionId');
      
      // すべてのSubscriptionが停止したらポーリングも停止
      if (_callbacks.isEmpty) {
        _stopPolling();
      }
    } catch (e) {
      AppLogger.warning(' Failed to stop subscription: $e');
    }
  }
  
  /// すべてのSubscriptionを停止
  Future<void> stopAllSubscriptions() async {
    try {
      await rust_api.stopAllSubscriptions();
      _callbacks.clear();
      _activeSubscriptions.clear();
      _stopPolling();
      
      AppLogger.debug(' All subscriptions stopped');
    } catch (e) {
      AppLogger.warning(' Failed to stop all subscriptions: $e');
    }
  }
  
  /// ポーリングを開始
  /// 
  /// 初期状態は高速モード（100ms）で開始し、
  /// アイドル時は自動的に省電力モードに移行
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    _currentPollingIntervalMs = _minPollingIntervalMs; // 初期は高速モード
    _consecutiveEmptyPolls = 0;
    
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _currentPollingIntervalMs),
      (_) => _pollEvents(),
    );
    
    AppLogger.debug('📡 Event polling started (interval: ${_currentPollingIntervalMs}ms)');
  }
  
  /// ポーリングを停止
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    
    // 状態をリセット
    _currentPollingIntervalMs = _minPollingIntervalMs;
    _consecutiveEmptyPolls = 0;
    
    AppLogger.debug('📡 Event polling stopped');
  }
  
  /// イベントをポーリング（動的間隔制御）
  /// 
  /// Phase 1最適化:
  /// - イベント受信時: 高速モード（100ms）に即座に切り替え
  /// - 空ポーリング継続時: 指数バックオフで省電力化
  /// - 最適化効果: 体感速度2-3倍、バッテリー消費削減
  Future<void> _pollEvents() async {
    if (_callbacks.isEmpty) return;
    
    try {
      // Rust側からイベントを受信
      final events = await rust_api.receiveSubscriptionEvents(
        timeoutMs: BigInt.from(_receiveTimeoutMs),
      );
      
      if (events.isEmpty) {
        // 空ポーリング: 指数バックオフで間隔を延長
        _handleEmptyPoll();
        return;
      }
      
      // イベント受信: 高速モードに即座に切り替え
      _handleEventReceived(events.length);
      
      // Subscription IDごとにイベントをグループ化
      final eventsBySubscription = <String, List<rust_api.ReceivedEvent>>{};
      for (final event in events) {
        eventsBySubscription
            .putIfAbsent(event.subscriptionId, () => [])
            .add(event);
      }
      
      // 対応するコールバックを呼び出し
      for (final entry in eventsBySubscription.entries) {
        final subscriptionId = entry.key;
        final subscriptionEvents = entry.value;
        
        final callback = _callbacks[subscriptionId];
        if (callback != null) {
          callback(subscriptionEvents);
        }
      }
    } catch (e) {
      // ポーリングエラー: 間隔を延長して負荷を軽減
      _handlePollingError();
      // AppLogger.warning(' Event polling error: $e');
    }
  }
  
  /// 空ポーリング時の処理（指数バックオフ）
  /// 
  /// 空ポーリングが3回以上続いた場合、間隔を2倍に延長（最大1000ms）
  /// jokyoの知見: アイドル時は省電力化してバッテリーを節約
  void _handleEmptyPoll() {
    _consecutiveEmptyPolls++;
    
    // 3回以上の空ポーリングで間隔を延長
    if (_consecutiveEmptyPolls > 3) {
      final oldInterval = _currentPollingIntervalMs;
      _currentPollingIntervalMs = min(
        _currentPollingIntervalMs * 2, // 指数バックオフ（2倍）
        _maxPollingIntervalMs,
      );
      
      // 間隔が変更された場合のみタイマーを更新
      if (_currentPollingIntervalMs != oldInterval) {
        _updatePollingInterval();
        AppLogger.debug(
          '💤 Polling slowed: ${oldInterval}ms → ${_currentPollingIntervalMs}ms '
          '(idle: $_consecutiveEmptyPolls polls)',
        );
      }
    }
  }
  
  /// イベント受信時の処理（高速モード復帰）
  /// 
  /// イベント受信時は即座に最速間隔（100ms）に戻し、
  /// 続くイベントを素早くキャッチする
  void _handleEventReceived(int eventCount) {
    final oldInterval = _currentPollingIntervalMs;
    _consecutiveEmptyPolls = 0;
    _currentPollingIntervalMs = _minPollingIntervalMs;
    
    // 間隔が変更された場合のみタイマーを更新
    if (_currentPollingIntervalMs != oldInterval) {
      _updatePollingInterval();
      AppLogger.debug(
        '⚡ Polling accelerated: ${oldInterval}ms → ${_currentPollingIntervalMs}ms '
        '(received: $eventCount events)',
      );
    } else {
      AppLogger.debug('📥 Received $eventCount events via subscription');
    }
  }
  
  /// エラー時の処理（負荷軽減）
  /// 
  /// エラー発生時は連続空ポーリング回数を増やし、
  /// 次回から間隔を延長して負荷を軽減
  void _handlePollingError() {
    _consecutiveEmptyPolls = max(_consecutiveEmptyPolls, 3);
  }
  
  /// ポーリング間隔を更新
  /// 
  /// タイマーを再作成して新しい間隔を適用
  /// Timer.periodic は間隔変更できないため、再作成が必要
  void _updatePollingInterval() {
    if (!_isPolling) return;
    
    // 既存のタイマーをキャンセル
    _pollingTimer?.cancel();
    
    // 新しい間隔でタイマーを再作成
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _currentPollingIntervalMs),
      (_) => _pollEvents(),
    );
  }
  
  /// アクティブなSubscription数を取得
  int get activeSubscriptionCount => _callbacks.length;
  
  /// アクティブなSubscription一覧を取得
  List<rust_api.SubscriptionInfo> get activeSubscriptions =>
      _activeSubscriptions.values.toList();
  
  /// ポーリング中かチェック
  bool get isPolling => _isPolling;
  
  /// Phase 1: 現在のポーリング間隔を取得（デバッグ用）
  int get currentPollingIntervalMs => _currentPollingIntervalMs;
  
  /// Phase 1: 連続空ポーリング回数を取得（デバッグ用）
  int get consecutiveEmptyPolls => _consecutiveEmptyPolls;
  
  /// Phase 1: ポーリング状態のサマリーを取得
  Map<String, dynamic> get pollingStats => {
    'isPolling': _isPolling,
    'currentIntervalMs': _currentPollingIntervalMs,
    'consecutiveEmptyPolls': _consecutiveEmptyPolls,
    'activeSubscriptions': _callbacks.length,
    'mode': _currentPollingIntervalMs <= _minPollingIntervalMs 
        ? 'fast' 
        : _currentPollingIntervalMs >= _maxPollingIntervalMs 
            ? 'idle' 
            : 'transitioning',
  };
  
  /// サービスを破棄
  void dispose() {
    _stopPolling();
    _callbacks.clear();
    _activeSubscriptions.clear();
  }
}

