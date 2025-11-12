import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';

/// TodoをNostrに同期するUseCase
class SyncToNostrUseCase implements UseCase<void, SyncToNostrParams> {
  const SyncToNostrUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Either<Failure, void>> call(SyncToNostrParams params) async {
    return _repository.syncToNostr(params.todo);
  }
}

/// SyncToNostrUseCaseのパラメータ
class SyncToNostrParams {
  const SyncToNostrParams({required this.todo});

  final Todo todo;
}

