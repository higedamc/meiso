import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../models/custom_list.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/amber_service.dart';
import '../services/link_preview_service.dart';
import '../services/widget_service.dart';
import '../services/group_task_service.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';
import 'custom_lists_provider.dart';
import 'app_settings_provider.dart';
import '../utils/error_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
// Phase B: UseCaseのインポート
import '../features/todo/application/providers/usecase_providers.dart';
import '../features/todo/application/usecases/create_todo_usecase.dart';
import '../features/todo/application/usecases/update_todo_usecase.dart';
import '../features/todo/application/usecases/delete_todo_usecase.dart';
import '../features/todo/infrastructure/providers/repository_providers.dart';

// Amberモード判定のためのインポート
export 'nostr_provider.dart' show isAmberModeProvider;

/// AmberServiceのProvider
final amberServiceProvider = Provider((ref) => AmberService());

/// 日付ごとにグループ化されたTodoリストを管理するProvider
/// 
/// Map<DateTime?, List<Todo>>:
/// - null キー: Someday
/// - DateTime: 特定の日付
final todosProvider =
    StateNotifierProvider<TodosNotifier, AsyncValue<Map<DateTime?, List<Todo>>>>(
  (ref) => TodosNotifier(ref),
);

class TodosNotifier extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>> {
  TodosNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref _ref;
  final _uuid = const Uuid();
  
  // バッチ同期用のタイマー
  Timer? _batchSyncTimer;
  
  // MLS初期化フラグ（Option B PoC）
  bool _mlsInitialized = false;

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localTodos = await localStorageService.loadTodos();
      
      final hasLocalData = localTodos.isNotEmpty;
      
