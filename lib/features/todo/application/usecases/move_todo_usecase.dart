import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/value_objects/todo_date.dart';

/// Todoを別の日付やリストに移動するUseCase
/// 
/// date, customList, positionを一度に更新する
class MoveTodoUseCase implements UseCase<Todo, MoveTodoParams> {
  const MoveTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(MoveTodoParams params) async {
    // 既存のTodoを取得
    final todoResult = await _repository.getTodoById(params.todoId);
    if (todoResult.isLeft()) {
      return todoResult;
    }

    final existingTodo = todoResult.getOrElse(() => throw Exception('Unreachable'));

    // 移動先の情報で更新
    final updatedTodo = existingTodo.copyWith(
      date: params.newDate ?? existingTodo.date,
      customListId: params.newCustomListId ?? existingTodo.customListId,
      order: params.newOrder ?? existingTodo.order,
      updatedAt: DateTime.now(),
      needsSync: true, // 更新したので同期が必要
    );

    return _repository.updateTodo(updatedTodo);
  }
}

/// MoveTodoUseCaseのパラメータ
class MoveTodoParams {
  const MoveTodoParams({
    required this.todoId,
    this.newDate,
    this.newCustomListId,
    this.newOrder,
  });

  final String todoId;
  final TodoDate? newDate;
  final String? newCustomListId;
  final int? newOrder;
}

