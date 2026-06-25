import 'package:dartz/dartz.dart';

import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/repositories/shared_list_repository.dart';

class SendSharedInvitationParams {
  const SendSharedInvitationParams({
    required this.recipientNpub,
    required this.groupId,
    required this.groupName,
    required this.groupNsecHex,
    this.keyEpoch = 1,
  });

  final String recipientNpub;
  final String groupId;
  final String groupName;
  final String groupNsecHex;
  final int keyEpoch;
}

class SendSharedInvitationUseCase
    implements UseCase<String, SendSharedInvitationParams> {
  const SendSharedInvitationUseCase(this._repository);
  final SharedListRepository _repository;

  @override
  Future<Either<Failure, String>> call(SendSharedInvitationParams params) {
    return _repository.sendInvitation(
      recipientNpub: params.recipientNpub,
      groupId: params.groupId,
      groupName: params.groupName,
      groupNsecHex: params.groupNsecHex,
      keyEpoch: params.keyEpoch,
    );
  }
}
