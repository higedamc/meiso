import 'package:dartz/dartz.dart';

import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/shared_invitation.dart';
import '../../domain/repositories/shared_list_repository.dart';

class SyncSharedInvitationsParams {
  const SyncSharedInvitationsParams({required this.recipientPublicKeyHex});
  final String recipientPublicKeyHex;
}

class SyncSharedInvitationsUseCase
    implements UseCase<List<SharedInvitation>, SyncSharedInvitationsParams> {
  const SyncSharedInvitationsUseCase(this._repository);
  final SharedListRepository _repository;

  @override
  Future<Either<Failure, List<SharedInvitation>>> call(
    SyncSharedInvitationsParams params,
  ) {
    return _repository.syncInvitations(
      recipientPublicKeyHex: params.recipientPublicKeyHex,
    );
  }
}
