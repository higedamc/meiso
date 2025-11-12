import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// NostrからTodoを同期するUseCase
class SyncFromNostrUseCase implements UseCase<List<Todo>, NoParams> {
  const SyncFromNostrUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, List<Todo>>> call(NoParams params) async {
    return _repository.syncFromNostr();
  }
}

