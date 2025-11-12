import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';

/// Nostrからカスタムリストを同期するUseCase
class SyncCustomListsFromNostrUseCase implements UseCase<List<CustomList>, List<String>> {
  const SyncCustomListsFromNostrUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, List<CustomList>>> call(List<String> nostrListNames) async {
    // 1. Nostrから同期
    final syncResult = await repository.syncFromNostr(nostrListNames);
    
    return syncResult.fold(
      (failure) => Left(failure),
      (syncedLists) async {
        // 2. リストが空の場合はデフォルトリストを作成
        if (syncedLists.isEmpty) {
          return repository.createDefaultListsIfEmpty();
        }
        return Right(syncedLists);
      },
    );
  }
}

