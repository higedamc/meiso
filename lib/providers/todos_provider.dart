import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../models/custom_list.dart';
import '../models/task_link.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/amber_service.dart';
import '../services/link_preview_service.dart';
import '../services/widget_service.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';
import 'custom_lists_provider.dart';
import 'app_settings_provider.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
// Phase B & C.2.3: UseCaseのインポート
import '../features/todo/application/providers/usecase_providers.dart';
import '../features/todo/application/usecases/create_todo_usecase.dart';
import '../features/todo/application/usecases/update_todo_usecase.dart';
import '../features/todo/application/usecases/delete_todo_usecase.dart';
import '../features/todo/application/usecases/generate_recurring_instances_usecase.dart';
import '../features/todo/application/usecases/remove_child_instances_usecase.dart';
import '../features/todo/infrastructure/providers/repository_providers.dart';
// MLS: グループ管理用Repositoryのインポート
import '../features/mls/infrastructure/providers/repository_providers.dart'
    as mls_providers;
import '../features/shared_list/infrastructure/providers/repository_providers.dart'
    as shared_providers;
import '../utils/fractional_index.dart';

// Amberモード判定のためのインポート
export 'nostr_provider.dart' show isAmberModeProvider;

/// 同期トリガー（Joplin-like: 復帰時は差分同期、手動はフル同期）
enum TodoSyncTrigger {
  appStart,
  appResume,
  manual,
  background,
}

/// AmberServiceのProvider
final Provider<AmberService> amberServiceProvider = Provider(
  (ref) => AmberService(),
);

/// 日付ごとにグループ化されたTodoリストを管理するProvider
///
/// Map<DateTime?, List<Todo>>:
/// - null キー: Someday
/// - DateTime: 特定の日付
final todosProvider =
    StateNotifierProvider<
      TodosNotifier,
      AsyncValue<Map<DateTime?, List<Todo>>>
    >(
      TodosNotifier.new,
    );

/// 親タスクごとのサブタスク展開状態（メモリ保持）
final subtaskExpansionProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

