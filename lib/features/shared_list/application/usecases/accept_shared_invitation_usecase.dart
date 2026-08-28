import 'package:dartz/dartz.dart';

import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/shared_group_credentials.dart';
import '../../domain/entities/shared_invitation.dart';
import '../../domain/repositories/shared_list_repository.dart';

class AcceptSharedInvitationParams {
  const AcceptSharedInvitationParams({
    required this.invitation,
    required this.recipientPublicKeyHex,
    this.recipientNsecHex,
  });

  final SharedInvitation invitation;
  final String recipientPublicKeyHex;
  final String? recipientNsecHex;
}

class AcceptSharedInvitationUseCase
    implements UseCase<SharedGroupCredentials, AcceptSharedInvitationParams> {
  const AcceptSharedInvitationUseCase(this._repository);
  final SharedListRepository _repository;

  @override
  Future<Either<Failure, SharedGroupCredentials>> call(
    AcceptSharedInvitationParams params,
  ) {
    return _repository.acceptInvitation(
      invitation: params.invitation,
      recipientPublicKeyHex: params.recipientPublicKeyHex,
      recipientNsecHex: params.recipientNsecHex,
    );
  }
}
