import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// 特定のTodoをIDで取得するUseCase
class GetTodoByIdUseCase implements UseCase<Todo, GetTodoByIdParams> {
  const GetTodoByIdUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, Todo>> call(GetTodoByIdParams params) async {
    return _repository.getTodoById(params.todoId);
  }
}

/// GetTodoByIdUseCaseのパラメータ
class GetTodoByIdParams {
  const GetTodoByIdParams({required this.todoId});

  final String todoId;
}

