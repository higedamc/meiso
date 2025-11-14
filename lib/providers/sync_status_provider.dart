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
    
    /// 同期中のメッセージ（「データ読み込み中...」「データ移行中...」など）
    String? message,
    
    /// 同期待ちのアイテム数
    @Default(0) int pendingItems,
    
    /// リトライ回数
    @Default(0) int retryCount,
    
    /// Phase 8.5: 進捗追跡フィールド
    
    /// 全体のステップ数（同期フェーズの総数）
    @Default(0) int totalSteps,
    
    /// 完了したステップ数
    @Default(0) int completedSteps,
    
    /// 進捗パーセンテージ (0-100)
    @Default(0) int percentage,
    
    /// 現在のフェーズ名（「AppSettings同期中」「カスタムリスト同期中」など）
    String? currentPhase,
    
    /// 初回同期フラグ（ローカルストレージが空の状態からの初回起動時のみtrue）
    @Default(false) bool isInitialSync,
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
    final oldPendingItems = state.pendingItems;
    final newPendingItems = state.pendingItems + itemCount;
    
    print('🔍 [SyncStatus] startSync() called: pendingItems: $oldPendingItems → $newPendingItems');
    
    state = state.copyWith(
      state: SyncState.syncing,
      pendingItems: newPendingItems,
    );
    
    print('🔍 [SyncStatus] startSync() completed: current pendingItems: ${state.pendingItems}');
  }

  /// 同期成功
  void syncSuccess({int itemCount = 1}) {
    final oldPendingItems = state.pendingItems;
    final newPendingItems = (state.pendingItems - itemCount).clamp(0, 9999);
    final newState = newPendingItems > 0 ? SyncState.syncing : SyncState.success;
    
    print('🔍 [SyncStatus] syncSuccess() called: pendingItems: $oldPendingItems → $newPendingItems, state → $newState');
    
    state = state.copyWith(
      state: newState,
      lastSyncTime: DateTime.now(),
      pendingItems: newPendingItems,
      retryCount: 0,
      errorMessage: null,
    );
    
    print('🔍 [SyncStatus] syncSuccess() completed: current pendingItems: ${state.pendingItems}, current state: ${state.state}');
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

  /// 同期中のメッセージを更新
  void updateMessage(String message) {
    state = state.copyWith(message: message);
  }

  /// メッセージをクリア
  void clearMessage() {
    state = state.copyWith(message: null);
  }
  
  /// Phase 8.5: 進捗追跡メソッド
  
  /// 同期を開始し、全体のステップ数を設定
  void startSyncWithProgress({
    required int totalSteps,
    String? initialPhase,
    bool isInitialSync = false,
  }) {
    state = state.copyWith(
      state: SyncState.syncing,
      totalSteps: totalSteps,
      completedSteps: 0,
      percentage: 0,
      currentPhase: initialPhase,
      errorMessage: null,
      isInitialSync: isInitialSync,
    );
  }
  
  /// ステップを完了し、進捗を更新
  void completeStep({String? nextPhase}) {
    final newCompletedSteps = state.completedSteps + 1;
    final newPercentage = state.totalSteps > 0
        ? ((newCompletedSteps / state.totalSteps) * 100).round()
        : 0;
    
    state = state.copyWith(
      completedSteps: newCompletedSteps,
      percentage: newPercentage,
      currentPhase: nextPhase,
    );
  }
  
  /// 特定のフェーズにジャンプ（ステップ数とパーセンテージを直接設定）
  void setProgress({
    required int completedSteps,
    required int percentage,
    String? currentPhase,
  }) {
    state = state.copyWith(
      completedSteps: completedSteps,
      percentage: percentage,
      currentPhase: currentPhase,
    );
  }
  
  /// 進捗をリセット
  void resetProgress() {
    state = state.copyWith(
      totalSteps: 0,
      completedSteps: 0,
      percentage: 0,
      currentPhase: null,
      isInitialSync: false,
    );
  }
}

