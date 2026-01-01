import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../services/logger_service.dart';
import '../../../../models/todo.dart'; // Models層のTodoを使用
import '../../domain/repositories/todo_repository.dart';

/// 親タスクの子インスタンス（自動生成されたリカーリングタスク）を削除するUseCase
/// 
/// リカーリングタスクの更新時や再生成時に、既存の子インスタンスを削除します。
class RemoveChildInstancesUseCase
    implements UseCase<Map<DateTime?, List<Todo>>, RemoveChildInstancesParams> {

  RemoveChildInstancesUseCase(this._repository);
  final TodoRepository _repository;

  @override
  Future<Either<Failure, Map<DateTime?, List<Todo>>>> call(
    RemoveChildInstancesParams params,
  ) async {
    try {
      final parentId = params.parentId;
      final todos = Map<DateTime?, List<Todo>>.from(params.currentTodos);

      AppLogger.debug('[RemoveChildInstances] 子インスタンスを削除開始: $parentId');

      var removedCount = 0;
      final removedTodos = <Todo>[];

      // 全ての日付から子インスタンスを削除
      for (final date in todos.keys) {
        final list = List<Todo>.from(todos[date] ?? []);
        final originalLength = list.length;

        // 削除されるタスクを記録（ローカルストレージからも削除する必要があるため）
        final toRemove = list.where((t) => t.parentRecurringId == parentId).toList();
        removedTodos.addAll(toRemove);

        // 子インスタンスを削除
        list.removeWhere((t) => t.parentRecurringId == parentId);

        if (list.length < originalLength) {
          removedCount += originalLength - list.length;
          todos[date] = list;
        }
      }

      AppLogger.debug('[RemoveChildInstances] $removedCount個の子インスタンスを削除しました');

      // ローカルストレージから削除
      if (removedTodos.isNotEmpty) {
        for (final todo in removedTodos) {
          final result = await _repository.deleteTodoFromLocal(todo.id);
          result.fold(
            (failure) {
              AppLogger.warning('[RemoveChildInstances] ⚠️ ローカル削除失敗: ${todo.id} - ${failure.message}');
            },
            (_) {
              AppLogger.debug('[RemoveChildInstances] ローカル削除成功: ${todo.id}');
            },
          );
        }
      }

      return Right(todos);
    } catch (e, stackTrace) {
      AppLogger.error('[RemoveChildInstances] ❌ Failed to remove child instances', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to remove child instances: $e'));
    }
  }
}

/// RemoveChildInstancesUseCaseのパラメータ
class RemoveChildInstancesParams {

  const RemoveChildInstancesParams({
    required this.parentId,
    required this.currentTodos,
  });
  /// 親タスクのID
  final String parentId;

  /// 現在の全Todoマップ
  final Map<DateTime?, List<Todo>> currentTodos;
}

