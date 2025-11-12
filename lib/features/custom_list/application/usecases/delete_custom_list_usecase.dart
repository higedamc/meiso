import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/repositories/custom_list_repository.dart';

/// カスタムリストを削除するUseCase
class DeleteCustomListUseCase implements UseCase<void, String> {
  const DeleteCustomListUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, void>> call(String id) {
    return repository.deleteCustomList(id);
  }
}

