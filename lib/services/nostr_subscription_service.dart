import 'dart:async';
import 'dart:convert';
import '../bridge_generated.dart/api.dart' as rust_api;

/// Subscription経由でイベントを受信するコールバック
typedef SubscriptionCallback = void Function(List<rust_api.ReceivedEvent> events);

/// Nostr Subscriptionを管理するサービス
class NostrSubscriptionService {
  final Map<String, SubscriptionCallback> _callbacks = {};
  final Map<String, rust_api.SubscriptionInfo> _activeSubscriptions = {};
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  static const int _pollingIntervalMs = 1000; // 1秒ごとにポーリング
  static const int _receiveTimeoutMs = 500; // 受信タイムアウト
  
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
      
      print('📡 Subscription started: ${subscriptionInfo.subscriptionId}');
      
      // ポーリング開始（まだ開始していなければ）
      _startPolling();
      
      return subscriptionInfo.subscriptionId;
    } catch (e) {
      print('⚠️ Failed to start subscription: $e');
      rethrow;
    }
  }
  
  /// Subscriptionを停止
  Future<void> stopSubscription(String subscriptionId) async {
    try {
      await rust_api.stopSubscription(subscriptionId: subscriptionId);
      _callbacks.remove(subscriptionId);
      _activeSubscriptions.remove(subscriptionId);
      
      print('🛑 Subscription stopped: $subscriptionId');
      
      // すべてのSubscriptionが停止したらポーリングも停止
      if (_callbacks.isEmpty) {
        _stopPolling();
      }
    } catch (e) {
      print('⚠️ Failed to stop subscription: $e');
    }
  }
  
  /// すべてのSubscriptionを停止
  Future<void> stopAllSubscriptions() async {
    try {
      await rust_api.stopAllSubscriptions();
      _callbacks.clear();
      _activeSubscriptions.clear();
      _stopPolling();
      
      print('🛑 All subscriptions stopped');
    } catch (e) {
      print('⚠️ Failed to stop all subscriptions: $e');
    }
  }
  
  /// ポーリングを開始
  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    _pollingTimer = Timer.periodic(
      Duration(milliseconds: _pollingIntervalMs),
      (_) => _pollEvents(),
    );
    
    print('📡 Event polling started');
  }
  
  /// ポーリングを停止
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    
    print('🛑 Event polling stopped');
  }
  
  /// イベントをポーリング
  Future<void> _pollEvents() async {
    if (_callbacks.isEmpty) return;
    
    try {
      // Rust側からイベントを受信
      final events = await rust_api.receiveSubscriptionEvents(
        timeoutMs: BigInt.from(_receiveTimeoutMs),
      );
      
      if (events.isEmpty) return;
      
      print('📥 Received ${events.length} events via subscription');
      
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
      // ポーリングエラーはログだけ出力（接続エラーなど頻繁に起こりうる）
      // print('⚠️ Event polling error: $e');
    }
  }
  
  /// アクティブなSubscription数を取得
  int get activeSubscriptionCount => _callbacks.length;
  
  /// アクティブなSubscription一覧を取得
  List<rust_api.SubscriptionInfo> get activeSubscriptions =>
      _activeSubscriptions.values.toList();
  
  /// ポーリング中かチェック
  bool get isPolling => _isPolling;
  
  /// サービスを破棄
  void dispose() {
    _stopPolling();
    _callbacks.clear();
    _activeSubscriptions.clear();
  }
}