      if (hasLocalData) {
        // ローカルデータがある場合：即座に表示
        final Map<DateTime?, List<Todo>> grouped = {};
        for (final todo in localTodos) {
          grouped[todo.date] ??= [];
          grouped[todo.date]!.add(todo);
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
        state = AsyncValue.data({});
        
        // ログイン済みの場合のみ優先同期（初回同期フラグ付き）
        if (_ref.read(nostrInitializedProvider)) {
          AppLogger.debug(' [Todos] Nostr初期化済み。優先同期を開始（初回同期）');
          _prioritySync(isInitialSync: true);
        } else {
          AppLogger.debug(' [Todos] Nostr未初期化（ログイン前）のため、同期をスキップ');
        }
      }
      
      // 自動バッチ同期タイマーを開始（30秒ごと）
      _startBatchSyncTimer();
      
    } catch (e) {
      AppLogger.warning(' Todo初期化エラー: $e');
      // エラー時は空のマップで初期化
      AppLogger.warning(' エラー発生のため空のリストで開始');
      state = AsyncValue.data({});
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
      // タイムアウト付きで同期実行（60秒）
      await Future.delayed(Duration.zero).timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          AppLogger.warning(' [Todos] 優先同期タイムアウト（60秒）');
          _ref.read(syncStatusProvider.notifier).syncError(
            '同期がタイムアウトしました',
            shouldRetry: false,
          );
          return;
        },
      ).then((_) async {
        // マイグレーション完了チェック（一度だけ実行）
        final migrationCompleted = await localStorageService.isMigrationCompleted();
        AppLogger.debug(' [Todos] マイグレーションステータス: $migrationCompleted');
        
        if (!migrationCompleted) {
          AppLogger.debug(' [Todos] データステータスを確認中...');
          
          // まずKind 30001（新形式）をチェック
          _ref.read(syncStatusProvider.notifier).updateMessage('データ読み込み中...');
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
              _ref.read(syncStatusProvider.notifier).updateMessage('データ移行中...');
              
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
        
        _ref.read(syncStatusProvider.notifier).updateMessage('データ同期中...');
        await syncFromNostr(isInitialSync: isInitialSync);
        AppLogger.info(' [Todos] 優先同期完了');
      });
    } catch (e, stackTrace) {
      AppLogger.error(' [Todos] 優先同期エラー', error: e, stackTrace: stackTrace);
      _ref.read(syncStatusProvider.notifier).syncError(
        '同期エラー: ${e.toString()}',
        shouldRetry: false,
      );
    }
  }
  
  /// バックグラウンド同期（UIブロックしない）
  Future<void> _backgroundSync() async {
    // 画面表示後に実行
    await Future.delayed(const Duration(seconds: 1));
    
    // Nostr初期化チェック（即座に）
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.debug(' [Todos] Nostr未初期化のため、バックグラウンド同期をスキップ');
      return;
    }
    
    AppLogger.info(' [Todos] バックグラウンド同期を開始');

    try {
      AppLogger.info(' Starting background Nostr sync...');
      
      // タイムアウト付きで実行（60秒）
      await Future.delayed(Duration.zero).timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          AppLogger.debug(' Background sync timeout - continuing with local data');
          _ref.read(syncStatusProvider.notifier).syncError(
            'バックグラウンド同期がタイムアウトしました',
            shouldRetry: false,
          );
          return;
        },
      ).then((_) async {
        // マイグレーション完了チェック（一度だけ実行）
        final migrationCompleted = await localStorageService.isMigrationCompleted();
        AppLogger.debug(' Migration status check: completed=$migrationCompleted');
        
        if (!migrationCompleted) {
          AppLogger.debug(' Checking data status...');
          
          // まずKind 30001（新形式）をチェック
          _ref.read(syncStatusProvider.notifier).updateMessage('データ読み込み中...');
          AppLogger.debug(' Step 1: Checking Kind 30001 existence...');
          final hasNewData = await checkKind30001Exists();
          AppLogger.debug(' Step 1 result: hasNewData=$hasNewData');
          
          if (hasNewData) {
            // Kind 30001にデータがある = マイグレーション済み
            AppLogger.info(' Found Kind 30001 data. Migration already completed on another device.');
            AppLogger.debug(' Loading data from Kind 30001...');
            AppLogger.debug('  SKIPPING migration - Kind 30001 found!');
            
            // Kind 30001から同期（この後のsyncFromNostr()で実行される）
            await localStorageService.setMigrationCompleted();
            AppLogger.info(' Migration flag set to completed');
          } else {
            // Kind 30001がない → Kind 30078をチェック
            AppLogger.debug(' No Kind 30001 found. Checking for old Kind 30078 events...');
            AppLogger.debug(' Step 2: Checking Kind 30078 existence...');
            final needsMigration = await checkMigrationNeeded();
            AppLogger.debug(' Step 2 result: needsMigration=$needsMigration');
            
            if (needsMigration) {
              AppLogger.debug(' Found old Kind 30078 TODO events. Starting migration...');
              AppLogger.warning('  MIGRATION WILL START - THIS WILL TRIGGER AMBER DECRYPTION');
              _ref.read(syncStatusProvider.notifier).updateMessage('データ移行中...');
              
              // マイグレーション実行（Kind 30078 → Kind 30001）
              await migrateFromKind30078ToKind30001();
              AppLogger.info(' Migration completed successfully');
            } else {
              AppLogger.info(' No old events found. Marking migration as completed.');
              // 旧イベントがない場合はマイグレーション完了として記録
              await localStorageService.setMigrationCompleted();
              AppLogger.info(' Migration flag set to completed (no data)');
            }
          }
        } else {
          AppLogger.info(' Migration already completed (cached)');
        }
        
        _ref.read(syncStatusProvider.notifier).updateMessage('データ同期中...');
        await syncFromNostr();
        AppLogger.info(' Background sync completed');
      });
    } catch (e, stackTrace) {
      AppLogger.warning(' バックグラウンド同期失敗: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      
      // エラー状態を更新（ローカルデータは保持）
      _ref.read(syncStatusProvider.notifier).syncError(
        'バックグラウンド同期に失敗しました: ${e.toString()}',
        shouldRetry: false,
      );
      
      // 3秒後にエラーをクリア
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(syncStatusProvider.notifier).clearError();
      });
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
  Future<void> addTodo(String title, DateTime? date, {String? customListId}) async {
    if (title.trim().isEmpty) return;

    AppLogger.debug(' addTodo called: "$title" for date: $date, customListId: $customListId');
    AppLogger.debug('📍 Stack trace location: addTodo');
    if (customListId != null) {
      AppLogger.debug(' IMPORTANT: This todo is being added to custom list: $customListId');
    }

    await state.whenData((todos) async {
      // Phase B: CreateTodoUseCaseを使ってTodoを生成
      final createTodoUseCase = _ref.read(createTodoUseCaseProvider);
      final result = await createTodoUseCase(CreateTodoParams(
        title: title,
        date: date,
        customListId: customListId,
        currentTodos: todos,
      ));

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

          final list = List<Todo>.from(todos[date] ?? []);
          list.add(newTodo);

          final updatedTodos = {
            ...todos,
            date: list,
          };

          // 【楽観的UI更新】即座にUI更新
          state = AsyncValue.data(updatedTodos);
          AppLogger.info(' UI updated immediately (optimistic)');

          // 以下、全てバックグラウンドで実行（UIをブロックしない）
          _performBackgroundTasks(
            newTodo: newTodo,
            updatedTodos: updatedTodos,
            autoRecurrence: autoRecurrence,
            date: date,
            detectedUrl: detectedUrl,
            customListId: customListId,
          );
        },
      );
    }).value;
  }

  /// バックグラウンドで全ての非同期タスクを実行（UIをブロックしない）
  Future<void> _performBackgroundTasks({
    required Todo newTodo,
    required Map<DateTime?, List<Todo>> updatedTodos,
    required RecurrencePattern? autoRecurrence,
    required DateTime? date,
    required String? detectedUrl,
    required String? customListId,
  }) async {
    try {
      // リカーリングタスクの場合、将来のインスタンスを事前生成
      if (autoRecurrence != null && date != null) {
        await _generateFutureInstances(newTodo, updatedTodos);
      }

      // ローカルストレージに保存
      AppLogger.debug(' Saving to local storage (background)...');
      await _saveAllTodosToLocal();
      AppLogger.info(' Local save complete');
      
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
        final isGroup = await customListsAsync.whenData((customLists) async {
          final list = customLists.firstWhere(
            (l) => l.id == customListId, 
            orElse: () => CustomList(
              id: '', 
              name: '', 
              order: 0, 
              createdAt: DateTime.now(), 
              updatedAt: DateTime.now(),
            ),
          );
          return list.isGroup;
        }).value ?? false;
        
        if (isGroup) {
          AppLogger.info('📤 Syncing to group list: $customListId');
          _syncToNostr(() async {
            await _syncGroupToNostr(customListId);
          });
          return; // 通常のTodo同期はスキップ
        }
      }
      
      // 通常のTodo同期
      _syncToNostrBackground();
    } catch (e, stackTrace) {
      AppLogger.error('❌ Background task failed: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// バックグラウンドでリンクプレビューを取得
  Future<void> _fetchLinkPreviewInBackground(
    String todoId,
    DateTime? date,
    String url,
  ) async {
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
            
            AppLogger.debug(' Updating link preview for: "${currentTodo.title}"');
            
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
        AppLogger.warning(' Failed to fetch link preview metadata, removing placeholder...');
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



  /// Todoを更新（楽観的UI更新）
  /// 
  /// Phase B: UpdateTodoUseCaseを使用してTodoを更新
  Future<void> updateTodo(Todo todo) async {
    await state.whenData((todos) async {
      // Phase B: UpdateTodoUseCaseを使ってTodoを更新
      final updateTodoUseCase = _ref.read(updateTodoUseCaseProvider);
      final result = await updateTodoUseCase(UpdateTodoParams(
        todo: todo,
        currentTodos: todos,
      ));

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
            final isGroup = await customListsAsync.whenData((customLists) async {
              final list = customLists.firstWhere((l) => l.id == todo.customListId!, orElse: () => CustomList(id: '', name: '', order: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
              return list.isGroup;
            }).value ?? false;
            
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
  Future<void> updateTodoTitle(String id, DateTime? date, String newTitle) async {
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

        // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
        _updateUnsyncedCount();
        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoのカスタムリスト紐づけを更新（楽観的UI更新）
  Future<void> updateTodoCustomListId(String id, DateTime? date, String? customListId) async {
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

        // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
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

    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        // URLを検出してメタデータを取得（バックグラウンド）
        final detectedUrl = LinkPreviewService.extractUrl(newTitle.trim());
        AppLogger.debug(' URL detected in update: $detectedUrl');
        
        // URLが検出された場合、即座にタイトルから削除
        String finalTitle = newTitle.trim();
        LinkPreview? initialLinkPreview = list[index].linkPreview;
        
        if (detectedUrl != null) {
          // URLからドメイン名を抽出
          String domainName = detectedUrl;
          try {
            final uri = Uri.parse(detectedUrl);
            domainName = uri.host;
          } catch (e) {
            // パースエラー時はそのままURLを使用
          }
          
          finalTitle = LinkPreviewService.removeUrlFromText(newTitle.trim(), detectedUrl);
          // 空になった場合（URLのみの入力）はドメイン名を使用
          if (finalTitle.trim().isEmpty) {
            finalTitle = domainName;
          }
          
          // 一時的なリンクプレビューを作成（取得中を示す）
          initialLinkPreview = LinkPreview(
            url: detectedUrl,
            title: domainName, // ドメイン名を表示
            description: '読み込み中...', // 取得中を日本語で表示
            imageUrl: null,
          );
          
          AppLogger.debug(' Title after URL removal (update): "$finalTitle" (domain: $domainName)');
        }
        
        final updatedTodo = list[index].copyWith(
          title: finalTitle,
          recurrence: recurrence,
          linkPreview: initialLinkPreview,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );
        
        list[index] = updatedTodo;
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // リカーリングタスクの場合、将来のインスタンスを事前生成
        if (recurrence != null && date != null) {
          await _generateFutureInstances(updatedTodo, todos);
        } else if (recurrence == null) {
          // 繰り返しを解除した場合、子タスクを削除
          await _removeChildInstances(id, todos);
        }

        // ローカルストレージに保存（awaitする）
        await _saveAllTodosToLocal();
        
        // Widgetを更新
        await _updateWidget();

        // URLメタデータ取得（非同期・バックグラウンド）
        if (detectedUrl != null) {
          _fetchLinkPreviewInBackground(id, date, detectedUrl);
        }

        // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
        _updateUnsyncedCount();
        _syncToNostrBackground();
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
          final isGroup = await customListsAsync.whenData((customLists) async {
            final list = customLists.firstWhere((l) => l.id == updatedTodo.customListId!, orElse: () => CustomList(id: '', name: '', order: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
            return list.isGroup;
          }).value ?? false;
          
          if (isGroup) {
            AppLogger.info('📤 Syncing to group list: ${updatedTodo.customListId}');
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
        final result = await updateTodoUseCase(UpdateTodoParams(
          todo: updatedTodo,
          currentTodos: todos,
        ));

        await result.fold(
          (failure) async {
            // エラーハンドリング
            AppLogger.error('❌ Failed to toggle todo: ${failure.message}');
            state = AsyncValue.error(failure, StackTrace.current);
          },
          (updatedTodos) async {
            // リカーリングタスクの完了時に次回のタスクを生成
            if (!wasCompleted && todo.recurrence != null && todo.date != null) {
              await _createNextRecurringTask(todo, updatedTodos);
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
              final isGroup = await customListsAsync.whenData((customLists) async {
                final list = customLists.firstWhere((l) => l.id == todo.customListId!, orElse: () => CustomList(id: '', name: '', order: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
                return list.isGroup;
              }).value ?? false;
              
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
      }
    }).value;
  }

  /// リカーリングタスクの次回インスタンスを生成（30日分）
  Future<void> _createNextRecurringTask(
    Todo originalTodo,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    if (originalTodo.recurrence == null || originalTodo.date == null) {
      return;
    }

    AppLogger.debug(' リカーリングタスク完了: ${originalTodo.title}');
    AppLogger.debug(' 将来のインスタンスを再生成します（30日分）');

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

    AppLogger.debug(' 親タスクID: ${parentTask.id}');
    AppLogger.debug(' 元のタスクの日付: ${parentTask.date}');
    
    DateTime? currentDate = originalTodo.date; // 完了したタスクの日付から開始
    int generatedCount = 0;
    const maxInstances = 50; // 最大50個まで生成（無限ループ防止）
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    // 30日以内の将来のインスタンスを生成
    while (generatedCount < maxInstances) {
      final nextDate = parentTask.recurrence!.calculateNextDate(currentDate!);
      
      if (nextDate == null) {
        AppLogger.info(' 繰り返し終了');
        break; // 繰り返し終了
      }

      // 30日以内の日付のみ生成
      if (nextDate.isAfter(thirtyDaysLater)) {
        AppLogger.debug(' 30日以内の範囲を超えたため終了');
        break;
      }

      // 既に同じタイトルのタスクが存在するかチェック
      final existingTasks = todos[nextDate] ?? [];
      final alreadyExists = existingTasks.any((t) => 
        t.parentRecurringId == parentId ||
        (t.title == parentTask!.title && t.recurrence != null && t.id != parentId && !t.completed)
      );

      if (!alreadyExists) {
        // 新しいインスタンスを生成
        final newTodo = Todo(
          id: _uuid.v4(),
          title: parentTask.title,
          completed: false,
          date: nextDate,
          order: _getNextOrder(todos, nextDate),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          recurrence: parentTask.recurrence,
          parentRecurringId: parentId,
          linkPreview: parentTask.linkPreview,
          needsSync: true, // 同期が必要
        );

        final list = List<Todo>.from(todos[nextDate] ?? []);
        list.add(newTodo);
        todos[nextDate] = list;

        generatedCount++;
        AppLogger.info(' インスタンス生成: ${nextDate.month}/${nextDate.day}');
      } else {
        AppLogger.debug(' インスタンス既存: ${nextDate.month}/${nextDate.day}');
      }

      currentDate = nextDate;
    }

    AppLogger.debug(' 合計${generatedCount}個のインスタンスを生成しました');

    // 状態を更新（この時点でUIに反映）
    state = AsyncValue.data(Map.from(todos));
    
    // ローカルに保存
    await _saveAllTodosToLocal();

    // Nostrにも同期
    await _syncToNostr(() async {
      await _syncAllTodosToNostr();
    });
  }

  /// リカーリングタスクの将来のインスタンスを事前生成（30日分）
  Future<void> _generateFutureInstances(
    Todo originalTodo,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    if (originalTodo.recurrence == null || originalTodo.date == null) {
      return;
    }

    AppLogger.debug(' 将来のインスタンスを生成開始: ${originalTodo.title}');
    AppLogger.debug(' 元のタスクの日付: ${originalTodo.date}');
    
    // 元のタスクが含まれているか確認
    final originalDateTasks = todos[originalTodo.date] ?? [];
    final originalTaskExists = originalDateTasks.any((t) => t.id == originalTodo.id);
    AppLogger.debug(' 元のタスクが存在: $originalTaskExists (${originalDateTasks.length}件のタスク)');

    DateTime? currentDate = originalTodo.date;
    int generatedCount = 0;
    const maxInstances = 50; // 最大50個まで生成（無限ループ防止）
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    // 既存の子インスタンスを削除
    await _removeChildInstances(originalTodo.id, todos);
    
    // 削除後に元のタスクがまだ存在するか確認
    final afterRemoveTasks = todos[originalTodo.date] ?? [];
    final originalTaskStillExists = afterRemoveTasks.any((t) => t.id == originalTodo.id);
    AppLogger.debug(' 削除後の元のタスク存在: $originalTaskStillExists (${afterRemoveTasks.length}件のタスク)');

    // 30日以内の将来のインスタンスを生成
    while (generatedCount < maxInstances) {
      final nextDate = originalTodo.recurrence!.calculateNextDate(currentDate!);
      
      if (nextDate == null) {
        AppLogger.info(' 繰り返し終了');
        break; // 繰り返し終了
      }

      // 30日以内の日付のみ生成
      if (nextDate.isAfter(thirtyDaysLater)) {
        AppLogger.debug(' 30日以内の範囲を超えたため終了');
        break;
      }

      // 既に同じタイトルのタスクが存在するかチェック
      final existingTasks = todos[nextDate] ?? [];
      final alreadyExists = existingTasks.any((t) => 
        t.parentRecurringId == originalTodo.id ||
        (t.title == originalTodo.title && t.recurrence != null && t.id != originalTodo.id)
      );

      if (!alreadyExists) {
        // 新しいインスタンスを生成
        final newTodo = Todo(
          id: _uuid.v4(),
          title: originalTodo.title,
          completed: false,
          date: nextDate,
          order: _getNextOrder(todos, nextDate),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          recurrence: originalTodo.recurrence,
          parentRecurringId: originalTodo.id,
          linkPreview: originalTodo.linkPreview,
          needsSync: true, // 同期が必要
        );

        final list = List<Todo>.from(todos[nextDate] ?? []);
        list.add(newTodo);
        todos[nextDate] = list;

        generatedCount++;
        AppLogger.info(' インスタンス生成: ${nextDate.month}/${nextDate.day}');
      }

      currentDate = nextDate;
    }

    AppLogger.debug(' 合計${generatedCount}個のインスタンスを生成しました');
    
    // 最終的に元のタスクが含まれているか確認
    final finalTasks = todos[originalTodo.date] ?? [];
    final finalTaskExists = finalTasks.any((t) => t.id == originalTodo.id);
    AppLogger.debug(' 最終的な元のタスク存在: $finalTaskExists (${finalTasks.length}件のタスク)');

    // 状態を更新
    state = AsyncValue.data(Map.from(todos));
  }

  /// 親タスクの子インスタンスを削除
  Future<void> _removeChildInstances(
    String parentId,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    AppLogger.debug(' 子インスタンスを削除: $parentId');
    
    int removedCount = 0;
    for (final date in todos.keys) {
      final list = List<Todo>.from(todos[date] ?? []);
      final originalLength = list.length;
      
      list.removeWhere((t) => t.parentRecurringId == parentId);
      
      if (list.length < originalLength) {
        removedCount += originalLength - list.length;
        todos[date] = list;
      }
    }

    AppLogger.debug(' ${removedCount}個の子インスタンスを削除しました');

    if (removedCount > 0) {
      state = AsyncValue.data(Map.from(todos));
    }
  }

  /// Todoを削除（楽観的UI更新）
  /// 
  /// Phase B: DeleteTodoUseCaseを使用してTodoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      // Phase B: DeleteTodoUseCaseを使ってTodoを削除
      final deleteTodoUseCase = _ref.read(deleteTodoUseCaseProvider);
      final result = await deleteTodoUseCase(DeleteTodoParams(
        id: id,
        date: date,
        currentTodos: todos,
      ));

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

      AppLogger.debug(' リカーリングタスクのインスタンスを削除: ${todo.title} (${date})');

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
      int deletedCount = 0;
      final updatedTodos = Map<DateTime?, List<Todo>>.from(todos);
      
      for (final dateKey in updatedTodos.keys) {
        final dateList = List<Todo>.from(updatedTodos[dateKey] ?? []);
        final originalLength = dateList.length;
        
        // 親タスク、または親タスクから派生した子タスクをすべて削除
        dateList.removeWhere((t) => 
          t.id == parentId || 
          t.parentRecurringId == parentId
        );
        
        if (dateList.length < originalLength) {
          deletedCount += originalLength - dateList.length;
          updatedTodos[dateKey] = dateList;
        }
      }

      AppLogger.debug(' 合計${deletedCount}個のリカーリングインスタンスを削除しました');

      state = AsyncValue.data(updatedTodos);

      // ローカルストレージに保存（awaitする）
      await _saveAllTodosToLocal();

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
      _updateUnsyncedCount();
      _syncToNostrBackground();
    }).value;
  }

  /// Todoを並び替え（楽観的UI更新）
  Future<void> reorderTodo(
    DateTime? date,
    int oldIndex,
    int newIndex,
  ) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      // orderを再計算
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );
      }

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
      _syncToNostrBackground();
    }).value;
  }

  /// Todoを別の日付に移動（楽観的UI更新）
  Future<void> moveTodo(String id, DateTime? fromDate, DateTime? toDate) async {
    if (fromDate == toDate) return;

    await state.whenData((todos) async {
      final fromList = List<Todo>.from(todos[fromDate] ?? []);
      final toList = List<Todo>.from(todos[toDate] ?? []);

      final todoIndex = fromList.indexWhere((t) => t.id == id);
      if (todoIndex == -1) return;

      final todo = fromList.removeAt(todoIndex);
      final movedTodo = todo.copyWith(
        date: toDate,
        order: _getNextOrder({toDate: toList}, toDate),
        updatedAt: DateTime.now(),
        needsSync: true, // 同期が必要
      );
      toList.add(movedTodo);

      state = AsyncValue.data({
        ...todos,
        fromDate: fromList,
        toDate: toList,
      });

      // ローカルストレージに保存（awaitする）
      await _saveAllTodosToLocal();
      
      // Widgetを更新
      await _updateWidget();

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
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
  void _syncToNostrBackground() {
    AppLogger.debug(' _syncToNostrBackground called (non-blocking)');
    
    final isInitialized = _ref.read(nostrInitializedProvider);
    if (!isInitialized) {
      AppLogger.warning(' Nostr未初期化のため、バックグラウンド同期をスキップ');
      return;
    }

    // awaitせずに実行（Fire and forget）
    Future.microtask(() async {
      try {
        AppLogger.info(' Starting background sync to Nostr...');
        await _syncAllTodosToNostr();
        
        // 同期成功後、needsSyncフラグをクリア
        await _clearNeedsSyncFlags();
        
        AppLogger.info(' Background sync completed successfully');
        _ref.read(syncStatusProvider.notifier).syncSuccess();
      } catch (e, stackTrace) {
        AppLogger.error(' Background sync failed: $e');
        AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        // エラーは記録するが、UIには影響しない
        _ref.read(syncStatusProvider.notifier).syncError(
          'バックグラウンド同期エラー: ${e.toString()}',
          shouldRetry: false,
        );
        
        // 3秒後にエラーをクリア
        Future.delayed(const Duration(seconds: 3), () {
          _ref.read(syncStatusProvider.notifier).clearError();
        });
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
    _ref.read(syncStatusProvider.notifier).state = 
      _ref.read(syncStatusProvider).copyWith(
        pendingItems: unsyncedTodos.length,
      );
  }

  /// 同期成功後、needsSyncフラグをクリア
  /// 指定されたTodoのeventIdを更新
  Future<void> _updateTodoEventIdInState(String todoId, DateTime? date, String eventId) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == todoId);
      
      if (index != -1) {
        list[index] = list[index].copyWith(
          eventId: eventId,
          needsSync: false, // 同期完了
        );
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });
        
        AppLogger.info(' Updated eventId for todo "${list[index].title}": $eventId');
      }
    }).value;
    
    // ローカルストレージに保存
    await _saveAllTodosToLocal();
  }

  /// 指定されたTodoのcustomListIdを更新（マイグレーション用）
  Future<void> _updateTodoCustomListIdInState(String todoId, DateTime? date, String newListId) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == todoId);
      
      if (index != -1) {
        list[index] = list[index].copyWith(
          customListId: newListId,
        );
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });
      }
    }).value;
    
    // ローカルストレージに保存
    await _saveAllTodosToLocal();
  }

  Future<void> _clearNeedsSyncFlags() async {
    state.whenData((todos) async {
      final Map<DateTime?, List<Todo>> updatedTodos = {};
      bool hasChanges = false;

      for (final entry in todos.entries) {
        final date = entry.key;
        final list = entry.value.map((todo) {
          if (todo.needsSync) {
            hasChanges = true;
            return todo.copyWith(needsSync: false);
          }
          return todo;
        }).toList();
        updatedTodos[date] = list;
      }

      if (hasChanges) {
        state = AsyncValue.data(updatedTodos);
        await _saveAllTodosToLocal();
        _updateUnsyncedCount(); // 未同期カウントを更新
        AppLogger.info(' Cleared needsSync flags for all todos');
      }
    });
  }

  /// 自動バッチ同期タイマーを開始（30秒ごと）
  void _startBatchSyncTimer() {
    AppLogger.debug(' Starting batch sync timer (every 30 seconds)');
    
    // 既存のタイマーをキャンセル
    _batchSyncTimer?.cancel();
    
    // 30秒ごとに実行
    _batchSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _executeBatchSync();
    });
  }

  /// バッチ同期を実行
  Future<void> _executeBatchSync() async {
    final unsyncedTodos = _getUnsyncedTodos();
    
    if (unsyncedTodos.isEmpty) {
      AppLogger.info(' No unsynced todos - skipping batch sync');
      return;
    }

    AppLogger.info(' Batch sync: ${unsyncedTodos.length} unsynced todos found');
    AppLogger.debug(' Syncing to Nostr...');
    
    // バックグラウンドで同期
    _syncToNostrBackground();
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
    
    final isInitialized = _ref.read(nostrInitializedProvider);
    AppLogger.debug(' Nostr initialized in _syncAllTodosToNostr: $isInitialized');
    
    if (!isInitialized) {
      AppLogger.warning(' Nostr未初期化のため同期をスキップ');
      return;
    }

    // state.whenDataは、stateがdata状態でない場合は何もしない
    // そのため、loading/error状態の場合は同期をスキップ
    final stateValue = state;
    if (!stateValue.hasValue) {
      AppLogger.warning(' State is not ready (loading or error), skipping sync');
      throw Exception('State is not ready for sync');
    }

    await state.whenData((todos) async {  // ← awaitを追加！
      AppLogger.debug(' _syncAllTodosToNostr: state.whenData callback STARTED');
      
      // 全TODOをフラット化
      final allTodos = <Todo>[];
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }

      AppLogger.debug(' Total todos to sync: ${allTodos.length}');
      
      // カスタムリストに属するTodoをログ出力
      final customListTodos = allTodos.where((t) => t.customListId != null).toList();
      if (customListTodos.isNotEmpty) {
        AppLogger.debug(' Found ${customListTodos.length} todos with customListId:');
        for (final todo in customListTodos) {
          AppLogger.debug('   - "${todo.title}" → customListId: ${todo.customListId}');
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
                final nameBasedId = CustomListHelpers.generateIdFromName(list.name);
                customListsMap[list.id] = nameBasedId;
                customListNames[nameBasedId] = list.name;
              }
            }
          }).value;
          
          // 1. Todoをリストごとにグループ化（名前ベースIDに変換）
          // グループリストのTodoは除外（別途 _syncGroupToNostr で同期される）
          final Map<String, List<Todo>> groupedTodos = {};
          for (final todo in allTodos) {
            // グループリストのTodoはスキップ
            if (todo.customListId != null && groupListIds.contains(todo.customListId)) {
              AppLogger.debug('   Skipping group list todo: "${todo.title}" (groupId: ${todo.customListId})');
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
            final todoTitles = entry.value.map((t) => t.title).take(3).join(', ');
            AppLogger.debug('  - List "${entry.key}": ${entry.value.length} todos (${todoTitles}${entry.value.length > 3 ? '...' : ''})');
          }
          
          // 2. 公開鍵取得
          var publicKey = _ref.read(publicKeyProvider);
          var npub = _ref.read(nostrPublicKeyProvider);
          
          // 公開鍵がnullの場合、Rust側から復元を試みる
          if (publicKey == null) {
            AppLogger.warning(' Public key (hex) is null, attempting to restore from storage...');
            try {
              publicKey = await nostrService.getPublicKey();
              if (publicKey != null) {
                AppLogger.info(' Public key (hex) restored from storage: ${publicKey.substring(0, 16)}...');
                _ref.read(publicKeyProvider.notifier).state = publicKey;
                
                // npub形式にも変換して設定
                try {
                  npub = await nostrService.hexToNpub(publicKey);
                  _ref.read(nostrPublicKeyProvider.notifier).state = npub;
                  AppLogger.info(' Public key (npub) also restored: ${npub.substring(0, 16)}...');
                } catch (e) {
                  AppLogger.error(' Failed to convert hex to npub: $e');
                }
              } else {
                AppLogger.error(' Failed to restore public key - no key found in storage');
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
            
            AppLogger.debug(' Processing list "$listId" (${listTodos.length} todos)');
            
            // リストのTodoをJSONに変換
            final todosJson = jsonEncode(listTodos.map((todo) => {
              'id': todo.id,
              'title': todo.title,
              'completed': todo.completed,
              'date': todo.date?.toIso8601String(),
              'order': todo.order,
              'created_at': todo.createdAt.toIso8601String(),
              'updated_at': todo.updatedAt.toIso8601String(),
              'event_id': todo.eventId,
              'link_preview': todo.linkPreview?.toJson(),
              'custom_list_id': todo.customListId,
              'recurrence': todo.recurrence?.toJson(),
              'parent_recurring_id': todo.parentRecurringId,
              'needs_sync': todo.needsSync,
            }).toList());
            
            AppLogger.debug(' List "$listId" JSON (${todosJson.length} bytes, ${listTodos.length}件)');
            
            // AmberでNIP-44暗号化
            AppLogger.debug('🔐 Amberで暗号化中（リスト: $listId）...');
            
            String encryptedContent;
            try {
              // まずContentProvider経由で試す（バックグラウンド処理）
              encryptedContent = await amberService.encryptNip44WithContentProvider(
                plaintext: todosJson,
                pubkey: publicKey,
                npub: npub,
              );
              AppLogger.info(' 暗号化完了（バックグラウンド） (${encryptedContent.length} bytes)');
            } on PlatformException catch (e) {
              // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
              AppLogger.warning(' ContentProvider暗号化失敗 (${e.code}), UI経由で再試行します...');
              encryptedContent = await amberService.encryptNip44(todosJson, publicKey);
              AppLogger.info(' 暗号化完了（UI経由） (${encryptedContent.length} bytes)');
            }
            
            // 暗号化済みcontentで未署名イベントを作成（Kind 30001）
            final unsignedEvent = await nostrService.createUnsignedEncryptedTodoListEvent(
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
              AppLogger.warning(' ContentProvider署名失敗 (${e.code}), UI経由で再試行します...');
              signedEvent = await amberService.signEventWithTimeout(unsignedEvent);
              AppLogger.info(' 署名完了（UI経由）');
            }
            
            // リレーに送信
            AppLogger.debug(' リレーに送信中（リスト: $listId）...');
            final sendResult = await nostrService.sendSignedEvent(signedEvent);
            AppLogger.info(' 送信完了: ${sendResult.eventId}');
            AppLogger.debug(' List "$listId" event ID: ${sendResult.eventId}');
            
            // このリストの各TodoのeventIdとcustomListIdを更新
            for (final todo in listTodos) {
              await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
              
              // 名前ベースIDに更新（UUIDベースの場合のマイグレーション）
              if (todo.customListId != null && todo.customListId != listId) {
                await _updateTodoCustomListIdInState(todo.id, todo.date, listId);
                AppLogger.info(' Migrated customListId: ${todo.customListId} -> $listId for "${todo.title}"');
              }
            }
            AppLogger.info(' Updated eventId for ${listTodos.length} todos in list "$listId"');
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
            if (todo.customListId != null && groupListIds.contains(todo.customListId)) {
              AppLogger.debug('   Skipping group list todo: "${todo.title}" (groupId: ${todo.customListId})');
              return false;
            }
            return true;
          }).toList();
          
          AppLogger.info(' Calling nostrService.createTodoListOnNostr with ${nonGroupTodos.length} non-group todos (excluded ${allTodos.length - nonGroupTodos.length} group todos)...');
          
          try {
            final sendResult = await nostrService.createTodoListOnNostr(nonGroupTodos);
            AppLogger.info('✅✅ TODOリスト送信完了: ${sendResult.eventId} (${nonGroupTodos.length}件)');
            
            // 全TodoのeventIdを更新
            for (final todo in nonGroupTodos) {
              await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
            }
            AppLogger.info(' Updated eventId for ${nonGroupTodos.length} todos');
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
      
      AppLogger.debug(' _syncAllTodosToNostr: state.whenData callback COMPLETED successfully');
    }).value;  // ← .value追加で確実に完了を待つ
    
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
        // タイムアウト付きで同期実行（30秒）
        await syncFunction().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('同期がタイムアウトしました（30秒）');
          },
        );
        AppLogger.debug(' Calling syncSuccess()');
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        AppLogger.info(' Amber同期成功');
      } catch (e) {
        AppLogger.debug(' Calling syncError()');
        _ref.read(syncStatusProvider.notifier).syncError(
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

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    const timeout = Duration(seconds: 15);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.debug(' Executing syncFunction() (attempt ${attempt + 1}/${maxRetries + 1})...');
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
          _ref.read(syncStatusProvider.notifier).syncError(
            e.toString(),
            shouldRetry: false,
          );
          AppLogger.error(' Nostr同期失敗（最終試行）: $e');
          AppLogger.debug(' _syncToNostr: Normal mode COMPLETED with error');
          // エラーを再スローせず、ローカルデータは保持
        } else {
          // リトライする
          AppLogger.warning(' Nostr同期エラー（${attempt + 1}/${maxRetries + 1}回目）: $e');
          AppLogger.info(' ${retryDelay.inSeconds}秒後にリトライします...');
          
          await Future.delayed(retryDelay);
        }
      }
    }
  }

  /// すべてのTodoをローカルストレージに保存
  Future<void> _saveAllTodosToLocal() async {
    AppLogger.debug('💾 [Provider] _saveAllTodosToLocal() called');
    state.whenData((todos) async {
      final allTodos = <Todo>[];
      
      // すべてのTodoをフラットなリストに変換
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }
      
      AppLogger.debug('💾 [Provider] Saving ${allTodos.length} todos to local storage');
      try {
        await localStorageService.saveTodos(allTodos);
        AppLogger.info('✅ [Provider] Saved ${allTodos.length} todos to local storage');
      } catch (e) {
        AppLogger.warning(' ローカル保存エラー: $e');
      }
    });
  }
  
  /// Widgetを更新
  Future<void> _updateWidget() async {
    state.whenData((todos) async {
      try {
        await WidgetService.updateWidget(todos);
      } catch (e) {
        // Widget更新の失敗はログに残すのみ
        AppLogger.warning(' Widget更新エラー: $e');
      }
    });
  }


  /// 手動で全Todoリストをリレーに送信（バックアップ手段）
  /// UIから呼び出される公開メソッド
  Future<void> manualSyncToNostr() async {
    AppLogger.info(' Manual sync to Nostr triggered');
    _ref.read(syncStatusProvider.notifier).startSync();
    
    try {
      await _syncAllTodosToNostr();
      
      // 同期成功後、needsSyncフラグをクリア
      await _clearNeedsSyncFlags();
      
      _ref.read(syncStatusProvider.notifier).syncSuccess();
      AppLogger.info(' Manual sync completed successfully');
    } catch (e, stackTrace) {
      AppLogger.error(' Manual sync failed: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      
      _ref.read(syncStatusProvider.notifier).syncError(
        '手動同期エラー: ${e.toString()}',
        shouldRetry: false,
      );
      
      // 3秒後にエラーをクリア
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(syncStatusProvider.notifier).clearError();
      });
      
      rethrow; // UIにエラーを伝播
    }
  }

  /// Phase 8.5.3: グループ系データをバックグラウンドで同期（優先度低）
  Future<void> _syncGroupDataInBackground() async {
    AppLogger.info('🔄 [Background] グループ系同期開始（バックグラウンド）');
    
    // バックグラウンド同期の開始を通知
    _ref.read(syncStatusProvider.notifier).startSync();
    
    try {
      // グループリスト、グループタスク、グループ招待を並列同期
      // Phase 8.4: kind: 30001グループリスト同期は廃止（MLSグループのみ使用）
      await Future.wait([
        // 1. グループリスト同期 - 削除（Phase 8.4）
        
        // 2. グループタスク同期
        syncAllGroupTodos().then((_) {
          AppLogger.info('✅ [Background] グループタスク同期完了');
        }).catchError((e) {
          AppLogger.warning('⚠️ [Background] グループタスク同期エラー: $e');
        }),
        
        // 3. グループ招待同期
        _ref.read(customListsProvider.notifier).syncGroupInvitations().then((_) {
          AppLogger.info('✅ [Background] グループ招待同期完了');
        }).catchError((e) {
          AppLogger.warning('⚠️ [Background] グループ招待同期エラー: $e');
        }),
      ], eagerError: false);
      
      AppLogger.info('✅ [Background] グループ系同期完了');
      
      // バックグラウンド同期の完了を通知
      _ref.read(syncStatusProvider.notifier).syncSuccess();
    } catch (e) {
      AppLogger.error('❌ [Background] グループ系同期エラー', error: e);
      
      // エラーを通知
      _ref.read(syncStatusProvider.notifier).syncError(
        'グループ系同期エラー: ${e.toString()}',
        shouldRetry: false,
      );
      
      // 5秒後にエラーをクリアしてアイドル状態に戻す
      Future.delayed(const Duration(seconds: 5), () {
        _ref.read(syncStatusProvider.notifier).clearError();
      });
    }
  }
  
  /// Phase 8.5.1: 暗号化イベントからカスタムリスト名を抽出（並列同期用）
  /// Phase 8.5.2: 軽量版リスト名取得（最適化済み）
  Future<List<String>> _fetchEncryptedEventsForListNames() async {
    final nostrService = _ref.read(nostrServiceProvider);
    
    try {
      final userPubkey = await nostrService.getPublicKey();
      if (userPubkey == null) {
        AppLogger.warning('⚠️ [Sync] 公開鍵がないため、リスト名取得をスキップ');
        return [];
      }
      
      // Phase 8.5.2: 新しい軽量APIを使用（contentを取得しない）
      final listNamesData = await ErrorHandler.withTimeout<List<rust_api.TodoListName>>(
        operation: () => rust_api.fetchTodoListNamesOnly(publicKeyHex: userPubkey),
        operationName: 'fetchTodoListNamesOnly',
        timeout: const Duration(seconds: 5),
        defaultValue: <rust_api.TodoListName>[],
      );
      
      if (listNamesData.isEmpty) {
        AppLogger.debug('📋 [Sync] リスト名なし、空リスト返却');
        return [];
      }
      
      // list_idからリスト名を抽出
      final List<String> listNames = [];
      for (final data in listNamesData) {
        String listName;
        
        // titleタグがあればそれを使用
        if (data.title != null && data.title!.isNotEmpty) {
          listName = data.title!;
        } else if (data.listId.startsWith('meiso-list-')) {
          // titleがない場合、list_idから名前を抽出
          listName = data.listId.substring('meiso-list-'.length);
        } else {
          listName = data.listId;
        }
        
        if (!listNames.contains(listName)) {
          listNames.add(listName);
        }
      }
      
      AppLogger.info('✅ [Sync] リスト名取得完了: ${listNames.length}件（軽量API使用）');
      return listNames;
    } catch (e) {
      AppLogger.error('❌ [Sync] カスタムリスト名抽出エラー', error: e);
      return [];
    }
  }
  
  /// Nostrからすべてのtodoを同期（Kind 30001 - Todoリスト全体を取得）
  Future<void> syncFromNostr({bool isInitialSync = false}) async {
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.warning(' Nostr未初期化のため同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);

    // Phase 8.5.1: 進捗付き同期開始（全3ステップ）
    _ref.read(syncStatusProvider.notifier).startSyncWithProgress(
      totalSteps: 3,
      initialPhase: 'AppSettings同期中...',
      isInitialSync: isInitialSync,
    );

    try {
      // Phase 8.5.1: 優先度付き並列同期
      AppLogger.info('🚀 [Sync] Phase 1: 優先同期開始（並列実行）');
      
      // Phase 1: 重要データを並列同期（AppSettings + カスタムリスト名取得）
      final phase1Results = await Future.wait([
        // 1. AppSettings同期（リレーリスト含む）
        _ref.read(appSettingsProvider.notifier).syncFromNostr().then((_) {
          AppLogger.info('✅ [Sync] AppSettings同期完了');
          return true;
        }).catchError((e) {
          AppLogger.warning('⚠️ [Sync] AppSettings同期エラー（続行）: $e');
          return false;
        }),
        
        // 2. 暗号化Todoリストイベント取得（カスタムリスト名抽出のため）
        _fetchEncryptedEventsForListNames().then((listNames) {
          AppLogger.info('✅ [Sync] カスタムリスト名抽出完了: ${listNames.length}件');
          return listNames;
        }).catchError((e) {
          AppLogger.warning('⚠️ [Sync] カスタムリスト名抽出エラー: $e');
          return <String>[];
        }),
      ], eagerError: false); // エラーがあっても全て完了するまで待つ
      
      final customListNames = phase1Results[1] as List<String>;
      
      AppLogger.info('✅ [Sync] Phase 1完了（${Duration(milliseconds: 0)})');
      
      // Phase 8.5.1: Phase 1完了（33%）
      _ref.read(syncStatusProvider.notifier).setProgress(
        completedSteps: 1,
        percentage: 33,
        currentPhase: 'カスタムリスト同期中... (${customListNames.length}件)',
      );
      
      // Phase 2: カスタムリスト同期（Phase 1の結果を使用）
      AppLogger.info('📋 [Sync] Phase 2: カスタムリスト同期開始');
      try {
        await _ref.read(customListsProvider.notifier).syncListsFromNostr(customListNames);
        AppLogger.info('✅ [Sync] カスタムリスト同期完了');
      } catch (e) {
        AppLogger.warning('⚠️ [Sync] カスタムリスト同期エラー: $e');
      }
      
      // Phase 8.5.1: Phase 2完了（66%）
      _ref.read(syncStatusProvider.notifier).setProgress(
        completedSteps: 2,
        percentage: 66,
        currentPhase: 'TODO同期中...',
      );
      
      // Phase 3: TODO同期（タイムアウト付き、短縮: 20秒）
      AppLogger.info('📝 [Sync] Phase 3: TODO同期開始');
      await Future(() async {
        if (isAmberMode) {
          // Amberモード: すべてのTodoリストイベント（Kind 30001）を取得 → Amberで復号化
          AppLogger.debug('🔐 Amberモードですべてのリストを同期します（Kind 30001、復号化あり、バックグラウンド処理）');
          
          final encryptedEvents = await nostrService.fetchAllEncryptedTodoLists();
          
          if (encryptedEvents.isEmpty) {
            AppLogger.warning(' Todoリストイベントが見つかりません（Kind 30001）');
            
            // ローカルデータの有無をチェック
            final hasLocalData = await state.whenData((localTodos) {
              final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
              if (localTodoCount > 0) {
                AppLogger.debug(' リモートにイベントがありませんが、ローカルに${localTodoCount}件のTodoがあるため保持します');
                return true;
              }
              return false;
            }).value ?? false;
            
            if (hasLocalData) {
              AppLogger.info(' ローカルデータを保持（リモートは空/Amber）');
              
              // Phase 8.5.3: グループ系はバックグラウンドで同期
              _ref.read(syncStatusProvider.notifier).syncSuccess();
              
              // バックグラウンドでグループ系同期を開始（UIをブロックしない）
              Future.microtask(() => _syncGroupDataInBackground());
              
              return; // ここで関数を抜ける
            }
            
            // ローカルデータもない場合は空状態に
            AppLogger.debug(' ローカルもリモートもデータがありません');
            
            // Phase 8.5.3: グループ系はバックグラウンドで同期
            _ref.read(syncStatusProvider.notifier).syncSuccess();
            
            // バックグラウンドでグループ系同期を開始（UIをブロックしない）
            Future.microtask(() => _syncGroupDataInBackground());
            
            return;
          }
          
          AppLogger.debug(' ${encryptedEvents.length}件のTodoリストイベントを取得');
          
          // カスタムリスト名を抽出
          final List<String> nostrListNames = [];
          AppLogger.info(' [Sync] 📋 Extracting custom list names from ${encryptedEvents.length} events...');
          
          for (int i = 0; i < encryptedEvents.length; i++) {
            final event = encryptedEvents[i];
            AppLogger.debug(' [Sync]   Event $i: listId="${event.listId}", title="${event.title}", eventId=${event.eventId}');
            
            if (event.listId != null) {
              final listId = event.listId!;
              
              // デフォルトリストは除外
              if (listId == 'meiso-todos') {
                AppLogger.debug(' [Sync]     → Skipping default list (meiso-todos)');
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
                  AppLogger.warning(' [Sync]     ⚠️ No title tag, extracted from list_id: "$listName"');
                } else {
                  // list_idが予期しない形式の場合、そのまま使用
                  listName = listId;
                  AppLogger.warning(' [Sync]     ⚠️ No title tag, using list_id as name: "$listName"');
                }
              }
              
              // 重複チェック
              if (!nostrListNames.contains(listName)) {
                nostrListNames.add(listName);
                AppLogger.info(' [Sync]     ✅ Found custom list: "$listName" (d tag: $listId)');
              } else {
                AppLogger.debug(' [Sync]     → Duplicate list name, skipping: "$listName"');
              }
            } else {
              AppLogger.warning(' [Sync]     ❌ Event $i has null listId (title=${event.title})');
            }
          }
          
          AppLogger.info(' [Sync] 📊 Extracted ${nostrListNames.length} custom list names: ${nostrListNames.join(", ")}');
          
          // Phase 8.5: カスタムリスト名は既にPhase 1で取得済みなので、ここでは使用のみ
          // （このコードパスは旧実装との互換性のため残す）
          AppLogger.debug(' [Sync] カスタムリスト名: ${nostrListNames.join(", ")}（Phase 1で処理済み）');
          
          final amberService = _ref.read(amberServiceProvider);
          var publicKey = _ref.read(publicKeyProvider);
          var npub = _ref.read(nostrPublicKeyProvider);
          
          // 公開鍵がnullの場合、Rust側から復元を試みる
          if (publicKey == null) {
            AppLogger.warning(' Public key (hex) is null, attempting to restore from storage...');
            try {
              publicKey = await nostrService.getPublicKey();
              if (publicKey != null) {
                AppLogger.info(' Public key (hex) restored from storage: ${publicKey.substring(0, 16)}...');
                _ref.read(publicKeyProvider.notifier).state = publicKey;
                
                // npub形式にも変換して設定
                try {
                  npub = await nostrService.hexToNpub(publicKey);
                  _ref.read(nostrPublicKeyProvider.notifier).state = npub;
                  AppLogger.info(' Public key (npub) also restored: ${npub.substring(0, 16)}...');
                } catch (e) {
                  AppLogger.error(' Failed to convert hex to npub: $e');
                }
              } else {
                AppLogger.error(' Failed to restore public key - no key found in storage');
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
          
          // すべてのリストを復号化してマージ
          final allSyncedTodos = <Todo>[];
          
          for (final encryptedEvent in encryptedEvents) {
            try {
              AppLogger.debug(' リストを復号化中 (Event ID: ${encryptedEvent.eventId}, List: ${encryptedEvent.listId})');
              
              // Amberで復号化
              String decryptedJson;
              try {
                // まずContentProvider経由で試す（バックグラウンド処理）
                decryptedJson = await amberService.decryptNip44WithContentProvider(
                  ciphertext: encryptedEvent.encryptedContent,
                  pubkey: publicKey,
                  npub: npub,
                );
                AppLogger.info(' 復号化完了（バックグラウンド）');
              } on PlatformException catch (e) {
                // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
                AppLogger.warning(' ContentProvider復号化失敗 (${e.code}), UI経由で再試行します...');
                decryptedJson = await amberService.decryptNip44(
                  encryptedEvent.encryptedContent,
                  publicKey,
                );
                AppLogger.info(' 復号化完了（UI経由）');
              }
              
              // JSONをパース（Todoリスト配列）
              final todoList = jsonDecode(decryptedJson) as List<dynamic>;
              
              final syncedTodos = todoList.map((todoMap) {
                final map = todoMap as Map<String, dynamic>;
                return Todo(
                  id: map['id'] as String,
                  title: map['title'] as String,
                  completed: map['completed'] as bool,
                  date: map['date'] != null 
                      ? DateTime.parse(map['date'] as String) 
                      : null,
                  order: map['order'] as int,
                  createdAt: DateTime.parse(map['created_at'] as String),
                  updatedAt: DateTime.parse(map['updated_at'] as String),
                  eventId: map['event_id'] as String? ?? encryptedEvent.eventId,
                  linkPreview: map['link_preview'] != null 
                      ? LinkPreview.fromJson(map['link_preview'] as Map<String, dynamic>)
                      : null,
                  customListId: map['custom_list_id'] as String?,
                  recurrence: map['recurrence'] != null
                      ? RecurrencePattern.fromJson(map['recurrence'] as Map<String, dynamic>)
                      : null,
                  parentRecurringId: map['parent_recurring_id'] as String?,
                  needsSync: false, // Nostrから取得したデータは常に同期済み
                );
              }).toList();
              
              AppLogger.info(' リスト復号化完了: ${syncedTodos.length}件のTodo (List: ${encryptedEvent.listId})');
              allSyncedTodos.addAll(syncedTodos);
            } catch (e, stackTrace) {
              // 復号化・パースエラー：このリストをスキップして次へ
              AppLogger.error('❌ リスト復号化失敗 (Event ID: ${encryptedEvent.eventId}, List: ${encryptedEvent.listId}): $e', 
                error: e, stackTrace: stackTrace);
              AppLogger.warning('⚠️ このリストをスキップして続行します');
            }
          }
          
          AppLogger.info('🎉 [DEBUG] For loop completed! About to log sync status...');
          AppLogger.info(' [Sync] 3/3: Todoを同期中...');
          AppLogger.info(' すべてのリスト復号化完了: 合計${allSyncedTodos.length}件のTodo');
          
          // allSyncedTodosが空の場合、復号化に失敗した可能性が高い
          // ローカルデータを保持するために、マージをスキップする
          if (allSyncedTodos.isEmpty) {
            AppLogger.warning('⚠️ リモートから復号化できたTodoが0件です。ローカルデータを保持します。');
            
            // ローカルデータの有無をチェック
            final hasLocalData = state.maybeWhen(
              data: (localTodos) {
                final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
                AppLogger.info(' ローカルに${localTodoCount}件のTodoがあります');
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
          AppLogger.info('🚀 [DEBUG] Calling _updateStateWithSyncedTodos with ${allSyncedTodos.length} todos...');
          _updateStateWithSyncedTodos(allSyncedTodos);
          AppLogger.info('✅ [DEBUG] _updateStateWithSyncedTodos returned!');
          AppLogger.info(' [Sync] Todo同期完了');
          
        } else {
          // 通常モード: Rust側で復号化済みのTodoリストを取得（Kind 30001）
          AppLogger.info(' 通常モードで同期します（Kind 30001）');
          
          // ステップ1: メタデータを取得してカスタムリストを同期
          AppLogger.debug(' ステップ1: カスタムリストのメタデータを取得します');
          final metadata = await nostrService.fetchAllTodoListMetadata();
          
          // カスタムリスト名を抽出（デフォルトリストは除外）
          final List<String> nostrListNames = [];
          AppLogger.info(' [Sync] 📋 Extracting custom list names from ${metadata.length} metadata entries...');
          
          for (int i = 0; i < metadata.length; i++) {
            final meta = metadata[i];
            AppLogger.debug(' [Sync]   Metadata $i: listId="${meta.listId}", title="${meta.title}"');
            
            if (meta.listId != null) {
              final listId = meta.listId!;
              
              // デフォルトリストは除外
              if (listId == 'meiso-todos') {
                AppLogger.debug(' [Sync]     → Skipping default list (meiso-todos)');
                continue;
              }
              
              // リスト名を取得（titleタグがあればそれを使用、なければlist_idから生成）
              String listName;
              if (meta.title != null && meta.title!.isNotEmpty) {
                listName = meta.title!;
                AppLogger.debug(' [Sync]     → Using title tag: "$listName"');
              } else {
                // titleタグがない場合、list_idから名前を抽出
                // 例: "meiso-list-mylist" → "mylist"
                if (listId.startsWith('meiso-list-')) {
                  listName = listId.substring('meiso-list-'.length);
                  AppLogger.warning(' [Sync]     ⚠️ No title tag, extracted from list_id: "$listName"');
                } else {
                  // list_idが予期しない形式の場合、そのまま使用
                  listName = listId;
                  AppLogger.warning(' [Sync]     ⚠️ No title tag, using list_id as name: "$listName"');
                }
              }
              
              // 重複チェック
              if (!nostrListNames.contains(listName)) {
                nostrListNames.add(listName);
                AppLogger.info(' [Sync]     ✅ Found custom list: "$listName" (d tag: $listId)');
              } else {
                AppLogger.debug(' [Sync]     → Duplicate list name, skipping: "$listName"');
              }
            } else {
              AppLogger.warning(' [Sync]     ❌ Metadata $i has null listId (title=${meta.title})');
            }
          }
          
          AppLogger.info(' [Sync] 📊 Extracted ${nostrListNames.length} custom list names: ${nostrListNames.join(", ")}');
          
          // カスタムリストを同期（名前ベース）
          // nostrListNamesが空の場合でも呼び出し、デフォルトリストを作成
          AppLogger.info(' [Sync] 2/3: カスタムリストを同期中...');
          await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
          AppLogger.info(' [Sync] カスタムリスト同期完了');
          
          // ステップ2: Todoデータを取得
          AppLogger.info(' [Sync] 3/3: Todoを同期中...');
          AppLogger.debug(' ステップ2: Todoデータを取得します');
          final syncedTodos = await nostrService.syncTodoListFromNostr();
          AppLogger.debug(' ${syncedTodos.length}件のTodoを取得しました');
          AppLogger.info(' [Sync] Todo同期完了');
          
          // イベントが見つからない場合（空リスト）はローカルデータを保持
          if (syncedTodos.isEmpty) {
            final hasLocalData = await state.whenData((localTodos) {
              final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
              if (localTodoCount > 0) {
                AppLogger.debug(' リモートにイベントがありませんが、ローカルに${localTodoCount}件のTodoがあるため保持します');
                return true; // ローカルデータがある
              }
              return false;
            }).value ?? false;
            
            // ローカルデータがある場合は同期をスキップ
            if (hasLocalData) {
              AppLogger.info(' ローカルデータを保持（リモートは空）');
              _ref.read(syncStatusProvider.notifier).syncSuccess();
              return; // ここで関数を抜ける
            }
          }
          
          // Nostrから取得したデータのneedsSyncフラグを強制的にfalseにする
          final cleanedTodos = syncedTodos.map((todo) => todo.copyWith(needsSync: false)).toList();
          AppLogger.info(' needsSyncフラグをクリア: ${cleanedTodos.length}件');
          
          _updateStateWithSyncedTodos(cleanedTodos);
        }
        
        // Phase 8.5.1: Phase 3完了（100%）
        _ref.read(syncStatusProvider.notifier).setProgress(
          completedSteps: 3,
          percentage: 100,
          currentPhase: '同期完了',
        );
        
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        AppLogger.info(' Nostr同期成功');
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.debug(' syncFromNostr タイムアウト（30秒）');
          throw Exception('データ同期がタイムアウトしました（30秒）');
        },
      );
      
    } catch (e, stackTrace) {
      _ref.read(syncStatusProvider.notifier).syncError(
        e.toString(),
        shouldRetry: false,
      );
      AppLogger.error(' Nostr同期失敗: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      
      // 3秒後にエラーをクリア（ローカルデータで継続使用可能にする）
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(syncStatusProvider.notifier).clearError();
      });
    }
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
  void _updateStateWithSyncedTodos(List<Todo> syncedTodos) {
    try {
      AppLogger.info(' Starting merge: ${syncedTodos.length} remote todos');
      
      // 防御的コーディング: stateから現在のTodoを取得
      final Map<DateTime?, List<Todo>> localTodos;
      final currentState = state;
      
      if (currentState is AsyncData<Map<DateTime?, List<Todo>>>) {
        localTodos = currentState.value;
        final localCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
        AppLogger.debug(' Current state is AsyncData with $localCount todos');
      } else {
        // stateがAsyncDataでない場合は空から開始
        AppLogger.warning('⚠️ State is not AsyncData (type: ${currentState.runtimeType}), starting with empty map');
        localTodos = {};
      }
      
      // ローカルの全タスクをフラット化してMapに変換
      final localTodoMap = <String, Todo>{};
      int localTotalCount = 0;
      for (final dateGroup in localTodos.values) {
        for (final todo in dateGroup) {
          localTodoMap[todo.id] = todo;
          localTotalCount++;
        }
      }
      
      AppLogger.debug(' Local todos: $localTotalCount');
      
      // マージ結果を格納
      final mergedTodos = <String, Todo>{};
      int conflictCount = 0;
      int localWinsCount = 0;
      int remoteWinsCount = 0;
      
      // ステップ1: リモートのタスクを処理
      for (final remoteTodo in syncedTodos) {
        final localTodo = localTodoMap[remoteTodo.id];
        
        if (localTodo == null) {
          // ローカルに存在しない → リモートを採用
          mergedTodos[remoteTodo.id] = remoteTodo;
          AppLogger.debug(' Remote only: "${remoteTodo.title}" (${remoteTodo.id.substring(0, 8)}...)');
        } else {
          // 両方に存在 → 競合解決
          conflictCount++;
          
          // ルール1: needsSyncフラグがtrueの場合、ローカルを優先
          if (localTodo.needsSync) {
            mergedTodos[remoteTodo.id] = localTodo;
            localWinsCount++;
            AppLogger.debug(' Conflict resolved (needsSync): Local wins - "${localTodo.title}"');
            AppLogger.debug('   Local updated: ${localTodo.updatedAt.toIso8601String()}');
            AppLogger.debug('   Remote updated: ${remoteTodo.updatedAt.toIso8601String()}');
            continue;
          }
          
          // ルール2: updatedAtタイムスタンプを比較
          final localUpdated = localTodo.updatedAt;
          final remoteUpdated = remoteTodo.updatedAt;
          
          if (remoteUpdated.isAfter(localUpdated)) {
            // リモートの方が新しい → リモートを採用
            mergedTodos[remoteTodo.id] = remoteTodo;
            remoteWinsCount++;
            
            // タイトルが異なる場合は競合を警告
            if (localTodo.title != remoteTodo.title) {
              AppLogger.debug('🔀 Conflict resolved: Remote wins - "${remoteTodo.title}"');
              AppLogger.debug('   Local: "${localTodo.title}" (${localUpdated.toIso8601String()})');
              AppLogger.debug('   Remote: "${remoteTodo.title}" (${remoteUpdated.toIso8601String()})');
            }
          } else if (localUpdated.isAfter(remoteUpdated)) {
            // ローカルの方が新しい → ローカルを採用
            // ローカルの方が新しい場合、リレーに再送信が必要
            mergedTodos[remoteTodo.id] = localTodo.copyWith(needsSync: true);
            localWinsCount++;
            
            // タイトルが異なる場合は競合を警告
            if (localTodo.title != remoteTodo.title) {
              AppLogger.debug(' Conflict resolved: Local wins - "${localTodo.title}" (will resync)');
              AppLogger.debug('   Local: "${localTodo.title}" (${localUpdated.toIso8601String()})');
              AppLogger.debug('   Remote: "${remoteTodo.title}" (${remoteUpdated.toIso8601String()})');
            }
          } else {
            // 同じタイムスタンプ → リモートを優先（デフォルト動作）
            mergedTodos[remoteTodo.id] = remoteTodo;
            remoteWinsCount++;
            
            if (localTodo.title != remoteTodo.title || localTodo.completed != remoteTodo.completed) {
              AppLogger.warning(' Same timestamp but different content: Remote wins - "${remoteTodo.title}"');
              AppLogger.debug('   Local: "${localTodo.title}" (completed: ${localTodo.completed})');
              AppLogger.debug('   Remote: "${remoteTodo.title}" (completed: ${remoteTodo.completed})');
            }
          }
        }
      }
      
      // ステップ2: ローカルのみに存在するタスクを追加
      int localOnlyCount = 0;
      int deletedByRemoteCount = 0;
      
      for (final localTodo in localTodoMap.values) {
        if (!mergedTodos.containsKey(localTodo.id)) {
          // リモートに存在しない場合の処理
          
          // グループタスクは個人タスク同期の対象外 → 無条件で保持
          if (localTodo.customListId != null) {
            try {
              final customLists = _ref.read(customListsProvider).valueOrNull ?? [];
              final list = customLists.firstWhere(
                (l) => l.id == localTodo.customListId!,
                orElse: () => CustomList(
                  id: '',
                  name: '',
                  order: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              
              if (list.isGroup) {
                // グループタスクは個人タスク同期の影響を受けないため保持
                mergedTodos[localTodo.id] = localTodo;
                localOnlyCount++;
                AppLogger.debug('🔒 Group task protected: "${localTodo.title}" (${localTodo.id.substring(0, 8)}...)');
                continue; // 以降の個人タスク用ロジックをスキップ
              }
            } catch (e) {
              // グループ判定でエラーが起きても、個人タスクとして処理を継続
              AppLogger.warning('⚠️ Failed to check if task is group task: $e, treating as personal task');
            }
          }
          
          if (localTodo.needsSync) {
            // ケース1: needsSyncがtrue → まだ同期されていない新しいタスク
            // ローカルを保持してリレーに送信する
            mergedTodos[localTodo.id] = localTodo;
            localOnlyCount++;
            AppLogger.debug(' Local only (new): "${localTodo.title}" (${localTodo.id.substring(0, 8)}...) - will sync');
          } else {
            // ケース2: needsSyncがfalse → 他のデバイスで削除された可能性
            // ただし、ローカルが最近更新されている場合は保持する
            final now = DateTime.now();
            final hoursSinceUpdate = now.difference(localTodo.updatedAt).inHours;
            
            if (hoursSinceUpdate < 24) {
              // 24時間以内の更新 → ローカルを保持（削除ではなく、同期のタイミング差の可能性）
              mergedTodos[localTodo.id] = localTodo.copyWith(needsSync: true);
              localOnlyCount++;
              AppLogger.debug(' Local only (recent update): "${localTodo.title}" - will resync (updated ${hoursSinceUpdate}h ago)');
            } else {
              // 24時間以上前の更新 → 他のデバイスで削除されたと判断
              deletedByRemoteCount++;
              AppLogger.debug('  Deleted by remote: "${localTodo.title}" (${localTodo.id.substring(0, 8)}...) - removing locally');
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
      
      // 状態を更新
      state = AsyncValue.data(grouped);
      
      // ローカルストレージに保存
      _saveAllTodosToLocal();
      
      // Widgetを更新
      _updateWidget();
      
      // ローカルが新しいタスクがある場合、自動的に再同期
      if (localWinsCount > 0 || localOnlyCount > 0) {
        AppLogger.info(' Scheduling resync due to local changes');
        _updateUnsyncedCount();
      }
    } catch (e, stackTrace) {
      // マージ処理でエラーが発生した場合
      AppLogger.error('❌ Error in _updateStateWithSyncedTodos: $e', error: e, stackTrace: stackTrace);
      
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
      
      state = AsyncValue.data(grouped);
      AppLogger.warning('⚠️ Fallback: Showing only remote todos due to merge error');
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
    
    _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.checking;
    _ref.read(syncStatusProvider.notifier).updateMessage('データ移行準備中...');
    
    try {
      // 1. 既存のKind 30078イベントを取得
      AppLogger.debug(' Fetching existing Kind 30078 events...');
      _ref.read(syncStatusProvider.notifier).updateMessage('旧データ取得中...');
      
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
        _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.notNeeded;
        return;
      }
      
      AppLogger.debug(' Found ${oldTodos.length} todos in Kind 30078 format');
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.needed;
      
      // 2. Kind 30001形式で再送信
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.inProgress;
      AppLogger.debug(' Migrating todos to Kind 30001 format...');
      _ref.read(syncStatusProvider.notifier).updateMessage('新形式に変換中...');
      
      // 一時的に状態を更新（UIに反映）
      final Map<DateTime?, List<Todo>> grouped = {};
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
        AppLogger.debug(' Deleting ${oldEventIds.length} old Kind 30078 events...');
        _ref.read(syncStatusProvider.notifier).updateMessage('旧データ削除中...');
        
        // Phase C.2.2: Repository経由で削除
        final deleteResult = await repository.deleteNostrEvents(
          eventIds: oldEventIds,
          reason: 'Migrated to Kind 30001 (NIP-51 Bookmark List)',
        );
        
        deleteResult.fold(
          (failure) {
            AppLogger.warning(' Failed to delete old events: ${failure.message}');
            // 削除失敗してもマイグレーションは成功とみなす
          },
          (_) {
            AppLogger.info(' Old events deleted successfully');
          },
        );
      }
      
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.completed;
      _ref.read(syncStatusProvider.notifier).updateMessage('データ移行完了');
      AppLogger.debug('🎉 Migration completed successfully!');
      
      // Phase C.2.2: Repository経由でマイグレーション完了フラグを保存
      final setCompletedResult = await repository.setMigrationCompleted();
      setCompletedResult.fold(
        (failure) => AppLogger.warning(' Failed to save migration flag: ${failure.message}'),
        (_) => AppLogger.info(' Migration completed flag saved'),
      );
      
      // メッセージをクリア
      await Future.delayed(const Duration(seconds: 1));
      _ref.read(syncStatusProvider.notifier).clearMessage();
      
    } catch (e, stackTrace) {
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.failed;
      AppLogger.error(' Migration failed: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
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
        AppLogger.warning('[Provider] Failed to check Kind 30001: ${failure.message}');
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
        AppLogger.warning('[Provider] Failed to check migration: ${failure.message}');
        return false; // エラー時はfalseを返す（マイグレーション不要として扱う）
      },
      (needed) {
        if (!needed) {
          // マイグレーション不要（完了済み）
          _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.completed;
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
      
      // 公開鍵を取得
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
      
      // グループリストを取得
      final groupLists = await groupTaskService.fetchMyGroupTaskLists(
        publicKey: publicKey,
        npub: npub,
      );
      final groupList = groupLists.where((g) => g.groupId == groupId).firstOrNull;
      
      if (groupList == null) {
        AppLogger.warning('⚠️ Group not found: $groupId');
        return;
      }
      
      // グループタスクを復号化
      final groupTodos = await groupTaskService.decryptGroupTaskList(
        groupList: groupList,
        publicKey: publicKey,
        npub: npub,
      );
      
      AppLogger.info('✅ Decrypted ${groupTodos.length} todos from group');
      
      // 既存のグループタスクを削除
      await state.whenData((todos) async {
        final updated = Map<DateTime?, List<Todo>>.from(todos);
        
        // グループIDが一致するタスクを削除
        for (final dateKey in updated.keys) {
          updated[dateKey] = updated[dateKey]!
              .where((t) => t.customListId != groupId)
              .toList();
        }
        
        // 新しいグループタスクを追加
        for (final todo in groupTodos) {
          final dateKey = todo.date;
          updated[dateKey] ??= [];
          updated[dateKey]!.add(todo);
        }
        
        // ローカルストレージに保存
        final allTodos = <Todo>[];
        for (final dateGroup in updated.values) {
          allTodos.addAll(dateGroup);
        }
        await localStorageService.saveTodos(allTodos);
        
        state = AsyncValue.data(updated);
        
        AppLogger.info('✅ Group todos synced to local storage');
      }).value;
      
    } catch (e, st) {
      AppLogger.error('❌ Failed to sync group todos: $e', error: e, stackTrace: st);
    }
  }
  
  /// グループにタスクを追加（楽観的UI更新）
  Future<void> addTodoToGroup({
    required String groupId,
    required String title,
    DateTime? date,
  }) async {
    final uuid = const Uuid();
    final now = DateTime.now();
    
    final newTodo = Todo(
      id: uuid.v4(),
      title: title,
      completed: false,
      date: date,
      order: 0, // 先頭に追加
      createdAt: now,
      updatedAt: now,
      customListId: groupId,
      needsSync: true,
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
      
      state = AsyncValue.data(updated);
      
      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);
      
      AppLogger.info('✅ [Group] Todo added to local storage (optimistic)');
      
      // バックグラウンドでグループタスクを暗号化してNostrに同期
      _syncGroupToNostr(groupId);
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
      
      state = AsyncValue.data(updated);
      
      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);
      
      AppLogger.info('✅ [Group] Todo updated in local storage (optimistic)');
      
      // バックグラウンドでグループタスクを暗号化してNostrに同期
      _syncGroupToNostr(groupId);
    }).value;
  }
  
  /// グループからタスクを削除（楽観的UI更新）
  Future<void> deleteTodoFromGroup({
    required String groupId,
    required String todoId,
  }) async {
    await state.whenData((todos) async {
      final updated = Map<DateTime?, List<Todo>>.from(todos);
      
      // タスクを削除
      for (final dateKey in updated.keys) {
        updated[dateKey] = updated[dateKey]!
            .where((t) => t.id != todoId)
            .toList();
      }
      
      state = AsyncValue.data(updated);
      
      // ローカルストレージに保存
      final allTodos = <Todo>[];
      for (final dateGroup in updated.values) {
        allTodos.addAll(dateGroup);
      }
      await localStorageService.saveTodos(allTodos);
      
      AppLogger.info('✅ [Group] Todo deleted from local storage (optimistic)');
      
      // バックグラウンドでグループタスクを暗号化してNostrに同期
      _syncGroupToNostr(groupId);
    }).value;
  }
  
  /// グループタスクをNostrに同期（バックグラウンド）
  Future<void> _syncGroupToNostr(String groupId) async {
    try {
      AppLogger.info('📤 [GroupSync] Syncing group tasks to Nostr: $groupId');
      
      // グループリスト情報を取得
      final customListsAsync = _ref.read(customListsProvider);
      final customLists = customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
      final groupList = customLists.where((l) => l.id == groupId && l.isGroup).firstOrNull;
      
      if (groupList == null) {
        AppLogger.warning('⚠️ [GroupSync] Group list not found: $groupId');
        return;
      }
      
      // グループのタスクを取得
      final todos = await state.whenData((todos) {
        final groupTodos = <Todo>[];
        for (final dateGroup in todos.values) {
          for (final todo in dateGroup) {
            if (todo.customListId == groupId) {
              groupTodos.add(todo);
            }
          }
        }
        return groupTodos;
      }).value ?? [];
      
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
            AppLogger.info('[GroupSync] hex公開鍵を復元: ${publicKey.substring(0, 16)}...');
            _ref.read(publicKeyProvider.notifier).state = publicKey;
            
            npub = await nostrService.hexToNpub(publicKey);
            _ref.read(nostrPublicKeyProvider.notifier).state = npub;
            AppLogger.info('[GroupSync] npub公開鍵も復元: ${npub.substring(0, 16)}...');
          } else {
            throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
          }
        } catch (e) {
          AppLogger.error('[GroupSync] 公開鍵の復元に失敗: $e');
          throw Exception('公開鍵が設定されていません: $e');
        }
      }
      
      // Phase 8.3: MLSグループ判定
      // TODO: グループメンバー情報からMLS/旧実装を判定
      // 現在はgroupMembersが空でない = MLSグループと仮定
      final isMlsGroup = groupList.groupMembers.isNotEmpty || 
                        groupList.isPendingInvitation; // 招待済みグループもMLS
      
      String? eventId;
      
      if (isMlsGroup) {
        // Phase 8.3: MLS経由で送信
        AppLogger.info('🔐 [GroupSync] MLS group detected, using MLS encryption');
        eventId = await _syncGroupToNostrMls(
          groupId: groupId,
          todos: todos,
          publicKey: publicKey,
        );
      } else {
        // 旧実装（Phase 8.4で廃止予定）
        AppLogger.info('📦 [GroupSync] Legacy group, using old encryption');
        eventId = await groupTaskService.createGroupTaskList(
          tasks: todos,
          customList: groupList,
          publicKey: publicKey,
          npub: npub,
        );
      }
      
      if (eventId != null) {
        // 成功した場合、各タスクのneedsSyncフラグをfalseに設定
        // 注意: グループタスクは個別のeventIdを持たない（リスト全体が1つのeventId）
        await state.whenData((currentTodos) async {
          final updated = Map<DateTime?, List<Todo>>.from(currentTodos);
          
          for (final dateKey in updated.keys) {
            updated[dateKey] = updated[dateKey]!.map((todo) {
              if (todo.customListId == groupId) {
                // グループタスクは needsSync のみ更新（eventId は null のまま）
                return todo.copyWith(
                  needsSync: false,
                );
              }
              return todo;
            }).toList();
          }
          
          // 状態を更新
          state = AsyncValue.data(updated);
          
          // ローカルストレージに保存
          await _saveAllTodosToLocal();
          
          AppLogger.info('✅ [GroupSync] Group tasks synced to Nostr: ${todos.length} tasks (list eventId: $eventId)');
        }).value;
      } else {
        AppLogger.warning('⚠️ [GroupSync] Group task sync failed: eventId is null');
      }
    } catch (e, st) {
      AppLogger.error('❌ [GroupSync] Failed to sync group to Nostr: $e', error: e, stackTrace: st);
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
      
      AppLogger.info('🔐 [MLS] Encrypting ${todos.length} todos for group: $groupId');
      
      // 各TODOを個別に暗号化して送信
      for (final todo in todos) {
        // TODOをJSONに変換
        final todoJson = jsonEncode({
          'id': todo.id,
          'title': todo.title,
          'completed': todo.completed,
          'date': todo.date?.toIso8601String(),
          'order': todo.order,
          'created_at': todo.createdAt.toIso8601String(),
          'updated_at': todo.updatedAt.toIso8601String(),
          'custom_list_id': todo.customListId,
          'recurrence': todo.recurrence?.toJson(),
          'parent_recurring_id': todo.parentRecurringId,
        });
        
        // MLS暗号化
        final encryptedMsg = await rust_api.mlsAddTodo(
          nostrId: publicKey,
          groupId: groupId,
          todoJson: todoJson,
        );
        
        AppLogger.debug('🔒 [MLS] Encrypted todo: ${todo.title.substring(0, 20)}... (${encryptedMsg.length} bytes)');
        
        // Export SecretからListen Keyを取得
        final listenKey = await rust_api.mlsGetListenKey(
          nostrId: publicKey,
          groupId: groupId,
        );
        
        // Listen KeyでNostrに送信（Kind 30078）
        final nostrService = _ref.read(nostrServiceProvider);
        final eventId = await nostrService.sendMlsGroupTodo(
          listenKey: listenKey,
          encryptedContent: encryptedMsg,
          groupId: groupId,
        );
        
        AppLogger.info('📤 [MLS] Sent todo to Nostr: ${todo.title} (eventId: ${eventId?.substring(0, 16)}...)');
      }
      
      // TODO: 実際のeventIdを返す（現在は簡易実装）
      return 'mls-group-$groupId-${DateTime.now().millisecondsSinceEpoch}';
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] Failed to sync group to Nostr via MLS', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// 全グループのタスクを一括同期（復号化してローカルに追加）
  Future<void> syncAllGroupTodos() async {
    try {
      AppLogger.info('🔄 [Batch] Syncing all group todos...');
      
      // 公開鍵を取得
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
      
      // 全グループリストを一括取得
      final groupLists = await groupTaskService.fetchMyGroupTaskLists(
        publicKey: publicKey,
        npub: npub,
      );
      
      if (groupLists.isEmpty) {
        AppLogger.info('ℹ️ No group lists found');
        return;
      }
      
      AppLogger.info('📥 Found ${groupLists.length} group lists');
      
      // 全グループのタスクを復号化
      final Map<String, List<Todo>> groupTodosMap = {};
      
      for (final groupList in groupLists) {
        try {
          AppLogger.debug('🔓 Decrypting tasks for group: ${groupList.groupName}');
          final groupTodos = await groupTaskService.decryptGroupTaskList(
            groupList: groupList,
            publicKey: publicKey,
            npub: npub,
          );
          groupTodosMap[groupList.groupId] = groupTodos;
          AppLogger.debug('✅ Decrypted ${groupTodos.length} todos from ${groupList.groupName}');
        } catch (e) {
          AppLogger.error('❌ Failed to decrypt group ${groupList.groupName}: $e');
          // エラーでも他のグループは処理続行
        }
      }
      
      final totalTodos = groupTodosMap.values.fold<int>(0, (sum, list) => sum + list.length);
      AppLogger.info('✅ [Batch] Decrypted $totalTodos todos from ${groupLists.length} groups');
      
      // ローカルストレージに反映
      await state.whenData((todos) async {
        final updated = Map<DateTime?, List<Todo>>.from(todos);
        
        // 既存のグループタスクを全て削除
        final allGroupIds = groupLists.map((g) => g.groupId).toSet();
        for (final dateKey in updated.keys) {
          updated[dateKey] = updated[dateKey]!
              .where((t) => t.customListId == null || !allGroupIds.contains(t.customListId))
              .toList();
        }
        
        // 全グループの新しいタスクを追加
        for (final groupTodos in groupTodosMap.values) {
          for (final todo in groupTodos) {
            final dateKey = todo.date;
            updated[dateKey] = (updated[dateKey] ?? [])..add(todo);
          }
        }
        
        // 状態を更新
        state = AsyncValue.data(updated);
        
        // ローカルストレージに保存
        await _saveAllTodosToLocal();
        
        AppLogger.info('✅ [Batch] Updated state with group todos');
      }).value;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to sync all group todos: $e', error: e, stackTrace: stackTrace);
    }
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
  
  /// MLS TODO暗号化テスト
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
      
      AppLogger.debug('🔒 [MLS] TODO暗号化: groupId=$groupId');
      
      final encrypted = await rust_api.mlsAddTodo(
        nostrId: userPubkey,
        groupId: groupId,
        todoJson: todoJson,
      );
      
      AppLogger.debug('✅ [MLS] TODO暗号化完了: ${encrypted.length}文字');
      
      return encrypted;
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] TODO暗号化エラー', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// MLS TODO復号化テスト
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
      
      AppLogger.debug('🔓 [MLS] TODO復号化: groupId=$groupId');
      
      final result = await rust_api.mlsDecryptTodo(
        nostrId: userPubkey,
        groupId: groupId,
        encryptedMsg: encryptedMsg,
      );
      
      AppLogger.debug('✅ [MLS] TODO復号化完了: sender=${result.$2}');
      
      return result.$1; // decrypted_json
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] TODO復号化エラー', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// 特定の日付のTodoリストを取得するProvider
/// 未完了タスクを上、完了済みタスクを下に表示
final todosForDateProvider = Provider.family<List<Todo>, DateTime?>((ref, date) {
  final todosAsync = ref.watch(todosProvider);
  return todosAsync.when(
    data: (todos) {
      final list = todos[date] ?? [];
      
      // 未完了タスクと完了済みタスクに分ける
      final incomplete = list.where((t) => !t.completed).toList();
      final completed = list.where((t) => t.completed).toList();
      
      // 未完了タスクをorder順にソート
      incomplete.sort((a, b) => a.order.compareTo(b.order));
      // 完了済みタスクもorder順にソート（完了した順番を保持）
      completed.sort((a, b) => a.order.compareTo(b.order));
      
      // 未完了 + 完了済みの順で結合
      return [...incomplete, ...completed];
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
  notStarted,     // 未実行
  checking,       // チェック中
  needed,         // マイグレーションが必要
  inProgress,     // 実行中
  completed,      // 完了
  failed,         // 失敗
  notNeeded,      // マイグレーション不要（既にKind 30001のみ）
}

