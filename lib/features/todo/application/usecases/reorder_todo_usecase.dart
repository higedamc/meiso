import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// Todoの順序を変更するUseCase
/// 
/// 同じリスト内でTodoの位置を変更する
class ReorderTodoUseCase implements UseCase<Todo, ReorderTodoParams> {
  const ReorderTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(ReorderTodoParams params) async {
    // 既存のTodoを取得
    final todoResult = await _repository.getTodoById(params.todoId);
    if (todoResult.isLeft()) {
      return todoResult;
    }

    final existingTodo = todoResult.getOrElse(() => throw Exception('Unreachable'));

    // 新しいorderで更新
    final updatedTodo = existingTodo.copyWith(
      order: params.newOrder,
      updatedAt: DateTime.now(),
      needsSync: true, // 更新したので同期が必要
    );

    return _repository.updateTodo(updatedTodo);
  }
}

/// ReorderTodoUseCaseのパラメータ
class ReorderTodoParams {
  const ReorderTodoParams({
    required this.todoId,
    required this.newOrder,
  });

  final String todoId;
  final int newOrder;
}

