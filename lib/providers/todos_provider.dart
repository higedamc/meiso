import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';
import '../services/local_storage_service.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';

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
    } catch (e, stackTrace) {
      print('⚠️ Todo初期化エラー: $e');
      state = AsyncValue.error(e, stackTrace);
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
  Future<void> addTodo(String title, DateTime? date) async {
    if (title.trim().isEmpty) return;

    state.whenData((todos) async {
      final now = DateTime.now();
      final newTodo = Todo(
        id: _uuid.v4(),
        title: title.trim(),
        completed: false,
        date: date,
        order: _getNextOrder(todos, date),
        createdAt: now,
        updatedAt: now,
      );

      final list = List<Todo>.from(todos[date] ?? []);
      list.add(newTodo);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final nostrService = _ref.read(nostrServiceProvider);
        final eventId = await nostrService.createTodoOnNostr(newTodo);
        
        // eventIdをTodoに設定して状態を更新
        _updateTodoEventId(newTodo.id, date, eventId);
      });
    });
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

    await state.whenData((todos) async {
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
    state.whenData((todos) async {
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

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final nostrService = _ref.read(nostrServiceProvider);
          final eventId = await nostrService.updateTodoOnNostr(list[index]);
          
          // eventIdをTodoに設定して状態を更新
          _updateTodoEventId(todo.id, todo.date, eventId);
        });
      }
    });
  }

  /// Todoのタイトルを更新
  Future<void> updateTodoTitle(String id, DateTime? date, String newTitle) async {
    if (newTitle.trim().isEmpty) return;

    state.whenData((todos) async {
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

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final nostrService = _ref.read(nostrServiceProvider);
          final eventId = await nostrService.updateTodoOnNostr(list[index]);
          
          // eventIdをTodoに設定して状態を更新
          _updateTodoEventId(id, date, eventId);
        });
      }
    });
  }

  /// Todoの完了状態をトグル
  Future<void> toggleTodo(String id, DateTime? date) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final todo = list[index];
        list[index] = todo.copyWith(
          completed: !todo.completed,
          updatedAt: DateTime.now(),
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final nostrService = _ref.read(nostrServiceProvider);
          final eventId = await nostrService.updateTodoOnNostr(list[index]);
          
          // eventIdをTodoに設定して状態を更新
          _updateTodoEventId(id, date, eventId);
        });
      }
    });
  }

  /// Todoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final nostrService = _ref.read(nostrServiceProvider);
        await nostrService.deleteTodoOnNostr(id);
      });
    });
  }

  /// Todoを並び替え
  Future<void> reorderTodo(
    DateTime? date,
    int oldIndex,
    int newIndex,
  ) async {
    state.whenData((todos) async {
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

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final nostrService = _ref.read(nostrServiceProvider);
        for (final todo in list) {
          final eventId = await nostrService.updateTodoOnNostr(todo);
          _updateTodoEventId(todo.id, date, eventId);
        }
      });
    });
  }

  /// Todoを別の日付に移動
  Future<void> moveTodo(String id, DateTime? fromDate, DateTime? toDate) async {
    if (fromDate == toDate) return;

    state.whenData((todos) async {
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

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final nostrService = _ref.read(nostrServiceProvider);
        final eventId = await nostrService.updateTodoOnNostr(movedTodo);
        _updateTodoEventId(movedTodo.id, toDate, eventId);
      });
    });
  }

  /// 次の order 値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) return 0;
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Nostrへの同期処理（リトライ機能付き）
  Future<void> _syncToNostr(Future<void> Function() syncFunction) async {
    if (!_ref.read(nostrInitializedProvider)) {
      // Nostr未初期化の場合はスキップ
      return;
    }

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
    await state.whenData((todos) async {
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

  /// TodoにeventIdを設定して状態を更新
  void _updateTodoEventId(String todoId, DateTime? date, String eventId) {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == todoId);

      if (index != -1) {
        list[index] = list[index].copyWith(eventId: eventId);
        
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

