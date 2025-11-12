import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/value_objects/todo_date.dart';

/// 日付でフィルタリングしたTodoを取得するUseCase
class GetTodosByDateUseCase implements UseCase<List<Todo>, GetTodosByDateParams> {
  const GetTodosByDateUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, List<Todo>>> call(GetTodosByDateParams params) async {
    // TodoDateをDateTimeに変換
    final dateTime = params.date?.value;
    return _repository.getTodosByDate(dateTime);
  }
}

/// GetTodosByDateUseCaseのパラメータ
class GetTodosByDateParams {
  const GetTodosByDateParams({required this.date});

  final TodoDate date;
}