class TodosNotifier
    extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>> {
  TodosNotifier(this._ref) : super(const AsyncValue.loading()) {
    _registerBackfillCallbacks();
    _setupBatchSyncLifecycle();
    _initialize();
  }

  final Ref _ref;

  // バッチ同期用のタイマー
  Timer? _batchSyncTimer;

  // MLS初期化フラグ（Option B PoC）
  bool _mlsInitialized = false;

  // Issue #101: 削除済みタスクIDのブラックリスト（リスト再作成時の復活防止）
  Set<String> _deletedTodoIds = {};

  // MLS realtime subscriptions (groupId -> subscription + refCount)
  final Map<String, _MlsGroupRealtimeSubscription> _mlsGroupTodoSubscriptions =
      {};

  // Realtime dedupe (groupId -> seen eventIds)
  final Map<String, Set<String>> _mlsGroupTodoSeenEventIds = {};

  // グループ系バックグラウンド同期の多重起動ガード
  bool _groupBackgroundSyncInProgress = false;

  Timer? _mlsRealtimeSaveDebounce;

  // Issue #11: UNDO機能（最後に削除した1件のみ復元可能）
  Todo? _lastDeletedTodo;
  Timer? _deletionTimer;

  void _registerBackfillCallbacks() {
    Future<void>.microtask(() {
      if (!mounted) return;
      _ref
          .read(nostrServiceProvider)
          .setGlobalBackfillResultHandler(
            _onGlobalBackfillResult,
          );
    });
  }

  /// Nostrの初期化状態に応じて、バッチ同期タイマーを開始/停止する。
  ///
  /// - ログイン前（Nostr未初期化）ではタイマーを起動しない（ログスパム防止）
  /// - 初期化された瞬間にタイマーを開始し、未同期があれば一度だけ即実行する
  void _setupBatchSyncLifecycle() {
    // 既に初期化済みなら即開始（restoreNostrConnection 等で先に初期化済みの可能性がある）
    if (_ref.read(nostrInitializedProvider)) {
      _startBatchSyncTimer(force: true);
      Future.microtask(_executeBatchSync);
    }

    _ref.listen<bool>(
      nostrInitializedProvider,
      (previous, next) {
        if (!mounted) return;

        if (next) {
          _startBatchSyncTimer(force: true);
          // 起動/ログイン直後に未同期が残っていれば一度だけ即実行する
          Future.microtask(_executeBatchSync);
        } else {
          // ログアウト等で未初期化に戻ったら停止
          _batchSyncTimer?.cancel();
        }
      },
    );
  }

  /// Provider更新をmicrotaskに逃がす（dispose中のElementにrebuildが飛ぶ事故を避ける）
  ///
  /// NOTE:
  /// Riverpodのwatch解除タイミングとNavigatorのpop/disposeが競合すると、
  /// 稀に `Element.markNeedsBuild ... _ElementLifecycle.defunct` が起きることがある。
  /// state更新は「次フレーム」に逃がす（microtaskだとまだdispose中でクラッシュすることがある）。
  void _setTodosStateAsync(Map<DateTime?, List<Todo>> todos) {
    // NOTE: dispose/route popと競合しやすいのでpost-frameで更新する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      state = AsyncValue.data(todos);
    });
  }

  Future<void> _initialize() async {
    try {
      // Issue #101: 削除済みタスクIDを読み込み
      final deletedTodoIds = await localStorageService.loadDeletedTodoIds();
      _deletedTodoIds = deletedTodoIds.toSet();
      AppLogger.info(
        '💾 [Issue#101] Loaded ${_deletedTodoIds.length} deleted todo IDs from blacklist',
      );
      if (_deletedTodoIds.isNotEmpty) {
        AppLogger.info(
          '📝 [Issue#101] Blacklisted IDs: ${_deletedTodoIds.take(5).map((id) => id.substring(0, 16)).join(", ")}${_deletedTodoIds.length > 5 ? "..." : ""}',
        );
      }

      // ローカルストレージから読み込み
      final localTodosRaw = await localStorageService.loadTodos();
      final localTodos = localTodosRaw
          .map(
            (todo) => todo.copyWith(date: _normalizeDateForGrouping(todo.date)),
          )
          .toList();

      final hasLocalData = localTodos.isNotEmpty;

      if (hasLocalData) {
        // ローカルデータがある場合：即座に表示
        final grouped = <DateTime?, List<Todo>>{};
        for (final todo in localTodos) {
          final dateKey = _normalizeDateForGrouping(todo.date);
          grouped[dateKey] ??= [];
          grouped[dateKey]!.add(todo);
        }

        // 各日付のリストをorder順にソート
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
        }

        AppLogger.info(' [Todos] ローカルから${localTodos.length}件のタスクを読み込み');
        state = AsyncValue.data(grouped);

        // ログイン済みの場合のみバックグラウンド同期
        if (_ref.read(nostrInitializedProvider)) {
          AppLogger.debug(' [Todos] Nostr初期化済み。バックグラウンド同期を開始');
          _backgroundSync();
        } else {
          AppLogger.debug(' [Todos] Nostr未初期化（ログイン前）のため、同期をスキップ');
        }
      } else {
        // ローカルデータがない場合：空の状態
        AppLogger.info(' [Todos] ローカルデータなし');
        state = const AsyncValue.data({});

        // ログイン済みの場合のみ優先同期（初回同期フラグ付き）
        if (_ref.read(nostrInitializedProvider)) {
          AppLogger.debug(' [Todos] Nostr初期化済み。優先同期を開始（初回同期）');
          _prioritySync(isInitialSync: true);
        } else {
          AppLogger.debug(' [Todos] Nostr未初期化（ログイン前）のため、同期をスキップ');
        }
      }
    } catch (e) {
      AppLogger.warning(' Todo初期化エラー: $e');
      // エラー時は空のマップで初期化
      AppLogger.warning(' エラー発生のため空のリストで開始');
      state = const AsyncValue.data({});
    }
  }

  /// 優先同期（遅延なし、初回ログイン時用）
  Future<void> _prioritySync({bool isInitialSync = false}) async {
    // Nostr初期化チェック（即座に）
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.debug(' [Todos] Nostr未初期化のため、優先同期をスキップ');
      return;
    }

    AppLogger.info(' [Todos] 優先同期を開始${isInitialSync ? "（初回同期）" : ""}');

    try {
      // タイムアウト付きで同期実行（15秒）
      await Future<void>.delayed(Duration.zero)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () async {
              AppLogger.warning(' [Todos] 優先同期タイムアウト（15秒）');
              _ref
                  .read(syncStatusProvider.notifier)
                  .syncError(
                    '同期がタイムアウトしました',
                    shouldRetry: false,
                  );
              return;
            },
          )
          .then((_) async {
            // マイグレーション完了チェック（一度だけ実行）
            final migrationCompleted = await localStorageService
                .isMigrationCompleted();
            AppLogger.debug(' [Todos] マイグレーションステータス: $migrationCompleted');

            if (!migrationCompleted) {
              AppLogger.debug(' [Todos] データステータスを確認中...');

              // まずKind 30001（新形式）をチェック
              _ref
                  .read(syncStatusProvider.notifier)
                  .updateMessage('__l10n__:syncLoadingData');
              AppLogger.debug(' [Todos] Kind 30001の存在確認...');
              final hasNewData = await checkKind30001Exists();
              AppLogger.debug(' [Todos] Kind 30001: $hasNewData');

              if (hasNewData) {
                // Kind 30001にデータがある = マイグレーション済み
                AppLogger.info(' [Todos] Kind 30001データ検出。マイグレーション済み');
                AppLogger.debug(' [Todos] Kind 30001からデータをロード中...');
                AppLogger.debug(' [Todos] マイグレーションスキップ - Kind 30001が存在');

                // Kind 30001から同期（この後のsyncFromNostr()で実行される）
                await localStorageService.setMigrationCompleted();
                AppLogger.info(' [Todos] マイグレーション完了フラグを設定');
              } else {
                // Kind 30001がない → Kind 30078をチェック
                AppLogger.debug(' [Todos] Kind 30001なし。Kind 30078をチェック...');
                AppLogger.debug(' [Todos] Kind 30078の存在確認...');
                final needsMigration = await checkMigrationNeeded();
                AppLogger.debug(' [Todos] Kind 30078: $needsMigration');

                if (needsMigration) {
                  AppLogger.debug(' [Todos] 旧Kind 30078データ検出。マイグレーション開始...');
                  AppLogger.warning(' [Todos] マイグレーション実行 - Amber復号化が必要');
                  _ref
                      .read(syncStatusProvider.notifier)
                      .updateMessage('__l10n__:syncMigratingData');

                  // マイグレーション実行（Kind 30078 → Kind 30001）
                  await migrateFromKind30078ToKind30001();
                  AppLogger.info(' [Todos] マイグレーション完了');
                } else {
                  AppLogger.info(' [Todos] 旧データなし。マイグレーション不要');
                  // 旧イベントがない場合はマイグレーション完了として記録
                  await localStorageService.setMigrationCompleted();
                  AppLogger.info(' [Todos] マイグレーション完了フラグを設定（データなし）');
                }
              }
            } else {
              AppLogger.info(' [Todos] マイグレーション済み（キャッシュ）');
            }

            _ref
                .read(syncStatusProvider.notifier)
                .updateMessage('__l10n__:syncSyncingData');
            await syncFromNostr(isInitialSync: isInitialSync);
            AppLogger.info(' [Todos] 優先同期完了');
          });
    } catch (e, stackTrace) {
      AppLogger.error(' [Todos] 優先同期エラー', error: e, stackTrace: stackTrace);
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            '同期エラー: ${e}',
            shouldRetry: false,
          );
    } finally {
      // 同期完了後、進捗をリセット（isInitialSyncフラグもクリア）
      _ref.read(syncStatusProvider.notifier).resetProgress();
      AppLogger.debug(' [Todos] 優先同期の進捗をリセットしました');
    }
  }

  /// バックグラウンド同期（UIブロックしない）
  Future<void> _backgroundSync() async {
    // Nostr初期化チェック（即座に）
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.debug(' [Todos] Nostr未初期化のため、バックグラウンド同期をスキップ');
      return;
    }

    AppLogger.info(' [Todos] バックグラウンド同期を開始');

    try {
      AppLogger.info(' Starting background Nostr sync...');

      // タイムアウト付きで実行（15秒）
      await Future<void>.delayed(Duration.zero)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () async {
              AppLogger.debug(
                ' Background sync timeout - continuing with local data',
              );
              _ref
                  .read(syncStatusProvider.notifier)
                  .syncError(
                    'バックグラウンド同期がタイムアウトしました',
                    shouldRetry: false,
                  );
              return;
            },
          )
          .then((_) async {
            // マイグレーション完了チェック（一度だけ実行）
            final migrationCompleted = await localStorageService
                .isMigrationCompleted();
            AppLogger.debug(
              ' Migration status check: completed=$migrationCompleted',
            );

            if (!migrationCompleted) {
              AppLogger.debug(' Checking data status...');

              // まずKind 30001（新形式）をチェック
              _ref
                  .read(syncStatusProvider.notifier)
                  .updateMessage('__l10n__:syncLoadingData');
              AppLogger.debug(' Step 1: Checking Kind 30001 existence...');
              final hasNewData = await checkKind30001Exists();
              AppLogger.debug(' Step 1 result: hasNewData=$hasNewData');

              if (hasNewData) {
                // Kind 30001にデータがある = マイグレーション済み
                AppLogger.info(
                  ' Found Kind 30001 data. Migration already completed on another device.',
                );
                AppLogger.debug(' Loading data from Kind 30001...');
                AppLogger.debug('  SKIPPING migration - Kind 30001 found!');

                // Kind 30001から同期（この後のsyncFromNostr()で実行される）
                await localStorageService.setMigrationCompleted();
                AppLogger.info(' Migration flag set to completed');
              } else {
                // Kind 30001がない → Kind 30078をチェック
                AppLogger.debug(
                  ' No Kind 30001 found. Checking for old Kind 30078 events...',
                );
                AppLogger.debug(' Step 2: Checking Kind 30078 existence...');
                final needsMigration = await checkMigrationNeeded();
                AppLogger.debug(
                  ' Step 2 result: needsMigration=$needsMigration',
                );

                if (needsMigration) {
                  AppLogger.debug(
                    ' Found old Kind 30078 TODO events. Starting migration...',
                  );
                  AppLogger.warning(
                    '  MIGRATION WILL START - THIS WILL TRIGGER AMBER DECRYPTION',
                  );
                  _ref
                      .read(syncStatusProvider.notifier)
                      .updateMessage('__l10n__:syncMigratingData');

                  // マイグレーション実行（Kind 30078 → Kind 30001）
                  await migrateFromKind30078ToKind30001();
                  AppLogger.info(' Migration completed successfully');
                } else {
                  AppLogger.info(
                    ' No old events found. Marking migration as completed.',
                  );
                  // 旧イベントがない場合はマイグレーション完了として記録
                  await localStorageService.setMigrationCompleted();
                  AppLogger.info(' Migration flag set to completed (no data)');
                }
              }
            } else {
              AppLogger.info(' Migration already completed (cached)');
            }

            _ref
                .read(syncStatusProvider.notifier)
                .updateMessage('__l10n__:syncSyncingData');
            await syncFromNostr();
            AppLogger.info(' Background sync completed');
          });
    } catch (e, stackTrace) {
      AppLogger.warning(' バックグラウンド同期失敗: $e');
      AppLogger.error(
        'Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );

      // エラー状態を更新（ローカルデータは保持）
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            'バックグラウンド同期に失敗しました: ${e}',
            shouldRetry: false,
          );
    }
  }

  // 初回起動時のダミーデータは作成しない
  // （削除済み: _createInitialDummyData メソッド）
  //
  // 以前は「Nostr統合を完了する」などのダミーデータを作成していましたが、
  // これによりリレーサーバー上の既存データが空のリストで上書きされる問題がありました。
  // 現在は初回起動時は空のリストから始まり、リレーサーバーからデータを同期します。

  /// 新しいTodoを追加（楽観的UI更新）
  ///
  /// Phase B: CreateTodoUseCaseを使用してTodoを生成
  Future<void> addTodo(
    String title,
    DateTime? date, {
    String? customListId,
  }) async {
    if (title.trim().isEmpty) return;
    final uiStopwatch = Stopwatch()..start();

    AppLogger.info(
      '📥 [ADD_TODO] START: title="$title", date=$date, customListId=$customListId',
    );
    AppLogger.debug('📍 Stack trace location: addTodo');
    if (customListId != null) {
      AppLogger.debug(
        ' IMPORTANT: This todo is being added to custom list: $customListId',
      );
    }

    await state.whenData((todos) async {
      AppLogger.info('📥 [ADD_TODO] Calling CreateTodoUseCase...');
      // Phase B: CreateTodoUseCaseを使ってTodoを生成
      final createTodoUseCase = _ref.read(createTodoUseCaseProvider);
      final result = await createTodoUseCase(
        CreateTodoParams(
          title: title,
          date: date,
          customListId: customListId,
          currentTodos: todos,
        ),
      );

      AppLogger.info('📥 [ADD_TODO] CreateTodoUseCase completed');

      result.fold(
        (failure) {
          // エラーハンドリング
          AppLogger.error('❌ Failed to create todo: ${failure.message}');
          state = AsyncValue.error(failure, StackTrace.current);
        },
        (newTodo) async {
          // URL検出（UseCaseで既に処理済み）
          final detectedUrl = newTodo.linkPreview?.url;
          final autoRecurrence = newTodo.recurrence;

          AppLogger.info(
            '📥 [ADD_TODO] newTodo created: id=${newTodo.id.substring(0, 8)}, title="${newTodo.title}", recurrence=${autoRecurrence?.type}',
          );

          final list = List<Todo>.from(todos[date] ?? []);
          list.add(newTodo);

          final updatedTodos = {
            ...todos,
            date: list,
          };

          // 【楽観的UI更新】個人Todo/グループTodoともに同一フレームで反映
          state = AsyncValue.data(updatedTodos);
          uiStopwatch.stop();
          AppLogger.info(
            '⚡ [ADD_TODO] UI updated in ${uiStopwatch.elapsedMilliseconds}ms',
          );

          // 永続化はUI描画を待たずに非同期で開始
          unawaited(_saveAllTodosToLocal());

          // リカーリングタスクの場合は完全に完了してからUI更新
          // （将来のインスタンスをUIに反映させるため）
          if (autoRecurrence != null && date != null) {
            final updatedTodosAfterBackground = await _performBackgroundTasks(
              newTodo: newTodo,
              updatedTodos: updatedTodos,
              autoRecurrence: autoRecurrence,
              date: date,
              detectedUrl: detectedUrl,
              customListId: customListId,
            );
            // バックグラウンドタスク完了後、更新されたtodosでUI更新
            _setTodosStateAsync(updatedTodosAfterBackground);
            AppLogger.info('📥 [ADD_TODO] UI updated with recurring instances');
          } else {
            // 通常のタスクはバックグラウンドで実行（UIをブロックしない）
            Future.microtask(() {
              _performBackgroundTasks(
                newTodo: newTodo,
                updatedTodos: updatedTodos,
                autoRecurrence: autoRecurrence,
                date: date,
                detectedUrl: detectedUrl,
                customListId: customListId,
              );
            });
          }
        },
      );
    }).value;
  }

  /// バックグラウンドで全ての非同期タスクを実行（UIをブロックしない）
  ///
  /// 戻り値: 更新された todos マップ
  Future<Map<DateTime?, List<Todo>>> _performBackgroundTasks({
    required Todo newTodo,
    required Map<DateTime?, List<Todo>> updatedTodos,
    required RecurrencePattern? autoRecurrence,
    required DateTime? date,
    required String? detectedUrl,
    required String? customListId,
  }) async {
    try {
      AppLogger.info(
        '🔄 [BACKGROUND] autoRecurrence=$autoRecurrence, date=$date',
      );

      // Phase C.2.3: リカーリングタスクの場合、将来のインスタンスを事前生成（14日分）
      if (autoRecurrence != null && date != null) {
        AppLogger.info('🔄 [BACKGROUND] Generating recurring instances...');
        final generateUseCase = _ref.read(
          generateRecurringInstancesUseCaseProvider,
        );
        final generateResult = await generateUseCase(
          GenerateRecurringInstancesParams(
            parentTodo: newTodo,
            currentTodos: updatedTodos,
          ),
        );

        generateResult.fold(
          (failure) {
            AppLogger.error(
              '❌ Failed to generate recurring instances: ${failure.message}',
            );
          },
          (updatedTodosWithRecurring) {
            // 生成したインスタンスで状態更新
            updatedTodos = updatedTodosWithRecurring;
            // 🐛 Fix: state に反映させないと _saveAllTodosToLocal() が古い state を保存してしまう
            state = AsyncValue.data(updatedTodos);
            AppLogger.info('[Todos] ✅ Recurring instances generated (14 days)');
          },
        );

        // 生成したインスタンスをローカルに保存
        AppLogger.debug(' Saving recurring instances to local storage...');
        await _saveAllTodosToLocal();
        AppLogger.info(' Recurring instances saved');
      }

      // Widgetを更新
      await _updateWidget();

      // URLメタデータ取得（非同期・バックグラウンド）
      if (detectedUrl != null) {
        _fetchLinkPreviewInBackground(newTodo.id, date, detectedUrl);
      }

      // 未同期カウントを更新
      _updateUnsyncedCount();

      // グループリストのTodoの場合、グループタスクとして同期
      if (customListId != null) {
        final customListsAsync = _ref.read(customListsProvider);
        final isGroup =
            await customListsAsync.whenData((customLists) async {
              final list = customLists.firstWhere(
                (l) => l.id == customListId,
                orElse: () => CustomList(
                  id: '',
                  name: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              return list.isGroup;
            }).value ??
            false;

        if (isGroup) {
          // 🔥 Phase 8.3 Fix: グループTodoをローカルストレージに保存
          await _saveAllTodosToLocal();
          AppLogger.info('📤 Syncing to group list: $customListId');
          _syncToNostr(() async {
            await _syncGroupToNostr(customListId);
          });
          return updatedTodos; // 通常のTodo同期はスキップ
        }
      }

      // 🔥 即座に同期（バックグラウンド）
      AppLogger.info('📦 Syncing to Nostr immediately (background)');
      _syncToNostrBackground();
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ Background task failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 更新された todos を返す
    return updatedTodos;
  }

  /// バックグラウンドでリンクプレビューを取得
  Future<void> _fetchLinkPreviewInBackground(
    String todoId,
    DateTime? date,
    String url,
  ) async {
    // リンクプレビュー生成は対象 URL のホストへ直接 HTTP アクセスする。これは
    // リレー用 SOCKS プロキシを経由しないため、Tor モード時に実 IP が第三者へ
    // 漏れる。リモート取得が許可された場合（Tor 無効）のみ実行する。
    if (!_ref.read(remoteContentFetchAllowedProvider)) {
      AppLogger.debug(
        ' Skip link preview fetch (remote content fetch disabled / Tor mode)',
      );
      return;
    }
    try {
      AppLogger.debug(' Fetching link preview for: $url');
      final linkPreview = await LinkPreviewService.fetchLinkPreview(url);

      if (linkPreview != null) {
        AppLogger.info(' Link preview fetched, updating todo...');

        // Todoを更新（リンクプレビューのみ更新、タイトルは既に処理済み）
        state.whenData((todos) async {
          final list = List<Todo>.from(todos[date] ?? []);
          final index = list.indexWhere((t) => t.id == todoId);

          if (index != -1) {
            final currentTodo = list[index];

            AppLogger.debug(
              ' Updating link preview for: "${currentTodo.title}"',
            );

            list[index] = currentTodo.copyWith(
              linkPreview: linkPreview,
              updatedAt: DateTime.now(),
            );

            state = AsyncValue.data({
              ...todos,
              date: list,
            });

            // ローカルストレージに保存
            await _saveAllTodosToLocal();

            // Nostr同期（バックグラウンド）
            _syncToNostr(() async {
              await _syncAllTodosToNostr();
            });
          }
        });
      } else {
        // リンクプレビューの取得に失敗した場合、一時的なプレビューを削除
        AppLogger.warning(
          ' Failed to fetch link preview metadata, removing placeholder...',
        );
        state.whenData((todos) async {
          final list = List<Todo>.from(todos[date] ?? []);
          final index = list.indexWhere((t) => t.id == todoId);

          if (index != -1) {
            final currentTodo = list[index];

            list[index] = currentTodo.copyWith(
              linkPreview: null, // プレースホルダーを削除
              updatedAt: DateTime.now(),
            );

            state = AsyncValue.data({
              ...todos,
              date: list,
            });

            // ローカルストレージに保存
            await _saveAllTodosToLocal();
          }
        });
      }
    } catch (e) {
      AppLogger.warning(' Failed to fetch link preview: $e');
      // エラーの場合も一時的なプレビューを削除
      state.whenData((todos) async {
        final list = List<Todo>.from(todos[date] ?? []);
        final index = list.indexWhere((t) => t.id == todoId);

        if (index != -1) {
          final currentTodo = list[index];

          list[index] = currentTodo.copyWith(
            linkPreview: null, // プレースホルダーを削除
            updatedAt: DateTime.now(),
          );

          state = AsyncValue.data({
            ...todos,
            date: list,
          });

          // ローカルストレージに保存
          await _saveAllTodosToLocal();
        }
      });
    }
  }

  // ============================================
  // Issue #11: UNDO機能（最後に削除した1件のみ復元可能）
  // ============================================

  /// タスクをソフト削除（UIのみ削除、永続化・同期しない）
  ///
  /// SnackBarのタイムアウト後に`_confirmDelete()`が呼ばれるまで、
  /// 削除は確定しない。
  void softDeleteTodo(Todo todo) {
    // 前のタイマーがあればキャンセル（新しい削除で上書き）
    _deletionTimer?.cancel();

    // 最後に削除したタスクとして保持
    _lastDeletedTodo = todo;

    // UIから削除
    state.whenData((todos) {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      list.removeWhere((t) => t.id == todo.id);

      state = AsyncValue.data({
        ...todos,
        todo.date: list,
      });
    });

    AppLogger.info(
      '🗑️ [UNDO] Soft deleted: ${todo.title} (id: ${todo.id.substring(0, 8)})',
    );
  }

  /// 削除をUNDO（UIのみ復元、永続化・同期しない）
  void undoDeleteTodo() {
    AppLogger.info(
      '📞 [UNDO] undoDeleteTodo called, _lastDeletedTodo: ${_lastDeletedTodo != null ? _lastDeletedTodo!.title : "null"}',
    );

    if (_lastDeletedTodo == null) {
      AppLogger.warning('⚠️ [UNDO] No task to restore');
      return;
    }

    final todo = _lastDeletedTodo!;

    // タイマーをキャンセル
    AppLogger.info('⏹️ [UNDO] Canceling timer...');
    _deletionTimer?.cancel();
    _deletionTimer = null;

    // UIに復元
    state.whenData((todos) {
      final list = List<Todo>.from(todos[todo.date] ?? []);

      // 重複チェック
      if (!list.any((t) => t.id == todo.id)) {
        list.add(todo);

        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });
        AppLogger.info('✅ [UNDO] State updated with restored todo');
      } else {
        AppLogger.warning('⚠️ [UNDO] Todo already exists in state');
      }
    });

    AppLogger.info(
      '↩️ [UNDO] Restored: ${todo.title} (id: ${todo.id.substring(0, 8)})',
    );

    // クリア
    _lastDeletedTodo = null;
  }

  /// 削除を確定（永続化・同期を実行）
  ///
  /// SnackBarのタイムアウト後に呼ばれる
  ///
  /// 注意: state は既に softDeleteTodo() で更新済みなので、
  /// ここでは state を触らず、ローカルストレージと Nostr のみを更新する
  Future<void> _confirmDelete(Todo todo) async {
    AppLogger.info(
      '✅ [UNDO] Confirming delete: ${todo.title} (id: ${todo.id.substring(0, 8)})',
    );

    try {
      // グループタスクかどうかを判定
      bool isGroupTask = false;
      if (todo.customListId != null) {
        final customListsAsync = _ref.read(customListsProvider);
        final customLists =
            customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
        final customList = customLists
            .where((l) => l.id == todo.customListId)
            .firstOrNull;
        isGroupTask = customList?.isGroup ?? false;
      }

      // Issue #11: state は触らず、ローカルストレージから直接削除
      final repository = _ref.read(todoRepositoryProvider);
      final deleteResult = await repository.deleteTodoFromLocal(todo.id);

      deleteResult.fold(
        (failure) {
          AppLogger.error(
            '❌ [UNDO] Failed to delete from local storage: ${failure.message}',
          );
          // state は壊さない（既に softDeleteTodo で更新済み）
        },
        (_) {
          AppLogger.info('✅ [UNDO] Deleted from local storage successfully');
        },
      );

      // Issue #11: Nostr に同期
      if (isGroupTask) {
        // グループタスクの場合は MLS イベントを送信
        AppLogger.info('📤 [UNDO] Sending MLS delete event for group task...');
        await _sendMlsGroupTodoAction(
          groupId: todo.customListId!,
          action: 'delete',
          todo: todo,
          todoIdOverride: todo.id,
        );
      } else {
        // 通常のタスクの場合は全体を同期
        AppLogger.info('📤 [UNDO] Syncing all todos to Nostr (background)...');
        _syncToNostrBackground();
      }

      AppLogger.info('🎉 [UNDO] Delete confirmed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [UNDO] _confirmDelete failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // state は壊さない（既に softDeleteTodo で更新済み）
    }

    // クリア
    _lastDeletedTodo = null;
    _deletionTimer = null;
  }

  /// SnackBarのタイムアウト後に削除を確定するタイマーを設定
  void scheduleDeleteConfirmation(Duration delay) {
    AppLogger.info(
      '📞 [UNDO] scheduleDeleteConfirmation called, _lastDeletedTodo: ${_lastDeletedTodo != null ? _lastDeletedTodo!.title : "null"}',
    );

    if (_lastDeletedTodo == null) {
      AppLogger.warning('⚠️ [UNDO] Cannot schedule: _lastDeletedTodo is null');
      return;
    }

    final todo = _lastDeletedTodo!;

    _deletionTimer = Timer(delay, () async {
      AppLogger.info('⏰ [UNDO] Timer fired! Calling _confirmDelete...');
      await _confirmDelete(todo);
    });

    AppLogger.info(
      '⏱️ [UNDO] Scheduled delete confirmation in ${delay.inSeconds}s for: ${todo.title}',
    );
  }

  // ============================================
  // End of UNDO機能
  // ============================================

  /// Nostrから取得したTodoを追加（既存データを保持）
  Future<void> addTodoWithData(Todo todo) async {
    state.whenData((todos) {
      final list = List<Todo>.from(todos[todo.date] ?? []);

      // 同じIDが存在しないことを確認
      if (!list.any((t) => t.id == todo.id)) {
        list.add(todo);

        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });
      }
    });
  }

  // ============================================
  // Subtask / Task-Link operations
  // ============================================

  /// 親タスクのサブタスク展開状態を返す
  bool isSubtasksExpanded(String parentId) {
    return _ref.read(subtaskExpansionProvider).contains(parentId);
  }

  /// 親タスクのサブタスク表示をトグルする
  void toggleSubtasksExpanded(String parentId) {
    final notifier = _ref.read(subtaskExpansionProvider.notifier);
    final current = notifier.state;
    if (current.contains(parentId)) {
      notifier.state = current.where((id) => id != parentId).toSet();
    } else {
      notifier.state = {...current, parentId};
    }
  }

  /// 指定タスクのサブタスク一覧を取得
  List<Todo> getSubtasks(String parentId) {
    final todos = state.valueOrNull;
    if (todos == null) return [];
    final all = <Todo>[];
    for (final group in todos.values) {
      all.addAll(group.where((t) => t.parentTaskId == parentId));
    }
    all.sort((a, b) => a.order.compareTo(b.order));
    return all;
  }

  /// サブタスクの完了率を計算 (0.0 ~ 1.0)
  double getSubtaskProgress(String parentId) {
    final subs = getSubtasks(parentId);
    if (subs.isEmpty) return 0.0;
    return subs.where((t) => t.completed).length / subs.length;
  }

  /// サブタスクを追加
  Future<void> addSubtask(String parentId, String title, DateTime? date) async {
    if (title.trim().isEmpty) return;

    await state.whenData((todos) async {
      // 親タスクを検索
      Todo? parent;
      for (final group in todos.values) {
        for (final t in group) {
          if (t.id == parentId) {
            parent = t;
            break;
          }
        }
        if (parent != null) break;
      }
      if (parent == null) return;
      if (parent.isSubtask) {
        AppLogger.warning(
          '[Subtask] Blocked grandchild creation for parentId=$parentId',
        );
        return;
      }

      final effectiveDate = date ?? parent.date;
      final siblings = getSubtasks(parentId);
      final maxOrder = siblings.isEmpty
          ? 0
          : siblings.map((s) => s.order).reduce((a, b) => a > b ? a : b);

      final createTodoUseCase = _ref.read(createTodoUseCaseProvider);
      final result = await createTodoUseCase(
        CreateTodoParams(
          title: title,
          date: effectiveDate,
          customListId: parent.customListId,
          currentTodos: todos,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('Failed to create subtask: ${failure.message}');
        },
        (newTodo) async {
          final subtask = newTodo.copyWith(
            parentTaskId: parentId,
            depth: parent!.depth + 1,
            order: maxOrder + 1,
          );

          final list = List<Todo>.from(todos[effectiveDate] ?? []);
          list.add(subtask);

          state = AsyncValue.data({...todos, effectiveDate: list});

          await _saveAllTodosToLocal();
          await _updateWidget();
          _updateUnsyncedCount();
          _syncToNostr(() => _syncAllTodosToNostr());
        },
      );
    }).value;
  }

  /// タスクリンクを追加（双方向）
  Future<void> addTaskLink(
    String sourceId,
    String targetId,
    TaskLinkType linkType,
  ) async {
    await state.whenData((todos) async {
      var updated = Map<DateTime?, List<Todo>>.from(todos);

      // source にリンク追加
      updated = _addLinkToTodo(updated, sourceId, targetId, linkType);
      // target に逆方向リンク追加
      updated = _addLinkToTodo(updated, targetId, sourceId, linkType.inverse);

      state = AsyncValue.data(updated);
      await _saveAllTodosToLocal();
      _syncToNostr(() => _syncAllTodosToNostr());
    }).value;
  }

  /// タスクリンクを削除（双方向）
  Future<void> removeTaskLink(
    String sourceId,
    String targetId,
    TaskLinkType linkType,
  ) async {
    await state.whenData((todos) async {
      var updated = Map<DateTime?, List<Todo>>.from(todos);

      updated = _removeLinkFromTodo(updated, sourceId, targetId, linkType);
      updated = _removeLinkFromTodo(
        updated,
        targetId,
        sourceId,
        linkType.inverse,
      );

      state = AsyncValue.data(updated);
      await _saveAllTodosToLocal();
      _syncToNostr(() => _syncAllTodosToNostr());
    }).value;
  }

  /// ID からタスクを検索
  Todo? findTodoById(String id) {
    final todos = state.valueOrNull;
    if (todos == null) return null;
    for (final group in todos.values) {
      for (final t in group) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  /// 全タスクのフラットリスト（検索用）
  List<Todo> get allTodosFlat {
    final todos = state.valueOrNull;
    if (todos == null) return [];
    return todos.values.expand((g) => g).toList();
  }

  Map<DateTime?, List<Todo>> _addLinkToTodo(
    Map<DateTime?, List<Todo>> todos,
    String todoId,
    String targetId,
    TaskLinkType linkType,
  ) {
    final result = <DateTime?, List<Todo>>{};
    for (final entry in todos.entries) {
      result[entry.key] = entry.value.map((t) {
        if (t.id == todoId) {
          final links = List<TaskLink>.from(t.taskLinks);
          if (!links.any(
            (l) => l.targetTaskId == targetId && l.linkType == linkType,
          )) {
            links.add(TaskLink(targetTaskId: targetId, linkType: linkType));
          }
          // updatedAtを更新しないと、syncのLWWマージ(remoteUpdated.isAfter)で
          // リンク変更が他端末に伝播しないことがある。
          return t.copyWith(
            taskLinks: links,
            needsSync: true,
            updatedAt: DateTime.now(),
          );
        }
        return t;
      }).toList();
    }
    return result;
  }

  Map<DateTime?, List<Todo>> _removeLinkFromTodo(
    Map<DateTime?, List<Todo>> todos,
    String todoId,
    String targetId,
    TaskLinkType linkType,
  ) {
    final result = <DateTime?, List<Todo>>{};
    for (final entry in todos.entries) {
      result[entry.key] = entry.value.map((t) {
        if (t.id == todoId) {
          final links = List<TaskLink>.from(t.taskLinks);
          links.removeWhere(
            (l) => l.targetTaskId == targetId && l.linkType == linkType,
          );
          // updatedAtを更新しないと、syncのLWWマージでリンク削除が他端末に
          // 伝播せず、削除済みリンクが復活することがある。
          return t.copyWith(
            taskLinks: links,
            needsSync: true,
            updatedAt: DateTime.now(),
          );
        }
        return t;
      }).toList();
    }
    return result;
  }

  /// 親タスクとその子タスクを一括で完了にする
  Future<void> completeParentAndSubtasks(String parentId) async {
    await state.whenData((todos) async {
      Todo? parentTodo;
      var hasUpdated = false;
      final now = DateTime.now();
      final updated = <DateTime?, List<Todo>>{};

      for (final entry in todos.entries) {
        updated[entry.key] = entry.value.map((todo) {
          final isParent = todo.id == parentId;
          final isChild = todo.parentTaskId == parentId;
          if (!isParent && !isChild) {
            return todo;
          }

          if (isParent) {
            parentTodo = todo;
          }

          if (todo.completed) {
            return todo;
          }

          hasUpdated = true;
          return todo.copyWith(
            completed: true,
            updatedAt: now,
            needsSync: true,
          );
        }).toList();
      }

      if (!hasUpdated) {
        return;
      }

      // 親を完了したら、一覧上の子表示は閉じる
      final expansionNotifier = _ref.read(subtaskExpansionProvider.notifier);
      expansionNotifier.state = expansionNotifier.state
          .where((id) => id != parentId)
          .toSet();

      state = AsyncValue.data(updated);
      await _saveAllTodosToLocal();
      await _updateWidget();
      _updateUnsyncedCount();

      if (parentTodo?.customListId != null) {
        final customListsAsync = _ref.read(customListsProvider);
        final isGroup =
            await customListsAsync.whenData((customLists) async {
              final list = customLists.firstWhere(
                (l) => l.id == parentTodo!.customListId!,
                orElse: () => CustomList(
                  id: '',
                  name: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              return list.isGroup;
            }).value ??
            false;

        if (isGroup) {
          _syncToNostr(() async {
            await _syncGroupToNostr(parentTodo!.customListId!);
          });
          return;
        }
      }

      _syncToNostrBackground();
    }).value;
  }

  // ============================================
  // End of Subtask / Task-Link operations
  // ============================================

  /// Todoを更新（楽観的UI更新）
  ///
  /// Phase B: UpdateTodoUseCaseを使用してTodoを更新
  Future<void> updateTodo(Todo todo) async {
    await state.whenData((todos) async {
      // Phase B: UpdateTodoUseCaseを使ってTodoを更新
      final updateTodoUseCase = _ref.read(updateTodoUseCaseProvider);
      final result = await updateTodoUseCase(
        UpdateTodoParams(
          todo: todo,
          currentTodos: todos,
        ),
      );

      result.fold(
        (failure) {
          // エラーハンドリング
          AppLogger.error('❌ Failed to update todo: ${failure.message}');
          state = AsyncValue.error(failure, StackTrace.current);
        },
        (updatedTodos) async {
          // 【楽観的UI更新】即座にUI更新
          state = AsyncValue.data(updatedTodos);

          // ローカルストレージに保存（awaitする）
          await _saveAllTodosToLocal();

          // Widgetを更新
          await _updateWidget();

          // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
          _updateUnsyncedCount();

          // グループリストのTodoの場合、グループタスクとして同期
          if (todo.customListId != null) {
            final customListsAsync = _ref.read(customListsProvider);
            final isGroup =
                await customListsAsync.whenData((customLists) async {
                  final list = customLists.firstWhere(
                    (l) => l.id == todo.customListId!,
                    orElse: () => CustomList(
                      id: '',
                      name: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  return list.isGroup;
                }).value ??
                false;

            if (isGroup) {
              AppLogger.info('📤 Syncing to group list: ${todo.customListId}');
              _syncToNostr(() async {
                await _syncGroupToNostr(todo.customListId!);
              });
              return; // 通常のTodo同期はスキップ
            }
          }

          _syncToNostrBackground();
        },
      );
    }).value;
  }

  /// Todoのタイトルを更新（楽観的UI更新）
  Future<void> updateTodoTitle(
    String id,
    DateTime? date,
    String newTitle,
  ) async {
    if (newTitle.trim().isEmpty) return;

    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          title: newTitle.trim(),
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存（awaitする）
        await _saveAllTodosToLocal();

        // Widgetを更新
        await _updateWidget();

        // 【楽観的UI更新】即座に同期（バックグラウンド）
        _updateUnsyncedCount();
        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoのカスタムリスト紐づけを更新（楽観的UI更新）
  Future<void> updateTodoCustomListId(
    String id,
    DateTime? date,
    String? customListId,
  ) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          customListId: customListId,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存（awaitする）
        await _saveAllTodosToLocal();

        // Widgetを更新
        await _updateWidget();

        // 【楽観的UI更新】即座に同期（バックグラウンド）
        _updateUnsyncedCount();
        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoの添付画像URLを更新（楽観的UI更新）
  Future<void> updateTodoImageUrl(
    String id,
    DateTime? date,
    String? imageUrl,
  ) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          imageUrl: imageUrl,
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        await _saveAllTodosToLocal();
        await _updateWidget();
        _updateUnsyncedCount();
        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoのタイトルと繰り返しパターンを更新（楽観的UI更新）
  Future<void> updateTodoWithRecurrence(
    String id,
    DateTime? date,
    String newTitle,
    RecurrencePattern? recurrence,
  ) async {
    if (newTitle.trim().isEmpty) return;

    AppLogger.info(
      '🔄 [UPDATE] updateTodoWithRecurrence called: id=${id.substring(0, 8)}, newTitle="$newTitle"',
    );

    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final oldTitle = list[index].title;
        AppLogger.info(
          '🔄 [UPDATE] Found todo: oldTitle="$oldTitle", newTitle="$newTitle"',
        );
        // URLを検出してメタデータを取得（バックグラウンド）
        final detectedUrl = LinkPreviewService.extractUrl(newTitle.trim());
        AppLogger.debug(' URL detected in update: $detectedUrl');

        // URLが検出された場合、即座にタイトルから削除
        var finalTitle = newTitle.trim();
        LinkPreview? initialLinkPreview;

        if (detectedUrl != null) {
          // URLからドメイン名を抽出
          var domainName = detectedUrl;
          try {
            final uri = Uri.parse(detectedUrl);
            domainName = uri.host;
          } catch (e) {
            // パースエラー時はそのままURLを使用
          }

          finalTitle = LinkPreviewService.removeUrlFromText(
            newTitle.trim(),
            detectedUrl,
          );
          // 空になった場合（URLのみの入力）はドメイン名を使用
          if (finalTitle.trim().isEmpty) {
            finalTitle = domainName;
          }

          // リンクプレビューの初期表示。Tor 等でリモート取得がスキップされる場合は
          // 「読み込み中」のまま固まらないよう、ドメイン名のみの確定表示にする。
          final showPreviewLoading = _ref.read(
            remoteContentFetchAllowedProvider,
          );
          initialLinkPreview = LinkPreview(
            url: detectedUrl,
            title: domainName, // ドメイン名を表示
            description: showPreviewLoading ? '読み込み中...' : null,
          );

          AppLogger.debug(
            ' Title after URL removal (update): "$finalTitle" (domain: $domainName)',
          );
        } else {
          // URLが検出されなかった場合は linkPreview を削除
          initialLinkPreview = null;
          AppLogger.debug(' No URL detected - removing linkPreview');
        }

        final updatedTodo = list[index].copyWith(
          title: finalTitle,
          recurrence: recurrence,
          linkPreview: initialLinkPreview,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        AppLogger.info(
          '🔄 [UPDATE] Updating todo: title="${updatedTodo.title}", needsSync=${updatedTodo.needsSync}',
        );

        list[index] = updatedTodo;

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        AppLogger.info(
          '✅ [UPDATE] State updated with new title: "${updatedTodo.title}"',
        );

        // Phase C.2.3: リカーリングタスクの場合、将来のインスタンスを事前生成
        if (recurrence != null && date != null) {
          // 最新のstateを取得
          var currentTodos = state.valueOrNull ?? {};

          // 既存の子インスタンスを削除
          final removeUseCase = _ref.read(removeChildInstancesUseCaseProvider);
          final removeResult = await removeUseCase(
            RemoveChildInstancesParams(
              parentId: id,
              currentTodos: currentTodos,
            ),
          );

          removeResult.fold(
            (failure) {
              AppLogger.error(
                '❌ Failed to remove child instances: ${failure.message}',
              );
            },
            (todosAfterRemove) {
              currentTodos = todosAfterRemove;
              AppLogger.debug('[Todos] ✅ Child instances removed');
            },
          );

          // 新しいインスタンスを生成
          final generateUseCase = _ref.read(
            generateRecurringInstancesUseCaseProvider,
          );
          final generateResult = await generateUseCase(
            GenerateRecurringInstancesParams(
              parentTodo: updatedTodo,
              currentTodos: currentTodos,
            ),
          );

          generateResult.fold(
            (failure) {
              AppLogger.error(
                '❌ Failed to generate recurring instances: ${failure.message}',
              );
            },
            (updatedTodosWithRecurring) {
              state = AsyncValue.data(updatedTodosWithRecurring);
              AppLogger.info('[Todos] ✅ Recurring instances generated');
            },
          );
        } else if (recurrence == null) {
          // Phase C.2.3: 繰り返しを解除した場合、子タスクを削除
          final removeUseCase = _ref.read(removeChildInstancesUseCaseProvider);

          // 最新のstateを取得してから削除処理を実行
          final currentTodos = state.valueOrNull ?? {};
          final removeResult = await removeUseCase(
            RemoveChildInstancesParams(
              parentId: id,
              currentTodos: currentTodos,
            ),
          );

          removeResult.fold(
            (failure) {
              AppLogger.error(
                '❌ Failed to remove child instances: ${failure.message}',
              );
            },
            (todosAfterRemove) {
              state = AsyncValue.data(todosAfterRemove);
              AppLogger.debug(
                '[Todos] ✅ Child instances removed (recurrence disabled)',
              );
            },
          );
        }

        // ローカルストレージに保存（awaitする）
        AppLogger.info('💾 [UPDATE] Saving to local storage...');
        await _saveAllTodosToLocal();
        AppLogger.info('✅ [UPDATE] Saved to local storage');

        // Widgetを更新
        await _updateWidget();

        // URLメタデータ取得（非同期・バックグラウンド）
        if (detectedUrl != null) {
          _fetchLinkPreviewInBackground(id, date, detectedUrl);
        }

        // 【楽観的UI更新】バッチ同期タイマーに追加（即座の同期を避ける）
        _updateUnsyncedCount();
        _syncToNostrBackground();
        AppLogger.info(
          '🚀 [UPDATE] updateTodoWithRecurrence completed successfully',
        );
      } else {
        AppLogger.error(
          '❌ [UPDATE] Todo not found in list: id=${id.substring(0, 8)}',
        );
      }
    }).value;
  }

  /// 単一インスタンスのタイトルのみを更新（リカーリング情報は変更せず、親から独立）
  Future<void> updateSingleInstanceTitle(
    String id,
    DateTime? date,
    String newTitle,
  ) async {
    if (newTitle.trim().isEmpty) return;

    AppLogger.info(
      '🔄 [UPDATE] updateSingleInstanceTitle called: id=${id.substring(0, 8)}, newTitle="$newTitle"',
    );

    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final oldTitle = list[index].title;
        AppLogger.info(
          '🔄 [UPDATE] Found todo: oldTitle="$oldTitle", newTitle="$newTitle"',
        );

        // URLを検出してメタデータを取得（バックグラウンド）
        final detectedUrl = LinkPreviewService.extractUrl(newTitle.trim());
        AppLogger.debug(' URL detected in update: $detectedUrl');

        // URLが検出された場合、即座にタイトルから削除
        var finalTitle = newTitle.trim();
        LinkPreview? initialLinkPreview;

        if (detectedUrl != null) {
          // URLからドメイン名を抽出
          var domainName = detectedUrl;
          try {
            final uri = Uri.parse(detectedUrl);
            domainName = uri.host;
          } catch (e) {
            // パースエラー時はそのままURLを使用
          }

          finalTitle = LinkPreviewService.removeUrlFromText(
            newTitle.trim(),
            detectedUrl,
          );
          // 空になった場合（URLのみの入力）はドメイン名を使用
          if (finalTitle.trim().isEmpty) {
            finalTitle = domainName;
          }

          // リンクプレビューの初期表示。Tor 等でリモート取得がスキップされる場合は
          // 「読み込み中」のまま固まらないよう、ドメイン名のみの確定表示にする。
          final showPreviewLoading = _ref.read(
            remoteContentFetchAllowedProvider,
          );
          initialLinkPreview = LinkPreview(
            url: detectedUrl,
            title: domainName,
            description: showPreviewLoading ? '読み込み中...' : null,
          );

          AppLogger.debug(
            ' Title after URL removal (single update): "$finalTitle" (domain: $domainName)',
          );
        } else {
          // URLが検出されなかった場合は linkPreview を削除
          initialLinkPreview = null;
          AppLogger.debug(' No URL detected - removing linkPreview');
        }

        // 単一インスタンスのみ更新（親から独立させる）
        final updatedTodo = list[index].copyWith(
          title: finalTitle,
          linkPreview: initialLinkPreview,
          // リカーリング情報は保持するが、親との紐づけは解除しない
          // （ユーザーが単一インスタンスのみ更新を選択した場合は、
          // このインスタンスだけ別のタイトルを持つことができる）
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        AppLogger.info(
          '🔄 [UPDATE] Updating single instance: title="${updatedTodo.title}", needsSync=${updatedTodo.needsSync}',
        );

        list[index] = updatedTodo;

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        AppLogger.info(
          '✅ [UPDATE] State updated with new title: "${updatedTodo.title}"',
        );

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Widgetを更新
        await _updateWidget();

        // バックグラウンドでメタデータを取得。
        // リンクプレビュー生成は対象ホストへ直接 HTTP アクセスし、SOCKS プロキシを
        // 経由しないため、Tor モード時は実 IP 漏洩を避けるためスキップする。
        if (detectedUrl != null &&
            _ref.read(remoteContentFetchAllowedProvider)) {
          Future<void>.microtask(() async {
            try {
              final linkPreview = await LinkPreviewService.fetchLinkPreview(
                detectedUrl,
              );

              // メタデータ取得後、タスクを再度更新
              await state.whenData((currentTodos) async {
                final currentList = List<Todo>.from(currentTodos[date] ?? []);
                final currentIndex = currentList.indexWhere((t) => t.id == id);

                if (currentIndex != -1) {
                  currentList[currentIndex] = currentList[currentIndex]
                      .copyWith(
                        linkPreview: linkPreview,
                        updatedAt: DateTime.now(),
                        needsSync: true,
                      );

                  state = AsyncValue.data({
                    ...currentTodos,
                    date: currentList,
                  });

                  await _saveAllTodosToLocal();
                  await _updateWidget();

                  AppLogger.info(' Link preview fetched and updated');
                }
              }).value;
            } catch (e) {
              AppLogger.error('Failed to fetch link preview: $e');
            }
          });
        }

        // 即座に同期（バックグラウンド）
        _updateUnsyncedCount();
        _syncToNostrBackground();

        AppLogger.info(
          '🚀 [UPDATE] updateSingleInstanceTitle completed successfully',
        );
      } else {
        AppLogger.error(
          '❌ [UPDATE] Todo not found in list: id=${id.substring(0, 8)}',
        );
      }
    }).value;
  }

  /// リンクプレビューを削除（楽観的UI更新）
  Future<void> removeLinkPreview(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          linkPreview: null,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存（awaitする）
        await _saveAllTodosToLocal();

        // Widgetを更新
        await _updateWidget();

        // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
        _updateUnsyncedCount();

        // グループリストのTodoの場合、グループタスクとして同期
        final updatedTodo = list[index];
        if (updatedTodo.customListId != null) {
          final customListsAsync = _ref.read(customListsProvider);
          final isGroup =
              await customListsAsync.whenData((customLists) async {
                final list = customLists.firstWhere(
                  (l) => l.id == updatedTodo.customListId!,
                  orElse: () => CustomList(
                    id: '',
                    name: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
                return list.isGroup;
              }).value ??
              false;

          if (isGroup) {
            AppLogger.info(
              '📤 Syncing to group list: ${updatedTodo.customListId}',
            );
            _syncToNostr(() async {
              await _syncGroupToNostr(updatedTodo.customListId!);
            });
            return; // 通常のTodo同期はスキップ
          }
        }

        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoの完了状態をトグル（楽観的UI更新）
  ///
  /// Phase B: UpdateTodoUseCaseを使用してTodoを更新
  Future<void> toggleTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final todo = list[index];
        final wasCompleted = todo.completed;

        // Phase B: UpdateTodoUseCaseを使ってTodoを更新
        final updatedTodo = todo.copyWith(
          completed: !todo.completed,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        final updateTodoUseCase = _ref.read(updateTodoUseCaseProvider);
        final result = await updateTodoUseCase(
          UpdateTodoParams(
            todo: updatedTodo,
            currentTodos: todos,
          ),
        );

        await result.fold(
          (failure) async {
            // エラーハンドリング
            AppLogger.error('❌ Failed to toggle todo: ${failure.message}');
            state = AsyncValue.error(failure, StackTrace.current);
          },
          (updatedTodos) async {
            // スマートな再生成: 残りインスタンスが閾値以下の場合のみ追加生成（タイプ別ウィンドウ）
            AppLogger.debug(
              '[Todos] 🔍 Toggle check: wasCompleted=$wasCompleted, recurrence=${todo.recurrence}, date=${todo.date}',
            );
            if (!wasCompleted && todo.recurrence != null && todo.date != null) {
              final remainingInstances = _countRemainingRecurringInstances(
                todo,
                updatedTodos,
              );
              final threshold = _recurringRegenerateThreshold(todo);

              AppLogger.info(
                '[Todos] 📊 残りインスタンス: $remainingInstances件 (閾値: $threshold)',
              );

              if (remainingInstances <= threshold) {
                AppLogger.info(
                  '[Todos] 🔄 残りインスタンス: $remainingInstances件 → 次のウィンドウ分を生成します',
                );
                final updatedTodosAfterRecurring =
                    await _createNextRecurringTask(todo, updatedTodos);
                if (updatedTodosAfterRecurring != null) {
                  updatedTodos = updatedTodosAfterRecurring;
                }
              } else {
                AppLogger.debug(
                  '[Todos] ⏭️ 残りインスタンス: $remainingInstances件 → 再生成スキップ',
                );
              }
            } else {
              AppLogger.debug('[Todos] ⏭️ 再生成条件を満たしていません');
            }

            // 【楽観的UI更新】即座にUI更新
            state = AsyncValue.data(updatedTodos);

            // ローカルストレージに保存（awaitする）
            await _saveAllTodosToLocal();

            // Widgetを更新
            await _updateWidget();

            // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
            _updateUnsyncedCount();

            // グループリストのTodoの場合、グループタスクとして同期
            if (todo.customListId != null) {
              final customListsAsync = _ref.read(customListsProvider);
              final isGroup =
                  await customListsAsync.whenData((customLists) async {
                    final list = customLists.firstWhere(
                      (l) => l.id == todo.customListId!,
                      orElse: () => CustomList(
                        id: '',
                        name: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return list.isGroup;
                  }).value ??
                  false;

              if (isGroup) {
                AppLogger.info(
                  '📤 Syncing to group list: ${todo.customListId}',
                );
                _syncToNostr(() async {
                  await _syncGroupToNostr(todo.customListId!);
                });
                return; // 通常のTodo同期はスキップ
              }
            }

            // 【楽観的UI更新】即座に同期（バックグラウンド）
            _syncToNostrBackground();
          },
        );
      }
    }).value;
  }

  /// Phase C.2.3: リカーリングタスクの次回インスタンスを生成（14日分）
  ///
  /// タスク完了時に将来のインスタンスを再生成します（残り7日分以下の場合）。
  /// ローリングウィンドウ方式で常に「今日 + 13日先まで」をカバーします。
  ///
  /// 戻り値: 更新された todos マップ（生成失敗時は null）
  Future<Map<DateTime?, List<Todo>>?> _createNextRecurringTask(
    Todo originalTodo,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    if (originalTodo.recurrence == null || originalTodo.date == null) {
      return null;
    }

    AppLogger.debug('[Todos] リカーリングタスク完了: ${originalTodo.title}');
    AppLogger.debug('[Todos] 将来のインスタンスを再生成します（14日分）');

    // 親タスクのIDを特定（このタスクが子インスタンスの場合は親IDを使用）
    final parentId = originalTodo.parentRecurringId ?? originalTodo.id;

    // このリカーリングタスクの親となるタスクを探す
    Todo? parentTask;
    for (final dateGroup in todos.values) {
      for (final task in dateGroup) {
        if (task.id == parentId) {
          parentTask = task;
          break;
        }
      }
      if (parentTask != null) break;
    }

    // 親タスクが見つからない場合は、完了したタスク自身を使用
    parentTask ??= originalTodo;

    AppLogger.debug('[Todos] 親タスクID: ${parentTask.id}');
    AppLogger.debug('[Todos] 元のタスクの日付: ${parentTask.date}');

    // Phase C.2.3: GenerateRecurringInstancesUseCaseを使用
    final generateUseCase = _ref.read(
      generateRecurringInstancesUseCaseProvider,
    );
    final generateResult = await generateUseCase(
      GenerateRecurringInstancesParams(
        parentTodo: parentTask,
        currentTodos: todos,
      ),
    );

    Map<DateTime?, List<Todo>>? result;

    generateResult.fold(
      (failure) {
        AppLogger.error(
          '❌ Failed to generate next recurring instances: ${failure.message}',
        );
        result = null;
      },
      (updatedTodos) {
        AppLogger.info('[Todos] ✅ Next recurring instances generated');
        result = updatedTodos;
      },
    );

    if (result != null) {
      // ローカルに保存
      state = AsyncValue.data(result!);
      await _saveAllTodosToLocal();

      // Nostrにも同期（バックグラウンド）
      _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }

    return result;
  }

  // Phase C.2.3: _generateFutureInstances() と _removeChildInstances() は
  // UseCaseに移行したため削除しました。
  // - GenerateRecurringInstancesUseCase
  // - RemoveChildInstancesUseCase

  /// リカーリングタスクの残りインスタンス数を数える（タイプ別ウィンドウ）
  ///
  /// スマートな再生成のために使用。残りが閾値以下になったら追加生成する。
  /// 毎日・毎週: 14日以内の件数、閾値7。毎月: 90日以内の件数、閾値2。毎年: 400日以内の件数、閾値1。
  int _countRemainingRecurringInstances(
    Todo todo,
    Map<DateTime?, List<Todo>> todos,
  ) {
    if (todo.recurrence == null) {
      return 0;
    }

    // 親タスクのIDを特定
    final parentId = todo.parentRecurringId ?? todo.id;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 繰り返しタイプに応じたウィンドウ（GenerateRecurringInstancesUseCaseと一致）
    final int windowDays;
    switch (todo.recurrence!.type) {
      case RecurrenceType.monthly:
        windowDays = 90;
        break;
      case RecurrenceType.yearly:
        windowDays = 400;
        break;
      default:
        windowDays = 14;
    }
    final windowEnd = today.add(Duration(days: windowDays));

    var count = 0;

    for (final dateGroup in todos.values) {
      for (final task in dateGroup) {
        if ((task.parentRecurringId == parentId || task.id == parentId) &&
            !task.completed &&
            task.date != null) {
          final taskDate = DateTime(
            task.date!.year,
            task.date!.month,
            task.date!.day,
          );
          if (!taskDate.isBefore(today) && !taskDate.isAfter(windowEnd)) {
            count++;
          }
        }
      }
    }

    AppLogger.debug(
      '[Todos] リカーリングタスク残りインスタンス数: $count (parentId: $parentId, ${windowDays}日以内)',
    );
    return count;
  }

  /// 繰り返しタイプごとの「再生成する残り閾値」（この数以下で再生成）
  int _recurringRegenerateThreshold(Todo todo) {
    if (todo.recurrence == null) return 0;
    switch (todo.recurrence!.type) {
      case RecurrenceType.monthly:
        return 2;
      case RecurrenceType.yearly:
        return 1;
      default:
        return 7; // 毎日・毎週
    }
  }

  /// Todoを削除（楽観的UI更新）
  ///
  /// Phase B: DeleteTodoUseCaseを使用してTodoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      // 削除前に対象Todoを取得（グループ削除通知用）
      final beforeList = List<Todo>.from(todos[date] ?? []);
      final beforeIndex = beforeList.indexWhere((t) => t.id == id);
      final beforeTodo = beforeIndex == -1 ? null : beforeList[beforeIndex];

      // Phase B: DeleteTodoUseCaseを使ってTodoを削除
      final deleteTodoUseCase = _ref.read(deleteTodoUseCaseProvider);
      final result = await deleteTodoUseCase(
        DeleteTodoParams(
          id: id,
          date: date,
          currentTodos: todos,
        ),
      );

      result.fold(
        (failure) {
          // エラーハンドリング
          AppLogger.error('❌ Failed to delete todo: ${failure.message}');
          state = AsyncValue.error(failure, StackTrace.current);
        },
        (updatedTodos) async {
          // 【楽観的UI更新】即座にUI更新
          state = AsyncValue.data(updatedTodos);

          // ローカルストレージに保存（awaitする）
          await _saveAllTodosToLocal();

          // Widgetを更新
          await _updateWidget();

          // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
          // 削除後の全TODOリストを送信（Replaceable eventなので古いイベントは自動的に置き換わる）
          _updateUnsyncedCount();

          // グループリストのTodoだった場合はMLS差分イベント（delete）を送る
          if (beforeTodo?.customListId != null) {
            final customListsAsync = _ref.read(customListsProvider);
            final isGroup =
                await customListsAsync.whenData((customLists) async {
                  final list = customLists.firstWhere(
                    (l) => l.id == beforeTodo!.customListId!,
                    orElse: () => CustomList(
                      id: '',
                      name: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  return list.isGroup;
                }).value ??
                false;

            if (isGroup) {
              final groupId = beforeTodo!.customListId!;
              _syncToNostr(() async {
                await _sendMlsGroupTodoAction(
                  groupId: groupId,
                  action: 'delete',
                  todo: beforeTodo,
                  todoIdOverride: beforeTodo.id,
                );
              });
              return;
            }
          }

          _syncToNostrBackground();
        },
      );
    }).value;
  }

  /// リカーリングタスクのこのインスタンスのみを削除（楽観的UI更新）
  Future<void> deleteRecurringInstance(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);

      // 該当するTodoを探す
      final todo = list.firstWhere((t) => t.id == id);

      // このインスタンスを削除
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      AppLogger.debug(' リカーリングタスクのインスタンスを削除: ${todo.title} ($date)');

      // ローカルストレージに保存（awaitする）
      await _saveAllTodosToLocal();

      // Widgetを更新
      await _updateWidget();

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// リカーリングタスクのすべてのインスタンスを削除（楽観的UI更新）
  Future<void> deleteAllRecurringInstances(String id, DateTime? date) async {
    await state.whenData((todos) async {
      // 削除対象のTodoを取得
      final list = List<Todo>.from(todos[date] ?? []);
      final todo = list.firstWhere((t) => t.id == id);

      // 親タスクのIDを特定
      final parentId = todo.parentRecurringId ?? todo.id;

      AppLogger.debug(' すべてのリカーリングインスタンスを削除: parentId=$parentId');

      // すべての日付から関連するタスクを削除
      var deletedCount = 0;
      final updatedTodos = Map<DateTime?, List<Todo>>.from(todos);

      for (final dateKey in updatedTodos.keys) {
        final dateList = List<Todo>.from(updatedTodos[dateKey] ?? []);
        final originalLength = dateList.length;

        // 親タスク、または親タスクから派生した子タスクをすべて削除
        dateList.removeWhere(
          (t) => t.id == parentId || t.parentRecurringId == parentId,
        );

        if (dateList.length < originalLength) {
          deletedCount += originalLength - dateList.length;
          updatedTodos[dateKey] = dateList;
        }
      }

      AppLogger.debug(' 合計$deletedCount個のリカーリングインスタンスを削除しました');

      state = AsyncValue.data(updatedTodos);

      // ローカルストレージに保存（awaitする）
      await _saveAllTodosToLocal();

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// リストに属する全てのTodoを削除
  ///
  /// Phase E.5: リスト削除時に使用
  /// カスタムリストを削除する際、そのリストに属する全てのTODOも削除
  /// Issue #101: リスト再作成時に、そのリストに関連する削除済みタスクIDをクリア
  /// ゾンビタスク問題の修正
  Future<void> clearDeletedTodoIdsForList(String listId) async {
    AppLogger.info(
      '🔄 [Issue#101] Clearing deleted todo IDs for re-created list: $listId',
    );

    final prefix = '$listId:';
    final beforeCount = _deletedTodoIds.length;

    // {listId}:{todoId} 形式のIDを全て削除
    _deletedTodoIds.removeWhere((id) => id.startsWith(prefix));

    final removedCount = beforeCount - _deletedTodoIds.length;

    if (removedCount > 0) {
      AppLogger.info(
        '✅ [Issue#101] Removed $removedCount deleted todo IDs for list: $listId',
      );

      // ローカルストレージにも反映
      await localStorageService.saveDeletedTodoIds(_deletedTodoIds.toList());
      AppLogger.info(
        '💾 [Issue#101] Updated storage (remaining: ${_deletedTodoIds.length})',
      );
    } else {
      AppLogger.info(
        'ℹ️  [Issue#101] No deleted todo IDs found for list: $listId',
      );
    }
  }

  /// Issue #101: 削除したタスクのevent_idを記録して、リスト再作成時に復活しないようにする
  Future<void> deleteAllTodosInList(String listId) async {
    await state.whenData((todos) async {
      AppLogger.info('🗑️  [Todos] Deleting all todos in list: $listId');

      var deletedCount = 0;
      final updatedTodos = Map<DateTime?, List<Todo>>.from(todos);
      final deletedTodoIds = <String>[]; // Issue #101: 削除したタスクのIDを記録

      AppLogger.info(
        '📊 [Issue#101] Current state has ${todos.keys.length} date groups',
      );

      for (final dateKey in updatedTodos.keys) {
        final dateList = List<Todo>.from(updatedTodos[dateKey] ?? []);
        final originalLength = dateList.length;

        AppLogger.debug(
          '📋 [Issue#101] Checking date group: $dateKey (${dateList.length} todos)',
        );

        // Issue #101: 削除前にタスクIDを記録（{listId}:{todoId}形式）
        for (final todo in dateList) {
          if (todo.customListId == listId) {
            final compositeId = '$listId:${todo.id}';
            deletedTodoIds.add(compositeId);
            AppLogger.info(
              '🎯 [Issue#101] Recording deleted todo ID: $compositeId (title: "${todo.title}")',
            );
          }
        }

        // 該当リストのTodoを削除
        dateList.removeWhere((t) => t.customListId == listId);

        if (dateList.length < originalLength) {
          deletedCount += originalLength - dateList.length;
          updatedTodos[dateKey] = dateList;
        }
      }

      AppLogger.info(
        '✅ [Todos] Deleted $deletedCount todos from list: $listId',
      );

      // Issue #101: 削除したタスクのIDをLocalStorageに保存
      if (deletedTodoIds.isNotEmpty) {
        AppLogger.info(
          '💾 [Issue#101] Recording ${deletedTodoIds.length} deleted todo IDs to prevent resurrection',
        );
        AppLogger.info(
          '📝 [Issue#101] Deleted todo IDs: ${deletedTodoIds.map((id) => id.substring(0, 16)).join(", ")}...',
        );

        final existingDeletedIds = await localStorageService
            .loadDeletedTodoIds();
        AppLogger.info(
          '📚 [Issue#101] Existing deleted IDs in storage: ${existingDeletedIds.length}',
        );

        final mergedDeletedIds = {
          ...existingDeletedIds,
          ...deletedTodoIds,
        }.toList();
        await localStorageService.saveDeletedTodoIds(mergedDeletedIds);

        AppLogger.info(
          '✅ [Issue#101] Saved deleted todo IDs (total: ${mergedDeletedIds.length})',
        );

        // メモリ上のブラックリストも更新
        _deletedTodoIds.addAll(deletedTodoIds);
        AppLogger.info(
          '🧠 [Issue#101] Updated in-memory blacklist (total: ${_deletedTodoIds.length})',
        );
      } else {
        AppLogger.warning(
          '⚠️ [Issue#101] No todos found to delete for list: $listId',
        );
      }

      state = AsyncValue.data(updatedTodos);

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Widgetを更新
      await _updateWidget();

      // バックグラウンドでNostr同期
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// Todoを並び替え（楽観的UI更新）
  ///
  /// [displayedList] は UI 上に表示されている順序のリスト。
  /// ReorderableListView の onReorder インデックスはこのリストに対応する。
  /// サブタスクを親グループ外にドロップした場合、ルートタスクに昇格する。
  Future<void> reorderTodo(
    DateTime? date,
    int oldIndex,
    int newIndex,
    List<Todo> displayedList,
  ) async {
    await state.whenData((todos) async {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final reordered = List<Todo>.from(displayedList);
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);

      // サブタスク昇格判定: 親グループ外に移動されたら root に昇格
      if (item.parentTaskId != null) {
        final promoted = _shouldPromoteToRoot(reordered, newIndex, item);
        if (promoted) {
          reordered[newIndex] = item.copyWith(
            parentTaskId: null,
            depth: 0,
          );
          HapticFeedback.mediumImpact();
        }
      }

      // 表示リストの新しい順序を ID → order にマッピング
      final orderMap = <String, int>{};
      final parentMap = <String, String?>{};
      final depthMap = <String, int>{};
      for (var i = 0; i < reordered.length; i++) {
        final t = reordered[i];
        orderMap[t.id] = i;
        parentMap[t.id] = t.parentTaskId;
        depthMap[t.id] = t.depth;
      }

      // raw リストを更新（非表示アイテムは末尾に配置）
      final rawList = List<Todo>.from(todos[date] ?? []);
      final now = DateTime.now();
      int nextHiddenOrder = reordered.length;
      final newList = <Todo>[];

      for (final raw in rawList) {
        final displayOrder = orderMap[raw.id];
        if (displayOrder != null) {
          newList.add(
            raw.copyWith(
              order: displayOrder,
              parentTaskId: parentMap[raw.id],
              depth: depthMap[raw.id] ?? raw.depth,
              updatedAt: now,
              needsSync: true,
            ),
          );
        } else {
          newList.add(
            raw.copyWith(
              order: nextHiddenOrder++,
              updatedAt: now,
              needsSync: true,
            ),
          );
        }
      }

      state = AsyncValue.data({
        ...todos,
        date: newList,
      });

      await _saveAllTodosToLocal();
      await _updateWidget();
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// サブタスクが親グループの外に移動されたかを判定する。
  /// 直前のアイテムが同じ親 or 親自身でなければ昇格対象。
  bool _shouldPromoteToRoot(List<Todo> list, int movedIndex, Todo item) {
    if (movedIndex == 0) return true;
    final prev = list[movedIndex - 1];
    if (prev.id == item.parentTaskId) return false;
    if (prev.parentTaskId == item.parentTaskId) return false;
    return true;
  }

  /// ルートタスクを指定した親のサブタスクに変換する。
  ///
  /// 対象タスクが既にサブタスクを持つ場合は、それらを [newParentId] の
  /// 直接の子（兄弟）に付け替える。グランドチルドは作らない。
  Future<void> convertToSubtask(String taskId, String newParentId) async {
    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(
        todos.map((k, v) => MapEntry(k, List<Todo>.from(v))),
      );

      Todo? task;
      DateTime? taskDate;
      Todo? parent;

      for (final entry in updated.entries) {
        for (final t in entry.value) {
          if (t.id == taskId) {
            task = t;
            taskDate = entry.key;
          }
          if (t.id == newParentId) {
            parent = t;
          }
        }
      }

      if (task == null || parent == null) return;
      if (parent.isSubtask) return;

      final existingSubtasks = getSubtasks(taskId);
      final now = DateTime.now();

      final dateList = updated[taskDate];
      if (dateList == null) return;

      // 対象タスクを子タスクに変換
      final taskIdx = dateList.indexWhere((t) => t.id == taskId);
      if (taskIdx == -1) return;
      dateList[taskIdx] = task.copyWith(
        parentTaskId: newParentId,
        depth: 1,
        updatedAt: now,
        needsSync: true,
      );

      // 既存のサブタスクを新しい親の直接の子に付け替え
      for (final sub in existingSubtasks) {
        for (final entry in updated.entries) {
          final list = entry.value;
          final subIdx = list.indexWhere((t) => t.id == sub.id);
          if (subIdx != -1) {
            list[subIdx] = sub.copyWith(
              parentTaskId: newParentId,
              depth: 1,
              updatedAt: now,
              needsSync: true,
            );
            break;
          }
        }
      }

      state = AsyncValue.data(updated);
      await _saveAllTodosToLocal();
      await _updateWidget();
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// サブタスクをルートタスクに昇格する。
  Future<void> promoteToRoot(String taskId) async {
    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(
        todos.map((k, v) => MapEntry(k, List<Todo>.from(v))),
      );

      for (final entry in updated.entries) {
        final list = entry.value;
        final idx = list.indexWhere((t) => t.id == taskId);
        if (idx != -1) {
          final now = DateTime.now();
          list[idx] = list[idx].copyWith(
            parentTaskId: null,
            depth: 0,
            updatedAt: now,
            needsSync: true,
          );

          state = AsyncValue.data(updated);
          await _saveAllTodosToLocal();
          await _updateWidget();
          _updateUnsyncedCount();
          _syncToNostrBackground();
          return;
        }
      }
    }).value;
  }

  /// Todoを別の日付に移動（楽観的UI更新）
  Future<void> moveTodo(String id, DateTime? fromDate, DateTime? toDate) async {
    if (fromDate == toDate) return;

    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(
        todos.map((k, v) => MapEntry(k, List<Todo>.from(v))),
      );

      final fromList = updated[fromDate] ?? [];
      final toList = updated.putIfAbsent(toDate, () => []);

      final todoIndex = fromList.indexWhere((t) => t.id == id);
      if (todoIndex == -1) return;

      final todo = fromList.removeAt(todoIndex);
      final now = DateTime.now();
      final isSubtask = todo.parentTaskId != null;

      if (isSubtask) {
        // サブタスク自身を移動 -> ルートに昇格
        final movedTodo = todo.copyWith(
          date: toDate,
          order: _getNextOrder(updated, toDate),
          updatedAt: now,
          needsSync: true,
          parentTaskId: null,
          depth: 0,
        );
        toList.add(movedTodo);
      } else {
        // ルートタスクを移動 -> 子タスクも追従
        final movedTodo = todo.copyWith(
          date: toDate,
          order: _getNextOrder(updated, toDate),
          updatedAt: now,
          needsSync: true,
        );
        toList.add(movedTodo);

        // 全日付グループからこの親の子タスクを収集して移動
        final childIds = <String>{};
        for (final dateKey in updated.keys.toList()) {
          final group = updated[dateKey]!;
          final children = group.where((t) => t.parentTaskId == id).toList();
          if (children.isEmpty) continue;
          for (final child in children) {
            childIds.add(child.id);
            group.remove(child);
            toList.add(
              child.copyWith(
                date: toDate,
                updatedAt: now,
                needsSync: true,
              ),
            );
          }
        }
      }

      updated[fromDate] = fromList;
      updated[toDate] = toList;
      state = AsyncValue.data(updated);

      await _saveAllTodosToLocal();
      await _updateWidget();
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// 次の order 値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) return 0;
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// バックグラウンドでNostr同期（awaitしない、UIをブロックしない）
  ///
  /// コールドスタート時はリレー接続がまだ確立中の場合があるため、
  /// 初回失敗時に 1 回だけ短い待機後にリトライする。
  void _syncToNostrBackground() {
    AppLogger.debug(' _syncToNostrBackground called (non-blocking)');

    final isInitialized = _ref.read(nostrInitializedProvider);
    if (!isInitialized) {
      return;
    }

    Future.microtask(() async {
      const maxAttempts = 2;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          AppLogger.info(' Background sync attempt $attempt/$maxAttempts');
          await _syncAllTodosToNostr();
          await _clearNeedsSyncFlagsForNonGroup();

          AppLogger.info(' Background sync completed successfully');
          _ref.read(syncStatusProvider.notifier).syncSuccess();
          return;
        } catch (e, stackTrace) {
          if (attempt < maxAttempts) {
            AppLogger.warning(
              ' Background sync attempt $attempt failed, retrying in 3s: $e',
            );
            await Future<void>.delayed(const Duration(seconds: 3));
            continue;
          }
          AppLogger.error(
            ' Background sync failed after $maxAttempts attempts: $e',
          );
          AppLogger.error(
            'Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
          );
          _ref
              .read(syncStatusProvider.notifier)
              .syncError(
                'Background sync error: $e',
                shouldRetry: false,
              );
        }
      }
    });
  }

  /// 未同期のTodoを取得
  List<Todo> _getUnsyncedTodos() {
    return state.when(
      data: (todos) {
        final allTodos = <Todo>[];
        for (final dateGroup in todos.values) {
          allTodos.addAll(dateGroup.where((t) => t.needsSync));
        }
        return allTodos;
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// 未同期タスク数をSyncStatusProviderに通知
  void _updateUnsyncedCount() {
    final unsyncedTodos = _getUnsyncedTodos();
    _ref.read(syncStatusProvider.notifier).state = _ref
        .read(syncStatusProvider)
        .copyWith(
          pendingItems: unsyncedTodos.length,
        );
  }

  /// 同期成功後、needsSync/eventIdをまとめて更新（1回の保存で反映）
  Future<void> _markTodosSyncedWithEventId(
    List<Todo> targetTodos,
    String eventId, {
    required bool globalBackfillPending,
  }) async {
    final todos = state.valueOrNull;
    if (todos == null || targetTodos.isEmpty) return;

    final targetIds = targetTodos.map((t) => t.id).toSet();
    final now = DateTime.now();
    final updated = <DateTime?, List<Todo>>{};
    var updatedCount = 0;

    for (final entry in todos.entries) {
      final date = entry.key;
      final list = entry.value.map((todo) {
        if (!targetIds.contains(todo.id)) return todo;
        updatedCount += 1;
        return todo.copyWith(
          eventId: eventId,
          needsSync: false,
          localRelaySyncedAt: now,
          globalSyncPending: globalBackfillPending,
          globalSyncFailed: false,
        );
      }).toList();
      updated[date] = list;
    }

    state = AsyncValue.data(updated);
    await _saveAllTodosToLocal();
    AppLogger.info(' Updated eventId for $updatedCount todos: $eventId');
  }

  void _setEventIdBeforeRelayAck(List<Todo> targetTodos, String eventId) {
    final todos = state.valueOrNull;
    if (todos == null || targetTodos.isEmpty) return;
    final targetIds = targetTodos.map((t) => t.id).toSet();

    final updated = <DateTime?, List<Todo>>{};
    for (final entry in todos.entries) {
      updated[entry.key] = entry.value.map((todo) {
        if (!targetIds.contains(todo.id)) return todo;
        return todo.copyWith(eventId: eventId);
      }).toList();
    }
    state = AsyncValue.data(updated);
  }

  void _clearEventIdForTodos(List<Todo> targetTodos) {
    final todos = state.valueOrNull;
    if (todos == null || targetTodos.isEmpty) return;
    final targetIds = targetTodos.map((t) => t.id).toSet();

    final updated = <DateTime?, List<Todo>>{};
    for (final entry in todos.entries) {
      updated[entry.key] = entry.value.map((todo) {
        if (!targetIds.contains(todo.id)) return todo;
        return todo.copyWith(eventId: null);
      }).toList();
    }
    state = AsyncValue.data(updated);
  }

  Future<void> _markGlobalBackfillStateByEventId({
    required String eventId,
    required bool success,
    String? errorMessage,
  }) async {
    final todos = state.valueOrNull;
    if (todos == null) return;

    var changed = false;
    final now = DateTime.now();
    final updated = <DateTime?, List<Todo>>{};
    for (final entry in todos.entries) {
      updated[entry.key] = entry.value.map((todo) {
        if (todo.eventId != eventId) return todo;
        changed = true;
        return todo.copyWith(
          globalSyncPending: false,
          globalSyncFailed: !success,
          globalRelaySyncedAt: success ? now : todo.globalRelaySyncedAt,
        );
      }).toList();
    }
    if (!changed) return;

    state = AsyncValue.data(updated);
    await _saveAllTodosToLocal();
    _updateUnsyncedCount();

    if (!success) {
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            'Global relay backfill failed: ${errorMessage ?? "unknown error"}',
            shouldRetry: true,
          );
    }
  }

  Future<void> _onGlobalBackfillResult(
    String eventId,
    bool success,
    String? errorMessage,
  ) async {
    await _markGlobalBackfillStateByEventId(
      eventId: eventId,
      success: success,
      errorMessage: errorMessage,
    );
  }

  Set<String> _currentGroupListIds() {
    final lists = _ref.read(customListsProvider).valueOrNull;
    if (lists == null) return <String>{};
    return lists.where((l) => l.isGroup).map((l) => l.id).toSet();
  }

  /// `syncAllTodosToNostr` はグループTODOを送らないので、ここで全消しすると
  /// 「送れていないグループTODOまで同期済みに見える」不整合になる。
  Future<void> _clearNeedsSyncFlagsForNonGroup() async {
    final todos = state.valueOrNull;
    if (todos == null) return;

    final groupIds = _currentGroupListIds();

    final updatedTodos = <DateTime?, List<Todo>>{};
    var hasChanges = false;

    for (final entry in todos.entries) {
      final date = entry.key;
      final list = entry.value.map((todo) {
        final isGroupTodo =
            todo.customListId != null && groupIds.contains(todo.customListId);
        if (todo.needsSync && !isGroupTodo) {
          hasChanges = true;
          return todo.copyWith(needsSync: false);
        }
        return todo;
      }).toList();
      updatedTodos[date] = list;
    }

    if (!hasChanges) return;

    state = AsyncValue.data(updatedTodos);
    await _saveAllTodosToLocal();
    _updateUnsyncedCount();
    AppLogger.info(' Cleared needsSync flags for non-group todos');
  }

  /// 自動バッチ同期タイマーを開始（3秒後に一度だけ実行）
  void _startBatchSyncTimer({bool force = false}) {
    // ログイン前（Nostr未初期化）ではタイマーを起動しない
    if (!force && !_ref.read(nostrInitializedProvider)) {
      return;
    }

    // 既存のタイマーをキャンセル
    _batchSyncTimer?.cancel();

    // 5秒後に一度だけ実行（リレー接続確立に余裕を持たせる）
    _batchSyncTimer = Timer(const Duration(seconds: 5), () {
      _executeBatchSync();
    });
  }

  /// バッチ同期を実行
  Future<void> _executeBatchSync() async {
    // ログイン前（Nostr未初期化）では同期しない（ログスパム防止）
    if (!_ref.read(nostrInitializedProvider)) {
      return;
    }

    final unsyncedTodos = _getUnsyncedTodos();

    // 🔥 Phase 8.3 Fix: 送信すべきTodoの処理
    if (unsyncedTodos.isNotEmpty) {
      AppLogger.info(
        ' Batch sync: ${unsyncedTodos.length} unsynced todos found',
      );

      // カスタムリスト情報を一度だけ取得（キャッシュ）
      final customListsAsync = _ref.read(customListsProvider);
      final customLists =
          await customListsAsync.whenData((lists) => lists).value ?? [];
      final groupIds = customLists
          .where((l) => l.isGroup)
          .map((l) => l.id)
          .toSet();

      // グループTodoと個人Todoを分けて処理
      final groupTodos = <String, List<Todo>>{}; // groupId -> todos
      final personalTodos = <Todo>[];

      for (final todo in unsyncedTodos) {
        if (todo.customListId != null && groupIds.contains(todo.customListId)) {
          // グループTodo
          groupTodos[todo.customListId!] ??= [];
          groupTodos[todo.customListId!]!.add(todo);
        } else {
          // 個人Todo
          personalTodos.add(todo);
        }
      }

      // グループTodoを送信（各グループごと）
      if (groupTodos.isNotEmpty) {
        AppLogger.info(
          ' Sending ${groupTodos.length} group lists (${groupTodos.values.fold(0, (sum, list) => sum + list.length)} todos)',
        );
        for (final groupId in groupTodos.keys) {
          _syncToNostr(() async {
            await _syncGroupToNostr(groupId);
          });
        }
      }

      // 個人Todoを送信
      if (personalTodos.isNotEmpty) {
        AppLogger.info(' Sending ${personalTodos.length} personal todos');
        _syncToNostrBackground();
      }
    }

    // 🔥 MLSグループ同期は別タイマーで管理（バッチ同期からは削除）
    // バッチ同期は軽量に保つため、個人Todoの送信のみを行う
  }

  /// 全MLSグループからTodoを受信（Phase 8.3）
  /// 注: バッチ同期の高速化のため、現在はバッチ同期から切り離されています。
  /// 必要に応じて別のタイマーで管理するか、手動同期で使用してください。
  // ignore: unused_element
  Future<void> _syncAllMlsGroupTodos() async {
    try {
      final publicKey = await _ref.read(nostrServiceProvider).getPublicKey();
      if (publicKey == null) {
        return;
      }

      // 全カスタムリストを取得
      final customListsAsync = _ref.read(customListsProvider);
      final customLists = await customListsAsync
          .whenData((lists) => lists)
          .value;
      if (customLists == null) {
        return;
      }

      // MLSグループのみをフィルタリング
      final mlsGroups = customLists
          .where((list) => list.isGroup && !list.isPendingInvitation)
          .toList();

      if (mlsGroups.isEmpty) {
        AppLogger.debug('📭 [MLS] No MLS groups to sync');
        return;
      }

      AppLogger.info(
        '📥 [MLS] Syncing ${mlsGroups.length} MLS groups for new todos...',
      );

      // 各グループからTodoを受信
      for (final group in mlsGroups) {
        try {
          await _syncMlsGroupTodos(
            groupId: group.id,
            publicKey: publicKey,
          );
        } catch (e) {
          AppLogger.warning('⚠️ [MLS] Failed to sync group ${group.name}: $e');
          // エラーは無視して他のグループを続行
        }
      }

      AppLogger.info('✅ [MLS] Completed syncing all MLS groups');
    } catch (e) {
      AppLogger.error('❌ [MLS] Failed to sync all MLS groups: $e');
    }
  }

  /// Notifierがdisposeされたときにタイマーをキャンセル
  @override
  void dispose() {
    AppLogger.debug(' Disposing TodosNotifier, cancelling batch sync timer');
    _batchSyncTimer?.cancel();
    super.dispose();
  }

  /// 全TODOリストをNostrに同期（新実装 - Kind 30001）
  /// すべてのTodo操作後に呼び出される
  Future<void> _syncAllTodosToNostr() async {
    AppLogger.info(' _syncAllTodosToNostr called');
    final syncStopwatch = Stopwatch()..start();
    unawaited(_ref.read(nostrServiceProvider).processGlobalBackfillQueue());

    final isInitialized = _ref.read(nostrInitializedProvider);
    AppLogger.debug(
      ' Nostr initialized in _syncAllTodosToNostr: $isInitialized',
    );

    if (!isInitialized) {
      return;
    }

    // state.whenDataは、stateがdata状態でない場合は何もしない
    // そのため、loading/error状態の場合は同期をスキップ
    final stateValue = state;
    if (!stateValue.hasValue) {
      AppLogger.warning(
        ' State is not ready (loading or error), skipping sync',
      );
      throw Exception('State is not ready for sync');
    }

    await state.whenData((todos) async {
      // ← awaitを追加！
      AppLogger.debug(' _syncAllTodosToNostr: state.whenData callback STARTED');

      // 全TODOをフラット化
      final allTodos = <Todo>[];
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }

      AppLogger.debug(' Total todos to sync: ${allTodos.length}');

      // カスタムリストに属するTodoをログ出力
      final customListTodos = allTodos
          .where((t) => t.customListId != null)
          .toList();
      if (customListTodos.isNotEmpty) {
        AppLogger.debug(
          ' Found ${customListTodos.length} todos with customListId:',
        );
        for (final todo in customListTodos) {
          AppLogger.debug(
            '   - "${todo.title}" → customListId: ${todo.customListId}',
          );
        }
      }

      final isAmberMode = _ref.read(isAmberModeProvider);
      final nostrService = _ref.read(nostrServiceProvider);

      AppLogger.debug('🔐 Amber mode: $isAmberMode');

      try {
        if (isAmberMode) {
          // Amberモード: リストごとに分割 → JSON → Amber暗号化 → 未署名イベント → Amber署名 → リレー送信
          AppLogger.debug('🔐 Amberモードでリストごとに同期します（バックグラウンド処理）');

          // カスタムリスト情報を取得（UUIDから名前ベースIDへの変換用 & グループリスト判定）
          final customListsAsync = _ref.read(customListsProvider);
          final customListsMap = <String, String>{}; // oldId -> newId
          final customListNames = <String, String>{}; // newId -> name
          final groupListIds = <String>{}; // グループリストのID
          await customListsAsync.whenData((customLists) async {
            for (final list in customLists) {
              if (list.isGroup) {
                // グループリストはIDをそのまま保持
                groupListIds.add(list.id);
              } else {
                // 通常のカスタムリストは名前ベースIDに変換
                final nameBasedId = CustomListHelpers.generateIdFromName(
                  list.name,
                );
                customListsMap[list.id] = nameBasedId;
                customListNames[nameBasedId] = list.name;
              }
            }
          }).value;

          // 1. Todoをリストごとにグループ化（名前ベースIDに変換）
          // グループリストのTodoは除外（別途 _syncGroupToNostr で同期される）
          final groupedTodos = <String, List<Todo>>{};
          for (final todo in allTodos) {
            // グループリストのTodoはスキップ
            if (todo.customListId != null &&
                groupListIds.contains(todo.customListId)) {
              AppLogger.debug(
                '   Skipping group list todo: "${todo.title}" (groupId: ${todo.customListId})',
              );
              continue;
            }

            // customListIdを名前ベースIDに変換
            String listKey;
            if (todo.customListId == null) {
              listKey = 'default';
            } else {
              // UUIDベースのIDを名前ベースIDに変換
              listKey = customListsMap[todo.customListId] ?? todo.customListId!;
            }

            groupedTodos.putIfAbsent(listKey, () => []);
            groupedTodos[listKey]!.add(todo);
          }

          AppLogger.debug(' Grouped todos into ${groupedTodos.length} lists');
          for (final entry in groupedTodos.entries) {
            final todoTitles = entry.value
                .map((t) => t.title)
                .take(3)
                .join(', ');
            AppLogger.debug(
              '  - List "${entry.key}": ${entry.value.length} todos ($todoTitles${entry.value.length > 3 ? '...' : ''})',
            );
          }

          // 2. 公開鍵取得
          var publicKey = _ref.read(publicKeyProvider);
          var npub = _ref.read(nostrPublicKeyProvider);

          // 公開鍵がnullの場合、Rust側から復元を試みる
          if (publicKey == null) {
            AppLogger.warning(
              ' Public key (hex) is null, attempting to restore from storage...',
            );
            try {
              publicKey = await nostrService.getPublicKey();
              if (publicKey != null) {
                AppLogger.info(
                  ' Public key (hex) restored from storage: ${publicKey.substring(0, 16)}...',
                );
                _ref.read(publicKeyProvider.notifier).state = publicKey;

                // npub形式にも変換して設定
                try {
                  npub = await nostrService.hexToNpub(publicKey);
                  _ref.read(nostrPublicKeyProvider.notifier).state = npub;
                  AppLogger.info(
                    ' Public key (npub) also restored: ${npub.substring(0, 16)}...',
                  );
                } catch (e) {
                  AppLogger.error(' Failed to convert hex to npub: $e');
                }
              } else {
                AppLogger.error(
                  ' Failed to restore public key - no key found in storage',
                );
                throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
              }
            } catch (e) {
              AppLogger.error(' Failed to restore public key: $e');
              throw Exception('公開鍵が設定されていません: $e');
            }
          }

          if (npub == null) {
            final hasPublicKey = await nostrService.hasPublicKey();
            final isUsingAmber = localStorageService.isUsingAmber();
            AppLogger.error(' npub形式の公開鍵がnullです');
            AppLogger.debug('   - hex公開鍵: ${publicKey.substring(0, 16)}...');
            AppLogger.debug('   - Amberモード: $isUsingAmber');
            AppLogger.debug('   - 公開鍵ファイル存在: $hasPublicKey');
            throw Exception('公開鍵が設定されていません（npub形式が取得できません）');
          }

          final amberService = _ref.read(amberServiceProvider);

          // 3. 各リストごとに暗号化・署名・送信
          for (final entry in groupedTodos.entries) {
            final listId = entry.key; // これは既に名前ベースID
            final listTodos = entry.value;
            final listTitle = listId == 'default'
                ? null
                : customListNames[listId]; // 名前ベースIDから名前を取得

            AppLogger.debug(
              ' Processing list "$listId" (${listTodos.length} todos)',
            );

            // リストのTodoをJSONに変換
            final todosJson = jsonEncode(
              listTodos
                  .map(
                    (todo) => {
                      'id': todo.id,
                      'title': todo.title,
                      'completed': todo.completed,
                      'date': todo.date?.toIso8601String(),
                      'order': todo.order,
                      'created_at': todo.createdAt.toIso8601String(),
                      'updated_at': todo.updatedAt.toIso8601String(),
                      'event_id': todo.eventId,
                      'link_preview': todo.linkPreview?.toJson(),
                      // d tagとpayloadのlist識別子を一致させる（defaultはnull）。
                      'custom_list_id': listId == 'default' ? null : listId,
                      'recurrence': todo.recurrence?.toJson(),
                      'parent_recurring_id': todo.parentRecurringId,
                      'parent_task_id': todo.parentTaskId,
                      'depth': todo.depth,
                      'task_links': todo.taskLinks.isNotEmpty
                          ? todo.taskLinks.map((l) => l.toJson()).toList()
                          : null,
                      'image_url': todo.imageUrl,
                      'needs_sync': todo.needsSync,
                    },
                  )
                  .toList(),
            );

            AppLogger.debug(
              ' List "$listId" JSON (${todosJson.length} bytes, ${listTodos.length}件)',
            );

            // AmberでNIP-44暗号化
            AppLogger.debug('🔐 Amberで暗号化中（リスト: $listId）...');

            String encryptedContent;
            try {
              // まずContentProvider経由で試す（バックグラウンド処理）
              encryptedContent = await amberService
                  .encryptNip44WithContentProvider(
                    plaintext: todosJson,
                    pubkey: publicKey,
                    npub: npub,
                  );
              AppLogger.info(
                ' 暗号化完了（バックグラウンド） (${encryptedContent.length} bytes)',
              );
            } on PlatformException catch (e) {
              // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
              AppLogger.warning(
                ' ContentProvider暗号化失敗 (${e.code}), UI経由で再試行します...',
              );
              encryptedContent = await amberService.encryptNip44(
                todosJson,
                publicKey,
              );
              AppLogger.info(' 暗号化完了（UI経由） (${encryptedContent.length} bytes)');
            }

            // 暗号化済みcontentで未署名イベントを作成（Kind 30001）
            final unsignedEvent = await nostrService
                .createUnsignedEncryptedTodoListEvent(
                  encryptedContent: encryptedContent,
                  listId: listId == 'default' ? null : listId,
                  listTitle: listTitle,
                );
            AppLogger.debug('📄 未署名イベント作成完了（リスト: $listId）');

            // Amberで署名
            AppLogger.debug('✍️ Amberで署名中（リスト: $listId）...');

            String signedEvent;
            try {
              // まずContentProvider経由で試す（バックグラウンド）
              signedEvent = await amberService.signEventWithContentProvider(
                event: unsignedEvent,
                npub: npub,
              );
              AppLogger.info(' 署名完了（バックグラウンド）');
            } on PlatformException catch (e) {
              // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
              AppLogger.warning(
                ' ContentProvider署名失敗 (${e.code}), UI経由で再試行します...',
              );
              signedEvent = await amberService.signEventWithTimeout(
                unsignedEvent,
              );
              AppLogger.info(' 署名完了（UI経由）');
            }

            try {
              final signedEventMap =
                  jsonDecode(signedEvent) as Map<String, dynamic>;
              final predictedEventId = signedEventMap['id'] as String?;
              if (predictedEventId != null && predictedEventId.isNotEmpty) {
                _setEventIdBeforeRelayAck(listTodos, predictedEventId);
              }
            } catch (e) {
              AppLogger.warning(
                ' Failed to pre-set eventId before relay ack: $e',
              );
            }

            // Global relays first, local relay (Citrine) as backfill
            AppLogger.debug(' リレーに送信中（リスト: $listId）...');
            final sendResult = await nostrService.sendSignedEventGlobalFirst(
              signedEvent,
            );
            if (!sendResult.primarySendResult.success) {
              _clearEventIdForTodos(listTodos);
              throw Exception(
                sendResult.primarySendResult.errorMessage ??
                    'Global relay send failed',
              );
            }
            AppLogger.info(' 送信完了: ${sendResult.primarySendResult.eventId}');
            AppLogger.debug(
              ' List "$listId" event ID: ${sendResult.primarySendResult.eventId}',
            );

            // customListIdの名前ベースIDマイグレーション（必要なものだけ）
            final requiresMigration = listTodos.any(
              (todo) =>
                  todo.customListId != null && todo.customListId != listId,
            );
            if (requiresMigration) {
              final todos = state.valueOrNull;
              if (todos != null) {
                final updated = <DateTime?, List<Todo>>{};
                for (final entry in todos.entries) {
                  updated[entry.key] = entry.value.map((todo) {
                    if (todo.customListId != null &&
                        todo.customListId != listId &&
                        listTodos.any((target) => target.id == todo.id)) {
                      return todo.copyWith(customListId: listId);
                    }
                    return todo;
                  }).toList();
                }
                state = AsyncValue.data(updated);
              }
            }

            await _markTodosSyncedWithEventId(
              listTodos,
              sendResult.primarySendResult.eventId,
              globalBackfillPending: sendResult.localBackfillQueued,
            );
            AppLogger.info(
              ' Updated eventId for ${listTodos.length} todos in list "$listId"',
            );
          }

          AppLogger.info(' すべてのリストの送信完了');
        } else {
          // 通常モード: 秘密鍵で署名（Rust側でNIP-44暗号化）
          // ただし、グループリストのTodoは除外（別途 _syncGroupToNostr で同期）
          AppLogger.info(' 通常モードで全TODOリストを同期します');

          // グループリストを取得
          final customListsAsync = _ref.read(customListsProvider);
          final groupListIds = <String>{};
          await customListsAsync.whenData((customLists) async {
            for (final list in customLists) {
              if (list.isGroup) {
                groupListIds.add(list.id);
              }
            }
          }).value;

          // グループリストのTodoを除外
          final nonGroupTodos = allTodos.where((todo) {
            if (todo.customListId != null &&
                groupListIds.contains(todo.customListId)) {
              AppLogger.debug(
                '   Skipping group list todo: "${todo.title}" (groupId: ${todo.customListId})',
              );
              return false;
            }
            return true;
          }).toList();

          AppLogger.info(
            ' Calling nostrService.createTodoListOnNostr with ${nonGroupTodos.length} non-group todos (excluded ${allTodos.length - nonGroupTodos.length} group todos)...',
          );

          try {
            final sendResult = await nostrService.createTodoListOnNostr(
              nonGroupTodos,
            );
            AppLogger.info(
              '✅✅ TODOリスト送信完了: ${sendResult.eventId} (${nonGroupTodos.length}件)',
            );

            await _markTodosSyncedWithEventId(
              nonGroupTodos,
              sendResult.eventId,
              globalBackfillPending: false,
            );
            AppLogger.info(
              ' Updated eventId for ${nonGroupTodos.length} todos',
            );
          } catch (e) {
            AppLogger.error('❌❌ createTodoListOnNostr failed: $e');
            rethrow;
          }
        }
      } catch (e, stackTrace) {
        AppLogger.error(' TODOリスト同期失敗: $e');
        AppLogger.debug('スタックトレース: $stackTrace');
        rethrow;
      }

      AppLogger.debug(
        ' _syncAllTodosToNostr: state.whenData callback COMPLETED successfully',
      );
    }).value; // ← .value追加で確実に完了を待つ
    syncStopwatch.stop();
    AppLogger.info(
      '⚡ _syncAllTodosToNostr completed in ${syncStopwatch.elapsedMilliseconds}ms',
    );
    AppLogger.debug(' _syncAllTodosToNostr: method COMPLETED');
  }

  /// Nostrへの同期処理（リトライ機能付き）
  /// Amberモード時はAmber署名フローを使用
  Future<void> _syncToNostr(Future<void> Function() syncFunction) async {
    AppLogger.debug('📡 _syncToNostr called');

    final isInitialized = _ref.read(nostrInitializedProvider);
    AppLogger.debug(' Nostr initialized in _syncToNostr: $isInitialized');

    if (!isInitialized) {
      // Nostr未初期化の場合はスキップ（ローカル保存は完了している）
      AppLogger.warning(' Nostr未初期化のため_syncToNostrをスキップ');
      AppLogger.debug(' ローカル保存は完了しています。Nostr接続後に同期されます。');
      return;
    }

    // Amberモードの場合は専用フローを使用
    // （syncFunctionはAmberモード用に最適化されている前提）
    if (_ref.read(isAmberModeProvider)) {
      AppLogger.debug('🔐 Amberモードで同期します');
      // Amberモードの場合はリトライなし（ユーザー操作が必要なため）
      AppLogger.debug(' Calling startSync()');
      _ref.read(syncStatusProvider.notifier).startSync();

      try {
        AppLogger.debug(' Executing syncFunction() (Amber mode)...');
        // タイムアウト付きで同期実行（3秒）
        await syncFunction().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw Exception('同期がタイムアウトしました（3秒）');
          },
        );
        AppLogger.debug(' Calling syncSuccess()');
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        AppLogger.info(' Amber同期成功');
      } catch (e) {
        AppLogger.debug(' Calling syncError()');
        _ref
            .read(syncStatusProvider.notifier)
            .syncError(
              e.toString(),
              shouldRetry: false,
            );
        AppLogger.error(' Amber同期失敗: $e');
        // エラーを再スローせず、ローカルデータは保持
      }
      AppLogger.debug(' _syncToNostr: Amber mode COMPLETED');
      return;
    }

    // 通常モード: 秘密鍵で署名
    AppLogger.debug('🔑 通常モードで同期します');
    // 同期開始
    AppLogger.debug(' Calling startSync()');
    _ref.read(syncStatusProvider.notifier).startSync();

    const maxRetries = 2;
    const retryDelay = Duration(milliseconds: 500);
    const timeout = Duration(seconds: 3);

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.debug(
          ' Executing syncFunction() (attempt ${attempt + 1}/${maxRetries + 1})...',
        );
        // タイムアウト付きで同期実行
        await syncFunction().timeout(
          timeout,
          onTimeout: () {
            throw Exception('同期がタイムアウトしました（${timeout.inSeconds}秒）');
          },
        );

        // 成功
        AppLogger.debug(' Calling syncSuccess()');
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        AppLogger.info(' Nostr同期成功');
        AppLogger.debug(' _syncToNostr: Normal mode COMPLETED successfully');
        return;
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;

        if (isLastAttempt) {
          // 最終試行でも失敗
          AppLogger.debug(' Calling syncError() (final attempt)');
          _ref
              .read(syncStatusProvider.notifier)
              .syncError(
                e.toString(),
                shouldRetry: false,
              );
          AppLogger.error(' Nostr同期失敗（最終試行）: $e');
          AppLogger.debug(' _syncToNostr: Normal mode COMPLETED with error');
          // エラーを再スローせず、ローカルデータは保持
        } else {
          // リトライする
          AppLogger.warning(
            ' Nostr同期エラー（${attempt + 1}/${maxRetries + 1}回目）: $e',
          );
          AppLogger.info(' ${retryDelay.inSeconds}秒後にリトライします...');

          await Future<void>.delayed(retryDelay);
        }
      }
    }
  }

  /// すべてのTodoをローカルストレージに保存
  Future<void> _saveAllTodosToLocal() async {
    AppLogger.debug('💾 [Provider] _saveAllTodosToLocal() called');

    // 🔥 FIX: whenData()は非同期処理を正しくawaitしない
    // state.valueOrNullを使って直接データを取得し、awaitする
    final todos = state.valueOrNull;
    if (todos == null) {
      AppLogger.warning(' State is not ready, skipping save');
      return;
    }

    final allTodos = <Todo>[];

    // すべてのTodoをフラットなリストに変換
    for (final dateGroup in todos.values) {
      allTodos.addAll(dateGroup);
    }

    AppLogger.debug(
      '💾 [Provider] Saving ${allTodos.length} todos to local storage',
    );
    try {
      await localStorageService.saveTodos(allTodos);
      AppLogger.info(
        '✅ [Provider] Saved ${allTodos.length} todos to local storage',
      );
    } catch (e) {
      AppLogger.warning(' ローカル保存エラー: $e');
    }
  }

  /// Widgetを更新
  Future<void> _updateWidget() async {
    // 🔥 FIX: whenData()は非同期処理を正しくawaitしない
    // state.valueOrNullを使って直接データを取得し、awaitする
    final todos = state.valueOrNull;
    if (todos == null) {
      AppLogger.warning(' State is not ready, skipping widget update');
      return;
    }

    try {
      await WidgetService.updateWidget(todos);
    } catch (e) {
      // Widget更新の失敗はログに残すのみ
      AppLogger.warning(' Widget更新エラー: $e');
    }
  }

  /// 手動で全Todoリストをリレーに送信（バックアップ手段）
  /// UIから呼び出される公開メソッド
  Future<void> manualSyncToNostr() async {
    AppLogger.info(' Manual sync to Nostr triggered');
    _ref.read(syncStatusProvider.notifier).startSync();

    try {
      await _syncAllTodosToNostr();

      // 同期成功後、needsSyncフラグをクリア
      await _clearNeedsSyncFlagsForNonGroup();

      _ref.read(syncStatusProvider.notifier).syncSuccess();
      AppLogger.info(' Manual sync completed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(' Manual sync failed: $e');
      AppLogger.error(
        'Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );

      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            '手動同期エラー: ${e}',
            shouldRetry: false,
          );

      rethrow; // UIにエラーを伝播
    }
  }

  /// Phase 8.5.3: グループ系データをバックグラウンドで同期（優先度低）
  Future<void> _syncGroupDataInBackground() async {
    // 全同期経路（差分/フル/起動時ブートストラップ）から呼ばれるため、
    // 多重起動をガードする（内容はべき等だが無駄なリレー負荷を避ける）
    if (_groupBackgroundSyncInProgress) {
      AppLogger.debug('🔄 [Background] グループ系同期は実行中のためスキップ');
      return;
    }
    _groupBackgroundSyncInProgress = true;

    AppLogger.info('🔄 [Background] グループ系同期開始（バックグラウンド）');

    // バックグラウンド同期の開始を通知
    _ref.read(syncStatusProvider.notifier).startSync();

    try {
      // グループリスト、グループタスク、グループ招待を並列同期
      // Phase 8.4: kind: 30001グループリスト同期は廃止（MLSグループのみ使用）
      await Future.wait([
        // 1. グループリスト同期 - 削除（Phase 8.4）

        // 2. グループタスク同期
        syncAllGroupTodos()
            .then((_) {
              AppLogger.info('✅ [Background] グループタスク同期完了');
            })
            .catchError((Object e) {
              AppLogger.warning('⚠️ [Background] グループタスク同期エラー: $e');
            }),

        // 3. グループ招待同期
        _ref
            .read(customListsProvider.notifier)
            .syncGroupInvitations()
            .then((_) {
              AppLogger.info('✅ [Background] グループ招待同期完了');
            })
            .catchError((Object e) {
              AppLogger.warning('⚠️ [Background] グループ招待同期エラー: $e');
            }),
      ]);

      AppLogger.info('✅ [Background] グループ系同期完了');

      // バックグラウンド同期の完了を通知
      AppLogger.debug('🔍 [Background] Calling syncSuccess()...');
      _ref.read(syncStatusProvider.notifier).syncSuccess();
      AppLogger.debug('🔍 [Background] syncSuccess() completed');
    } catch (e) {
      AppLogger.error('❌ [Background] グループ系同期エラー', error: e);

      // エラーを通知
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            'グループ系同期エラー: ${e}',
            shouldRetry: false,
          );
    } finally {
      _groupBackgroundSyncInProgress = false;
    }
  }

  // Phase C.3.2.2: _fetchEncryptedEventsForListNames()削除
  // CustomListsProvider.fetchCustomListNamesFromNostr()に統合

  /// Nostrからすべてのtodoを同期（Kind 30001 - Todoリスト全体を取得）
  Future<void> syncFromNostr({
    bool isInitialSync = false,
    TodoSyncTrigger trigger = TodoSyncTrigger.manual,
  }) async {
    AppLogger.warning(
      '⬇️ [SYNC] syncFromNostr called: trigger=$trigger, isInitialSync=$isInitialSync',
    );

    if (!_ref.read(nostrInitializedProvider)) {
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);

    // ✅ 体感改善: 復帰時は「差分同期 + 短タイムアウト」でフル取得を避ける
    if (trigger == TodoSyncTrigger.appResume ||
        trigger == TodoSyncTrigger.appStart) {
      final lastSync = localStorageService.getLastTodoListSyncTime();
      if (lastSync != null) {
        await _syncFromNostrDelta(
          since: lastSync,
          isAmberMode: isAmberMode,
          nostrService: nostrService,
        );
        return;
      }
      // lastSync がない場合は初回相当 → 既存フル同期へフォールバック
    }

    // Phase 8.5.1: 進捗付き同期開始（全3ステップ）
    _ref
        .read(syncStatusProvider.notifier)
        .startSyncWithProgress(
          totalSteps: 3,
          initialPhase: '__l10n__:syncPhaseAppSettings',
          isInitialSync: isInitialSync,
        );

    try {
      // Phase 8.5.1: 優先度付き並列同期
      AppLogger.info('🚀 [Sync] Phase 1: 優先同期開始（並列実行）');

      // Phase 1: 重要データを並列同期（AppSettings + カスタムリスト名取得）
      final phase1Results = await Future.wait([
        // 1. AppSettings同期（リレーリスト含む）
        _ref
            .read(appSettingsProvider.notifier)
            .syncFromNostr(
              skipIfFresh: trigger != TodoSyncTrigger.manual,
            )
            .then((_) {
              AppLogger.info('✅ [Sync] AppSettings同期完了');
              return true;
            })
            .catchError((Object e) {
              AppLogger.warning('⚠️ [Sync] AppSettings同期エラー（続行）: $e');
              return false;
            }),

        // 2. 暗号化Todoリストイベント取得（カスタムリストメタデータ抽出のため）
        // Phase C.3.2.2: CustomListsProviderのRepository経由メソッドを使用（LWW対応）
        _ref
            .read(customListsProvider.notifier)
            .fetchCustomListMetadataFromNostr()
            .then((listMetadata) {
              AppLogger.info(
                '✅ [Sync] カスタムリストメタデータ抽出完了: ${listMetadata.length}件',
              );
              return listMetadata;
            })
            .catchError((Object e) {
              AppLogger.warning('⚠️ [Sync] カスタムリストメタデータ抽出エラー: $e');
              return <(String, String, String, int)>[];
            }),
      ]); // エラーがあっても全て完了するまで待つ

      final customListMetadata =
          phase1Results[1] as List<(String, String, String, int)>;

      AppLogger.info('✅ [Sync] Phase 1完了（${const Duration()})');

      // Phase 8.5.1: Phase 1完了（33%）
      _ref
          .read(syncStatusProvider.notifier)
          .setProgress(
            completedSteps: 1,
            percentage: 33,
            currentPhase: '__l10n__:syncPhaseCustomLists',
          );

      // Phase 2: カスタムリスト同期（Phase 1の結果を使用、LWW対応）
      AppLogger.info('📋 [Sync] Phase 2: カスタムリスト同期開始 (LWW)');
      try {
        await _ref
            .read(customListsProvider.notifier)
            .syncListsFromNostr(customListMetadata);
        AppLogger.info('✅ [Sync] カスタムリスト同期完了');
      } catch (e) {
        AppLogger.warning('⚠️ [Sync] カスタムリスト同期エラー: $e');
      }

      // Phase 8.5.1: Phase 2完了（66%）
      _ref
          .read(syncStatusProvider.notifier)
          .setProgress(
            completedSteps: 2,
            percentage: 66,
            currentPhase: '__l10n__:syncPhaseTodos',
          );

      // Phase 3: TODO同期（タイムアウト付き、短縮: 20秒）
      AppLogger.info('📝 [Sync] Phase 3: TODO同期開始');
      await Future(() async {
        if (isAmberMode) {
          // Amberモード: すべてのTodoリストイベント（Kind 30001）を取得 → Amberで復号化
          AppLogger.debug(
            '🔐 Amberモードですべてのリストを同期します（Kind 30001、復号化あり、バックグラウンド処理）',
          );

          final encryptedEvents = await nostrService
              .fetchAllEncryptedTodoLists();

          if (encryptedEvents.isEmpty) {
            AppLogger.warning(' Todoリストイベントが見つかりません（Kind 30001）');

            // ローカルデータの有無をチェック
            final hasLocalData =
                state.whenData((localTodos) {
                  final localTodoCount = localTodos.values.fold<int>(
                    0,
                    (sum, list) => sum + list.length,
                  );
                  if (localTodoCount > 0) {
                    AppLogger.debug(
                      ' リモートにイベントがありませんが、ローカルに$localTodoCount件のTodoがあるため保持します',
                    );
                    return true;
                  }
                  return false;
                }).value ??
                false;

            if (hasLocalData) {
              AppLogger.info(' ローカルデータを保持（リモートは空/Amber）');

              // Phase 8.5.3: グループ系はバックグラウンドで同期
              _ref.read(syncStatusProvider.notifier).syncSuccess();

              // バックグラウンドでグループ系同期を開始（UIをブロックしない）
              Future.microtask(_syncGroupDataInBackground);

              return; // ここで関数を抜ける
            }

            // ローカルデータもない場合は空状態に
            AppLogger.debug(' ローカルもリモートもデータがありません');

            // Phase 8.5.3: グループ系はバックグラウンドで同期
            _ref.read(syncStatusProvider.notifier).syncSuccess();

            // バックグラウンドでグループ系同期を開始（UIをブロックしない）
            Future.microtask(_syncGroupDataInBackground);

            return;
          }

          AppLogger.debug(' ${encryptedEvents.length}件のTodoリストイベントを取得');

          // カスタムリスト名を抽出
          final nostrListNames = <String>[];
          AppLogger.info(
            ' [Sync] 📋 Extracting custom list names from ${encryptedEvents.length} events...',
          );

          for (var i = 0; i < encryptedEvents.length; i++) {
            final event = encryptedEvents[i];
            AppLogger.debug(
              ' [Sync]   Event $i: listId="${event.listId}", title="${event.title}", eventId=${event.eventId}',
            );

            if (event.listId != null) {
              final listId = event.listId!;

              // デフォルトリストは除外
              if (listId == 'meiso-todos') {
                AppLogger.debug(
                  ' [Sync]     → Skipping default list (meiso-todos)',
                );
                continue;
              }

              // リスト名を取得（titleタグがあればそれを使用、なければlist_idから生成）
              String listName;
              if (event.title != null && event.title!.isNotEmpty) {
                listName = event.title!;
                AppLogger.debug(' [Sync]     → Using title tag: "$listName"');
              } else {
                // titleタグがない場合、list_idから名前を抽出
                // 例: "meiso-list-mylist" → "mylist"
                if (listId.startsWith('meiso-list-')) {
                  listName = listId.substring('meiso-list-'.length);
                  AppLogger.warning(
                    ' [Sync]     ⚠️ No title tag, extracted from list_id: "$listName"',
                  );
                } else {
                  // list_idが予期しない形式の場合、そのまま使用
                  listName = listId;
                  AppLogger.warning(
                    ' [Sync]     ⚠️ No title tag, using list_id as name: "$listName"',
                  );
                }
              }

              // 重複チェック
              if (!nostrListNames.contains(listName)) {
                nostrListNames.add(listName);
                AppLogger.info(
                  ' [Sync]     ✅ Found custom list: "$listName" (d tag: $listId)',
                );
              } else {
                AppLogger.debug(
                  ' [Sync]     → Duplicate list name, skipping: "$listName"',
                );
              }
            } else {
              AppLogger.warning(
                ' [Sync]     ❌ Event $i has null listId (title=${event.title})',
              );
            }
          }

          AppLogger.info(
            ' [Sync] 📊 Extracted ${nostrListNames.length} custom list names: ${nostrListNames.join(", ")}',
          );

          // Phase 8.5: カスタムリスト名は既にPhase 1で取得済みなので、ここでは使用のみ
          // （このコードパスは旧実装との互換性のため残す）
          AppLogger.debug(
            ' [Sync] カスタムリスト名: ${nostrListNames.join(", ")}（Phase 1で処理済み）',
          );

          final amberService = _ref.read(amberServiceProvider);
          var publicKey = _ref.read(publicKeyProvider);
          var npub = _ref.read(nostrPublicKeyProvider);

          // 公開鍵がnullの場合、Rust側から復元を試みる
          if (publicKey == null) {
            AppLogger.warning(
              ' Public key (hex) is null, attempting to restore from storage...',
            );
            try {
              publicKey = await nostrService.getPublicKey();
              if (publicKey != null) {
                AppLogger.info(
                  ' Public key (hex) restored from storage: ${publicKey.substring(0, 16)}...',
                );
                _ref.read(publicKeyProvider.notifier).state = publicKey;

                // npub形式にも変換して設定
                try {
                  npub = await nostrService.hexToNpub(publicKey);
                  _ref.read(nostrPublicKeyProvider.notifier).state = npub;
                  AppLogger.info(
                    ' Public key (npub) also restored: ${npub.substring(0, 16)}...',
                  );
                } catch (e) {
                  AppLogger.error(' Failed to convert hex to npub: $e');
                }
              } else {
                AppLogger.error(
                  ' Failed to restore public key - no key found in storage',
                );
                throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
              }
            } catch (e) {
              AppLogger.error(' Failed to restore public key: $e');
              throw Exception('公開鍵が設定されていません: $e');
            }
          }

          if (npub == null) {
            final hasPublicKey = await nostrService.hasPublicKey();
            final isUsingAmber = localStorageService.isUsingAmber();
            AppLogger.error(' npub形式の公開鍵がnullです');
            AppLogger.debug('   - hex公開鍵: ${publicKey.substring(0, 16)}...');
            AppLogger.debug('   - Amberモード: $isUsingAmber');
            AppLogger.debug('   - 公開鍵ファイル存在: $hasPublicKey');
            throw Exception('公開鍵が設定されていません（npub形式が取得できません）');
          }

          AppLogger.debug(' 公開鍵: ${publicKey.substring(0, 16)}...');

          // すべてのリストを並列復号してマージ
          // ContentProvider 復号はネイティブ側スレッドプールで並列実行され、
          // Intent フォールバックは AmberService 内のロックで直列化される
          final allSyncedTodos = <Todo>[];
          final decryptPk = publicKey;
          final decryptNpub = npub;

          final decryptedLists = await Future.wait(
            encryptedEvents.map((encryptedEvent) async {
              try {
                AppLogger.debug(
                  ' リストを復号化中 (Event ID: ${encryptedEvent.eventId}, List: ${encryptedEvent.listId})',
                );

                // Amberで復号化
                String decryptedJson;
                try {
                  // まずContentProvider経由で試す（バックグラウンド処理）
                  decryptedJson = await amberService
                      .decryptNip44WithContentProvider(
                        ciphertext: encryptedEvent.encryptedContent,
                        pubkey: decryptPk,
                        npub: decryptNpub,
                      );
                  AppLogger.info(' 復号化完了（バックグラウンド）');
                } on PlatformException catch (e) {
                  // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
                  AppLogger.warning(
                    ' ContentProvider復号化失敗 (${e.code}), UI経由で再試行します...',
                  );
                  decryptedJson = await amberService.decryptNip44(
                    encryptedEvent.encryptedContent,
                    decryptPk,
                  );
                  AppLogger.info(' 復号化完了（UI経由）');
                }

                // JSONをパース（Todoリスト配列）
                final todoList = jsonDecode(decryptedJson) as List<dynamic>;

                final syncedTodos = todoList.map((todoMap) {
                  final map = todoMap as Map<String, dynamic>;
                  final eventListKey = _customListIdFromDTag(
                    encryptedEvent.listId,
                  );
                  return Todo(
                    id: map['id'] as String,
                    title: map['title'] as String,
                    completed: map['completed'] as bool,
                    date: map['date'] != null
                        ? _normalizeDateForGrouping(
                            DateTime.parse(map['date'] as String),
                          )
                        : null,
                    order: map['order'] as int,
                    createdAt: DateTime.parse(map['created_at'] as String),
                    updatedAt: DateTime.parse(map['updated_at'] as String),
                    eventId:
                        map['event_id'] as String? ?? encryptedEvent.eventId,
                    linkPreview: map['link_preview'] != null
                        ? LinkPreview.fromJson(
                            map['link_preview'] as Map<String, dynamic>,
                          )
                        : null,
                    // d tag由来のlist keyを優先し、payload側の旧形式IDは互換正規化する。
                    customListId:
                        eventListKey ??
                        CustomListHelpers.normalizeListIdFromNostr(
                          map['custom_list_id'] as String?,
                        ),
                    recurrence: map['recurrence'] != null
                        ? RecurrencePattern.fromJson(
                            map['recurrence'] as Map<String, dynamic>,
                          )
                        : null,
                    parentRecurringId: map['parent_recurring_id'] as String?,
                    parentTaskId: map['parent_task_id'] as String?,
                    depth: (map['depth'] as int?) ?? 0,
                    taskLinks: _parseTaskLinksFromMap(map['task_links']),
                    imageUrl: map['image_url'] as String?,
                    needsSync: false,
                  );
                }).toList();

                AppLogger.info(
                  ' リスト復号化完了: ${syncedTodos.length}件のTodo (List: ${encryptedEvent.listId})',
                );
                return syncedTodos;
              } catch (e, stackTrace) {
                // 復号化・パースエラー：このリストをスキップして次へ
                AppLogger.error(
                  '❌ リスト復号化失敗 (Event ID: ${encryptedEvent.eventId}, List: ${encryptedEvent.listId}): $e',
                  error: e,
                  stackTrace: stackTrace,
                );
                AppLogger.warning('⚠️ このリストをスキップして続行します');
                return const <Todo>[];
              }
            }),
          );
          for (final syncedTodos in decryptedLists) {
            allSyncedTodos.addAll(syncedTodos);
          }
          AppLogger.info(' [Sync] 3/3: Todoを同期中...');
          AppLogger.info(' すべてのリスト復号化完了: 合計${allSyncedTodos.length}件のTodo');

          // Issue #101: 削除済みタスクIDでフィルタリング（リスト再作成時の復活防止）
          AppLogger.info(
            '🔍 [Issue#101] (Amber) Checking ${allSyncedTodos.length} synced todos against ${_deletedTodoIds.length} blacklisted IDs',
          );

          final allSyncedTodosFiltered = allSyncedTodos.where((todo) {
            // {listId}:{todoId} 形式でチェック
            final compositeId = todo.customListId != null
                ? '${todo.customListId}:${todo.id}'
                : todo.id; // 通常のタスク（非カスタムリスト）は従来通り

            final isDeleted = _deletedTodoIds.contains(compositeId);
            if (isDeleted) {
              AppLogger.info(
                '🚫 [Issue#101] (Amber) Filtered out deleted todo: $compositeId (title: "${todo.title}")',
              );
              return false;
            }
            return true;
          }).toList();

          if (allSyncedTodosFiltered.length != allSyncedTodos.length) {
            final filtered =
                allSyncedTodos.length - allSyncedTodosFiltered.length;
            AppLogger.info(
              '🛡️ [Issue#101] (Amber) Filtered $filtered resurrected todo(s) from deleted list',
            );
          } else {
            AppLogger.info(
              '✅ [Issue#101] (Amber) No resurrected todos detected (all ${allSyncedTodos.length} todos are valid)',
            );
          }

          // allSyncedTodosをフィルタリング済みのものに置き換え
          allSyncedTodos.clear();
          allSyncedTodos.addAll(allSyncedTodosFiltered);

          // allSyncedTodosが空の場合、復号化に失敗した可能性が高い
          // ローカルデータを保持するために、マージをスキップする
          if (allSyncedTodos.isEmpty) {
            AppLogger.warning('⚠️ リモートから復号化できたTodoが0件です。ローカルデータを保持します。');

            // ローカルデータの有無をチェック
            final hasLocalData = state.maybeWhen(
              data: (localTodos) {
                final localTodoCount = localTodos.values.fold<int>(
                  0,
                  (sum, list) => sum + list.length,
                );
                AppLogger.info(' ローカルに$localTodoCount件のTodoがあります');
                return localTodoCount > 0;
              },
              orElse: () => false,
            );

            if (hasLocalData) {
              AppLogger.info(' ローカルデータを保持（リモート復号化失敗）');
              _ref.read(syncStatusProvider.notifier).syncSuccess();
              return; // マージをスキップ
            }
          }

          // 状態を更新
          AppLogger.info(
            '🚀 [DEBUG] Calling _updateStateWithSyncedTodos with ${allSyncedTodos.length} todos...',
          );
          await _updateStateWithSyncedTodos(allSyncedTodos);
          AppLogger.info('✅ [DEBUG] _updateStateWithSyncedTodos returned!');
          AppLogger.info(' [Sync] Todo同期完了');
        } else {
          // 通常モード: Rust側で復号化済みのTodoリストを取得（Kind 30001）
          AppLogger.info(' 通常モードで同期します（Kind 30001）');

          // ステップ1: CustomListsProviderのメソッドを使用（LWW対応）
          AppLogger.debug(' ステップ1: カスタムリストのメタデータを取得します (LWW)');
          final customListMetadata = await _ref
              .read(customListsProvider.notifier)
              .fetchCustomListMetadataFromNostr();

          AppLogger.info(
            ' [Sync] 📊 Fetched ${customListMetadata.length} custom list metadata',
          );

          // カスタムリストを同期（LWW対応）
          // metadataが空の場合でも呼び出し、デフォルトリストを作成
          AppLogger.info(' [Sync] 2/3: カスタムリストを同期中 (LWW)...');
          await _ref
              .read(customListsProvider.notifier)
              .syncListsFromNostr(customListMetadata);
          AppLogger.info(' [Sync] カスタムリスト同期完了 (LWW)');

          // ステップ2: Todoデータを取得
          AppLogger.info(' [Sync] 3/3: Todoを同期中...');
          AppLogger.debug(' ステップ2: Todoデータを取得します');
          final syncedTodosRaw = await nostrService.syncTodoListFromNostr();
          AppLogger.debug(' ${syncedTodosRaw.length}件のTodoを取得しました');

          // Issue #101: 削除済みタスクIDでフィルタリング（リスト再作成時の復活防止）
          AppLogger.info(
            '🔍 [Issue#101] Checking ${syncedTodosRaw.length} synced todos against ${_deletedTodoIds.length} blacklisted IDs',
          );

          final syncedTodos = syncedTodosRaw.where((todo) {
            // {listId}:{todoId} 形式でチェック
            final compositeId = todo.customListId != null
                ? '${todo.customListId}:${todo.id}'
                : todo.id; // 通常のタスク（非カスタムリスト）は従来通り

            final isDeleted = _deletedTodoIds.contains(compositeId);
            if (isDeleted) {
              AppLogger.info(
                '🚫 [Issue#101] Filtered out deleted todo: $compositeId (title: "${todo.title}")',
              );
              return false;
            }
            return true;
          }).toList();

          if (syncedTodos.length != syncedTodosRaw.length) {
            final filtered = syncedTodosRaw.length - syncedTodos.length;
            AppLogger.info(
              '🛡️ [Issue#101] Filtered $filtered resurrected todo(s) from deleted list',
            );
          } else {
            AppLogger.info(
              '✅ [Issue#101] No resurrected todos detected (all ${syncedTodos.length} todos are valid)',
            );
          }

          AppLogger.info(' [Sync] Todo同期完了');

          // イベントが見つからない場合（空リスト）はローカルデータを保持
          if (syncedTodos.isEmpty) {
            final hasLocalData =
                state.whenData((localTodos) {
                  final localTodoCount = localTodos.values.fold<int>(
                    0,
                    (sum, list) => sum + list.length,
                  );
                  if (localTodoCount > 0) {
                    AppLogger.debug(
                      ' リモートにイベントがありませんが、ローカルに$localTodoCount件のTodoがあるため保持します',
                    );
                    return true; // ローカルデータがある
                  }
                  return false;
                }).value ??
                false;

            // ローカルデータがある場合は同期をスキップ
            if (hasLocalData) {
              AppLogger.info(' ローカルデータを保持（リモートは空）');
              _ref.read(syncStatusProvider.notifier).syncSuccess();
              return; // ここで関数を抜ける
            }
          }

          // Nostrから取得したデータのneedsSyncフラグを強制的にfalseにする
          final cleanedTodos = syncedTodos
              .map((todo) => todo.copyWith(needsSync: false))
              .toList();
          AppLogger.info(' needsSyncフラグをクリア: ${cleanedTodos.length}件');

          await _updateStateWithSyncedTodos(cleanedTodos);
        }

        // Phase 8.5.1: Phase 3完了（100%）
        _ref
            .read(syncStatusProvider.notifier)
            .setProgress(
              completedSteps: 3,
              percentage: 100,
              currentPhase: '__l10n__:syncCompleted',
            );

        _ref.read(syncStatusProvider.notifier).syncSuccess();
        // 次回の復帰/再起動時に差分同期を行うため、最終成功同期時刻を保存
        await localStorageService.setLastTodoListSyncTime(DateTime.now());
        AppLogger.info(' Nostr同期成功');

        // フル同期成功時もグループ系（MLS/shared-v1）を必ず同期する。
        // 手動 pull-to-refresh がグループタスクを取りこぼさないようにする。
        Future.microtask(_syncGroupDataInBackground);
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.debug(' syncFromNostr タイムアウト（15秒）');
          throw Exception('データ同期がタイムアウトしました（15秒）');
        },
      );
    } catch (e, stackTrace) {
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            e.toString(),
            shouldRetry: false,
          );
      AppLogger.error(' Nostr同期失敗: $e');
      AppLogger.error(
        'Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );
    }
  }

  /// 復帰/再起動時向けの差分同期（全履歴fetchを避ける）
  Future<void> _syncFromNostrDelta({
    required DateTime since,
    required bool isAmberMode,
    required NostrService nostrService,
  }) async {
    // 既にsync中なら重複実行しない（復帰連打・画面初期化との競合を避ける）
    final syncStatus = _ref.read(syncStatusProvider);
    if (syncStatus.state == SyncState.syncing) {
      AppLogger.debug(' [Todos] Sync already in progress, skipping delta sync');
      return;
    }

    // クロックスキュー/EOSE遅延対策で少し巻き戻して取得（重複はd-tag最新で吸収）
    final effectiveSince = since.subtract(const Duration(minutes: 2));
    final now = DateTime.now();

    _ref
        .read(syncStatusProvider.notifier)
        .startSyncWithProgress(
          totalSteps: 1,
          initialPhase: '__l10n__:syncPhaseDelta',
        );

    try {
      final customListsNotifier = _ref.read(customListsProvider.notifier);
      // 復帰時の差分同期でも、削除メタデータ/リスト状態を先に整合させる
      final customListMetadata = await customListsNotifier
          .fetchCustomListMetadataFromNostr(force: true);
      await customListsNotifier.syncListsFromNostr(customListMetadata);

      final localFlat = await localStorageService.loadTodos();
      final updatedFlat = List<Todo>.from(localFlat);

      if (isAmberMode) {
        final encryptedEvents = await nostrService
            .fetchAllEncryptedTodoListsSince(
              since: effectiveSince,
            );

        if (encryptedEvents.isEmpty) {
          await localStorageService.setLastTodoListSyncTime(now);
          _ref.read(syncStatusProvider.notifier).syncSuccess();
          // 個人Todoの差分が空でもグループ系イベントは存在しうるため、
          // グループ同期は必ずスケジュールする
          Future.microtask(_syncGroupDataInBackground);
          return;
        }

        final amberService = _ref.read(amberServiceProvider);
        var publicKey = _ref.read(publicKeyProvider);
        var npub = _ref.read(nostrPublicKeyProvider);

        if (publicKey == null) {
          publicKey = await nostrService.getPublicKey();
          if (publicKey != null) {
            _ref.read(publicKeyProvider.notifier).state = publicKey;
            try {
              npub = await nostrService.hexToNpub(publicKey);
              _ref.read(nostrPublicKeyProvider.notifier).state = npub;
            } catch (_) {}
          }
        }

        if (publicKey == null || npub == null) {
          throw Exception('公開鍵が設定されていません（差分同期）');
        }

        // 差分イベントは「変更のあったリストのみ」なので、リスト単位で置換する
        // 復号は並列実行し、updatedFlat への反映は順序を保って直列に行う
        final deltaPk = publicKey;
        final deltaNpub = npub;
        final decryptedDeltas = await Future.wait(
          encryptedEvents.map((event) async {
            final dTag = event.listId;
            final listKey = _customListIdFromDTag(dTag); // null=default

            try {
              String decryptedJson;
              try {
                decryptedJson = await amberService
                    .decryptNip44WithContentProvider(
                      ciphertext: event.encryptedContent,
                      pubkey: deltaPk,
                      npub: deltaNpub,
                    );
              } on PlatformException {
                decryptedJson = await amberService.decryptNip44(
                  event.encryptedContent,
                  deltaPk,
                );
              }

              final todoList = jsonDecode(decryptedJson) as List<dynamic>;
              final replacementTodos = todoList.map((todoMap) {
                final map = todoMap as Map<String, dynamic>;
                return Todo(
                  id: map['id'] as String,
                  title: map['title'] as String,
                  completed: map['completed'] as bool,
                  date: map['date'] != null
                      ? _normalizeDateForGrouping(
                          DateTime.parse(map['date'] as String),
                        )
                      : null,
                  order: map['order'] as int,
                  createdAt: DateTime.parse(map['created_at'] as String),
                  updatedAt: DateTime.parse(map['updated_at'] as String),
                  eventId: map['event_id'] as String? ?? event.eventId,
                  linkPreview: map['link_preview'] != null
                      ? LinkPreview.fromJson(
                          map['link_preview'] as Map<String, dynamic>,
                        )
                      : null,
                  customListId: listKey,
                  recurrence: map['recurrence'] != null
                      ? RecurrencePattern.fromJson(
                          map['recurrence'] as Map<String, dynamic>,
                        )
                      : null,
                  parentRecurringId: map['parent_recurring_id'] as String?,
                  parentTaskId: map['parent_task_id'] as String?,
                  depth: (map['depth'] as int?) ?? 0,
                  taskLinks: _parseTaskLinksFromMap(map['task_links']),
                  imageUrl: map['image_url'] as String?,
                  needsSync: false,
                );
              }).toList();

              return (listKey: listKey, todos: replacementTodos);
            } catch (e) {
              AppLogger.warning(
                ' [Todos] Delta decrypt failed for list=$dTag: $e',
              );
              // このリストは更新しない（ローカルを保持）
              return null;
            }
          }),
        );

        // 影響リストのみ置換
        for (final delta in decryptedDeltas) {
          if (delta == null) continue;
          updatedFlat.removeWhere((t) => t.customListId == delta.listKey);
          updatedFlat.addAll(delta.todos);
        }
      } else {
        final deltaTodos = await nostrService.syncTodoListFromNostrSince(
          since: effectiveSince,
        );

        if (deltaTodos.isEmpty) {
          await localStorageService.setLastTodoListSyncTime(now);
          _ref.read(syncStatusProvider.notifier).syncSuccess();
          // 個人Todoの差分が空でもグループ系イベントは存在しうるため、
          // グループ同期は必ずスケジュールする
          Future.microtask(_syncGroupDataInBackground);
          return;
        }

        // 取得できたTodoのcustomListId単位で置換（null=default）
        final affectedListKeys = <String?>{};
        for (final todo in deltaTodos) {
          affectedListKeys.add(
            CustomListHelpers.normalizeListIdFromNostr(todo.customListId),
          );
        }

        for (final key in affectedListKeys) {
          updatedFlat.removeWhere((t) => t.customListId == key);
        }

        updatedFlat.addAll(
          deltaTodos.map(
            (t) => t.copyWith(
              customListId: CustomListHelpers.normalizeListIdFromNostr(
                t.customListId,
              ),
              needsSync: false,
            ),
          ),
        );
      }

      await localStorageService.saveTodos(updatedFlat);
      state = AsyncValue.data(_groupTodosByDate(updatedFlat));

      await localStorageService.setLastTodoListSyncTime(now);
      _ref.read(syncStatusProvider.notifier).syncSuccess();

      // グループ系は重いので、復帰時はバックグラウンドでのみ実行
      Future.microtask(_syncGroupDataInBackground);
    } catch (e, stackTrace) {
      AppLogger.error(
        ' [Todos] Delta sync failed',
        error: e,
        stackTrace: stackTrace,
      );
      _ref
          .read(syncStatusProvider.notifier)
          .syncError(
            '差分同期エラー: ${e}',
            shouldRetry: false,
          );
    } finally {
      // 同期完了後、進捗をリセット
      _ref.read(syncStatusProvider.notifier).resetProgress();
      AppLogger.debug(' [Todos] Delta同期の進捗をリセットしました');
    }
  }

  /// d tag（meiso-todos / meiso-list-xxx）からcustomListIdへ変換
  List<TaskLink> _parseTaskLinksFromMap(dynamic raw) {
    if (raw == null) return [];
    try {
      final list = raw is String ? jsonDecode(raw) as List : raw as List;
      return list
          .map((e) => TaskLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.warning(' Failed to parse taskLinks from map: $e');
      return [];
    }
  }

  String? _customListIdFromDTag(String? dTag) {
    if (dTag == null) return null;
    if (dTag == 'meiso-todos') return null;
    return CustomListHelpers.normalizeListIdFromNostr(dTag);
  }

  /// フラットなTodo配列を日付ごとにグループ化
  Map<DateTime?, List<Todo>> _groupTodosByDate(List<Todo> todos) {
    final grouped = <DateTime?, List<Todo>>{};
    for (final todo in todos) {
      final dateKey = _normalizeDateForGrouping(todo.date);
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(todo.copyWith(date: dateKey));
    }
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
    }
    return grouped;
  }

  DateTime? _normalizeDateForGrouping(DateTime? raw) {
    if (raw == null) return null;
    final local = raw.isUtc ? raw.toLocal() : raw;
    return DateTime(local.year, local.month, local.day);
  }

  /// 同期したTodoで状態を更新（競合解決付き）
  ///
  /// リモートとローカルのTodoをマージし、競合を解決します。
  ///
  /// 競合解決のルール:
  /// 1. needsSyncフラグがtrueのタスク → ローカルを優先（未送信の変更を保護）
  /// 2. updatedAtタイムスタンプを比較 → より新しい方を採用
  /// 3. ローカルのみに存在 → ローカルを保持
  /// 4. リモートのみに存在 → リモートを採用
  Future<void> _updateStateWithSyncedTodos(List<Todo> syncedTodos) async {
    try {
      AppLogger.warning(
        '🔀 [MERGE] Starting merge: ${syncedTodos.length} remote todos',
      );

      // 防御的コーディング: stateから現在のTodoを取得
      final Map<DateTime?, List<Todo>> localTodos;
      final currentState = state;

      if (currentState is AsyncData<Map<DateTime?, List<Todo>>>) {
        localTodos = currentState.value;
        final localCount = localTodos.values.fold<int>(
          0,
          (sum, list) => sum + list.length,
        );
        AppLogger.debug(' Current state is AsyncData with $localCount todos');
      } else {
        // stateがAsyncDataでない場合は空から開始
        AppLogger.warning(
          '⚠️ State is not AsyncData (type: ${currentState.runtimeType}), starting with empty map',
        );
        localTodos = {};
      }

      // ローカルの全タスクをフラット化してMapに変換
      final localTodoMap = <String, Todo>{};
      var localTotalCount = 0;
      for (final dateGroup in localTodos.values) {
        for (final todo in dateGroup) {
          localTodoMap[todo.id] = todo;
          localTotalCount++;
        }
      }

      AppLogger.debug(' Local todos: $localTotalCount');

      // マージ結果を格納
      final mergedTodos = <String, Todo>{};
      var conflictCount = 0;
      var localWinsCount = 0;
      var remoteWinsCount = 0;

      // ステップ1: リモートのタスクを処理
      for (final remoteTodo in syncedTodos) {
        final localTodo = localTodoMap[remoteTodo.id];

        if (localTodo == null) {
          // ローカルに存在しない → リモートを採用
          mergedTodos[remoteTodo.id] = remoteTodo;
          AppLogger.debug(
            ' Remote only: "${remoteTodo.title}" (${remoteTodo.id.substring(0, 8)}...)',
          );
        } else {
          // 両方に存在 → 競合解決
          conflictCount++;

          // ルール1: needsSyncフラグがtrueの場合、ローカルを優先
          if (localTodo.needsSync) {
            mergedTodos[remoteTodo.id] = localTodo;
            localWinsCount++;
            AppLogger.warning(
              '🔀 [MERGE] Conflict resolved (needsSync): Local wins - "${localTodo.title}"',
            );
            AppLogger.warning(
              '   Local updated: ${localTodo.updatedAt.toIso8601String()}',
            );
            AppLogger.warning(
              '   Remote updated: ${remoteTodo.updatedAt.toIso8601String()}',
            );
            continue;
          }

          // ルール2: updatedAtタイムスタンプを比較
          final localUpdated = localTodo.updatedAt;
          final remoteUpdated = remoteTodo.updatedAt;

          if (remoteUpdated.isAfter(localUpdated)) {
            // リモートの方が新しい → リモートを採用（ローカル eventId を保持）
            mergedTodos[remoteTodo.id] = remoteTodo.copyWith(
              eventId: remoteTodo.eventId ?? localTodo.eventId,
            );
            remoteWinsCount++;

            if (localTodo.title != remoteTodo.title) {
              AppLogger.debug(
                '🔀 Conflict resolved: Remote wins - "${remoteTodo.title}"',
              );
            }
          } else if (localUpdated.isAfter(remoteUpdated)) {
            // ローカルの方が新しい → ローカルを採用（リレーに再送信が必要）
            mergedTodos[remoteTodo.id] = localTodo.copyWith(needsSync: true);
            localWinsCount++;

            if (localTodo.title != remoteTodo.title) {
              AppLogger.debug(
                ' Conflict resolved: Local wins - "${localTodo.title}" (will resync)',
              );
            }
          } else {
            // 同じタイムスタンプ → リモートを優先（ローカル eventId を保持）
            mergedTodos[remoteTodo.id] = remoteTodo.copyWith(
              eventId: remoteTodo.eventId ?? localTodo.eventId,
            );
            remoteWinsCount++;

            if (localTodo.title != remoteTodo.title ||
                localTodo.completed != remoteTodo.completed) {
              AppLogger.warning(
                ' Same timestamp but different content: Remote wins - "${remoteTodo.title}"',
              );
            }
          }
        }
      }

      // ステップ2: ローカルのみに存在するタスクを追加
      var localOnlyCount = 0;
      var deletedByRemoteCount = 0;

      for (final localTodo in localTodoMap.values) {
        if (!mergedTodos.containsKey(localTodo.id)) {
          // リモートに存在しない場合の処理

          // グループタスクは個人タスク同期の対象外 → 無条件で保持
          if (localTodo.customListId != null) {
            try {
              final customLists =
                  _ref.read(customListsProvider).valueOrNull ?? [];
              final list = customLists.firstWhere(
                (l) => l.id == localTodo.customListId!,
                orElse: () => CustomList(
                  id: '',
                  name: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              if (list.isGroup) {
                // グループタスクは個人タスク同期の影響を受けないため保持
                mergedTodos[localTodo.id] = localTodo;
                localOnlyCount++;
                AppLogger.debug(
                  '🔒 Group task protected: "${localTodo.title}" (${localTodo.id.substring(0, 8)}...)',
                );
                continue; // 以降の個人タスク用ロジックをスキップ
              }
            } catch (e) {
              // グループ判定でエラーが起きても、個人タスクとして処理を継続
              AppLogger.warning(
                '⚠️ Failed to check if task is group task: $e, treating as personal task',
              );
            }
          }

          if (localTodo.needsSync) {
            // ケース1: needsSyncがtrue → まだ同期されていない新しいタスク
            // ローカルを保持してリレーに送信する
            mergedTodos[localTodo.id] = localTodo;
            localOnlyCount++;
            AppLogger.debug(
              ' Local only (new): "${localTodo.title}" (${localTodo.id.substring(0, 8)}...) - will sync',
            );
          } else {
            // ケース2: needsSyncがfalse → 他のデバイスで削除された可能性
            // ただし、ローカルが最近更新されている場合は保持する
            final now = DateTime.now();
            final hoursSinceUpdate = now
                .difference(localTodo.updatedAt)
                .inHours;

            if (hoursSinceUpdate < 24) {
              // 24時間以内の更新 → ローカルを保持（削除ではなく、同期のタイミング差の可能性）
              mergedTodos[localTodo.id] = localTodo.copyWith(needsSync: true);
              localOnlyCount++;
              AppLogger.debug(
                ' Local only (recent update): "${localTodo.title}" - will resync (updated ${hoursSinceUpdate}h ago)',
              );
            } else {
              // 24時間以上前の更新 → 他のデバイスで削除されたと判断
              deletedByRemoteCount++;
              AppLogger.debug(
                '  Deleted by remote: "${localTodo.title}" (${localTodo.id.substring(0, 8)}...) - removing locally',
              );
              // mergedTodosに追加しない = ローカルから削除
            }
          }
        }
      }

      // マージ結果のサマリーを出力
      AppLogger.info(' Merge completed:');
      AppLogger.debug('   Total merged: ${mergedTodos.length}');
      AppLogger.debug('   Conflicts: $conflictCount');
      AppLogger.debug('   Local wins: $localWinsCount');
      AppLogger.debug('   Remote wins: $remoteWinsCount');
      AppLogger.debug('   Local only: $localOnlyCount');
      AppLogger.debug('   Deleted by remote: $deletedByRemoteCount');

      // ステップ3: 日付ごとにグループ化
      final grouped = <DateTime?, List<Todo>>{};
      for (final todo in mergedTodos.values) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }

      // 各日付のリストをorder順にソート
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }

      state = AsyncValue.data(grouped);
      await _saveAllTodosToLocal();
      await _updateWidget();

      // ローカルが新しいタスクがある場合、自動的に再同期
      if (localWinsCount > 0 || localOnlyCount > 0) {
        AppLogger.info(' Scheduling resync due to local changes');
        _updateUnsyncedCount();
      }
    } catch (e, stackTrace) {
      // マージ処理でエラーが発生した場合
      AppLogger.error(
        '❌ Error in _updateStateWithSyncedTodos: $e',
        error: e,
        stackTrace: stackTrace,
      );

      // エラーが起きても、リモートのタスクだけは表示する
      final grouped = <DateTime?, List<Todo>>{};
      for (final todo in syncedTodos) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }

      // ソート
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }

      _setTodosStateAsync(grouped);
      AppLogger.warning(
        '⚠️ Fallback: Showing only remote todos due to merge error',
      );
    }
  }

  // ========================================
  // マイグレーション関連
  // ========================================

  /// Kind 30078 → Kind 30001 へのマイグレーション
  ///
  /// 1. 既存のKind 30078イベントを取得
  /// 2. Kind 30001形式で再送信
  /// 3. 古いKind 30078イベントを削除（Kind 5）
  ///
  /// ⚠️ 注意: dタグが`todo-`で始まるイベントは自動的に除外されます（Rust側でフィルタリング済み）
  Future<void> migrateFromKind30078ToKind30001() async {
    AppLogger.info(' Starting migration from Kind 30078 to Kind 30001...');

    _ref.read(migrationStatusProvider.notifier).state =
        MigrationStatus.checking;
    _ref
        .read(syncStatusProvider.notifier)
        .updateMessage('__l10n__:syncPreparingMigration');

    try {
      // 1. 既存のKind 30078イベントを取得
      AppLogger.debug(' Fetching existing Kind 30078 events...');
      _ref
          .read(syncStatusProvider.notifier)
          .updateMessage('__l10n__:syncFetchingOldData');

      // Phase C.2.1: Repository経由で旧データ取得
      final repository = _ref.read(todoRepositoryProvider);
      final publicKey = _ref.read(publicKeyProvider);

      if (publicKey == null) {
        throw Exception('公開鍵が設定されていません');
      }

      final fetchResult = await repository.fetchOldTodosFromKind30078(
        publicKey: publicKey,
      );

      final oldTodos = fetchResult.fold(
        (failure) {
          throw Exception('旧データの取得に失敗しました: ${failure.message}');
        },
        (todos) => todos,
      );

      if (oldTodos.isEmpty) {
        AppLogger.info(' No Kind 30078 events found. Migration not needed.');
        _ref.read(migrationStatusProvider.notifier).state =
            MigrationStatus.notNeeded;
        return;
      }

      AppLogger.debug(' Found ${oldTodos.length} todos in Kind 30078 format');
      _ref.read(migrationStatusProvider.notifier).state =
          MigrationStatus.needed;

      // 2. Kind 30001形式で再送信
      _ref.read(migrationStatusProvider.notifier).state =
          MigrationStatus.inProgress;
      AppLogger.debug(' Migrating todos to Kind 30001 format...');
      _ref
          .read(syncStatusProvider.notifier)
          .updateMessage('__l10n__:syncConvertingToNewFormat');

      // 一時的に状態を更新（UIに反映）
      final grouped = <DateTime?, List<Todo>>{};
      for (final todo in oldTodos) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }
      state = AsyncValue.data(grouped);

      // Kind 30001形式で送信
      await _syncAllTodosToNostr();

      AppLogger.info(' Migration to Kind 30001 completed');

      // 3. 古いKind 30078イベントを削除
      final oldEventIds = oldTodos
          .map((t) => t.eventId)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (oldEventIds.isNotEmpty) {
        AppLogger.debug(
          ' Deleting ${oldEventIds.length} old Kind 30078 events...',
        );
        _ref
            .read(syncStatusProvider.notifier)
            .updateMessage('__l10n__:syncDeletingOldData');

        // Phase C.2.2: Repository経由で削除
        final deleteResult = await repository.deleteNostrEvents(
          eventIds: oldEventIds,
          reason: 'Migrated to Kind 30001 (NIP-51 Bookmark List)',
        );

        deleteResult.fold(
          (failure) {
            AppLogger.warning(
              ' Failed to delete old events: ${failure.message}',
            );
            // 削除失敗してもマイグレーションは成功とみなす
          },
          (_) {
            AppLogger.info(' Old events deleted successfully');
          },
        );
      }

      _ref.read(migrationStatusProvider.notifier).state =
          MigrationStatus.completed;
      _ref
          .read(syncStatusProvider.notifier)
          .updateMessage('__l10n__:syncMigrationCompleted');
      AppLogger.debug('🎉 Migration completed successfully!');

      // Phase C.2.2: Repository経由でマイグレーション完了フラグを保存
      final setCompletedResult = await repository.setMigrationCompleted();
      setCompletedResult.fold(
        (failure) => AppLogger.warning(
          ' Failed to save migration flag: ${failure.message}',
        ),
        (_) => AppLogger.info(' Migration completed flag saved'),
      );

      // メッセージをクリア
      await Future<void>.delayed(const Duration(seconds: 1));
      _ref.read(syncStatusProvider.notifier).clearMessage();
    } catch (e, stackTrace) {
      _ref.read(migrationStatusProvider.notifier).state =
          MigrationStatus.failed;
      AppLogger.error(' Migration failed: $e');
      AppLogger.error(
        'Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );
      rethrow;
    }
  }

  /// Kind 30001（新形式）にデータが存在するかチェック
  ///
  /// Kind 30001にデータがある = マイグレーション済み（別デバイスで実行済みなど）
  ///
  /// ⚠️ このメソッドは復号化せずにイベントの存在のみをチェックします
  Future<bool> checkKind30001Exists() async {
    AppLogger.debug('🔍 [Provider] checkKind30001Exists() called');

    // Phase C.2.1: Repository経由で確認
    final repository = _ref.read(todoRepositoryProvider);
    final result = await repository.checkKind30001Exists();

    return result.fold(
      (failure) {
        AppLogger.warning(
          '[Provider] Failed to check Kind 30001: ${failure.message}',
        );
        return false; // エラー時はfalseを返す
      },
      (exists) => exists,
    );
  }

  /// マイグレーションが必要かチェック
  ///
  /// Kind 30078のTODOイベント（旧形式）が存在する場合にtrueを返す
  /// ※ Kind 30078の設定イベント（d="meiso-settings"）は除外
  Future<bool> checkMigrationNeeded() async {
    AppLogger.debug('🔍 [Provider] checkMigrationNeeded() called');

    // Phase C.2.1: Repository経由で確認
    final repository = _ref.read(todoRepositoryProvider);
    final result = await repository.checkMigrationNeeded();

    return result.fold(
      (failure) {
        AppLogger.warning(
          '[Provider] Failed to check migration: ${failure.message}',
        );
        return false; // エラー時はfalseを返す（マイグレーション不要として扱う）
      },
      (needed) {
        if (!needed) {
          // マイグレーション不要（完了済み）
          _ref.read(migrationStatusProvider.notifier).state =
              MigrationStatus.completed;
        }
        return needed;
      },
    );
  }

  // ========================================
  // グループタスク管理（マルチパーティ暗号化）
  // ========================================

  /// グループタスクを同期（復号化してローカルに追加）
  Future<void> syncGroupTodos(String groupId) async {
    try {
      AppLogger.info('🔄 Syncing group todos for group: $groupId');

      final customListsAsync = _ref.read(customListsProvider);
      final customLists =
          customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
      final groupList = customLists
          .where((l) => l.id == groupId && l.isGroup)
          .firstOrNull;
      if (groupList == null) {
        AppLogger.warning('⚠️ Group list not found: $groupId');
        return;
      }

      if (groupList.protocolVersion == CustomListHelpers.protocolGw17V1) {
        await _syncGw17GroupTodos(groupId: groupId);
        AppLogger.info(
          '✅ [syncGroupTodos] Completed GW17 group todos sync for: $groupId',
        );
        return;
      }

      if (groupList.isSharedProtocol) {
        await _syncSharedGroupTodos(groupId: groupId);
        AppLogger.info(
          '✅ [syncGroupTodos] Completed shared-v1 group todos sync for: $groupId',
        );
        return;
      }

      // 1. ローカルからMLSグループを読み込む（存在確認）
      final mlsGroupRepo = _ref.read(mls_providers.mlsGroupRepositoryProvider);
      final loadResult = await mlsGroupRepo.loadMlsGroupFromLocal(
        groupId: groupId,
      );

      final mlsGroup = loadResult.fold(
        (failure) {
          AppLogger.warning('⚠️ Failed to load MLS group from local: $groupId');
          return null;
        },
        (group) => group,
      );

      if (mlsGroup == null) {
        AppLogger.warning('⚠️ MLS Group not found in local storage: $groupId');
        AppLogger.info(
          '💡 Hint: Make sure the group invitation was accepted successfully',
        );
        return;
      }

      AppLogger.info(
        '✅ MLS Group found in local storage: ${mlsGroup.groupName}',
      );

      // 2. 公開鍵を取得
      var publicKey = _ref.read(publicKeyProvider);
      var npub = _ref.read(nostrPublicKeyProvider);

      // 公開鍵がnullの場合、復元を試みる
      if (publicKey == null || npub == null) {
        AppLogger.warning(' 公開鍵が未設定、復元を試みます...');
        try {
          final nostrService = _ref.read(nostrServiceProvider);
          publicKey = await nostrService.getPublicKey();
          if (publicKey != null) {
            AppLogger.info(' hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
            _ref.read(publicKeyProvider.notifier).state = publicKey;

            npub = await nostrService.hexToNpub(publicKey);
            _ref.read(nostrPublicKeyProvider.notifier).state = npub;
            AppLogger.info(' npub公開鍵も復元: ${npub.substring(0, 16)}...');
          } else {
            throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
          }
        } catch (e) {
          AppLogger.error(' 公開鍵の復元に失敗: $e');
          throw Exception('公開鍵が設定されていません: $e');
        }
      }

      // 3. Phase 8.3: MLSグループTODOを同期
      await _initMlsIfNeeded();
      await _syncMlsGroupTodos(
        groupId: groupId,
        publicKey: publicKey,
      );

      AppLogger.info(
        '✅ [syncGroupTodos] Completed MLS group todos sync for: $groupId',
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [syncGroupTodos] Failed to sync group todos: $e',
        error: e,
        stackTrace: st,
      );

      // 🔥 Phase D.5.1 Critical Fix: エラー時もstateを更新
      // stateがloadingのまま残ると無限ローディングが発生する
      // 現在のデータを保持してdata状態に戻す
      final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
      state = AsyncValue.data(currentTodos);

      AppLogger.info('✅ [syncGroupTodos] State restored to data after error');
    }
  }

  /// Phase 8.3: MLSグループTODOを同期（受信・復号化）
  Future<void> _syncMlsGroupTodos({
    required String groupId,
    required String publicKey,
  }) async {
    try {
      AppLogger.info('🔐 [MLS] Syncing MLS group todos for: $groupId');

      // 1. Group Event(kind:445 + #h) を取得（NIP-EE準拠）
      final nostrService = _ref.read(nostrServiceProvider);

      final last = localStorageService.getLastMlsGroupTodosSyncTime(groupId);

      // 🔥 Phase 8.3 Fix: 初回同期時は since:0 で全イベントを取得
      // その後は前回の同期時刻から2分前を起点にする（クロックスキュー対策）
      final effectiveSince = last != null
          ? last.subtract(const Duration(minutes: 2))
          : DateTime.fromMillisecondsSinceEpoch(0);

      AppLogger.debug(
        '🕐 [MLS] Last sync: ${last?.toIso8601String() ?? "never"}',
      );
      AppLogger.debug(
        '🕐 [MLS] Effective since: ${effectiveSince.toIso8601String()}',
      );

      final events = await nostrService.fetchMlsGroupTodoEventsSince(
        groupId: groupId,
        since: effectiveSince,
      );

      if (events.isEmpty) {
        AppLogger.info('📭 [MLS] No MLS group todo events found for: $groupId');
        AppLogger.info(
          '💡 [MLS] This is normal for newly created/joined groups',
        );
        await localStorageService.setLastMlsGroupTodosSyncTime(
          groupId,
          DateTime.now(),
        );
        return;
      }

      AppLogger.info('📦 [MLS] Fetched ${events.length} MLS group todo events');

      // 3. 各イベントをMLS復号化して差分適用
      //
      // IMPORTANT:
      // MLS group todo は「差分イベント（add/update/toggle/delete...）」として届く。
      // ここで毎回「グループTODOを全消し→今回取得分だけ追加」をすると、
      // 差分取得（since）時に既存TODOが消えるので、必ずインクリメンタルに適用する。
      final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
      final updated = Map<DateTime?, List<Todo>>.from(currentTodos);

      // 既存のグループTODOをID→Todoで索引（更新/重複排除用）
      final byId = <String, Todo>{};
      for (final entry in updated.entries) {
        for (final t in entry.value) {
          if (t.customListId == groupId) {
            byId[t.id] = t;
          }
        }
      }

      for (final event in events) {
        try {
          // event_jsonをパースしてcontentを取得
          final eventData = jsonDecode(event.eventJson) as Map<String, dynamic>;
          final encryptedContent = eventData['content'] as String;

          // NIP-EE: `h` タグでグループを識別（後方互換で `group_id` も許容）
          if (!_isEventForGroup(eventData, groupId)) {
            AppLogger.debug('⏭️  [MLS] Skipping event for different group');
            continue;
          }

          // Phase D.8: MLS復号化（NIP-EE完全準拠、拡張された戻り値）
          final (todoContent, action, todoId, senderPubkey, _) = await rust_api
              .mlsDecryptTodo(
                nostrId: publicKey,
                groupId: groupId,
                encryptedMsg: encryptedContent,
              );

          // Phase D.8: 後方互換性
          final effectiveAction = action.isEmpty ? 'upsert' : action;
          final effectiveTodoId = todoId.isNotEmpty
              ? todoId
              : _tryExtractTodoId(todoContent);

          // deleteは内容が空でも適用可能
          if (effectiveAction == 'delete') {
            if (effectiveTodoId == null || effectiveTodoId.isEmpty) {
              AppLogger.warning(
                '⚠️ [MLS] delete action missing todoId, skipping',
              );
              continue;
            }

            // 既存から削除
            byId.remove(effectiveTodoId);
            for (final dateKey in updated.keys) {
              updated[dateKey] = updated[dateKey]!
                  .where((t) => t.id != effectiveTodoId)
                  .toList();
            }
            AppLogger.debug(
              '🗑️ [MLS] Deleted todo: $effectiveTodoId (from ${senderPubkey.substring(0, 16)}...)',
            );
            continue;
          }

          // upsert系はtodo JSONが必要
          final parsed = _parseTodoFromMlsPayload(
            payloadJson: todoContent,
            fallbackId: effectiveTodoId,
            groupId: groupId,
          );
          if (parsed == null) {
            AppLogger.warning(
              '⚠️ [MLS] Failed to parse todo payload, skipping (action=$effectiveAction)',
            );
            continue;
          }

          // 既存を置換（重複排除）
          final prev = byId[parsed.id];
          if (prev != null && prev.date != parsed.date) {
            // date移動があった場合、旧dateグループから除去
            updated[prev.date] = (updated[prev.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          } else {
            // 同一dateグループでも重複を除去
            updated[parsed.date] = (updated[parsed.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          }

          byId[parsed.id] = parsed;
          updated[parsed.date] ??= [];
          updated[parsed.date]!.add(parsed);

          AppLogger.debug(
            '✅ [MLS] Upsert todo: ${parsed.title} (action=$effectiveAction, from ${senderPubkey.substring(0, 16)}...)',
          );
        } catch (e) {
          AppLogger.error(
            '❌ [MLS] Failed to decrypt/parse event: $e',
            error: e,
          );
          // エラーでも他のイベントは処理続行
        }
      }

      AppLogger.info(
        '✅ [MLS] Applied ${events.length} events (currentTodosInGroup=${byId.length})',
      );

      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);

      // 🔥 Phase 8.7: グループTODO受信時は即座にUI更新
      // addPostFrameCallback による遅延ではなく、即座に state を更新する
      // これにより、受信したTODOが即座にUIに反映される
      state = AsyncValue.data(updated);
      AppLogger.info(
        '🎨 [MLS] UI updated immediately with received group todos',
      );

      AppLogger.info('✅ [MLS] Group todos synced to local storage');
      await localStorageService.setLastMlsGroupTodosSyncTime(
        groupId,
        DateTime.now(),
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [MLS] Failed to sync MLS group todos: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// shared-v1: kind:35000 タスクイベントを購読して LWW 適用
  /// 受諾済みの全 shared-v1 グループをフルフェッチ同期する。
  Future<void> _syncAllSharedGroupTodos() async {
    final customListsAsync = _ref.read(customListsProvider);
    final customLists =
        customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
    final sharedGroups = customLists
        .where(
          (l) => l.isGroup && l.isSharedProtocol && !l.isPendingInvitation,
        )
        .toList();
    if (sharedGroups.isEmpty) return;
    AppLogger.info(
      '🔄 [shared-v1] Syncing ${sharedGroups.length} shared group(s)',
    );
    for (final group in sharedGroups) {
      await _syncSharedGroupTodos(groupId: group.id);
    }
  }

  Future<void> _syncSharedGroupTodos({required String groupId}) async {
    try {
      AppLogger.info(
        '🔄 [shared-v1] _syncSharedGroupTodos start: groupId=$groupId',
      );
      final repo = _ref.read(shared_providers.sharedListRepositoryProvider);
      final credsResult = await repo.loadCredentials(groupId: groupId);
      final credentials = credsResult.fold((_) => null, (c) => c);
      if (credentials == null) {
        AppLogger.warning(
          '⚠️ [shared-v1] No group credentials for $groupId',
        );
        return;
      }

      // shared-v1 タスクは 1 タスク = 1 addressable event(kind:35000)であり、
      // relay 側で (kind, author=G, d=task-id) ごとに LWW 上書きされる。
      // つまり relay が保持するのは「各タスクの最新版のみ」= タスク数で上限が
      // 決まる有界な集合。よって `since` で増分取得する必要はなく、毎回フル
      // フェッチ(since=0)するのが最も堅牢かつ安価。
      //
      // 増分(since=lastSync)方式はピア間のクロックずれに脆弱で、相手端末の
      // created_at が自端末の lastSync より過去になると relay の since フィルタで
      // 恒久的に除外され、「最初の共有時のみ採用」というバグを生む。
      final effectiveSince = DateTime.fromMillisecondsSinceEpoch(0);

      AppLogger.info(
        '📥 [shared-v1] fetchTaskEvents (full): npub=${credentials.groupNpubHex.substring(0, 16)}...',
      );

      final eventsResult = await repo.fetchTaskEvents(
        groupNpubHex: credentials.groupNpubHex,
        since: effectiveSince,
      );

      final events = eventsResult.fold(
        (failure) {
          AppLogger.error(
            '❌ [shared-v1] fetchTaskEvents failed: ${failure.message}',
          );
          return <Map<String, dynamic>>[];
        },
        (e) {
          AppLogger.info(
            '📦 [shared-v1] fetched ${e.length} events from relays',
          );
          return e;
        },
      );
      if (events.isEmpty) {
        await localStorageService.setLastSharedGroupTodosSyncTime(
          groupId,
          DateTime.now(),
        );
        return;
      }

      final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
      final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
      final byId = <String, Todo>{};
      for (final entry in updated.entries) {
        for (final t in entry.value) {
          if (t.customListId == groupId) {
            byId[t.id] = t;
          }
        }
      }

      // LWW 決定論化: created_at 昇順（同秒は event id 辞書順）で適用する。
      // 複数リレー間で per-relay LWW 状態が分岐していると同一タスクの新旧
      // バージョンが混在して返るため、最新が最後に適用される順序を保証しないと
      // stale 巻き戻りや削除タスクのゾンビ復活が起きる（issue #138 R1/R2）。
      final orderedEvents = List<Map<String, dynamic>>.from(events)
        ..sort(_compareSharedEventMaps);

      for (final eventData in orderedEvents) {
        try {
          final kind = eventData['kind'] as int?;
          if (kind != 35000) continue;

          final signedJson = jsonEncode(eventData);
          final decrypted = await rust_api.sharedDecryptTaskEvent(
            groupNsecHex: credentials.groupNsecHex,
            eventJson: signedJson,
          );
          final data = jsonDecode(decrypted) as Map<String, dynamic>;
          final parsed = _parseSharedTaskPayload(
            data: data,
            groupId: groupId,
          );
          if (parsed == null) continue;

          final prev = byId[parsed.id];

          // LWW: フルフェッチでは過去イベントも返るため、ローカルに未同期
          // (needsSync=true) のより新しい編集がある場合は relay 版で上書きしない。
          if (prev != null &&
              prev.needsSync &&
              prev.updatedAt.isAfter(parsed.updatedAt)) {
            continue;
          }

          if (data['deleted'] == true) {
            byId.remove(parsed.id);
            for (final dateKey in updated.keys) {
              updated[dateKey] = updated[dateKey]!
                  .where((t) => t.id != parsed.id)
                  .toList();
            }
            continue;
          }

          if (prev != null && prev.date != parsed.date) {
            updated[prev.date] = (updated[prev.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          } else {
            updated[parsed.date] = (updated[parsed.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          }
          byId[parsed.id] = parsed;
          updated[parsed.date] ??= [];
          updated[parsed.date]!.add(parsed);
        } catch (e) {
          AppLogger.error('❌ [shared-v1] Failed to apply event: $e', error: e);
        }
      }

      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);
      state = AsyncValue.data(updated);
      await localStorageService.setLastSharedGroupTodosSyncTime(
        groupId,
        DateTime.now(),
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [shared-v1] sync failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// shared-v1 イベント(JSONマップ)を created_at 昇順 + 同秒は event id 辞書順
  /// で比較する。リレー側の NIP-01 タイブレークと同じ規則に揃え、
  /// どの端末でも同一の最終状態に収束させる。
  static int _compareSharedEventMaps(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final createdA = (a['created_at'] as num?)?.toInt() ?? 0;
    final createdB = (b['created_at'] as num?)?.toInt() ?? 0;
    if (createdA != createdB) {
      return createdA.compareTo(createdB);
    }
    final idA = a['id'] as String? ?? '';
    final idB = b['id'] as String? ?? '';
    return idA.compareTo(idB);
  }

  Todo? _parseSharedTaskPayload({
    required Map<String, dynamic> data,
    required String groupId,
  }) {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final status = data['status'] as String? ?? 'open';
    final completed = status == 'done' || data['completed'] == true;
    DateTime? date;
    final dateRaw = data['date'];
    if (dateRaw is String && dateRaw.isNotEmpty) {
      date = DateTime.tryParse(dateRaw);
    }
    // payload に含まれる editor_pubkey(最後に編集した実 npub hex)を採用する。
    // 欠落時は null(編集者不明)とする。以前は受信者自身の pubkey に
    // フォールバックしており、他人のタスクが「自分のタスク」として
    // 表示される可能性があった（issue #138 R4）。
    final payloadEditor = (data['editor_pubkey'] as String?)?.trim();
    return Todo(
      id: id,
      title: data['title'] as String? ?? '',
      completed: completed,
      date: date,
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(data['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.now(),
      customListId: groupId,
      needsSync: false,
      editorPubkey: (payloadEditor != null && payloadEditor.isNotEmpty)
          ? payloadEditor
          : null,
    );
  }

  Future<String?> _sendSharedGroupTodoAction({
    required String groupId,
    required String action,
    required String payload,
    Todo? todo,
    String? todoIdOverride,
    String? editorPubkey,
  }) async {
    AppLogger.info(
      '📤 [shared-v1] _sendSharedGroupTodoAction start: groupId=$groupId, action=$action',
    );
    final repo = _ref.read(shared_providers.sharedListRepositoryProvider);
    final credsResult = await repo.loadCredentials(groupId: groupId);
    final credentials = credsResult.fold((_) => null, (c) => c);
    if (credentials == null) {
      AppLogger.error(
        '❌ [shared-v1] credentials not found for groupId=$groupId',
      );
      throw Exception('shared-v1 credentials not found: $groupId');
    }
    AppLogger.debug(
      '🔑 [shared-v1] credentials loaded: npub=${credentials.groupNpubHex.substring(0, 16)}..., epoch=${credentials.keyEpoch}',
    );

    final data = jsonDecode(payload) as Map<String, dynamic>;
    data['status'] = (todo?.completed ?? false) ? 'done' : 'open';
    data['order'] = data['order'] ?? FractionalIndex.initial;
    data['list_id'] = groupId;
    data['deleted'] = action == 'delete';

    // クロックスキュー対策（issue #138 R3）: 編集対象の既存 updatedAt が
    // 自端末の現在時刻より未来（時計の進んだ他端末の編集）の場合、
    // そのままでは今回の編集が LWW で恒久的に負ける。単調増加を保証する。
    var updatedAt = DateTime.now();
    final prevUpdatedAt = todo?.updatedAt;
    if (prevUpdatedAt != null && !updatedAt.isAfter(prevUpdatedAt)) {
      updatedAt = prevUpdatedAt.add(const Duration(seconds: 1));
    }
    data['updated_at'] = updatedAt.toIso8601String();

    // 帰属表示のため editor_pubkey は常に埋める（issue #138 R4）
    final editor =
        editorPubkey ?? await _ref.read(nostrServiceProvider).getPublicKey();
    if (editor != null && editor.isNotEmpty) {
      data['editor_pubkey'] = editor;
    }

    final result = await repo.publishSignedTaskEvent(
      groupNsecHex: credentials.groupNsecHex,
      taskJson: jsonEncode(data),
    );
    return result.fold(
      (failure) {
        AppLogger.error(
          '❌ [shared-v1] publishSignedTaskEvent failed: ${failure.message}',
        );
        return null;
      },
      (id) {
        AppLogger.info(
          '✅ [shared-v1] task event published: eventId=${id.substring(0, 16)}..., taskId=${data['id']}',
        );
        return id;
      },
    );
  }

  Future<void> _syncGw17GroupTodos({
    required String groupId,
  }) async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final last = localStorageService.getLastMlsGroupTodosSyncTime(groupId);
      final since = last ?? DateTime.fromMillisecondsSinceEpoch(0);
      final messages = await nostrService.fetchGw17Messages(
        since: since,
        groupId: groupId,
      );
      if (messages.isEmpty) {
        await localStorageService.setLastMlsGroupTodosSyncTime(
          groupId,
          DateTime.now(),
        );
        return;
      }

      // Event-ID based dedup against persisted processed set
      final processedIds = localStorageService.loadProcessedGw17EventIds();
      final newMessages = messages
          .where((m) => m.eventId != null && !processedIds.contains(m.eventId))
          .toList();
      if (newMessages.isEmpty) {
        await localStorageService.setLastMlsGroupTodosSyncTime(
          groupId,
          DateTime.now(),
        );
        return;
      }

      final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
      final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
      final byId = <String, Todo>{};
      for (final entry in updated.entries) {
        for (final t in entry.value) {
          if (t.customListId == groupId) byId[t.id] = t;
        }
      }

      final appliedEventIds = <String>[];
      for (final message in newMessages) {
        if (message.todo == null) continue;
        final action = message.action ?? 'update';
        final todoId = message.todo!['id'] as String?;
        if (todoId == null || todoId.isEmpty) continue;

        if (action == 'delete') {
          byId.remove(todoId);
          for (final dateKey in updated.keys) {
            updated[dateKey] = updated[dateKey]!
                .where((t) => t.id != todoId)
                .toList();
          }
          if (message.eventId != null) appliedEventIds.add(message.eventId!);
          continue;
        }

        final parsed = _parseTodoFromMlsPayload(
          payloadJson: jsonEncode(message.todo),
          fallbackId: todoId,
          groupId: groupId,
        );
        if (parsed == null) continue;

        final prev = byId[parsed.id];
        if (prev != null) {
          updated[prev.date] = (updated[prev.date] ?? [])
              .where((t) => t.id != parsed.id)
              .toList();
        }
        updated[parsed.date] = (updated[parsed.date] ?? [])
            .where((t) => t.id != parsed.id)
            .toList();
        updated[parsed.date]!.add(parsed);
        byId[parsed.id] = parsed;
        if (message.eventId != null) appliedEventIds.add(message.eventId!);
      }

      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);
      state = AsyncValue.data(updated);
      if (appliedEventIds.isNotEmpty) {
        await localStorageService.addProcessedGw17EventIds(appliedEventIds);
      }
      await localStorageService.setLastMlsGroupTodosSyncTime(
        groupId,
        DateTime.now(),
      );
      AppLogger.info(
        '✅ [GW17] Applied ${newMessages.length} new messages (${messages.length - newMessages.length} deduped) for group: $groupId',
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [GW17] Failed to sync group todos: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// NIP-EE: kind:445 は `tags:[["h", <groupId>]]` でルーティングされる。
  /// 後方互換のため、旧実装の `["group_id", <groupId>]` も許容する。
  bool _isEventForGroup(Map<String, dynamic> eventData, String groupId) {
    final tags = eventData['tags'];
    if (tags is! List) return false;

    bool matches(String key) {
      for (final t in tags) {
        if (t is List && t.length >= 2 && t[0] == key && t[1] == groupId) {
          return true;
        }
      }
      return false;
    }

    return matches('h') || matches('group_id');
  }

  /// MLS payloadからtodoIdを推定（後方互換）
  String? _tryExtractTodoId(String payloadJson) {
    try {
      final map = jsonDecode(payloadJson) as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  /// MLS復号後のpayload（todo JSON）をTodoに変換
  Todo? _parseTodoFromMlsPayload({
    required String payloadJson,
    required String? fallbackId,
    required String groupId,
  }) {
    try {
      final todoData = jsonDecode(payloadJson) as Map<String, dynamic>;
      final id = (todoData['id'] as String?) ?? fallbackId;
      if (id == null || id.isEmpty) return null;

      DateTime? date;
      final dateStr = todoData['date'] as String?;
      if (dateStr != null) {
        date = DateTime.parse(dateStr);
      }

      return Todo(
        id: id,
        title: todoData['title'] as String? ?? '',
        completed: todoData['completed'] as bool? ?? false,
        date: date,
        order: todoData['order'] as int? ?? 0,
        createdAt: DateTime.parse(todoData['created_at'] as String),
        updatedAt: DateTime.parse(todoData['updated_at'] as String),
        customListId: groupId, // 🔥 受信側は必ずこのgroupIdに紐付ける
        recurrence: todoData['recurrence'] != null
            ? RecurrencePattern.fromJson(
                todoData['recurrence'] as Map<String, dynamic>,
              )
            : null,
        parentRecurringId: todoData['parent_recurring_id'] as String?,
        needsSync: false,
      );
    } catch (e) {
      AppLogger.error('❌ [MLS] Failed to parse todo payload: $e');
      return null;
    }
  }

  /// グループにタスクを追加（楽観的UI更新）
  Future<void> addTodoToGroup({
    required String groupId,
    required String title,
    DateTime? date,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final newTodo = Todo(
      id: uuid.v4(),
      title: title,
      date: date,
      createdAt: now,
      updatedAt: now,
      customListId: groupId,
      needsSync: true, // 🔥 Phase 8.3: グループTodoは同期が必要
    );

    // 楽観的UI更新
    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(todos);

      // 既存のタスクのorderを1つずつ増やす
      if (updated.containsKey(date)) {
        updated[date] = updated[date]!.map((t) {
          if (t.customListId == groupId && !t.completed) {
            return t.copyWith(order: t.order + 1);
          }
          return t;
        }).toList();
      } else {
        updated[date] = [];
      }

      // 新しいタスクを追加
      updated[date]!.insert(0, newTodo);

      // 🔥 Phase 8.7: グループTODO追加時は即座にUI更新
      // addPostFrameCallback による遅延ではなく、即座に state を更新する
      state = AsyncValue.data(updated);
      AppLogger.info('🎨 [Group] UI updated immediately for new group todo');

      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);

      AppLogger.info('✅ [Group] Todo added to local storage (optimistic)');

      // MLS差分イベントとして送信（add）
      _syncToNostr(() async {
        await _sendMlsGroupTodoAction(
          groupId: groupId,
          action: 'add',
          todo: newTodo,
        );
      });
    }).value;
  }

  /// グループのタスクを更新（楽観的UI更新）
  Future<void> updateTodoInGroup({
    required String groupId,
    required Todo updatedTodo,
  }) async {
    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(todos);

      // 既存のタスクを更新
      for (final dateKey in updated.keys) {
        updated[dateKey] = updated[dateKey]!.map((t) {
          if (t.id == updatedTodo.id) {
            return updatedTodo.copyWith(
              updatedAt: DateTime.now(),
              needsSync: true,
            );
          }
          return t;
        }).toList();
      }

      // 🔥 Phase 8.7: グループTODO更新時は即座にUI更新
      state = AsyncValue.data(updated);
      AppLogger.info(
        '🎨 [Group] UI updated immediately for updated group todo',
      );

      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);

      AppLogger.info('✅ [Group] Todo updated in local storage (optimistic)');

      // MLS差分イベントとして送信（update）
      _syncToNostr(() async {
        await _sendMlsGroupTodoAction(
          groupId: groupId,
          action: 'update',
          todo: updatedTodo,
        );
      });
    }).value;
  }

  /// グループからタスクを削除（楽観的UI更新）
  Future<void> deleteTodoFromGroup({
    required String groupId,
    required String todoId,
  }) async {
    await state.whenData((todos) async {
      // 削除前に対象Todoを特定（送信用）
      Todo? target;
      for (final entry in todos.entries) {
        for (final t in entry.value) {
          if (t.id == todoId && t.customListId == groupId) {
            target = t;
            break;
          }
        }
        if (target != null) break;
      }

      final updated = Map<DateTime?, List<Todo>>.from(todos);

      // タスクを削除
      for (final dateKey in updated.keys) {
        updated[dateKey] = updated[dateKey]!
            .where((t) => t.id != todoId)
            .toList();
      }

      _setTodosStateAsync(updated);

      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);

      AppLogger.info('✅ [Group] Todo deleted from local storage (optimistic)');

      // MLS差分イベントとして送信（delete）
      _syncToNostr(() async {
        await _sendMlsGroupTodoAction(
          groupId: groupId,
          action: 'delete',
          todo: target,
          todoIdOverride: todoId,
        );
      });
    }).value;
  }

  /// グループTODOのリアルタイム購読を開始（即反映）
  Future<void> startRealtimeGroupTodos(String groupId) async {
    final customListsAsync = _ref.read(customListsProvider);
    final customLists =
        customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
    final groupList = customLists
        .where((l) => l.id == groupId && l.isGroup)
        .firstOrNull;
    if (groupList != null &&
        groupList.protocolVersion == CustomListHelpers.protocolGw17V1) {
      AppLogger.info(
        'ℹ️ [GW17] Realtime subscription is not required: $groupId',
      );
      return;
    }

    final isShared = groupList != null && groupList.isSharedProtocol;

    // 参照カウント: 既に購読中ならrefCountだけ増やす
    final existing = _mlsGroupTodoSubscriptions[groupId];
    if (existing != null) {
      existing.refCount++;
      AppLogger.debug(
        '📡 [Group] Reusing realtime subscription: $groupId (refCount=${existing.refCount})',
      );
      // shared-v1: 購読再利用時もバックログ回収のためフルフェッチを発火する。
      // 購読が張りっぱなしでもポーリング停止中などに溜まった差分を
      // ここで確定的に取り込む。
      if (isShared) {
        unawaited(_syncSharedGroupTodos(groupId: groupId));
      }
      return;
    }

    // shared-v1: kind:35000/35001 を npub_G で購読する。
    // MLS とフィルタが異なるため別経路に分岐する。
    if (isShared) {
      final repo = _ref.read(shared_providers.sharedListRepositoryProvider);
      final credsResult = await repo.loadCredentials(groupId: groupId);
      final credentials = credsResult.fold((_) => null, (c) => c);
      if (credentials == null) {
        AppLogger.warning(
          '⚠️ [shared-v1] No credentials for $groupId; skipping realtime sub',
        );
        return;
      }

      final nostrService = _ref.read(nostrServiceProvider);
      AppLogger.info(
        '📡 [shared-v1] Starting realtime group task subscription: $groupId',
      );

      final subId = await nostrService.subscribeSharedGroupTasks(
        groupNpubHex: credentials.groupNpubHex,
        onEventsReceived: (events) {
          _handleRealtimeSharedGroupTaskEvents(
            groupId: groupId,
            groupNsecHex: credentials.groupNsecHex,
            events: events,
          );
        },
      );

      _mlsGroupTodoSubscriptions[groupId] = _MlsGroupRealtimeSubscription(
        subscriptionId: subId,
        refCount: 1,
      );
      _mlsGroupTodoSeenEventIds.putIfAbsent(groupId, () => <String>{});

      // 購読確立直後に明示的なフルフェッチを行う。
      // fetch_events は REQ+EOSE で確定的に現在状態を返すため、
      // リアルタイム購読の確立タイミングに依存せずバックログを回収できる。
      unawaited(_syncSharedGroupTodos(groupId: groupId));
      return;
    }

    AppLogger.debug('📡 [MLS] Initializing realtime subscription: $groupId');
    await _initMlsIfNeeded();

    final nostrService = _ref.read(nostrServiceProvider);
    final publicKey = await nostrService.getPublicKey();
    if (publicKey == null) {
      throw Exception('User public key not available');
    }

    AppLogger.info(
      '📡 [MLS] Starting realtime group todo subscription: $groupId',
    );

    final subId = await nostrService.subscribeMlsGroupTodos(
      groupId: groupId,
      onEventsReceived: (events) {
        _handleRealtimeMlsGroupTodoEvents(
          groupId: groupId,
          publicKey: publicKey,
          events: events,
        );
      },
    );

    _mlsGroupTodoSubscriptions[groupId] = _MlsGroupRealtimeSubscription(
      subscriptionId: subId,
      refCount: 1,
    );
    _mlsGroupTodoSeenEventIds.putIfAbsent(groupId, () => <String>{});
  }

  /// グループTODOのリアルタイム購読を停止
  Future<void> stopRealtimeGroupTodos(String groupId) async {
    final existing = _mlsGroupTodoSubscriptions[groupId];
    if (existing == null) return;

    existing.refCount--;
    if (existing.refCount > 0) return;

    final subId = existing.subscriptionId;
    _mlsGroupTodoSubscriptions.remove(groupId);
    _mlsGroupTodoSeenEventIds.remove(groupId);

    try {
      final nostrService = _ref.read(nostrServiceProvider);
      await nostrService.stopSubscription(subId);
      AppLogger.info(
        '🛑 [MLS] Stopped realtime group todo subscription: $groupId',
      );
    } catch (e) {
      AppLogger.warning('⚠️ [MLS] Failed to stop subscription ($groupId): $e');
    }
  }

  void _handleRealtimeMlsGroupTodoEvents({
    required String groupId,
    required String publicKey,
    required List<rust_api.ReceivedEvent> events,
  }) {
    // 非同期処理はここでfire-and-forget（購読スレッドを塞がない）
    Future<void>(() async {
      final seen = _mlsGroupTodoSeenEventIds.putIfAbsent(
        groupId,
        () => <String>{},
      );

      for (final event in events) {
        try {
          // dedupe by eventId
          if (seen.contains(event.eventId)) continue;
          seen.add(event.eventId);

          // event_jsonをパースしてcontentを取得
          final eventData = jsonDecode(event.eventJson) as Map<String, dynamic>;
          final encryptedContent = eventData['content'] as String;

          // NIP-EE: `h` タグでグループを識別（後方互換で `group_id` も許容）
          if (!_isEventForGroup(eventData, groupId)) continue;

          // MLS復号化
          final (todoContent, action, todoId, senderPubkey, _) = await rust_api
              .mlsDecryptTodo(
                nostrId: publicKey,
                groupId: groupId,
                encryptedMsg: encryptedContent,
              );

          await _applyMlsTodoDelta(
            groupId: groupId,
            todoContent: todoContent,
            action: action,
            todoId: todoId,
            senderPubkey: senderPubkey,
          );
        } catch (e, st) {
          AppLogger.error(
            '❌ [MLS] Failed to process realtime group todo event: $e',
            error: e,
            stackTrace: st,
          );
        }
      }
    });
  }

  /// shared-v1: リアルタイム受信した kind:35000 (task) を復号して状態に反映する。
  /// kind:35001 (meta) は現状 group メタ更新のみで、todo state には影響しないため
  /// ここではスキップする。
  void _handleRealtimeSharedGroupTaskEvents({
    required String groupId,
    required String groupNsecHex,
    required List<rust_api.ReceivedEvent> events,
  }) {
    Future<void>(() async {
      final seen = _mlsGroupTodoSeenEventIds.putIfAbsent(
        groupId,
        () => <String>{},
      );
      var changed = false;
      final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
      final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
      final byId = <String, Todo>{};
      for (final entry in updated.entries) {
        for (final t in entry.value) {
          if (t.customListId == groupId) {
            byId[t.id] = t;
          }
        }
      }

      // LWW 決定論化: 1回のポーリングで複数イベントが届いた場合も
      // created_at 昇順（同秒は event id 辞書順）で適用する（issue #138 R1/R2）。
      final orderedEvents = List<rust_api.ReceivedEvent>.from(events)
        ..sort((a, b) {
          if (a.createdAt != b.createdAt) {
            return a.createdAt.compareTo(b.createdAt);
          }
          return a.eventId.compareTo(b.eventId);
        });

      for (final event in orderedEvents) {
        try {
          if (seen.contains(event.eventId)) continue;
          seen.add(event.eventId);

          final eventData = jsonDecode(event.eventJson) as Map<String, dynamic>;
          final kind = eventData['kind'] as int?;
          if (kind != 35000) continue; // meta(35001) はここでは無視

          final decrypted = await rust_api.sharedDecryptTaskEvent(
            groupNsecHex: groupNsecHex,
            eventJson: event.eventJson,
          );
          final data = jsonDecode(decrypted) as Map<String, dynamic>;
          final parsed = _parseSharedTaskPayload(
            data: data,
            groupId: groupId,
          );
          if (parsed == null) continue;

          final prev = byId[parsed.id];

          // LWW: ローカルに未同期のより新しい編集があれば上書きしない。
          if (prev != null &&
              prev.needsSync &&
              prev.updatedAt.isAfter(parsed.updatedAt)) {
            continue;
          }

          if (data['deleted'] == true) {
            byId.remove(parsed.id);
            for (final dateKey in updated.keys.toList()) {
              updated[dateKey] = updated[dateKey]!
                  .where((t) => t.id != parsed.id)
                  .toList();
            }
            changed = true;
            continue;
          }

          if (prev != null && prev.date != parsed.date) {
            updated[prev.date] = (updated[prev.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          } else {
            updated[parsed.date] = (updated[parsed.date] ?? [])
                .where((t) => t.id != parsed.id)
                .toList();
          }
          byId[parsed.id] = parsed;
          updated[parsed.date] ??= [];
          updated[parsed.date]!.add(parsed);
          changed = true;
        } catch (e, st) {
          AppLogger.error(
            '❌ [shared-v1] Failed to apply realtime task event: $e',
            error: e,
            stackTrace: st,
          );
        }
      }

      if (changed) {
        final allTodos = <Todo>[];
        for (final dateGroup in updated.values) {
          allTodos.addAll(dateGroup);
        }
        await localStorageService.saveTodos(allTodos);
        state = AsyncValue.data(updated);
        AppLogger.info(
          '✅ [shared-v1] Applied realtime task delta for $groupId',
        );
      }
    });
  }

  /// 復号済みMLS Todoイベントを差分適用（upsert/delete）
  Future<void> _applyMlsTodoDelta({
    required String groupId,
    required String todoContent,
    required String action,
    required String todoId,
    required String senderPubkey,
  }) async {
    final effectiveAction = action.isEmpty ? 'upsert' : action;
    final effectiveTodoId = todoId.isNotEmpty
        ? todoId
        : _tryExtractTodoId(todoContent);

    final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
    final updated = Map<DateTime?, List<Todo>>.from(currentTodos);

    // index existing group todos
    final byId = <String, Todo>{};
    for (final entry in updated.entries) {
      for (final t in entry.value) {
        if (t.customListId == groupId) {
          byId[t.id] = t;
        }
      }
    }

    if (effectiveAction == 'delete') {
      if (effectiveTodoId == null || effectiveTodoId.isEmpty) return;
      byId.remove(effectiveTodoId);
      for (final dateKey in updated.keys) {
        updated[dateKey] = updated[dateKey]!
            .where((t) => t.id != effectiveTodoId)
            .toList();
      }

      _setTodosStateAsync(updated);
      _debouncedSaveAllTodos();
      AppLogger.info(
        '🗑️ [MLS] Realtime delete applied: $effectiveTodoId (from ${senderPubkey.substring(0, 16)}...)',
      );
      return;
    }

    final parsed = _parseTodoFromMlsPayload(
      payloadJson: todoContent,
      fallbackId: effectiveTodoId,
      groupId: groupId,
    );
    if (parsed == null) return;

    final prev = byId[parsed.id];
    if (prev != null) {
      updated[prev.date] = (updated[prev.date] ?? [])
          .where((t) => t.id != parsed.id)
          .toList();
    }
    updated[parsed.date] = (updated[parsed.date] ?? [])
        .where((t) => t.id != parsed.id)
        .toList();
    updated[parsed.date]!.add(parsed);

    _setTodosStateAsync(updated);
    _debouncedSaveAllTodos();
    AppLogger.info(
      '✅ [MLS] Realtime upsert applied: ${parsed.title} (action=$effectiveAction, from ${senderPubkey.substring(0, 16)}...)',
    );
  }

  void _debouncedSaveAllTodos() {
    _mlsRealtimeSaveDebounce?.cancel();
    _mlsRealtimeSaveDebounce = Timer(const Duration(milliseconds: 300), () {
      Future<void>(() async {
        try {
          await _saveAllTodosToLocal();
        } catch (e) {
          AppLogger.warning(
            '⚠️ [MLS] Failed to save todos after realtime update: $e',
          );
        }
      });
    });
  }

  /// MLSグループTODOをNostrへ送信（差分イベント）
  ///
  /// - action: add | update | toggle | delete | reorder | move
  /// - delete の場合、todo は null でも良い（todoIdOverride が必須）
  Future<void> _sendMlsGroupTodoAction({
    required String groupId,
    required String action,
    Todo? todo,
    String? todoIdOverride,
  }) async {
    final nostrService = _ref.read(nostrServiceProvider);
    final customListsAsync = _ref.read(customListsProvider);
    final customLists =
        customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
    final groupList = customLists
        .where((l) => l.id == groupId && l.isGroup)
        .firstOrNull;
    if (groupList == null) {
      throw Exception('Group list not found: $groupId');
    }

    final publicKey = await nostrService.getPublicKey();
    if (publicKey == null) {
      throw Exception('User public key not available');
    }

    final todoId = todoIdOverride ?? todo?.id;
    if (todoId == null || todoId.isEmpty) {
      throw Exception('todoId is required for MLS group action: $action');
    }

    // payload（todo JSON）
    final payload = todo != null
        ? jsonEncode({
            'id': todo.id,
            'title': todo.title,
            'completed': todo.completed,
            'date': todo.date?.toIso8601String(),
            'order': todo.order,
            'created_at': todo.createdAt.toIso8601String(),
            'updated_at': todo.updatedAt.toIso8601String(),
            'custom_list_id': groupId,
            'recurrence': todo.recurrence?.toJson(),
            'parent_recurring_id': todo.parentRecurringId,
          })
        : jsonEncode({
            'id': todoId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'custom_list_id': groupId,
          });

    String? eventId;
    if (groupList.protocolVersion == CustomListHelpers.protocolGw17V1) {
      if (groupList.groupMembers.isEmpty) {
        AppLogger.warning(
          '⚠️ [GW17] Group has no members, skip send: $groupId',
        );
        return;
      }
      for (final memberPubkey in groupList.groupMembers) {
        final sentId = await nostrService.sendGw17TodoUpdate(
          recipientPubkeyHex: memberPubkey,
          groupId: groupId,
          groupName: groupList.name,
          action: action,
          todoPayload: jsonDecode(payload) as Map<String, dynamic>,
        );
        eventId = sentId ?? eventId;
      }
    } else if (groupList.isSharedProtocol) {
      eventId = await _sendSharedGroupTodoAction(
        groupId: groupId,
        action: action,
        todo: todo,
        payload: payload,
        editorPubkey: publicKey,
      );
    } else {
      await _initMlsIfNeeded();
      // MLS暗号化（NIP-EE）
      final encryptedMsg = await rust_api.mlsAddTodo(
        nostrId: publicKey,
        groupId: groupId,
        todoJson: payload,
        action: action,
        todoId: todoId,
      );
      eventId = await nostrService.sendMlsGroupTodo(
        encryptedContent: encryptedMsg,
        groupId: groupId,
      );
    }

    if (eventId == null) {
      AppLogger.warning(
        '⚠️ [Group] Failed to send group todo action: $action (todoId=$todoId)',
      );
    } else {
      AppLogger.info(
        '✅ [Group] Sent group todo action: $action (todoId=$todoId, eventId=${eventId.substring(0, 16)}...)',
      );

      // 送信成功したら needsSync をクリア（削除は既にローカルから消えている）
      if (action != 'delete') {
        final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
        final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
        var changed = false;
        for (final dateKey in updated.keys) {
          updated[dateKey] = updated[dateKey]!.map((t) {
            if (t.id == todoId && t.customListId == groupId && t.needsSync) {
              changed = true;
              return t.copyWith(needsSync: false);
            }
            return t;
          }).toList();
        }
        if (changed) {
          _setTodosStateAsync(updated);
          _debouncedSaveAllTodos();
        }
      }
    }
  }

  /// グループタスクをNostrに同期（バックグラウンド）
  Future<void> _syncGroupToNostr(String groupId) async {
    try {
      AppLogger.info('📤 [GroupSync] Syncing group tasks to Nostr: $groupId');

      // グループリスト情報を取得
      final customListsAsync = _ref.read(customListsProvider);
      final customLists =
          customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
      final groupList = customLists
          .where((l) => l.id == groupId && l.isGroup)
          .firstOrNull;

      if (groupList == null) {
        AppLogger.warning('⚠️ [GroupSync] Group list not found: $groupId');
        return;
      }

      // グループのタスクを取得
      final todos =
          state.whenData((todos) {
            final groupTodos = <Todo>[];
            for (final dateGroup in todos.values) {
              for (final todo in dateGroup) {
                if (todo.customListId == groupId) {
                  groupTodos.add(todo);
                }
              }
            }
            return groupTodos;
          }).value ??
          [];

      if (todos.isEmpty) {
        AppLogger.info('ℹ️ [GroupSync] No todos to sync for group: $groupId');
        return;
      }

      // 公開鍵を取得
      var publicKey = _ref.read(publicKeyProvider);
      var npub = _ref.read(nostrPublicKeyProvider);

      // 公開鍵がnullの場合、復元を試みる
      if (publicKey == null || npub == null) {
        AppLogger.warning('[GroupSync] 公開鍵が未設定、復元を試みます...');
        try {
          final nostrService = _ref.read(nostrServiceProvider);
          publicKey = await nostrService.getPublicKey();
          if (publicKey != null) {
            AppLogger.info(
              '[GroupSync] hex公開鍵を復元: ${publicKey.substring(0, 16)}...',
            );
            _ref.read(publicKeyProvider.notifier).state = publicKey;

            npub = await nostrService.hexToNpub(publicKey);
            _ref.read(nostrPublicKeyProvider.notifier).state = npub;
            AppLogger.info(
              '[GroupSync] npub公開鍵も復元: ${npub.substring(0, 16)}...',
            );
          } else {
            throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
          }
        } catch (e) {
          AppLogger.error('[GroupSync] 公開鍵の復元に失敗: $e');
          throw Exception('公開鍵が設定されていません: $e');
        }
      }

      final isMlsGroup =
          groupList.protocolVersion == CustomListHelpers.protocolMlsV1;
      final isGw17Group =
          groupList.protocolVersion == CustomListHelpers.protocolGw17V1;

      String? eventId;

      if (isMlsGroup) {
        // Phase 8.3: MLS経由で送信
        AppLogger.info(
          '🔐 [GroupSync] MLS group detected, using MLS encryption',
        );
        eventId = await _syncGroupToNostrMls(
          groupId: groupId,
          todos: todos,
          publicKey: publicKey,
        );
      } else if (isGw17Group) {
        AppLogger.info('🎁 [GroupSync] GW17 group detected, using fan-out');
        eventId = await _syncGroupToNostrGw17(
          groupList: groupList,
          todos: todos,
        );
      } else if (groupList.isSharedProtocol) {
        // shared-v1: needsSync のタスクを差分イベント(update)としてフラッシュする。
        // 旧実装はここで kind:30001 のレガシーイベントを発行していたが、
        // 作成者以外は復号できない欠陥があり shared-v1 の同期にも不要なため廃止。
        final targets = todos.where((t) => t.needsSync).toList();
        AppLogger.info(
          '📤 [GroupSync] shared-v1 group: flushing ${targets.length} changed todos',
        );
        String? lastEventId;
        for (final todo in targets) {
          final payload = jsonEncode({
            'id': todo.id,
            'title': todo.title,
            'completed': todo.completed,
            'date': todo.date?.toIso8601String(),
            'order': todo.order,
            'created_at': todo.createdAt.toIso8601String(),
            'updated_at': todo.updatedAt.toIso8601String(),
            'custom_list_id': groupId,
            'recurrence': todo.recurrence?.toJson(),
            'parent_recurring_id': todo.parentRecurringId,
          });
          final sentId = await _sendSharedGroupTodoAction(
            groupId: groupId,
            action: 'update',
            payload: payload,
            todo: todo,
            editorPubkey: publicKey,
          );
          lastEventId = sentId ?? lastEventId;
        }
        eventId = lastEventId;
      } else {
        // 旧 kind:30001 グループ（レガシーマルチパーティ暗号化）は廃止済み。
        // 作成者以外は AES 鍵を復号できない欠陥があり、機能として成立して
        // いなかったため送信も行わない。
        AppLogger.warning(
          '⚠️ [GroupSync] Legacy kind:30001 group is no longer supported, skipping publish: $groupId',
        );
      }

      if (eventId != null) {
        // 成功した場合、送信対象（needsSync=true）のみ needsSync=false にする
        final currentTodos = state.valueOrNull ?? <DateTime?, List<Todo>>{};
        final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
        var cleared = 0;
        for (final dateKey in updated.keys) {
          updated[dateKey] = updated[dateKey]!.map((todo) {
            if (todo.customListId == groupId && todo.needsSync) {
              cleared++;
              return todo.copyWith(needsSync: false);
            }
            return todo;
          }).toList();
        }
        _setTodosStateAsync(updated);
        await _saveAllTodosToLocal();
        AppLogger.info(
          '✅ [GroupSync] Group tasks synced to Nostr: cleared=$cleared (lastEventId: $eventId)',
        );
      } else {
        AppLogger.warning(
          '⚠️ [GroupSync] Group task sync failed: eventId is null',
        );
      }
    } catch (e, st) {
      AppLogger.error(
        '❌ [GroupSync] Failed to sync group to Nostr: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Phase 8.3: MLS経由でグループTODOを送信
  Future<String?> _syncGroupToNostrMls({
    required String groupId,
    required List<Todo> todos,
    required String publicKey,
  }) async {
    try {
      await _initMlsIfNeeded();

      // 旧実装は「全TODOをaddとして送る」だったが、重複/競合の原因になるため、
      // ここでは needsSync=true のTODOのみを update(upsert) として送る。
      final targets = todos.where((t) => t.needsSync).toList();
      if (targets.isEmpty) {
        AppLogger.debug(
          'ℹ️ [MLS] No changed todos to sync for group: $groupId',
        );
        return null;
      }

      AppLogger.info(
        '🔐 [MLS] Encrypting ${targets.length} changed todos for group: $groupId',
      );

      final nostrService = _ref.read(nostrServiceProvider);

      String? lastEventId;
      for (final todo in targets) {
        final todoJson = jsonEncode({
          'id': todo.id,
          'title': todo.title,
          'completed': todo.completed,
          'date': todo.date?.toIso8601String(),
          'order': todo.order,
          'created_at': todo.createdAt.toIso8601String(),
          'updated_at': todo.updatedAt.toIso8601String(),
          'custom_list_id': groupId,
          'recurrence': todo.recurrence?.toJson(),
          'parent_recurring_id': todo.parentRecurringId,
        });

        final encryptedMsg = await rust_api.mlsAddTodo(
          nostrId: publicKey,
          groupId: groupId,
          todoJson: todoJson,
          action: 'update', // upsert扱い
          todoId: todo.id,
        );

        lastEventId = await nostrService.sendMlsGroupTodo(
          encryptedContent: encryptedMsg,
          groupId: groupId,
        );
      }

      return lastEventId;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [MLS] Failed to sync group to Nostr via MLS',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String?> _syncGroupToNostrGw17({
    required CustomList groupList,
    required List<Todo> todos,
  }) async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final targets = todos.where((t) => t.needsSync).toList();
      if (targets.isEmpty) return null;
      if (groupList.groupMembers.isEmpty) {
        AppLogger.warning('⚠️ [GW17] Group has no members: ${groupList.id}');
        return null;
      }

      String? lastEventId;
      for (final todo in targets) {
        final payload = {
          'id': todo.id,
          'title': todo.title,
          'completed': todo.completed,
          'date': todo.date?.toIso8601String(),
          'order': todo.order,
          'created_at': todo.createdAt.toIso8601String(),
          'updated_at': todo.updatedAt.toIso8601String(),
          'custom_list_id': groupList.id,
          'recurrence': todo.recurrence?.toJson(),
          'parent_recurring_id': todo.parentRecurringId,
        };
        for (final memberPubkey in groupList.groupMembers) {
          final eventId = await nostrService.sendGw17TodoUpdate(
            recipientPubkeyHex: memberPubkey,
            groupId: groupList.id,
            groupName: groupList.name,
            action: 'update',
            todoPayload: payload,
          );
          lastEventId = eventId ?? lastEventId;
        }
      }
      return lastEventId;
    } catch (e, st) {
      AppLogger.error(
        '❌ [GW17] Failed to sync group todos',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// 全グループのタスクを一括同期
  Future<void> syncAllGroupTodos() async {
    // shared-v1 グループは MLS の fetchMyGroupTaskLists(kind:445)経路に
    // 含まれないため、別途フルフェッチで同期する。バックグラウンド/起動時
    // 同期でも shared-v1 タスクが確実に取り込まれるようにする。
    await _syncAllSharedGroupTodos();

    // 旧 kind:30001 グループ（レガシーマルチパーティ暗号化）の一括取得は廃止。
    // NIP-44 復号に相手（作成者）でなく自分の公開鍵を渡す欠陥により、
    // 作成者以外は一度も復号できたことがなく、shared-v1/MLS に移行済みのため。
  }

  // ========================================
  // MLS関連メソッド（Option B PoC）
  // ========================================

  /// MLS初期化（必要に応じて実行）
  Future<void> _initMlsIfNeeded() async {
    if (_mlsInitialized) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/mls.db';

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        throw Exception('User public key not available');
      }

      AppLogger.info('🔐 [MLS] 初期化開始: dbPath=$dbPath, user=$userPubkey');

      await rust_api.mlsInitDb(
        dbPath: dbPath,
        nostrId: userPubkey,
      );

      _mlsInitialized = true;
      AppLogger.info('✅ [MLS] 初期化完了');
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] 初期化エラー', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// MLSグループを作成（PoC: メンバーなしで作成）
  Future<void> createMlsGroupList({
    required String listId,
    required String listName,
  }) async {
    try {
      await _initMlsIfNeeded();

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        throw Exception('User public key not available');
      }

      AppLogger.info('📦 [MLS] グループ作成開始: listId=$listId, listName=$listName');

      final welcomeMsg = await rust_api.mlsCreateTodoGroup(
        nostrId: userPubkey,
        groupId: listId,
        groupName: listName,
        keyPackages: [], // PoC: メンバーなし
      );

      AppLogger.info('✅ [MLS] グループ作成完了: welcomeSize=${welcomeMsg.length}');

      // Export SecretからListen Keyを取得（テスト）
      final listenKey = await rust_api.mlsGetListenKey(
        nostrId: userPubkey,
        groupId: listId,
      );

      AppLogger.info('🔑 [MLS] Listen Key: $listenKey');
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] グループ作成エラー', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Phase D.8: MLS TODO暗号化テスト（NIP-EE完全準拠）
  Future<String> encryptMlsTodo({
    required String groupId,
    required String todoJson,
  }) async {
    try {
      await _initMlsIfNeeded();

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        throw Exception('User public key not available');
      }

      AppLogger.debug('🔒 [Phase D.8] TODO暗号化: groupId=$groupId');

      // Phase D.8: テスト用のTODO IDを生成
      final testTodoId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      final encrypted = await rust_api.mlsAddTodo(
        nostrId: userPubkey,
        groupId: groupId,
        todoJson: todoJson,
        action: 'add', // Phase D.8: テスト用はaddアクション
        todoId: testTodoId, // Phase D.8: テスト用ID
      );

      AppLogger.debug(
        '✅ [Phase D.8] TODO暗号化完了: ${encrypted.length}文字 (action: add, todoId: $testTodoId)',
      );

      return encrypted;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [Phase D.8] TODO暗号化エラー',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Phase D.8: MLS TODO復号化テスト（NIP-EE完全準拠）
  Future<String> decryptMlsTodo({
    required String groupId,
    required String encryptedMsg,
  }) async {
    try {
      await _initMlsIfNeeded();

      final nostrService = _ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        throw Exception('User public key not available');
      }

      AppLogger.debug('🔓 [Phase D.8] TODO復号化: groupId=$groupId');

      // Phase D.8: 拡張された戻り値を取得
      final (todoContent, action, todoId, senderPubkey, _) = await rust_api
          .mlsDecryptTodo(
            nostrId: userPubkey,
            groupId: groupId,
            encryptedMsg: encryptedMsg,
          );

      if (action.isEmpty) {
        // Phase 9.1形式
        AppLogger.debug(
          '✅ [Phase D.8] TODO復号化完了 (Phase 9.1形式): sender=$senderPubkey',
        );
      } else {
        // Phase D.8形式
        AppLogger.debug('✅ [Phase D.8] TODO復号化完了:');
        AppLogger.debug('   Action: $action');
        AppLogger.debug('   TODO ID: $todoId');
        AppLogger.debug('   Sender: ${senderPubkey.substring(0, 16)}...');
      }

      return todoContent; // todo_content (JSON)
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [Phase D.8] TODO復号化エラー',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

class _MlsGroupRealtimeSubscription {
  _MlsGroupRealtimeSubscription({
    required this.subscriptionId,
    required this.refCount,
  });

  final String subscriptionId;
  int refCount;
}

/// 特定の日付のTodoリストを取得するProvider
/// 未完了タスクを上、完了済みタスクを下に表示
final ProviderFamily<List<Todo>, DateTime?> todosForDateProvider =
    Provider.family<List<Todo>, DateTime?>((ref, date) {
      final todosAsync = ref.watch(todosProvider);
      final expandedParents = ref.watch(subtaskExpansionProvider);
      return todosAsync.when(
        data: (todos) {
          final normalizedDate = date == null
              ? null
              : DateTime(date.year, date.month, date.day);
          final rawList = todos[normalizedDate] ?? [];
          final rootTodos = rawList.where((t) => !t.isSubtask).toList();
          final rootById = <String, Todo>{
            for (final todo in rootTodos) todo.id: todo,
          };

          final subtasksByParent = <String, List<Todo>>{};
          final orphanSubtasks = <Todo>[];
          for (final todo in rawList.where((t) => t.isSubtask)) {
            final parentId = todo.parentTaskId;
            if (parentId != null && rootById.containsKey(parentId)) {
              subtasksByParent.putIfAbsent(parentId, () => <Todo>[]).add(todo);
            } else {
              // 親が同日グループにいない子は末尾に表示する
              orphanSubtasks.add(todo);
            }
          }

          for (final subtasks in subtasksByParent.values) {
            subtasks.sort((a, b) => a.order.compareTo(b.order));
          }

          // 親タスクは従来どおり「未完了 → 完了」で並べる
          final incompleteRoots = rootTodos.where((t) => !t.completed).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          final completedRoots = rootTodos.where((t) => t.completed).toList()
            ..sort((a, b) => a.order.compareTo(b.order));

          final arranged = <Todo>[];

          void appendRootWithChildren(Todo root) {
            arranged.add(root);

            if (!expandedParents.contains(root.id)) {
              return;
            }

            final subtasks = subtasksByParent[root.id];
            if (subtasks == null || subtasks.isEmpty) {
              return;
            }

            arranged.addAll(subtasks);
          }

          for (final root in incompleteRoots) {
            appendRootWithChildren(root);
          }
          for (final root in completedRoots) {
            appendRootWithChildren(root);
          }

          if (orphanSubtasks.isNotEmpty) {
            final incompleteOrphans =
                orphanSubtasks.where((t) => !t.completed).toList()
                  ..sort((a, b) => a.order.compareTo(b.order));
            final completedOrphans =
                orphanSubtasks.where((t) => t.completed).toList()
                  ..sort((a, b) => a.order.compareTo(b.order));
            arranged.addAll(incompleteOrphans);
            arranged.addAll(completedOrphans);
          }

          return arranged;
        },
        loading: () => [],
        error: (_, __) => [],
      );
    });

// ========================================
// マイグレーション Provider
// ========================================

/// マイグレーション状態を管理するProvider
final migrationStatusProvider = StateProvider<MigrationStatus>((ref) {
  return MigrationStatus.notStarted;
});

enum MigrationStatus {
  notStarted, // 未実行
  checking, // チェック中
  needed, // マイグレーションが必要
  inProgress, // 実行中
  completed, // 完了
  failed, // 失敗
  notNeeded, // マイグレーション不要（既にKind 30001のみ）
}
