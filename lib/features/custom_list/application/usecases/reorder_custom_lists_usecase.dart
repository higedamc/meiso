import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';

/// カスタムリストを並び替えるUseCase
class ReorderCustomListsUseCase implements UseCase<List<CustomList>, List<CustomList>> {
  const ReorderCustomListsUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, List<CustomList>>> call(List<CustomList> lists) {
    return repository.reorderCustomLists(lists);
  }
}

