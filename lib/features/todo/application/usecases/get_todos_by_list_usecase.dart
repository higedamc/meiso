import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// カスタムリストでフィルタリングしたTodoを取得するUseCase
class GetTodosByListUseCase implements UseCase<List<Todo>, GetTodosByListParams> {
  const GetTodosByListUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, List<Todo>>> call(GetTodosByListParams params) async {
    return _repository.getTodosByCustomList(params.customListId);
  }
}

/// GetTodosByListUseCaseのパラメータ
class GetTodosByListParams {
  const GetTodosByListParams({required this.customListId});

  final String customListId;
}

