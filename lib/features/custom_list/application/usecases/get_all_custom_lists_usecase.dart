import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';

/// 全てのカスタムリストを取得するUseCase
class GetAllCustomListsUseCase implements UseCase<List<CustomList>, NoParams> {
  const GetAllCustomListsUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, List<CustomList>>> call(NoParams params) {
    return repository.getAllCustomLists();
  }
}

