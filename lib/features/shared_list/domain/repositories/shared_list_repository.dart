import 'package:dartz/dartz.dart';

import '../../../../core/common/failure.dart';
import '../entities/shared_group_credentials.dart';
import '../entities/shared_invitation.dart';

abstract class SharedListRepository {
  Future<Either<Failure, SharedGroupCredentials>> createSharedGroup({
    required String groupId,
    required String groupName,
  });

  Future<Either<Failure, String>> sendInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    required String groupNsecHex,
    required int keyEpoch,
  });

  Future<Either<Failure, List<SharedInvitation>>> syncInvitations({
    required String recipientPublicKeyHex,
  });

  Future<Either<Failure, SharedGroupCredentials>> acceptInvitation({
    required SharedInvitation invitation,
    required String recipientPublicKeyHex,
    String? recipientNsecHex,
  });

  Future<Either<Failure, SharedGroupCredentials?>> loadCredentials({
    required String groupId,
  });

  Future<Either<Failure, String>> publishSignedTaskEvent({
    required String groupNsecHex,
    required String taskJson,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchTaskEvents({
    required String groupNpubHex,
    required DateTime since,
  });
}
