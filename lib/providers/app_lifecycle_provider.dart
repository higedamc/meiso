import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import 'nostr_provider.dart';
import 'todos_provider.dart';
import 'sync_status_provider.dart';
import '../services/local_storage_service.dart';
import 'custom_lists_provider.dart';

/// アプリのライフサイクル状態を管理するProvider
final appLifecycleProvider = StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState>((ref) {
  return AppLifecycleNotifier(ref);
});

class AppLifecycleNotifier extends StateNotifier<AppLifecycleState> with WidgetsBindingObserver {
  AppLifecycleNotifier(this._ref) : super(AppLifecycleState.resumed) {
    // WidgetsBindingにオブザーバーを登録
    WidgetsBinding.instance.addObserver(this);
    AppLogger.debug('📱 AppLifecycleNotifier initialized');
  }

  final Ref _ref;
  DateTime? _lastResumedTime;
  bool _isReconnecting = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.debug('📱 AppLifecycleNotifier disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    super.didChangeAppLifecycleState(lifecycleState);
    state = lifecycleState;
    AppLogger.debug('📱 App lifecycle changed: $lifecycleState');

    // フォアグラウンドに復帰した場合
    if (lifecycleState == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (lifecycleState == AppLifecycleState.paused) {
      _onAppPaused();
    }
  }

  /// アプリがフォアグラウンドに復帰した時の処理
  Future<void> _onAppResumed() async {
    final now = DateTime.now();
    AppLogger.debug(' App resumed at: ${now.toIso8601String()}');

    // 前回の復帰からの経過時間を計算
    if (_lastResumedTime != null) {
      final duration = now.difference(_lastResumedTime!);
      AppLogger.debug('📱 Time since last resume: ${duration.inSeconds} seconds');
      
      // 5秒以上経過している場合のみ再接続を実行（連続復帰を防ぐ）
      if (duration.inSeconds < 5) {
        AppLogger.debug(' Skipping reconnect (too soon)');
        return;
      }
    }

    _lastResumedTime = now;

    // Nostr初期化済みかチェック
    final isInitialized = _ref.read(nostrInitializedProvider);
    if (!isInitialized) {
      AppLogger.debug('📱 Nostr not initialized, skipping reconnect');
      return;
    }

    // 公開鍵が設定されているかチェック（Amberモード対応）
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      AppLogger.warning(' Public key is null, attempting to restore...');
      await _restorePublicKey();
      
      // 復元後も null の場合はスキップ
      final restoredKey = _ref.read(publicKeyProvider);
      if (restoredKey == null) {
        AppLogger.error(' Failed to restore public key, skipping reconnect');
        return;
      }
    }

    // 既に再接続中の場合はスキップ
    if (_isReconnecting) {
      AppLogger.debug('📱 Already reconnecting, skipping');
      return;
    }

    // リレー再接続と同期を実行
    await _reconnectAndSync();
  }

  /// アプリがバックグラウンドに移行した時の処理
  void _onAppPaused() {
    AppLogger.debug('📱 App paused');
    // 必要に応じてクリーンアップ処理を追加
  }

  /// 公開鍵を復元する（Amberモード対応）
  Future<void> _restorePublicKey() async {
    try {
      AppLogger.debug(' Attempting to restore public key...');
      
      // Amberモードかチェック
      final isUsingAmber = localStorageService.isUsingAmber();
      if (!isUsingAmber) {
        AppLogger.debug(' Not in Amber mode, skipping public key restoration');
        return;
      }
      
      AppLogger.debug(' Amber mode detected, restoring public key from storage...');
      
      final nostrService = _ref.read(nostrServiceProvider);
      final publicKey = await nostrService.getPublicKey();
      
      if (publicKey != null) {
        AppLogger.info(' Public key restored: ${publicKey.substring(0, 16)}...');
        
        // publicKeyProviderに設定（hex形式）
        _ref.read(publicKeyProvider.notifier).state = publicKey;
        
        // hex形式からnpub形式に変換して設定
        try {
          final npubKey = await nostrService.hexToNpub(publicKey);
          _ref.read(nostrPublicKeyProvider.notifier).state = npubKey;
          AppLogger.info(' npub公開鍵も設定しました: ${npubKey.substring(0, 16)}...');
        } catch (e) {
          AppLogger.error(' hex→npub変換エラー: $e');
        }
        
        // nostrInitializedProviderもtrueにする（念のため）
        _ref.read(nostrInitializedProvider.notifier).state = true;
      } else {
        AppLogger.warning(' No public key found in storage (Amber mode)');
      }
    } catch (e, stackTrace) {
      AppLogger.error(' Failed to restore public key: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    }
  }

  /// リレー再接続と同期を実行
  Future<void> _reconnectAndSync() async {
    _isReconnecting = true;
    
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      
      // まず接続状態を確認し、必要なときだけ短時間reconnectする
      final connected = await nostrService.checkConnectionStatus();
      if (!connected) {
        AppLogger.info(' Starting relay reconnection (resume)...');
              _ref.read(syncStatusProvider.notifier).updateMessageKey('syncReconnectingRelays');
        try {
          // 復帰時は長時間待たない（最大3秒）
          await nostrService.reconnectRelaysWithTimeout();
          AppLogger.info(' Relay reconnection completed');
        } catch (e) {
          AppLogger.warning(' Relay reconnection failed: $e');
          // 再接続失敗でも、差分同期は試行する（ローカルデータで継続可能）
          _ref.read(syncStatusProvider.notifier).syncError(
            'リレー再接続エラー: ${e}',
            shouldRetry: false,
          );
        }
      }
      
      // 再接続成功後、データ同期を実行
      AppLogger.info(' Starting sync after reconnect...');
      _ref.read(syncStatusProvider.notifier).updateMessage('__l10n__:syncSyncingData');
      
      // TodosProviderの同期メソッドを呼び出し
      final todosNotifier = _ref.read(todosProvider.notifier);
      await todosNotifier.syncFromNostr(trigger: TodoSyncTrigger.appResume);
      await nostrService.processGlobalBackfillQueue();
      
      // Phase 8.1.2: グループ招待の同期
      try {
        final customListsNotifier = _ref.read(customListsProvider.notifier);
        await customListsNotifier.syncGroupInvitations();
        AppLogger.info(' Group invitations synced after reconnect');
      } catch (e) {
        AppLogger.warning(' Group invitation sync failed: $e');
        // エラーは無視（次回の同期で再試行）
      }
      
      AppLogger.info(' Sync after reconnect completed');
      _ref.read(syncStatusProvider.notifier).clearMessage();
      
    } catch (e, stackTrace) {
      AppLogger.error(' Reconnect and sync failed: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      
      _ref.read(syncStatusProvider.notifier).syncError(
        'フォアグラウンド復帰時の同期エラー: ${e}',
        shouldRetry: false,
      );
    } finally {
      _isReconnecting = false;
    }
  }

  /// 手動でリレー再接続と同期を実行（デバッグ用）
  Future<void> manualReconnectAndSync() async {
    AppLogger.debug('📱 Manual reconnect triggered');
    await _reconnectAndSync();
  }
}

