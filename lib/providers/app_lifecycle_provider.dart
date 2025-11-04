import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nostr_provider.dart';
import 'todos_provider.dart';
import 'sync_status_provider.dart';
import '../services/local_storage_service.dart';

/// アプリのライフサイクル状態を管理するProvider
final appLifecycleProvider = StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState>((ref) {
  return AppLifecycleNotifier(ref);
});

class AppLifecycleNotifier extends StateNotifier<AppLifecycleState> with WidgetsBindingObserver {
  AppLifecycleNotifier(this._ref) : super(AppLifecycleState.resumed) {
    // WidgetsBindingにオブザーバーを登録
    WidgetsBinding.instance.addObserver(this);
    print('📱 AppLifecycleNotifier initialized');
  }

  final Ref _ref;
  DateTime? _lastResumedTime;
  bool _isReconnecting = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('📱 AppLifecycleNotifier disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    super.didChangeAppLifecycleState(lifecycleState);
    state = lifecycleState;
    print('📱 App lifecycle changed: $lifecycleState');

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
    print('📱 App resumed at: ${now.toIso8601String()}');

    // 前回の復帰からの経過時間を計算
    if (_lastResumedTime != null) {
      final duration = now.difference(_lastResumedTime!);
      print('📱 Time since last resume: ${duration.inSeconds} seconds');
      
      // 5秒以上経過している場合のみ再接続を実行（連続復帰を防ぐ）
      if (duration.inSeconds < 5) {
        print('📱 Skipping reconnect (too soon)');
        return;
      }
    }

    _lastResumedTime = now;

    // Nostr初期化済みかチェック
    final isInitialized = _ref.read(nostrInitializedProvider);
    if (!isInitialized) {
      print('📱 Nostr not initialized, skipping reconnect');
      return;
    }

    // 公開鍵が設定されているかチェック（Amberモード対応）
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      print('⚠️ Public key is null, attempting to restore...');
      await _restorePublicKey();
      
      // 復元後も null の場合はスキップ
      final restoredKey = _ref.read(publicKeyProvider);
      if (restoredKey == null) {
        print('❌ Failed to restore public key, skipping reconnect');
        return;
      }
    }

    // 既に再接続中の場合はスキップ
    if (_isReconnecting) {
      print('📱 Already reconnecting, skipping');
      return;
    }

    // リレー再接続と同期を実行
    await _reconnectAndSync();
  }

  /// アプリがバックグラウンドに移行した時の処理
  void _onAppPaused() {
    print('📱 App paused');
    // 必要に応じてクリーンアップ処理を追加
  }

  /// 公開鍵を復元する（Amberモード対応）
  Future<void> _restorePublicKey() async {
    try {
      print('🔑 Attempting to restore public key...');
      
      // Amberモードかチェック
      final isUsingAmber = localStorageService.isUsingAmber();
      if (!isUsingAmber) {
        print('ℹ️ Not in Amber mode, skipping public key restoration');
        return;
      }
      
      print('🔐 Amber mode detected, restoring public key from storage...');
      
      final nostrService = _ref.read(nostrServiceProvider);
      final publicKey = await nostrService.getPublicKey();
      
      if (publicKey != null) {
        print('✅ Public key restored: ${publicKey.substring(0, 16)}...');
        
        // publicKeyProviderに設定（hex形式）
        _ref.read(publicKeyProvider.notifier).state = publicKey;
        
        // hex形式からnpub形式に変換して設定
        try {
          final npubKey = await nostrService.hexToNpub(publicKey);
          _ref.read(nostrPublicKeyProvider.notifier).state = npubKey;
          print('✅ npub公開鍵も設定しました: ${npubKey.substring(0, 16)}...');
        } catch (e) {
          print('❌ hex→npub変換エラー: $e');
        }
        
        // nostrInitializedProviderもtrueにする（念のため）
        _ref.read(nostrInitializedProvider.notifier).state = true;
      } else {
        print('⚠️ No public key found in storage (Amber mode)');
      }
    } catch (e, stackTrace) {
      print('❌ Failed to restore public key: $e');
      print('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    }
  }

  /// リレー再接続と同期を実行
  Future<void> _reconnectAndSync() async {
    _isReconnecting = true;
    
    try {
      print('🔄 Starting relay reconnection...');
      _ref.read(syncStatusProvider.notifier).updateMessage('リレー再接続中...');
      
      final nostrService = _ref.read(nostrServiceProvider);
      
      // リレー再接続を実行
      try {
        await nostrService.reconnectRelays();
        print('✅ Relay reconnection completed');
      } catch (e) {
        print('⚠️ Relay reconnection failed: $e');
        // 再接続失敗時もエラーは記録するが、同期は試行する
        _ref.read(syncStatusProvider.notifier).syncError(
          'リレー再接続エラー: ${e.toString()}',
          shouldRetry: false,
        );
        
        // 3秒後にエラーをクリア
        Future.delayed(const Duration(seconds: 3), () {
          _ref.read(syncStatusProvider.notifier).clearError();
        });
        
        return;
      }
      
      // 再接続成功後、データ同期を実行
      print('🔄 Starting sync after reconnect...');
      _ref.read(syncStatusProvider.notifier).updateMessage('データ同期中...');
      
      // TodosProviderの同期メソッドを呼び出し
      final todosNotifier = _ref.read(todosProvider.notifier);
      await todosNotifier.syncFromNostr();
      
      print('✅ Sync after reconnect completed');
      _ref.read(syncStatusProvider.notifier).clearMessage();
      
    } catch (e, stackTrace) {
      print('❌ Reconnect and sync failed: $e');
      print('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      
      _ref.read(syncStatusProvider.notifier).syncError(
        'フォアグラウンド復帰時の同期エラー: ${e.toString()}',
        shouldRetry: false,
      );
      
      // 3秒後にエラーをクリア
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(syncStatusProvider.notifier).clearError();
      });
    } finally {
      _isReconnecting = false;
    }
  }

  /// 手動でリレー再接続と同期を実行（デバッグ用）
  Future<void> manualReconnectAndSync() async {
    print('📱 Manual reconnect triggered');
    await _reconnectAndSync();
  }
}

