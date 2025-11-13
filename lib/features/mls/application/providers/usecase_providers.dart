import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../usecases/create_mls_group_usecase.dart';
import '../usecases/send_group_invitation_usecase.dart';
import '../usecases/auto_publish_key_package_usecase.dart';
import '../usecases/sync_group_invitations_usecase.dart';
import '../usecases/accept_group_invitation_usecase.dart';
import '../../domain/value_objects/key_package_publish_policy.dart';

// TODO: Phase D.5でRepository Providerを実装後、以下のproviderを有効化
// import '../../infrastructure/providers/repository_providers.dart';

/// CreateMlsGroupUseCase Provider
/// 
/// Phase D.5でRepository Providerを実装後に有効化
final createMlsGroupUseCaseProvider = Provider<CreateMlsGroupUseCase>((ref) {
  // TODO: Phase D.5で実装
  // final repository = ref.watch(mlsGroupRepositoryProvider);
  // return CreateMlsGroupUseCase(repository);
  throw UnimplementedError('Phase D.5で実装予定');
});

/// SendGroupInvitationUseCase Provider
/// 
/// Phase D.5でRepository Providerを実装後に有効化
final sendGroupInvitationUseCaseProvider = Provider<SendGroupInvitationUseCase>((ref) {
  // TODO: Phase D.5で実装
  // final repository = ref.watch(mlsGroupRepositoryProvider);
  // return SendGroupInvitationUseCase(repository);
  throw UnimplementedError('Phase D.5で実装予定');
});

/// AutoPublishKeyPackageUseCase Provider
/// 
/// Phase D.5でRepository Providerを実装後に有効化
final autoPublishKeyPackageUseCaseProvider = Provider<AutoPublishKeyPackageUseCase>((ref) {
  // TODO: Phase D.5で実装
  // final repository = ref.watch(keyPackageRepositoryProvider);
  // return AutoPublishKeyPackageUseCase(
  //   repository,
  //   policy: const KeyPackagePublishPolicy(),
  // );
  throw UnimplementedError('Phase D.5で実装予定');
});

/// SyncGroupInvitationsUseCase Provider
/// 
/// Phase D.5でRepository Providerを実装後に有効化
final syncGroupInvitationsUseCaseProvider = Provider<SyncGroupInvitationsUseCase>((ref) {
  // TODO: Phase D.5で実装
  // final repository = ref.watch(mlsGroupRepositoryProvider);
  // return SyncGroupInvitationsUseCase(repository);
  throw UnimplementedError('Phase D.5で実装予定');
});

/// AcceptGroupInvitationUseCase Provider
/// 
/// Phase D.5でRepository Providerを実装後に有効化
final acceptGroupInvitationUseCaseProvider = Provider<AcceptGroupInvitationUseCase>((ref) {
  // TODO: Phase D.5で実装
  // final groupRepository = ref.watch(mlsGroupRepositoryProvider);
  // final keyPackageRepository = ref.watch(keyPackageRepositoryProvider);
  // return AcceptGroupInvitationUseCase(groupRepository, keyPackageRepository);
  throw UnimplementedError('Phase D.5で実装予定');
});

/// KeyPackagePublishPolicy Provider
/// 
/// MLS Protocol準拠のKey Package公開ポリシー
final keyPackagePublishPolicyProvider = Provider<KeyPackagePublishPolicy>((ref) {
  return const KeyPackagePublishPolicy();
});

