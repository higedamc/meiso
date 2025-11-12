import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/repositories/todo_repository.dart';

/// Todoを削除するUseCase
class DeleteTodoUseCase implements UseCase<void, DeleteTodoParams> {
  const DeleteTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, void>> call(DeleteTodoParams params) async {
    return _repository.deleteTodo(params.todoId);
  }
}

/// DeleteTodoUseCaseのパラメータ
class DeleteTodoParams {
  const DeleteTodoParams({required this.todoId});

  final String todoId;
}

