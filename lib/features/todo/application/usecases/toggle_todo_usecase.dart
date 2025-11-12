import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// Todoの完了状態をトグルするUseCase
class ToggleTodoUseCase implements UseCase<Todo, ToggleTodoParams> {
  const ToggleTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(ToggleTodoParams params) async {
    // 既存のTodoを取得
    final todoResult = await _repository.getTodoById(params.todoId);
    if (todoResult.isLeft()) {
      return todoResult;
    }

    final existingTodo = todoResult.getOrElse(() => throw Exception('Unreachable'));

    // 完了状態を反転
    final updatedTodo = existingTodo.copyWith(
      completed: !existingTodo.completed,
      updatedAt: DateTime.now(),
      needsSync: true, // 更新したので同期が必要
    );

    return _repository.updateTodo(updatedTodo);
  }
}

/// ToggleTodoUseCaseのパラメータ
class ToggleTodoParams {
  const ToggleTodoParams({required this.todoId});

  final String todoId;
}

