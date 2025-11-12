import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../domain/value_objects/list_name.dart';

/// カスタムリストを更新するUseCase
class UpdateCustomListUseCase implements UseCase<CustomList, UpdateCustomListParams> {
  const UpdateCustomListUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, CustomList>> call(UpdateCustomListParams params) async {
    // 既存のCustomListを取得
    final result = await repository.getCustomListById(params.id);
    
    return result.fold(
      (failure) => Left(failure),
      (existingList) async {
        // 名前の変更がある場合はバリデーション
        ListName? newName;
        if (params.name != null) {
          final nameResult = ListName.create(params.name!);
          if (nameResult.isLeft()) {
            return nameResult.fold(
              (failure) => Left(failure),
              (_) => throw Exception('Unexpected Right'),
            );
          }
          newName = nameResult.getOrElse(() => throw Exception('Unexpected Left'));
        }
        
        // 更新されたCustomListを作成
        final updatedList = CustomList(
          id: existingList.id,
          name: newName ?? existingList.name,
          order: params.order ?? existingList.order,
          createdAt: existingList.createdAt,
          updatedAt: DateTime.now(),
        );
        
        return repository.updateCustomList(updatedList);
      },
    );
  }
}

class UpdateCustomListParams {
  const UpdateCustomListParams({
    required this.id,
    this.name,
    this.order,
  });
  
  final String id;
  final String? name;
  final int? order;
}

