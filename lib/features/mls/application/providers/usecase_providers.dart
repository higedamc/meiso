import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../usecases/create_mls_group_usecase.dart';
import '../usecases/send_group_invitation_usecase.dart';
import '../usecases/auto_publish_key_package_usecase.dart';
import '../usecases/sync_group_invitations_usecase.dart';
import '../usecases/accept_group_invitation_usecase.dart';
import '../../domain/value_objects/key_package_publish_policy.dart';
import '../../infrastructure/providers/repository_providers.dart';

/// CreateMlsGroupUseCase Provider
/// 
/// ✅ Phase D.5.2で実装完了
final createMlsGroupUseCaseProvider = Provider<CreateMlsGroupUseCase>((ref) {
  final repository = ref.watch(mlsGroupRepositoryProvider);
  return CreateMlsGroupUseCase(repository);
});

/// SendGroupInvitationUseCase Provider
/// 
/// ✅ Phase D.5.2で実装完了
final sendGroupInvitationUseCaseProvider = Provider<SendGroupInvitationUseCase>((ref) {
  final repository = ref.watch(mlsGroupRepositoryProvider);
  return SendGroupInvitationUseCase(repository);
});

/// AutoPublishKeyPackageUseCase Provider
/// 
/// ✅ Phase D.5.1で実装完了
final autoPublishKeyPackageUseCaseProvider = Provider<AutoPublishKeyPackageUseCase>((ref) {
  final repository = ref.watch(keyPackageRepositoryProvider);
  return AutoPublishKeyPackageUseCase(
    repository,
    policy: const KeyPackagePublishPolicy(),
  );
});

/// SyncGroupInvitationsUseCase Provider
/// 
/// ✅ Phase D.5.2で実装完了
final syncGroupInvitationsUseCaseProvider = Provider<SyncGroupInvitationsUseCase>((ref) {
  final repository = ref.watch(mlsGroupRepositoryProvider);
  return SyncGroupInvitationsUseCase(repository);
});

/// AcceptGroupInvitationUseCase Provider
/// 
/// ✅ Phase D.5.2で実装完了
final acceptGroupInvitationUseCaseProvider = Provider<AcceptGroupInvitationUseCase>((ref) {
  final groupRepository = ref.watch(mlsGroupRepositoryProvider);
  final keyPackageRepository = ref.watch(keyPackageRepositoryProvider);
  return AcceptGroupInvitationUseCase(groupRepository, keyPackageRepository);
});

/// KeyPackagePublishPolicy Provider
/// 
/// MLS Protocol準拠のKey Package公開ポリシー
final keyPackagePublishPolicyProvider = Provider<KeyPackagePublishPolicy>((ref) {
  return const KeyPackagePublishPolicy();
});

