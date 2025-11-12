import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/custom_list_repository.dart';
import '../../domain/value_objects/list_name.dart';

/// カスタムリストを作成するUseCase
class CreateCustomListUseCase implements UseCase<CustomList, CreateCustomListParams> {
  const CreateCustomListUseCase(this.repository);
  
  final CustomListRepository repository;
  
  @override
  Future<Either<Failure, CustomList>> call(CreateCustomListParams params) async {
    // 1. バリデーション
    final nameResult = ListName.create(params.name);
    
    // バリデーションエラーの場合は早期リターン
    if (nameResult.isLeft()) {
      return nameResult.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected Right'),
      );
    }
    
    final name = nameResult.getOrElse(() => throw Exception('Unexpected Left'));
    
    // 2. CustomListエンティティ作成
    final now = DateTime.now();
    final customList = CustomList(
      id: CustomList.generateIdFromName(params.name),
      name: name,
      order: params.order,
      createdAt: now,
      updatedAt: now,
    );
    
    // 3. リポジトリに保存
    return repository.createCustomList(customList);
  }
}

class CreateCustomListParams {
  const CreateCustomListParams({
    required this.name,
    required this.order,
  });
  
  final String name;
  final int order;
}

