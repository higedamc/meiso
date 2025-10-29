import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';

/// 日付ごとにグループ化されたTodoリストを管理するProvider
/// 
/// Map<DateTime?, List<Todo>>:
/// - null キー: Someday
/// - DateTime: 特定の日付
final todosProvider =
    StateNotifierProvider<TodosNotifier, AsyncValue<Map<DateTime?, List<Todo>>>>(
  (ref) => TodosNotifier(),
);

class TodosNotifier extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>> {
  TodosNotifier() : super(const AsyncValue.loading()) {
    _initialize();
  }

  final _uuid = const Uuid();

  Future<void> _initialize() async {
    // TODO: Phase2でRust側から同期する
    // 現在はダミーデータで初期化
    await Future.delayed(const Duration(milliseconds: 500));
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    state = AsyncValue.data({
      today: [
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
      ],
      tomorrow: [
        Todo(
          id: _uuid.v4(),
          title: 'Amber統合をテストする',
          completed: false,
          date: tomorrow,
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      null: [
        Todo(
          id: _uuid.v4(),
          title: 'リカーリングタスクを実装する',
          completed: false,
          date: null,
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    });
  }

  /// 新しいTodoを追加
  Future<void> addTodo(String title, DateTime? date) async {
    if (title.trim().isEmpty) return;

    state.whenData((todos) {
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

      // TODO: Phase2でRust側に送信
      // rustBridge.createTodo(newTodo);
    });
  }

  /// Todoを更新
  Future<void> updateTodo(Todo todo) async {
    state.whenData((todos) {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      final index = list.indexWhere((t) => t.id == todo.id);

      if (index != -1) {
        list[index] = todo.copyWith(updatedAt: DateTime.now());
        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });

        // TODO: Phase2でRust側に送信
        // rustBridge.updateTodo(todo);
      }
    });
  }

  /// Todoの完了状態をトグル
  Future<void> toggleTodo(String id, DateTime? date) async {
    state.whenData((todos) {
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

        // TODO: Phase2でRust側に送信
        // rustBridge.updateTodo(list[index]);
      }
    });
  }

  /// Todoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    state.whenData((todos) {
      final list = List<Todo>.from(todos[date] ?? []);
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // TODO: Phase2でRust側に送信
      // rustBridge.deleteTodo(id);
    });
  }

  /// Todoを並び替え
  Future<void> reorderTodo(
    DateTime? date,
    int oldIndex,
    int newIndex,
  ) async {
    state.whenData((todos) {
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

      // TODO: Phase2でRust側に同期
      // rustBridge.updateTodoOrders(list);
    });
  }

  /// Todoを別の日付に移動
  Future<void> moveTodo(String id, DateTime? fromDate, DateTime? toDate) async {
    if (fromDate == toDate) return;

    state.whenData((todos) {
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

      // TODO: Phase2でRust側に送信
      // rustBridge.updateTodo(movedTodo);
    });
  }

  /// 次の order 値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) return 0;
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// 特定の日付のTodoリストを取得するProvider
final todosForDateProvider = Provider.family<List<Todo>, DateTime?>((ref, date) {
  final todosAsync = ref.watch(todosProvider);
  return todosAsync.when(
    data: (todos) => todos[date] ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

