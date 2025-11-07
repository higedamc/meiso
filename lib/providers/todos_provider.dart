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
import '../services/recurrence_parser.dart';
import '../services/widget_service.dart';
import '../services/group_task_service.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../bridge_generated.dart/group_tasks.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';
import 'custom_lists_provider.dart';
import 'app_settings_provider.dart';

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
        
        // バックグラウンドで同期
        _backgroundSync();
      } else {
        // ローカルデータがない場合：空の状態にしてNostr同期を優先
        AppLogger.info(' [Todos] ローカルデータなし。Nostr同期を優先します');
        state = AsyncValue.data({});
        
        // 即座にNostr同期（遅延なし）
        _prioritySync();
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
  Future<void> _prioritySync() async {
    // Nostr初期化を最大10秒待つ
    int attempts = 0;
    while (!_ref.read(nostrInitializedProvider) && attempts < 10) {
      AppLogger.debug(' [Todos] Nostr初期化待機中... (${attempts + 1}/10)');
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }
    
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.warning(' [Todos] Nostr初期化タイムアウト（10秒）');
      return;
    }
    
    AppLogger.info(' [Todos] Nostr初期化完了。優先同期を開始');

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
        await syncFromNostr();
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
    
    // Nostr初期化を最大10秒待つ
    int attempts = 0;
    while (!_ref.read(nostrInitializedProvider) && attempts < 10) {
      AppLogger.debug(' Waiting for Nostr initialization... (attempt ${attempts + 1}/10)');
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }
    
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.warning(' Nostr not initialized after 10 seconds - skipping background sync');
      return;
    }
    
    AppLogger.info(' Nostr initialized, proceeding with background sync');

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
  Future<void> addTodo(String title, DateTime? date, {String? customListId}) async {
    if (title.trim().isEmpty) return;

    AppLogger.debug(' addTodo called: "$title" for date: $date, customListId: $customListId');
    AppLogger.debug('📍 Stack trace location: addTodo');
    if (customListId != null) {
      AppLogger.debug(' IMPORTANT: This todo is being added to custom list: $customListId');
    }

    await state.whenData((todos) async {
      final now = DateTime.now();
      
      // 繰り返しパターンを自動検出（TeuxDeux風）
      final parseResult = RecurrenceParser.parse(title, date);
      final cleanTitle = parseResult.cleanTitle;
      final autoRecurrence = parseResult.pattern;
      
      if (autoRecurrence != null) {
        AppLogger.info(' 自動検出: ${autoRecurrence.description}');
        AppLogger.debug(' クリーンタイトル: "$cleanTitle"');
      }
      
      // URLを検出してメタデータを取得（バックグラウンド）
      final detectedUrl = LinkPreviewService.extractUrl(cleanTitle);
      AppLogger.debug(' URL detected: $detectedUrl');
      
      // URLが検出された場合、即座にタイトルから削除
      String finalTitle = cleanTitle;
      LinkPreview? initialLinkPreview;
      
      if (detectedUrl != null) {
        // URLからドメイン名を抽出
        String domainName = detectedUrl;
        try {
          final uri = Uri.parse(detectedUrl);
          domainName = uri.host;
        } catch (e) {
          // パースエラー時はそのままURLを使用
        }
        
        finalTitle = LinkPreviewService.removeUrlFromText(cleanTitle, detectedUrl);
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
        
        AppLogger.debug(' Title after URL removal: "$finalTitle" (domain: $domainName)');
      }
      
      final newTodo = Todo(
        id: _uuid.v4(),
        title: finalTitle,
        completed: false,
        date: date,
        order: _getNextOrder(todos, date),
        createdAt: now,
        updatedAt: now,
        customListId: customListId,
        recurrence: autoRecurrence, // 自動検出された繰り返しパターンを設定
        linkPreview: initialLinkPreview, // 一時的なリンクプレビューを設定
        needsSync: true, // 同期が必要
      );
      
      AppLogger.debug(' Created new Todo object:');
      AppLogger.debug('   - id: ${newTodo.id}');
      AppLogger.debug('   - title: ${newTodo.title}');
      AppLogger.debug('   - date: ${newTodo.date}');
      AppLogger.debug('   - customListId: ${newTodo.customListId}');
      AppLogger.debug('   - order: ${newTodo.order}');

      final list = List<Todo>.from(todos[date] ?? []);
      list.add(newTodo);

      final updatedTodos = {
        ...todos,
        date: list,
      };

      state = AsyncValue.data(updatedTodos);

      // リカーリングタスクの場合、将来のインスタンスを事前生成
      if (autoRecurrence != null && date != null) {
        // 最新の state を渡す（元のタスクが含まれている）
        await _generateFutureInstances(newTodo, updatedTodos);
      }

      // ローカルストレージに保存（awaitする - これは速い）
      AppLogger.debug(' Saving to local storage...');
      await _saveAllTodosToLocal();
      AppLogger.info(' Local save complete');
      
      // Widgetを更新
      await _updateWidget();

      // URLメタデータ取得（非同期・バックグラウンド）
      if (detectedUrl != null) {
        _fetchLinkPreviewInBackground(newTodo.id, date, detectedUrl);
      }

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
      AppLogger.debug(' Starting background Nostr sync (non-blocking)...');
      _updateUnsyncedCount(); // 未同期カウントを更新
      _syncToNostrBackground();
    }).value;
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
  Future<void> updateTodo(Todo todo) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      final index = list.indexWhere((t) => t.id == todo.id);

      if (index != -1) {
        list[index] = todo.copyWith(
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );
        state = AsyncValue.data({
          ...todos,
          todo.date: list,
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
        _syncToNostrBackground();
      }
    }).value;
  }

  /// Todoの完了状態をトグル（楽観的UI更新）
  Future<void> toggleTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final todo = list[index];
        final wasCompleted = todo.completed;
        
        list[index] = todo.copyWith(
          completed: !todo.completed,
          updatedAt: DateTime.now(),
          needsSync: true, // 同期が必要
        );

        // リカーリングタスクの完了時に次回のタスクを生成
        if (!wasCompleted && todo.recurrence != null && todo.date != null) {
          await _createNextRecurringTask(todo, todos);
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
  Future<void> deleteTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存（awaitする）
      await _saveAllTodosToLocal();
      
      // Widgetを更新
      await _updateWidget();

      // 【楽観的UI更新】バックグラウンドでNostr同期（awaitしない）
      // 削除後の全TODOリストを送信（Replaceable eventなので古いイベントは自動的に置き換わる）
      _updateUnsyncedCount();
      _syncToNostrBackground();
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
          
          // カスタムリスト情報を取得（UUIDから名前ベースIDへの変換用）
          final customListsAsync = _ref.read(customListsProvider);
          final customListsMap = <String, String>{}; // oldId -> newId
          final customListNames = <String, String>{}; // newId -> name
          await customListsAsync.whenData((customLists) async {
            for (final list in customLists) {
              final nameBasedId = CustomListHelpers.generateIdFromName(list.name);
              customListsMap[list.id] = nameBasedId;
              customListNames[nameBasedId] = list.name;
            }
          }).value;
          
          // 1. Todoをリストごとにグループ化（名前ベースIDに変換）
          final Map<String, List<Todo>> groupedTodos = {};
          for (final todo in allTodos) {
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
          AppLogger.info(' 通常モードで全TODOリストを同期します');
          AppLogger.info(' Calling nostrService.createTodoListOnNostr with ${allTodos.length} todos...');
          
          try {
            final sendResult = await nostrService.createTodoListOnNostr(allTodos);
            AppLogger.info('✅✅ TODOリスト送信完了: ${sendResult.eventId} (${allTodos.length}件)');
            
            // 全TodoのeventIdを更新
            for (final todo in allTodos) {
              await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
            }
            AppLogger.info(' Updated eventId for ${allTodos.length} todos');
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
    state.whenData((todos) async {
      final allTodos = <Todo>[];
      
      // すべてのTodoをフラットなリストに変換
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }
      
      try {
        await localStorageService.saveTodos(allTodos);
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

  /// Nostrからすべてのtodoを同期（Kind 30001 - Todoリスト全体を取得）
  Future<void> syncFromNostr() async {
    if (!_ref.read(nostrInitializedProvider)) {
      AppLogger.warning(' Nostr未初期化のため同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);

    _ref.read(syncStatusProvider.notifier).startSync();

    try {
      // 最優先: AppSettings（リレーリスト含む）を同期
      AppLogger.info(' [Sync] 1/3: AppSettings（リレーリスト含む）を同期中...');
      try {
        await _ref.read(appSettingsProvider.notifier).syncFromNostr();
        AppLogger.info(' [Sync] AppSettings同期完了');
      } catch (e) {
        AppLogger.warning(' [Sync] AppSettings同期エラー（続行します）: $e');
      }
      
      // タイムアウト付きで同期実行（30秒）
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
              _ref.read(syncStatusProvider.notifier).syncSuccess();
              return; // ここで関数を抜ける
            }
            
            // ローカルデータもない場合は空状態に
            AppLogger.debug(' ローカルもリモートもデータがありません');
            _ref.read(syncStatusProvider.notifier).syncSuccess();
            return;
          }
          
          AppLogger.debug(' ${encryptedEvents.length}件のTodoリストイベントを取得');
          
          // カスタムリスト名を抽出
          final List<String> nostrListNames = [];
          for (final event in encryptedEvents) {
            if (event.listId != null && event.title != null) {
              final listId = event.listId!;
              // デフォルトリストは除外
              if (listId == 'meiso-todos') {
                continue;
              }
              // titleからリスト名を取得（重複チェック）
              if (!nostrListNames.contains(event.title!)) {
                nostrListNames.add(event.title!);
                AppLogger.debug(' [Sync] Found custom list: "${event.title}" (d tag: $listId)');
              }
            }
          }
          
          // カスタムリストを同期（名前ベース）
          // nostrListNamesが空の場合でも呼び出し、デフォルトリストを作成
          AppLogger.info(' [Sync] 2/3: カスタムリストを同期中...');
          await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
          AppLogger.info(' [Sync] カスタムリスト同期完了');
          
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
          }
          
          AppLogger.info(' [Sync] 3/3: Todoを同期中...');
          AppLogger.info(' すべてのリスト復号化完了: 合計${allSyncedTodos.length}件のTodo');
          
          // 状態を更新
          _updateStateWithSyncedTodos(allSyncedTodos);
          AppLogger.info(' [Sync] Todo同期完了');
          
        } else {
          // 通常モード: Rust側で復号化済みのTodoリストを取得（Kind 30001）
          AppLogger.info(' 通常モードで同期します（Kind 30001）');
          
          // ステップ1: メタデータを取得してカスタムリストを同期
          AppLogger.debug(' ステップ1: カスタムリストのメタデータを取得します');
          final metadata = await nostrService.fetchAllTodoListMetadata();
          
          // カスタムリスト名を抽出（デフォルトリストは除外）
          final List<String> nostrListNames = [];
          for (final meta in metadata) {
            if (meta.listId != null && meta.title != null) {
              final listId = meta.listId!;
              // デフォルトリストは除外
              if (listId == 'meiso-todos') {
                continue;
              }
              // titleからリスト名を取得（重複チェック）
              if (!nostrListNames.contains(meta.title!)) {
                nostrListNames.add(meta.title!);
                AppLogger.debug(' [Sync] Found custom list: "${meta.title}" (d tag: $listId)');
              }
            }
          }
          
          // カスタムリストを同期（名前ベース）
          // nostrListNamesが空の場合でも呼び出し、デフォルトリストを作成
          AppLogger.info(' [Sync] 2/3: カスタムリストを同期中...');
          if (nostrListNames.isNotEmpty) {
            AppLogger.info(' ${nostrListNames.length}件のカスタムリストを同期します');
          } else {
            AppLogger.debug(' カスタムリストが見つかりませんでした');
          }
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
    AppLogger.info(' Starting merge: ${syncedTodos.length} remote todos');
    
    state.whenData((localTodos) {
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
    });
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
      final nostrService = _ref.read(nostrServiceProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      
      // 1. 既存のKind 30078イベントを取得
      AppLogger.debug(' Fetching existing Kind 30078 events...');
      _ref.read(syncStatusProvider.notifier).updateMessage('旧データ取得中...');
      
      List<Todo> oldTodos;
      if (isAmberMode) {
        // Amberモード: 暗号化されたKind 30078イベントを取得
        final encryptedTodos = await nostrService.fetchEncryptedTodos();
        
        if (encryptedTodos.isEmpty) {
          AppLogger.info(' No Kind 30078 events found. Migration not needed.');
          _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.notNeeded;
          return;
        }
        
        AppLogger.debug(' Found ${encryptedTodos.length} encrypted Kind 30078 events');
        
        // Amberで復号化
        oldTodos = [];
        final amberService = _ref.read(amberServiceProvider);
        final publicKey = _ref.read(publicKeyProvider);
        
        if (publicKey == null) {
          throw Exception('公開鍵が設定されていません');
        }
        
        for (final encryptedTodo in encryptedTodos) {
          try {
            final decryptedJson = await amberService.decryptNip44(
              encryptedTodo.encryptedContent,
              publicKey,
            );
            final todoMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
            oldTodos.add(Todo(
              id: todoMap['id'] as String,
              title: todoMap['title'] as String,
              completed: todoMap['completed'] as bool,
              date: todoMap['date'] != null 
                  ? DateTime.parse(todoMap['date'] as String)
                  : null,
              order: todoMap['order'] as int,
              createdAt: DateTime.parse(todoMap['created_at'] as String),
              updatedAt: DateTime.parse(todoMap['updated_at'] as String),
              eventId: encryptedTodo.eventId,
              linkPreview: todoMap['link_preview'] != null
                  ? LinkPreview.fromJson(todoMap['link_preview'] as Map<String, dynamic>)
                  : null,
            ));
          } catch (e) {
            AppLogger.warning(' Failed to decrypt/parse event ${encryptedTodo.eventId}: $e');
          }
        }
      } else {
        // 旧実装（Kind 30078）は削除されました
        throw Exception('旧実装（Kind 30078）は削除されました。マイグレーション機能は利用できません。');
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
        try {
          await nostrService.deleteEvents(
            oldEventIds,
            reason: 'Migrated to Kind 30001 (NIP-51 Bookmark List)',
          );
          AppLogger.info(' Old events deleted successfully');
        } catch (e) {
          AppLogger.warning(' Failed to delete old events: $e');
          // 削除失敗してもマイグレーションは成功とみなす
        }
      }
      
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.completed;
      _ref.read(syncStatusProvider.notifier).updateMessage('データ移行完了');
      AppLogger.debug('🎉 Migration completed successfully!');
      
      // マイグレーション完了フラグをローカルに保存
      await localStorageService.setMigrationCompleted();
      
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
    AppLogger.debug(' checkKind30001Exists() called');
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      AppLogger.debug(' Mode: ${isAmberMode ? "Amber" : "Normal"}');
      
      if (isAmberMode) {
        // Amberモード: 暗号化されたTodoリストイベントを取得
        // ⚠️ 復号化はしない！イベントの存在だけチェック
        AppLogger.debug(' Fetching encrypted Kind 30001 event (NO DECRYPTION)...');
        final encryptedEvent = await nostrService.fetchEncryptedTodoList();
        
        if (encryptedEvent != null) {
          AppLogger.info(' Found Kind 30001 event (Amber mode) - Event ID: ${encryptedEvent.eventId}');
          AppLogger.info(' This means migration is already done. NO NEED TO DECRYPT OLD EVENTS!');
          return true;
        } else {
          AppLogger.debug(' No Kind 30001 event found (Amber mode)');
        }
      } else {
        // 通常モード: Rust側で復号化済みのTodoリストを取得
        AppLogger.debug(' Fetching Kind 30001 todos (normal mode)...');
        final todos = await nostrService.syncTodoListFromNostr();
        
        if (todos.isNotEmpty) {
          AppLogger.info(' Found Kind 30001 with ${todos.length} todos (normal mode)');
          return true;
        } else {
          AppLogger.debug(' No Kind 30001 todos found (normal mode)');
        }
      }
      
      AppLogger.debug(' No Kind 30001 found - will check Kind 30078');
      return false;
    } catch (e, stackTrace) {
      AppLogger.warning(' Failed to check Kind 30001: $e');
      AppLogger.error('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return false;
    }
  }

  /// マイグレーションが必要かチェック
  /// 
  /// Kind 30078のTODOイベント（旧形式）が存在する場合にtrueを返す
  /// ※ Kind 30078の設定イベント（d="meiso-settings"）は除外
  Future<bool> checkMigrationNeeded() async {
    // ローカルストレージでマイグレーション完了済みかチェック
    final completed = await localStorageService.isMigrationCompleted();
    if (completed) {
      AppLogger.info(' Migration already completed (cached)');
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.completed;
      return false;
    }
    
    // Kind 30078のTODOイベント（d="todo-*"）が存在するかチェック
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      
      if (isAmberMode) {
        // Amberモード: 暗号化されたイベントを取得
        final encryptedTodos = await nostrService.fetchEncryptedTodos();
        
        // Kind 30078のTODOイベント（d="todo-*"）が存在する場合のみマイグレーション必要
        if (encryptedTodos.isNotEmpty) {
          AppLogger.debug(' Found ${encryptedTodos.length} old Kind 30078 TODO events (Amber mode)');
          return true;
        }
      } else {
        // 旧実装（Kind 30078）は削除されました
        AppLogger.warning(' 旧実装（Kind 30078）は削除されました。マイグレーションチェックをスキップします。');
        return false;
      }
      
      AppLogger.info(' No old Kind 30078 TODO events found');
      return false;
    } catch (e) {
      AppLogger.warning(' Failed to check migration: $e');
      return false;
    }
  }
  
  // ========================================
  // グループタスク管理（マルチパーティ暗号化）
  // ========================================
  
  /// グループタスクを同期（復号化してローカルに追加）
  Future<void> syncGroupTodos(String groupId) async {
    try {
      AppLogger.info('🔄 Syncing group todos for group: $groupId');
      
      // グループリストを取得
      final groupLists = await groupTaskService.fetchMyGroupTaskLists();
      final groupList = groupLists.where((g) => g.groupId == groupId).firstOrNull;
      
      if (groupList == null) {
        AppLogger.warning('⚠️ Group not found: $groupId');
        return;
      }
      
      // グループタスクを復号化
      final groupTodos = await groupTaskService.decryptGroupTaskList(
        groupList: groupList,
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
      AppLogger.info('📤 Syncing group tasks to Nostr: $groupId');
      
      // グループリスト情報を取得
      final customListsAsync = _ref.read(customListsProvider);
      final customLists = customListsAsync.whenOrNull(data: (lists) => lists) ?? [];
      final groupList = customLists.where((l) => l.id == groupId && l.isGroup).firstOrNull;
      
      if (groupList == null) {
        AppLogger.warning('⚠️ Group list not found: $groupId');
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
        AppLogger.info('ℹ️ No todos to sync for group: $groupId');
        return;
      }
      
      // グループタスクリストを暗号化してNostrに保存
      await groupTaskService.createGroupTaskList(
        tasks: todos,
        customList: groupList,
      );
      
      AppLogger.info('✅ Group tasks synced to Nostr: ${todos.length} tasks');
    } catch (e, st) {
      AppLogger.error('❌ Failed to sync group to Nostr: $e', error: e, stackTrace: st);
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

