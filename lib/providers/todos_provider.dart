import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../services/local_storage_service.dart';
import '../services/amber_service.dart';
import '../services/link_preview_service.dart';
import '../services/recurrence_parser.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';

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

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localTodos = await localStorageService.loadTodos();
      
      if (localTodos.isEmpty) {
        // 初回起動時のみダミーデータを作成
        await _createInitialDummyData();
      } else {
        // ローカルデータをグループ化して状態に設定
        final Map<DateTime?, List<Todo>> grouped = {};
        for (final todo in localTodos) {
          grouped[todo.date] ??= [];
          grouped[todo.date]!.add(todo);
        }
        
        // 各日付のリストをorder順にソート
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
        }
        
        state = AsyncValue.data(grouped);
      }
      
      // Nostr同期は非同期で実行（初期化をブロックしない）
      _backgroundSync();
      
    } catch (e) {
      print('⚠️ Todo初期化エラー: $e');
      // エラー時でもダミーデータで初期化（UIを表示）
      try {
        await _createInitialDummyData();
      } catch (e2) {
        print('⚠️ ダミーデータ作成も失敗: $e2');
        // 最終フォールバック: 空のマップで初期化
        state = AsyncValue.data({});
      }
    }
  }
  
  /// バックグラウンド同期（UIブロックしない）
  Future<void> _backgroundSync() async {
    // 画面表示後に実行
    await Future.delayed(const Duration(seconds: 1));
    
    if (_ref.read(nostrInitializedProvider)) {
      try {
        print('🔄 Starting background Nostr sync...');
        
        // マイグレーション完了チェック（一度だけ実行）
        final migrationCompleted = await localStorageService.isMigrationCompleted();
        print('📋 Migration status check: completed=$migrationCompleted');
        
        if (!migrationCompleted) {
          print('🔍 Checking data status...');
          
          // まずKind 30001（新形式）をチェック
          _ref.read(syncStatusProvider.notifier).updateMessage('データ読み込み中...');
          print('🔍 Step 1: Checking Kind 30001 existence...');
          final hasNewData = await checkKind30001Exists();
          print('🔍 Step 1 result: hasNewData=$hasNewData');
          
          if (hasNewData) {
            // Kind 30001にデータがある = マイグレーション済み
            print('✅ Found Kind 30001 data. Migration already completed on another device.');
            print('📥 Loading data from Kind 30001...');
            print('⏭️  SKIPPING migration - Kind 30001 found!');
            
            // Kind 30001から同期（この後のsyncFromNostr()で実行される）
            await localStorageService.setMigrationCompleted();
            print('✅ Migration flag set to completed');
          } else {
            // Kind 30001がない → Kind 30078をチェック
            print('🔍 No Kind 30001 found. Checking for old Kind 30078 events...');
            print('🔍 Step 2: Checking Kind 30078 existence...');
            final needsMigration = await checkMigrationNeeded();
            print('🔍 Step 2 result: needsMigration=$needsMigration');
            
            if (needsMigration) {
              print('📦 Found old Kind 30078 TODO events. Starting migration...');
              print('⚠️  MIGRATION WILL START - THIS WILL TRIGGER AMBER DECRYPTION');
              _ref.read(syncStatusProvider.notifier).updateMessage('データ移行中...');
              
              // マイグレーション実行（Kind 30078 → Kind 30001）
              await migrateFromKind30078ToKind30001();
              print('✅ Migration completed successfully');
            } else {
              print('✅ No old events found. Marking migration as completed.');
              // 旧イベントがない場合はマイグレーション完了として記録
              await localStorageService.setMigrationCompleted();
              print('✅ Migration flag set to completed (no data)');
            }
          }
        } else {
          print('✅ Migration already completed (cached)');
        }
        
        _ref.read(syncStatusProvider.notifier).updateMessage('データ同期中...');
        await syncFromNostr();
        print('✅ Background sync completed');
      } catch (e) {
        print('⚠️ バックグラウンド同期失敗: $e');
        // エラーは無視（ローカルデータで継続）
      }
    } else {
      print('ℹ️ Nostr not initialized - skipping background sync');
    }
  }

  /// 初回起動時のダミーデータを作成
  Future<void> _createInitialDummyData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    final initialTodos = [
      Todo(
        id: _uuid.v4(),
        title: 'Nostr統合を完了する',
        completed: false,
        date: today,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'UI/UXを改善する',
        completed: false,
        date: today,
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'Amber統合をテストする',
        completed: false,
        date: tomorrow,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'リカーリングタスクを実装する',
        completed: false,
        date: null,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    
    // ローカルストレージに保存
    await localStorageService.saveTodos(initialTodos);
    
    // 状態に反映
    state = AsyncValue.data({
      today: [initialTodos[0], initialTodos[1]],
      tomorrow: [initialTodos[2]],
      null: [initialTodos[3]],
    });
  }

  /// 新しいTodoを追加
  Future<void> addTodo(String title, DateTime? date, {String? customListId}) async {
    if (title.trim().isEmpty) return;

    print('🆕 addTodo called: "$title" for date: $date, customListId: $customListId');

    await state.whenData((todos) async {
      final now = DateTime.now();
      
      // 繰り返しパターンを自動検出（TeuxDeux風）
      final parseResult = RecurrenceParser.parse(title, date);
      final cleanTitle = parseResult.cleanTitle;
      final autoRecurrence = parseResult.pattern;
      
      if (autoRecurrence != null) {
        print('🔄 自動検出: ${autoRecurrence.description}');
        print('📝 クリーンタイトル: "$cleanTitle"');
      }
      
      // URLを検出してメタデータを取得（バックグラウンド）
      final detectedUrl = LinkPreviewService.extractUrl(cleanTitle);
      print('🔗 URL detected: $detectedUrl');
      
      final newTodo = Todo(
        id: _uuid.v4(),
        title: cleanTitle,
        completed: false,
        date: date,
        order: _getNextOrder(todos, date),
        createdAt: now,
        updatedAt: now,
        customListId: customListId,
        recurrence: autoRecurrence, // 自動検出された繰り返しパターンを設定
      );

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

      // ローカルストレージに保存
      print('💾 Saving to local storage...');
      await _saveAllTodosToLocal();
      print('✅ Local save complete');

      // URLメタデータ取得（非同期・バックグラウンド）
      if (detectedUrl != null) {
        _fetchLinkPreviewInBackground(newTodo.id, date, detectedUrl);
      }

      // Nostrが初期化されているかチェック
      final isNostrInitialized = _ref.read(nostrInitializedProvider);
      print('🔍 Nostr initialized: $isNostrInitialized');

      // Nostr側に全TODOリストを送信（await追加）
      print('📤 Starting Nostr sync...');
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
      print('✅ Nostr sync completed');
    }).value;
  }

  /// バックグラウンドでリンクプレビューを取得
  Future<void> _fetchLinkPreviewInBackground(
    String todoId,
    DateTime? date,
    String url,
  ) async {
    try {
      print('🔗 Fetching link preview for: $url');
      final linkPreview = await LinkPreviewService.fetchLinkPreview(url);
      
      if (linkPreview != null) {
        print('✅ Link preview fetched, updating todo...');
        
        // Todoを更新
        state.whenData((todos) async {
          final list = List<Todo>.from(todos[date] ?? []);
          final index = list.indexWhere((t) => t.id == todoId);
          
          if (index != -1) {
            final currentTodo = list[index];
            
            // タイトルからURLを削除
            final newTitle = LinkPreviewService.removeUrlFromText(
              currentTodo.title,
              url,
            );
            
            print('📝 Title updated: "${currentTodo.title}" → "$newTitle"');
            
            list[index] = currentTodo.copyWith(
              title: newTitle.isNotEmpty ? newTitle : currentTodo.title, // 空になった場合は元のまま
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
      }
    } catch (e) {
      print('⚠️ Failed to fetch link preview: $e');
      // エラーは無視（リンクプレビューなしでTodoは利用可能）
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

  /// ローカルのeventIdがないTodoをNostrに送信
  Future<void> uploadPendingTodos() async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のためアップロードをスキップ');
      return;
    }

    state.whenData((todos) async {
      final nostrService = _ref.read(nostrServiceProvider);
      int uploadCount = 0;

      for (final dateGroup in todos.entries) {
        final date = dateGroup.key;
        final list = List<Todo>.from(dateGroup.value);

        for (int i = 0; i < list.length; i++) {
          final todo = list[i];
          
          // eventIdがないTodoを送信
          if (todo.eventId == null) {
            try {
              final eventId = await nostrService.createTodoOnNostr(todo);
              list[i] = todo.copyWith(eventId: eventId);
              uploadCount++;
              print('✅ Todoをアップロード: ${todo.title}');
            } catch (e) {
              print('⚠️ Todoアップロード失敗 (${todo.title}): $e');
            }
          }
        }

        // 更新された日付グループを反映
        todos[date] = list;
      }

      if (uploadCount > 0) {
        state = AsyncValue.data(Map.from(todos));
        await _saveAllTodosToLocal();
        print('✅ ${uploadCount}件のTodoをアップロードしました');
      } else {
        print('ℹ️ アップロードが必要なTodoはありません');
      }
    });
  }

  /// NostrからのTodoをローカルとマージ（スマートマージ）
  /// updatedAtが新しい方を優先
  Future<void> mergeTodosFromNostr(List<Todo> nostrTodos) async {
    state.whenData((localTodos) async {
      final Map<String, Todo> mergedMap = {};
      
      // ローカルのTodoをマップに追加
      for (final dateGroup in localTodos.values) {
        for (final todo in dateGroup) {
          mergedMap[todo.id] = todo;
        }
      }
      
      // NostrのTodoをマージ（新しい方を優先）
      for (final nostrTodo in nostrTodos) {
        final localTodo = mergedMap[nostrTodo.id];
        
        if (localTodo == null) {
          // ローカルに存在しない → 追加
          mergedMap[nostrTodo.id] = nostrTodo;
        } else {
          // 両方に存在 → 新しい方を採用
          if (nostrTodo.updatedAt.isAfter(localTodo.updatedAt)) {
            mergedMap[nostrTodo.id] = nostrTodo;
          }
          // localの方が新しい場合はそのまま
        }
      }
      
      // 日付ごとにグループ化
      final Map<DateTime?, List<Todo>> grouped = {};
      for (final todo in mergedMap.values) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }
      
      // 各日付のリストをorder順にソート
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }
      
      state = AsyncValue.data(grouped);
      
      // ローカルストレージに保存
      await _saveAllTodosToLocal();
    });
  }

  /// Todoを更新
  Future<void> updateTodo(Todo todo) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      final index = list.indexWhere((t) => t.id == todo.id);

      if (index != -1) {
        list[index] = todo.copyWith(updatedAt: DateTime.now());
        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に全TODOリストを送信（await追加）
        await _syncToNostr(() async {
          await _syncAllTodosToNostr();
        });
      }
    }).value;
  }

  /// Todoのタイトルを更新
  Future<void> updateTodoTitle(String id, DateTime? date, String newTitle) async {
    if (newTitle.trim().isEmpty) return;

    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          title: newTitle.trim(),
          updatedAt: DateTime.now(),
        );
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に全TODOリストを送信（await追加）
        await _syncToNostr(() async {
          await _syncAllTodosToNostr();
        });
      }
    }).value;
  }

  /// Todoのカスタムリスト紐づけを更新
  Future<void> updateTodoCustomListId(String id, DateTime? date, String? customListId) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          customListId: customListId,
          updatedAt: DateTime.now(),
        );
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に全TODOリストを送信
        await _syncToNostr(() async {
          await _syncAllTodosToNostr();
        });
      }
    }).value;
  }

  /// Todoのタイトルと繰り返しパターンを更新
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
        final updatedTodo = list[index].copyWith(
          title: newTitle.trim(),
          recurrence: recurrence,
          updatedAt: DateTime.now(),
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

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に全TODOリストを送信
        await _syncToNostr(() async {
          await _syncAllTodosToNostr();
        });
      }
    }).value;
  }

  /// Todoの完了状態をトグル
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
        );

        // リカーリングタスクの完了時に次回のタスクを生成
        if (!wasCompleted && todo.recurrence != null && todo.date != null) {
          await _createNextRecurringTask(todo, todos);
        }

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に全TODOリストを送信（await追加）
        await _syncToNostr(() async {
          await _syncAllTodosToNostr();
        });
      }
    }).value;
  }

  /// リカーリングタスクの次回インスタンスを生成
  Future<void> _createNextRecurringTask(
    Todo originalTodo,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    if (originalTodo.recurrence == null || originalTodo.date == null) {
      return;
    }

    // 次回の日付を計算
    final nextDate = originalTodo.recurrence!.calculateNextDate(originalTodo.date!);
    
    if (nextDate == null) {
      // 繰り返し終了
      print('🔄 リカーリングタスク終了: ${originalTodo.title}');
      return;
    }

    // 既に次回のタスクが存在するかチェック
    final existingTasks = todos[nextDate] ?? [];
    final alreadyExists = existingTasks.any((t) => 
      t.parentRecurringId == originalTodo.id ||
      (t.title == originalTodo.title && t.recurrence != null)
    );

    if (alreadyExists) {
      print('ℹ️ 次回のリカーリングタスクは既に存在します');
      return;
    }

    // 新しいタスクを生成
    final newTodo = Todo(
      id: _uuid.v4(),
      title: originalTodo.title,
      completed: false,
      date: nextDate,
      order: _getNextOrder(todos, nextDate),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      recurrence: originalTodo.recurrence, // 繰り返しパターンを継承
      parentRecurringId: originalTodo.id, // 元のタスクIDを記録
      linkPreview: originalTodo.linkPreview,
    );

    // 状態に追加
    final list = List<Todo>.from(todos[nextDate] ?? []);
    list.add(newTodo);

    todos[nextDate] = list;

    print('🔄 次回のリカーリングタスクを生成: ${newTodo.title} (${nextDate})');

    // 状態を更新（この時点でUIに反映）
    state = AsyncValue.data(Map.from(todos));
    
    // ローカルに保存
    await _saveAllTodosToLocal();

    // Nostrにも同期
    await _syncToNostr(() async {
      await _syncAllTodosToNostr();
    });
  }

  /// リカーリングタスクの将来のインスタンスを事前生成（7日分）
  Future<void> _generateFutureInstances(
    Todo originalTodo,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    if (originalTodo.recurrence == null || originalTodo.date == null) {
      return;
    }

    print('📅 将来のインスタンスを生成開始: ${originalTodo.title}');
    print('📅 元のタスクの日付: ${originalTodo.date}');
    
    // 元のタスクが含まれているか確認
    final originalDateTasks = todos[originalTodo.date] ?? [];
    final originalTaskExists = originalDateTasks.any((t) => t.id == originalTodo.id);
    print('📅 元のタスクが存在: $originalTaskExists (${originalDateTasks.length}件のタスク)');

    DateTime? currentDate = originalTodo.date;
    int generatedCount = 0;
    const maxInstances = 10; // 最大10個まで生成（無限ループ防止）
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));

    // 既存の子インスタンスを削除
    await _removeChildInstances(originalTodo.id, todos);
    
    // 削除後に元のタスクがまだ存在するか確認
    final afterRemoveTasks = todos[originalTodo.date] ?? [];
    final originalTaskStillExists = afterRemoveTasks.any((t) => t.id == originalTodo.id);
    print('📅 削除後の元のタスク存在: $originalTaskStillExists (${afterRemoveTasks.length}件のタスク)');

    // 7日以内の将来のインスタンスを生成
    while (generatedCount < maxInstances) {
      final nextDate = originalTodo.recurrence!.calculateNextDate(currentDate!);
      
      if (nextDate == null) {
        print('🔄 繰り返し終了');
        break; // 繰り返し終了
      }

      // 7日以内の日付のみ生成
      if (nextDate.isAfter(sevenDaysLater)) {
        print('📅 7日以内の範囲を超えたため終了');
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
        );

        final list = List<Todo>.from(todos[nextDate] ?? []);
        list.add(newTodo);
        todos[nextDate] = list;

        generatedCount++;
        print('✅ インスタンス生成: ${nextDate.month}/${nextDate.day}');
      }

      currentDate = nextDate;
    }

    print('📅 合計${generatedCount}個のインスタンスを生成しました');
    
    // 最終的に元のタスクが含まれているか確認
    final finalTasks = todos[originalTodo.date] ?? [];
    final finalTaskExists = finalTasks.any((t) => t.id == originalTodo.id);
    print('📅 最終的な元のタスク存在: $finalTaskExists (${finalTasks.length}件のタスク)');

    // 状態を更新
    state = AsyncValue.data(Map.from(todos));
  }

  /// 親タスクの子インスタンスを削除
  Future<void> _removeChildInstances(
    String parentId,
    Map<DateTime?, List<Todo>> todos,
  ) async {
    print('🗑️ 子インスタンスを削除: $parentId');
    
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

    print('🗑️ ${removedCount}個の子インスタンスを削除しました');

    if (removedCount > 0) {
      state = AsyncValue.data(Map.from(todos));
    }
  }

  /// Todoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    await state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に全TODOリストを送信（await追加）
      // 削除後の全TODOリストを送信（Replaceable eventなので古いイベントは自動的に置き換わる）
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }).value;
  }

  /// リカーリングタスクのこのインスタンスのみを削除
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

      print('🗑️ リカーリングタスクのインスタンスを削除: ${todo.title} (${date})');

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に全TODOリストを送信
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }).value;
  }

  /// リカーリングタスクのすべてのインスタンスを削除
  Future<void> deleteAllRecurringInstances(String id, DateTime? date) async {
    await state.whenData((todos) async {
      // 削除対象のTodoを取得
      final list = List<Todo>.from(todos[date] ?? []);
      final todo = list.firstWhere((t) => t.id == id);
      
      // 親タスクのIDを特定
      final parentId = todo.parentRecurringId ?? todo.id;
      
      print('🗑️ すべてのリカーリングインスタンスを削除: parentId=$parentId');
      
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

      print('🗑️ 合計${deletedCount}個のリカーリングインスタンスを削除しました');

      state = AsyncValue.data(updatedTodos);

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に全TODOリストを送信
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }).value;
  }

  /// Todoを並び替え
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
        );
      }

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に全TODOリストを送信（await追加）
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }).value;
  }

  /// Todoを別の日付に移動
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
      );
      toList.add(movedTodo);

      state = AsyncValue.data({
        ...todos,
        fromDate: fromList,
        toDate: toList,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に全TODOリストを送信（await追加）
      await _syncToNostr(() async {
        await _syncAllTodosToNostr();
      });
    }).value;
  }

  /// 次の order 値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) return 0;
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// 全TODOリストをNostrに同期（新実装 - Kind 30001）
  /// すべてのTodo操作後に呼び出される
  Future<void> _syncAllTodosToNostr() async {
    print('🔄 _syncAllTodosToNostr called');
    
    final isInitialized = _ref.read(nostrInitializedProvider);
    print('🔍 Nostr initialized in _syncAllTodosToNostr: $isInitialized');
    
    if (!isInitialized) {
      print('⚠️ Nostr未初期化のため同期をスキップ');
      return;
    }

    state.whenData((todos) async {
      // 全TODOをフラット化
      final allTodos = <Todo>[];
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }

      print('📦 Total todos to sync: ${allTodos.length}');

      final isAmberMode = _ref.read(isAmberModeProvider);
      final nostrService = _ref.read(nostrServiceProvider);
      
      print('🔐 Amber mode: $isAmberMode');

      try {
        if (isAmberMode) {
          // Amberモード: 全TODOリスト → JSON → Amber暗号化 → 未署名イベント → Amber署名 → リレー送信
          print('🔐 Amberモードで全TODOリストを同期します（バックグラウンド処理）');
          
          // 1. 全TODOをJSONに変換
          final todosJson = jsonEncode(allTodos.map((todo) => {
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
          }).toList());
          
          print('📝 TODOリスト JSON (${todosJson.length} bytes, ${allTodos.length}件)');
          
          // 2. 公開鍵取得
          final publicKey = _ref.read(publicKeyProvider);
          final npub = _ref.read(nostrPublicKeyProvider);
          if (publicKey == null || npub == null) {
            throw Exception('公開鍵が設定されていません');
          }
          
          // 3. AmberでNIP-44暗号化
          final amberService = _ref.read(amberServiceProvider);
          print('🔐 Amberで暗号化中（バックグラウンド）...');
          
          String encryptedContent;
          try {
            // まずContentProvider経由で試す（バックグラウンド処理）
            encryptedContent = await amberService.encryptNip44WithContentProvider(
              plaintext: todosJson,
              pubkey: publicKey,
              npub: npub,
            );
            print('✅ 暗号化完了（バックグラウンド、UIなし） (${encryptedContent.length} bytes)');
          } on PlatformException catch (e) {
            // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
            print('⚠️ ContentProvider暗号化失敗 (${e.code}), UI経由で再試行します...');
            encryptedContent = await amberService.encryptNip44(todosJson, publicKey);
            print('✅ 暗号化完了（UI経由） (${encryptedContent.length} bytes)');
          }
          
          // 4. 暗号化済みcontentで未署名イベントを作成（Kind 30001）
          final unsignedEvent = await nostrService.createUnsignedEncryptedTodoListEvent(
            encryptedContent: encryptedContent,
          );
          print('📄 未署名イベント作成完了（Kind 30001）');
          
          // 5. Amberで署名
          print('✍️ Amberで署名中（バックグラウンド）...');
          
          String signedEvent;
          try {
            // まずContentProvider経由で試す（バックグラウンド）
            signedEvent = await amberService.signEventWithContentProvider(
              event: unsignedEvent,
              npub: npub,
            );
            print('✅ 署名完了（バックグラウンド、UIなし）');
          } on PlatformException catch (e) {
            // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
            print('⚠️ ContentProvider署名失敗 (${e.code}), UI経由で再試行します...');
            signedEvent = await amberService.signEventWithTimeout(unsignedEvent);
            print('✅ 署名完了（UI経由）');
          }
          
          // 6. リレーに送信
          print('📤 リレーに送信中...');
          print('🔍 署名済みイベント (最初200文字): ${signedEvent.substring(0, 200.clamp(0, signedEvent.length))}...');
          final eventId = await nostrService.sendSignedEvent(signedEvent);
          print('✅ 送信完了: $eventId');
          print('🎯 Kind 30001イベントID: $eventId');
          
        } else {
          // 通常モード: 秘密鍵で署名（Rust側でNIP-44暗号化）
          print('🔄 通常モードで全TODOリストを同期します');
          print('🔄 Calling nostrService.createTodoListOnNostr with ${allTodos.length} todos...');
          
          try {
            final eventId = await nostrService.createTodoListOnNostr(allTodos);
            print('✅✅✅ TODOリスト送信完了: $eventId (${allTodos.length}件)');
          } catch (e) {
            print('❌❌❌ createTodoListOnNostr failed: $e');
            rethrow;
          }
        }
      } catch (e, stackTrace) {
        print('❌ TODOリスト同期失敗: $e');
        print('スタックトレース: $stackTrace');
        rethrow;
      }
    });
  }


  /// Nostrへの同期処理（リトライ機能付き）
  /// Amberモード時はAmber署名フローを使用
  Future<void> _syncToNostr(Future<void> Function() syncFunction) async {
    print('📡 _syncToNostr called');
    
    final isInitialized = _ref.read(nostrInitializedProvider);
    print('🔍 Nostr initialized in _syncToNostr: $isInitialized');
    
    if (!isInitialized) {
      // Nostr未初期化の場合はスキップ
      print('⚠️ Nostr未初期化のため_syncToNostrをスキップ');
      return;
    }

    // Amberモードの場合は専用フローを使用
    // （syncFunctionはAmberモード用に最適化されている前提）
    if (_ref.read(isAmberModeProvider)) {
      print('🔐 Amberモードで同期します');
      // Amberモードの場合はリトライなし（ユーザー操作が必要なため）
      _ref.read(syncStatusProvider.notifier).startSync();
      
      try {
        await syncFunction();
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        print('✅ Amber同期成功');
      } catch (e) {
        _ref.read(syncStatusProvider.notifier).syncError(
          e.toString(),
          shouldRetry: false,
        );
        print('❌ Amber同期失敗: $e');
      }
      return;
    }

    // 通常モード: 秘密鍵で署名
    // 同期開始
    _ref.read(syncStatusProvider.notifier).startSync();

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await syncFunction();
        
        // 成功
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        print('✅ Nostr同期成功');
        return;
        
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        
        if (isLastAttempt) {
          // 最終試行でも失敗
          _ref.read(syncStatusProvider.notifier).syncError(
            e.toString(),
            shouldRetry: false,
          );
          print('❌ Nostr同期失敗（最終試行）: $e');
        } else {
          // リトライする
          print('⚠️ Nostr同期エラー（${attempt + 1}/${maxRetries + 1}回目）: $e');
          print('🔄 ${retryDelay.inSeconds}秒後にリトライします...');
          
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
        print('⚠️ ローカル保存エラー: $e');
      }
    });
  }


  /// Nostrからすべてのtodoを同期（Kind 30001 - Todoリスト全体を取得）
  Future<void> syncFromNostr() async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のため同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);

    _ref.read(syncStatusProvider.notifier).startSync();

    try {
      if (isAmberMode) {
        // Amberモード: 暗号化されたTodoリストイベント（Kind 30001）を取得 → Amberで復号化
        print('🔐 Amberモードで同期します（Kind 30001、復号化あり、バックグラウンド処理）');
        
        final encryptedEvent = await nostrService.fetchEncryptedTodoList();
        
        if (encryptedEvent == null) {
          print('⚠️ Todoリストイベントが見つかりません（Kind 30001）');
          print('ℹ️ ローカルデータを保持します');
          // イベントが見つからない場合はローカルデータを保持（上書きしない）
          _ref.read(syncStatusProvider.notifier).syncSuccess();
          return;
        }
        
        print('📥 Todoリストイベントを取得 (Event ID: ${encryptedEvent.eventId})');
        
        final amberService = _ref.read(amberServiceProvider);
        final publicKey = _ref.read(publicKeyProvider);
        final npub = _ref.read(nostrPublicKeyProvider);
        
        if (publicKey == null || npub == null) {
          throw Exception('公開鍵が設定されていません');
        }
        
        print('🔑 公開鍵: ${publicKey.substring(0, 16)}...');
        print('🔓 Todoリストを復号化中...');
        
        // Amberで復号化
        String decryptedJson;
        try {
          // まずContentProvider経由で試す（バックグラウンド処理）
          decryptedJson = await amberService.decryptNip44WithContentProvider(
            ciphertext: encryptedEvent.encryptedContent,
            pubkey: publicKey,
            npub: npub,
          );
          print('✅ 復号化完了（バックグラウンド、UIなし）');
        } on PlatformException catch (e) {
          // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
          print('⚠️ ContentProvider復号化失敗 (${e.code}), UI経由で再試行します...');
          decryptedJson = await amberService.decryptNip44(
            encryptedEvent.encryptedContent,
            publicKey,
          );
          print('✅ 復号化完了（UI経由）');
        }
        
        print('復号化結果 (最初100文字): ${decryptedJson.substring(0, 100.clamp(0, decryptedJson.length))}...');
        
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
          );
        }).toList();
        
        print('✅ 復号化完了: ${syncedTodos.length}件のTodo');
        
        // 状態を更新
        _updateStateWithSyncedTodos(syncedTodos);
        
      } else {
        // 通常モード: Rust側で復号化済みのTodoリストを取得（Kind 30001）
        print('🔄 通常モードで同期します（Kind 30001）');
        final syncedTodos = await nostrService.syncTodoListFromNostr();
        print('📥 ${syncedTodos.length}件のTodoを取得しました');
        
        // イベントが見つからない場合（空リスト）はローカルデータを保持
        if (syncedTodos.isEmpty) {
          state.whenData((localTodos) {
            final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
            if (localTodoCount > 0) {
              print('ℹ️ リモートにイベントがありませんが、ローカルに${localTodoCount}件のTodoがあるため保持します');
              return; // ローカルデータを保持
            }
          });
        }
        
        _updateStateWithSyncedTodos(syncedTodos);
      }
      
      _ref.read(syncStatusProvider.notifier).syncSuccess();
      print('✅ Nostr同期成功');
      
    } catch (e, stackTrace) {
      _ref.read(syncStatusProvider.notifier).syncError(
        e.toString(),
        shouldRetry: false,
      );
      print('❌ Nostr同期失敗: $e');
      print('スタックトレース: ${stackTrace.toString().split('\n').take(5).join('\n')}');
    }
  }

  /// 同期したTodoで状態を更新
  void _updateStateWithSyncedTodos(List<Todo> syncedTodos) {
    // 日付ごとにグループ化
    final Map<DateTime?, List<Todo>> grouped = {};
    for (final todo in syncedTodos) {
      grouped[todo.date] ??= [];
      grouped[todo.date]!.add(todo);
    }
    
    // 各日付のリストをorder順にソート
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
    }
    
    state = AsyncValue.data(grouped);
    
    // ローカルストレージに保存
    _saveAllTodosToLocal();
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
    print('🔄 Starting migration from Kind 30078 to Kind 30001...');
    
    _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.checking;
    _ref.read(syncStatusProvider.notifier).updateMessage('データ移行準備中...');
    
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      
      // 1. 既存のKind 30078イベントを取得
      print('📥 Fetching existing Kind 30078 events...');
      _ref.read(syncStatusProvider.notifier).updateMessage('旧データ取得中...');
      
      List<Todo> oldTodos;
      if (isAmberMode) {
        // Amberモード: 暗号化されたKind 30078イベントを取得
        final encryptedTodos = await nostrService.fetchEncryptedTodos();
        
        if (encryptedTodos.isEmpty) {
          print('✅ No Kind 30078 events found. Migration not needed.');
          _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.notNeeded;
          return;
        }
        
        print('📥 Found ${encryptedTodos.length} encrypted Kind 30078 events');
        
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
            print('⚠️ Failed to decrypt/parse event ${encryptedTodo.eventId}: $e');
          }
        }
      } else {
        // 通常モード: 秘密鍵で復号化
        oldTodos = await nostrService.syncTodosFromNostr();
        
        if (oldTodos.isEmpty) {
          print('✅ No Kind 30078 events found. Migration not needed.');
          _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.notNeeded;
          return;
        }
      }
      
      print('📦 Found ${oldTodos.length} todos in Kind 30078 format');
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.needed;
      
      // 2. Kind 30001形式で再送信
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.inProgress;
      print('📤 Migrating todos to Kind 30001 format...');
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
      
      print('✅ Migration to Kind 30001 completed');
      
      // 3. 古いKind 30078イベントを削除
      final oldEventIds = oldTodos
          .map((t) => t.eventId)
          .where((id) => id != null)
          .cast<String>()
          .toList();
      
      if (oldEventIds.isNotEmpty) {
        print('🗑️ Deleting ${oldEventIds.length} old Kind 30078 events...');
        _ref.read(syncStatusProvider.notifier).updateMessage('旧データ削除中...');
        try {
          await nostrService.deleteEvents(
            oldEventIds,
            reason: 'Migrated to Kind 30001 (NIP-51 Bookmark List)',
          );
          print('✅ Old events deleted successfully');
        } catch (e) {
          print('⚠️ Failed to delete old events: $e');
          // 削除失敗してもマイグレーションは成功とみなす
        }
      }
      
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.completed;
      _ref.read(syncStatusProvider.notifier).updateMessage('データ移行完了');
      print('🎉 Migration completed successfully!');
      
      // マイグレーション完了フラグをローカルに保存
      await localStorageService.setMigrationCompleted();
      
      // メッセージをクリア
      await Future.delayed(const Duration(seconds: 1));
      _ref.read(syncStatusProvider.notifier).clearMessage();
      
    } catch (e, stackTrace) {
      _ref.read(migrationStatusProvider.notifier).state = MigrationStatus.failed;
      print('❌ Migration failed: $e');
      print('スタックトレース: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      rethrow;
    }
  }
  
  /// Kind 30001（新形式）にデータが存在するかチェック
  /// 
  /// Kind 30001にデータがある = マイグレーション済み（別デバイスで実行済みなど）
  /// 
  /// ⚠️ このメソッドは復号化せずにイベントの存在のみをチェックします
  Future<bool> checkKind30001Exists() async {
    print('🔍 checkKind30001Exists() called');
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      final isAmberMode = _ref.read(isAmberModeProvider);
      print('🔍 Mode: ${isAmberMode ? "Amber" : "Normal"}');
      
      if (isAmberMode) {
        // Amberモード: 暗号化されたTodoリストイベントを取得
        // ⚠️ 復号化はしない！イベントの存在だけチェック
        print('🔍 Fetching encrypted Kind 30001 event (NO DECRYPTION)...');
        final encryptedEvent = await nostrService.fetchEncryptedTodoList();
        
        if (encryptedEvent != null) {
          print('✅ Found Kind 30001 event (Amber mode) - Event ID: ${encryptedEvent.eventId}');
          print('✅ This means migration is already done. NO NEED TO DECRYPT OLD EVENTS!');
          return true;
        } else {
          print('ℹ️ No Kind 30001 event found (Amber mode)');
        }
      } else {
        // 通常モード: Rust側で復号化済みのTodoリストを取得
        print('🔍 Fetching Kind 30001 todos (normal mode)...');
        final todos = await nostrService.syncTodoListFromNostr();
        
        if (todos.isNotEmpty) {
          print('✅ Found Kind 30001 with ${todos.length} todos (normal mode)');
          return true;
        } else {
          print('ℹ️ No Kind 30001 todos found (normal mode)');
        }
      }
      
      print('ℹ️ No Kind 30001 found - will check Kind 30078');
      return false;
    } catch (e, stackTrace) {
      print('⚠️ Failed to check Kind 30001: $e');
      print('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
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
      print('✅ Migration already completed (cached)');
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
          print('📦 Found ${encryptedTodos.length} old Kind 30078 TODO events (Amber mode)');
          return true;
        }
      } else {
        // 通常モード: 秘密鍵で復号化
        final oldTodos = await nostrService.syncTodosFromNostr();
        
        if (oldTodos.isNotEmpty) {
          print('📦 Found ${oldTodos.length} old Kind 30078 TODO events (normal mode)');
          return true;
        }
      }
      
      print('✅ No old Kind 30078 TODO events found');
      return false;
    } catch (e) {
      print('⚠️ Failed to check migration: $e');
      return false;
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

