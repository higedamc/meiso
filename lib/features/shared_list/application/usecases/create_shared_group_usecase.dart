import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/shared_group_credentials.dart';
import '../../domain/repositories/shared_list_repository.dart';

class CreateSharedGroupParams {
  const CreateSharedGroupParams({
    required this.groupName,
    this.groupId,
  });

  final String groupName;
  final String? groupId;
}

class CreateSharedGroupUseCase
    implements UseCase<SharedGroupCredentials, CreateSharedGroupParams> {
  const CreateSharedGroupUseCase(this._repository);
  final SharedListRepository _repository;

  @override
  Future<Either<Failure, SharedGroupCredentials>> call(
    CreateSharedGroupParams params,
  ) {
    final groupId = params.groupId ?? const Uuid().v4();
    return _repository.createSharedGroup(
      groupId: groupId,
      groupName: params.groupName.trim().toUpperCase(),
    );
  }
}
