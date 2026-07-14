import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import 'app_settings_provider.dart';
import 'custom_lists_provider.dart';
import 'nostr_provider.dart';
import 'todos_provider.dart';

enum BootstrapSyncPhase {
  none,
  continueWithLocalCache,
  fetchingAccountRelays,
  fetchingGlobalTodos,
  fetchingGlobalGroupTodos,
  fetchingLocalTodos,
  fetchingLocalGroupTodos,
  fetchingGroupInvitations,
  syncCompleted,
  syncFailed,
}

class BootstrapSyncState {
  const BootstrapSyncState({
    required this.isBlocking,
    required this.isRunning,
    required this.phase,
    required this.errorMessage,
    required this.canFallbackToLocal,
    required this.hasCompleted,
  });

  const BootstrapSyncState.initial()
    : isBlocking = false,
      isRunning = false,
      phase = BootstrapSyncPhase.none,
      errorMessage = null,
      canFallbackToLocal = false,
      hasCompleted = false;

  final bool isBlocking;
  final bool isRunning;
  final BootstrapSyncPhase phase;
  final String? errorMessage;
  final bool canFallbackToLocal;
  final bool hasCompleted;

  BootstrapSyncState copyWith({
    bool? isBlocking,
    bool? isRunning,
    BootstrapSyncPhase? phase,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? canFallbackToLocal,
    bool? hasCompleted,
  }) {
    return BootstrapSyncState(
      isBlocking: isBlocking ?? this.isBlocking,
      isRunning: isRunning ?? this.isRunning,
      phase: phase ?? this.phase,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      canFallbackToLocal: canFallbackToLocal ?? this.canFallbackToLocal,
      hasCompleted: hasCompleted ?? this.hasCompleted,
    );
  }
}

final bootstrapSyncProvider =
    StateNotifierProvider<BootstrapSyncNotifier, BootstrapSyncState>((ref) {
      return BootstrapSyncNotifier(ref);
    });

class BootstrapSyncNotifier extends StateNotifier<BootstrapSyncState> {
  BootstrapSyncNotifier(this._ref) : super(const BootstrapSyncState.initial()) {
    _ref.listen<bool>(nostrInitializedProvider, (_, initialized) {
      if (initialized) {
        unawaited(runBootstrapIfNeeded());
      }
    });

    if (_ref.read(nostrInitializedProvider)) {
      unawaited(runBootstrapIfNeeded());
    }
  }

  final Ref _ref;
  bool _running = false;

  Future<void> runBootstrapIfNeeded({bool force = false}) async {
    if (_running) return;
    if (!_ref.read(nostrInitializedProvider)) return;

    final localTodos = await localStorageService.loadTodos();
    final shouldBlock = force || localTodos.isEmpty;

    if (!shouldBlock) {
      state = state.copyWith(
        isBlocking: false,
        isRunning: false,
        hasCompleted: true,
        phase: BootstrapSyncPhase.none,
        clearErrorMessage: true,
        canFallbackToLocal: false,
      );
      unawaited(_runBackgroundStartupRefresh());
      return;
    }

    await _runBlockingBootstrap();
  }

  Future<void> retryBootstrap() async {
    await runBootstrapIfNeeded(force: true);
  }

  void continueWithLocalCache() {
    state = state.copyWith(
      isBlocking: false,
      isRunning: false,
      phase: BootstrapSyncPhase.continueWithLocalCache,
      clearErrorMessage: true,
      canFallbackToLocal: false,
      hasCompleted: true,
    );
  }

  Future<void> _runBackgroundStartupRefresh() async {
    try {
      final todosNotifier = _ref.read(todosProvider.notifier);
      await todosNotifier.syncFromNostr(trigger: TodoSyncTrigger.appStart);
      await _ref.read(customListsProvider.notifier).syncGroupInvitations();
    } catch (e) {
      AppLogger.warning(' [Bootstrap] Background startup refresh failed: $e');
    }
  }

  /// Three-tier bootstrap: Hive (already loaded) -> Global relays -> Local relay (Citrine)
  Future<void> _runBlockingBootstrap() async {
    _running = true;
    state = state.copyWith(
      isBlocking: true,
      isRunning: true,
      phase: BootstrapSyncPhase.fetchingAccountRelays,
      clearErrorMessage: true,
      canFallbackToLocal: false,
      hasCompleted: false,
    );

    try {
      final appSettingsNotifier = _ref.read(appSettingsProvider.notifier);
      final customListsNotifier = _ref.read(customListsProvider.notifier);
      final todosNotifier = _ref.read(todosProvider.notifier);
      final nostrService = _ref.read(nostrServiceProvider);

      // Phase 0: Sync account settings (relay list, etc.)
      await appSettingsNotifier.syncFromNostr(
        skipIfFresh: false,
        minInterval: Duration.zero,
      );

      final relaySplit = await nostrService.resolveRelaySplit();
      final localRelays = relaySplit.$1;
      final globalRelays = relaySplit.$2;

      // Global relays are the primary source of truth
      final primaryRelays = globalRelays.isNotEmpty
          ? globalRelays
          : defaultRelays;

      // Phase 1: Fetch from all relays (global + local Citrine) in one pass
      // 以前は global 同期 → local relay 追加 → 全同期をもう一度、という
      // 二段構えだったが、TODO 同期とグループ同期が丸ごと二重に走り
      // 起動が遅くなるため、最初から全リレーに接続して 1 回で同期する
      state = state.copyWith(
        phase: BootstrapSyncPhase.fetchingGlobalTodos,
      );
      final allRelays = [...primaryRelays, ...localRelays];
      await nostrService.updateActiveRelays(allRelays);
      await todosNotifier.syncFromNostr(
        isInitialSync: true,
        trigger: TodoSyncTrigger.appStart,
      );

      state = state.copyWith(
        phase: BootstrapSyncPhase.fetchingGlobalGroupTodos,
      );
      await todosNotifier.syncAllGroupTodos();

      // Phase 3: Invitations and pending backfill
      state = state.copyWith(
        phase: BootstrapSyncPhase.fetchingGroupInvitations,
      );
      await customListsNotifier.syncGroupInvitations();
      await nostrService.processLocalBackfillQueue();

      state = state.copyWith(
        isBlocking: false,
        isRunning: false,
        hasCompleted: true,
        phase: BootstrapSyncPhase.syncCompleted,
        clearErrorMessage: true,
        canFallbackToLocal: false,
      );
    } catch (e, st) {
      AppLogger.error(
        ' [Bootstrap] Blocking bootstrap failed',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isBlocking: true,
        isRunning: false,
        hasCompleted: false,
        phase: BootstrapSyncPhase.syncFailed,
        errorMessage: e.toString(),
        canFallbackToLocal: true,
      );
    } finally {
      _running = false;
    }
  }
}
