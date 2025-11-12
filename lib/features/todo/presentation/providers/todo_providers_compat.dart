import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/todo.dart' as models;
import '../../../../models/recurrence_pattern.dart' show RecurrencePattern;
import '../../../../providers/todos_provider.dart' as legacy;
import '../../domain/entities/todo.dart' as domain;
import '../../domain/value_objects/todo_date.dart';
import '../view_models/todo_list_view_model.dart';
import 'todo_providers.dart';

/// 既存UIとの互換性レイヤー
/// 
/// TodoListStateをAsyncValue<Map<DateTime?, List<Todo>>>に変換し、
/// 既存のtodosProviderと同じインターフェースを提供する

// ============================================================================
// Todo変換ヘルパー
// ============================================================================

/// Domain層のTodoをModel層のTodoに変換
models.Todo _convertDomainToModel(domain.Todo domainTodo) {
  return models.Todo(
    id: domainTodo.id,
    title: domainTodo.title.value,
    completed: domainTodo.completed,
    createdAt: domainTodo.createdAt,
    updatedAt: domainTodo.updatedAt,
    date: domainTodo.date?.value,
    customListId: domainTodo.customListId,
    order: domainTodo.order,
    eventId: domainTodo.eventId,
    linkPreview: domainTodo.linkPreview,
    recurrence: domainTodo.recurrence,
    parentRecurringId: domainTodo.parentRecurringId,
    needsSync: domainTodo.needsSync,
  );
}

// ============================================================================
// 互換性Provider：todosProvider
// ============================================================================

/// 既存のtodosProviderと互換性のあるProvider
///
/// TodoListStateをAsyncValue<Map<DateTime?, List<Todo>>>に変換
/// 既存のUIコードをほぼ変更せずに新アーキテクチャを使用可能
final todosProviderCompat = Provider<AsyncValue<Map<DateTime?, List<models.Todo>>>>((ref) {
  final todoListState = ref.watch(todoListViewModelProvider);
  
  return todoListState.when(
    initial: () => const AsyncValue.loading(),
    loading: () => const AsyncValue.loading(),
    loaded: (groupedTodos) {
      // domain.TodoをModels.Todoに変換
      final Map<DateTime?, List<models.Todo>> converted = {};
      for (final entry in groupedTodos.entries) {
        converted[entry.key] = entry.value
            .map((domainTodo) => _convertDomainToModel(domainTodo))
            .toList();
      }
      return AsyncValue.data(converted);
    },
    error: (failure) => AsyncValue.error(
      failure,
      StackTrace.current,
    ),
  );
});

/// 既存の.notifier アクセス用の互換ラッパー
/// 
/// 使用例: ref.read(todosProviderNotifierCompat).addTodoCompat(...)
final todosProviderNotifierCompat = Provider<TodoListViewModelCompat>((ref) {
  final viewModel = ref.watch(todoListViewModelProvider.notifier);
  return TodoListViewModelCompat(viewModel, ref);
});

/// TodoListViewModelをラップして互換メソッドを提供
class TodoListViewModelCompat {
  TodoListViewModelCompat(this._viewModel, this._ref);
  
  final TodoListViewModel _viewModel;
  final Ref _ref;
  
  /// 既存のaddTodo互換メソッド
  Future<void> addTodo(
    String title,
    DateTime? date, {
    String? customListId,
  }) async {
    await _viewModel.createTodo(
      title: title,
      date: date != null ? TodoDate.dateOnly(date) : null,
      customListId: customListId,
    );
  }
  
  /// 既存のtoggleTodo互換メソッド
  Future<void> toggleTodo(String id, DateTime? date) async {
    await _viewModel.toggleTodo(id);
  }
  
  /// 既存のdeleteTodo互換メソッド
  Future<void> deleteTodo(String id, DateTime? date) async {
    await _viewModel.deleteTodo(id);
  }
  
  /// 既存のupdateTodoTitle互換メソッド
  Future<void> updateTodoTitle(
    String id,
    DateTime? date,
    String newTitle,
  ) async {
    await _viewModel.updateTodo(
      todoId: id,
      title: newTitle,
    );
  }
  
  /// 既存のupdateTodoCustomListId互換メソッド
  Future<void> updateTodoCustomListId(
    String id,
    DateTime? date,
    String? customListId,
  ) async {
    await _viewModel.updateTodo(
      todoId: id,
      customListId: customListId,
    );
  }
  
  /// 既存のreorderTodo互換メソッド
  Future<void> reorderTodo(
    String id,
    DateTime? oldDate,
    DateTime? newDate,
    int newOrder,
  ) async {
    if (oldDate != newDate) {
      await _viewModel.moveTodo(
        todoId: id,
        newDate: newDate != null ? TodoDate.dateOnly(newDate) : null,
        newOrder: newOrder,
      );
    } else {
      await _viewModel.reorderTodo(
        todoId: id,
        newOrder: newOrder,
      );
    }
  }
  
  /// 既存のmoveTodo互換メソッド
  Future<void> moveTodo(
    String id,
    DateTime? fromDate,
    DateTime? toDate,
  ) async {
    await _viewModel.moveTodo(
      todoId: id,
      newDate: toDate != null ? TodoDate.dateOnly(toDate) : null,
    );
  }
  
  /// 既存のsyncFromNostr互換メソッド
  Future<void> syncFromNostr() async {
    await _viewModel.syncFromNostr();
  }
  
  /// その他の必要なメソッド
  Future<void> addTodoWithData(models.Todo todo) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).addTodoWithData(todo);
  }
  
  Future<void> updateTodo(models.Todo todo) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).updateTodo(todo);
  }
  
  Future<void> removeLinkPreview(String id, DateTime? date) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).removeLinkPreview(id, date);
  }
  
  Future<void> deleteRecurringInstance(String id, DateTime? date) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).deleteRecurringInstance(id, date);
  }
  
  Future<void> deleteAllRecurringInstances(String id, DateTime? date) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).deleteAllRecurringInstances(id, date);
  }
  
  Future<void> updateTodoWithRecurrence(
    String id,
    DateTime? date,
    String newTitle,
    RecurrencePattern? recurrence,
  ) async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).updateTodoWithRecurrence(
      id,
      date,
      newTitle,
      recurrence,
    );
  }
  
  Future<void> manualSyncToNostr() async {
    // 【暫定実装】旧Providerの実装を呼び出す
    await _ref.read(legacy.todosProvider.notifier).manualSyncToNostr();
  }
}

// ============================================================================
// 日付別Todoリスト Provider
// ============================================================================

/// 特定の日付のTodoリストを取得するProvider
/// 未完了タスクを上、完了済みタスクを下に表示
final todosForDateProvider = Provider.family<List<models.Todo>, DateTime?>((ref, date) {
  final todosAsync = ref.watch(todosProviderCompat);
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

