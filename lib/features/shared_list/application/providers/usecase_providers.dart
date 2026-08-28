import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/providers/repository_providers.dart';
import '../usecases/accept_shared_invitation_usecase.dart';
import '../usecases/create_shared_group_usecase.dart';
import '../usecases/send_shared_invitation_usecase.dart';
import '../usecases/sync_shared_invitations_usecase.dart';

final createSharedGroupUseCaseProvider = Provider<CreateSharedGroupUseCase>((ref) {
  return CreateSharedGroupUseCase(ref.watch(sharedListRepositoryProvider));
});

final sendSharedInvitationUseCaseProvider =
    Provider<SendSharedInvitationUseCase>((ref) {
  return SendSharedInvitationUseCase(ref.watch(sharedListRepositoryProvider));
});

final syncSharedInvitationsUseCaseProvider =
    Provider<SyncSharedInvitationsUseCase>((ref) {
  return SyncSharedInvitationsUseCase(ref.watch(sharedListRepositoryProvider));
});

final acceptSharedInvitationUseCaseProvider =
    Provider<AcceptSharedInvitationUseCase>((ref) {
  return AcceptSharedInvitationUseCase(ref.watch(sharedListRepositoryProvider));
});
