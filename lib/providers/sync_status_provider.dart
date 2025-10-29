import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status_provider.freezed.dart';

/// 同期状態の種類
enum SyncState {
  /// 未初期化（Nostr未接続）
  notInitialized,
  
  /// アイドル（同期待機中）
  idle,
  
  /// 同期中
  syncing,
  
  /// 同期成功
  success,
  
  /// 同期エラー
  error,
}

/// 同期ステータス情報
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    @Default(SyncState.notInitialized) SyncState state,
    
    /// 最終同期日時
    DateTime? lastSyncTime,
    
    /// エラーメッセージ（エラー時のみ）
    String? errorMessage,
    
    /// 同期待ちのアイテム数
    @Default(0) int pendingItems,
    
    /// リトライ回数
    @Default(0) int retryCount,
  }) = _SyncStatus;
}

/// 同期ステータスを管理するProvider
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  /// Nostr初期化状態を設定
  void setInitialized(bool initialized) {
    if (initialized) {
      state = state.copyWith(
        state: SyncState.idle,
      );
    } else {
      state = const SyncStatus(); // リセット
    }
  }

  /// 同期開始
  void startSync({int itemCount = 1}) {
    state = state.copyWith(
      state: SyncState.syncing,
      pendingItems: state.pendingItems + itemCount,
    );
  }

  /// 同期成功
  void syncSuccess({int itemCount = 1}) {
    final newPendingItems = (state.pendingItems - itemCount).clamp(0, 9999);
    
    state = state.copyWith(
      state: newPendingItems > 0 ? SyncState.syncing : SyncState.success,
      lastSyncTime: DateTime.now(),
      pendingItems: newPendingItems,
      retryCount: 0,
      errorMessage: null,
    );
  }

  /// 同期エラー
  void syncError(String error, {bool shouldRetry = true}) {
    state = state.copyWith(
      state: SyncState.error,
      errorMessage: error,
      retryCount: shouldRetry ? state.retryCount + 1 : state.retryCount,
    );
  }

  /// エラーをクリア
  void clearError() {
    if (state.state == SyncState.error) {
      state = state.copyWith(
        state: SyncState.idle,
        errorMessage: null,
      );
    }
  }

  /// アイドル状態に戻す
  void setIdle() {
    state = state.copyWith(
      state: SyncState.idle,
      errorMessage: null,
    );
  }

  /// リトライカウントをリセット
  void resetRetryCount() {
    state = state.copyWith(retryCount: 0);
  }
}

