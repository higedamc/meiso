import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/mls_group.dart';
import '../../domain/errors/mls_errors.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../../domain/repositories/key_package_repository.dart';
import '../../domain/value_objects/key_package_publish_policy.dart';
import '../../../../services/logger_service.dart';
import 'auto_publish_key_package_usecase.dart';

/// グループ招待受諾のパラメータ
class AcceptGroupInvitationParams {
  
  const AcceptGroupInvitationParams({
    required this.publicKey,
    required this.groupId,
    required this.welcomeMessage,
  });
  final String publicKey;
  final String groupId;
  final String welcomeMessage;
}

/// グループ招待受諾UseCase
/// 
/// Welcome Messageを処理してMLSグループに参加する。
/// 招待受諾後、Key Packageを強制公開（forceUpload=true）して
/// Forward Secrecyを確保する。
/// 
/// 処理の流れ：
/// 1. Welcome Messageを処理してグループに参加
/// 2. 招待をローカルストレージから削除
/// 3. Key Packageを強制公開（MLS Protocol推奨）
class AcceptGroupInvitationUseCase 
    implements UseCase<MlsGroup, AcceptGroupInvitationParams> {
  
  const AcceptGroupInvitationUseCase(
    this._groupRepository,
    this._keyPackageRepository,
  );
  final MlsGroupRepository _groupRepository;
  final KeyPackageRepository _keyPackageRepository;
  
  @override
  Future<Either<Failure, MlsGroup>> call(
    AcceptGroupInvitationParams params,
  ) async {
    try {
      AppLogger.info('🎉 [AcceptGroupInvitationUseCase] Accepting invitation for group: ${params.groupId}');
      
      // 1. Welcome Messageを処理してグループに参加
      final acceptResult = await _groupRepository.acceptGroupInvitation(
        publicKey: params.publicKey,
        groupId: params.groupId,
        welcomeMessage: params.welcomeMessage,
      );
      
      return acceptResult.fold(
        (failure) {
          AppLogger.error('❌ [AcceptGroupInvitationUseCase] Failed to accept invitation: ${failure.message}');
          return Left(failure);
        },
        (mlsGroup) async {
          AppLogger.info('✅ [AcceptGroupInvitationUseCase] Successfully joined group: ${mlsGroup.groupName}');
          
          // 2. MLSグループをローカルストレージに保存
          final saveGroupResult = await _groupRepository.saveMlsGroupToLocal(mlsGroup);
          
          saveGroupResult.fold(
            (failure) => AppLogger.warning('⚠️ Failed to save MLS group: ${failure.message}'),
            (_) => AppLogger.debug('💾 MLS group saved locally'),
          );
          
          // 3. 招待をローカルストレージから削除
          final deleteInvitationResult = await _groupRepository.deleteInvitationFromLocal(
            groupId: params.groupId,
          );
          
          deleteInvitationResult.fold(
            (failure) => AppLogger.warning('⚠️ Failed to delete invitation: ${failure.message}'),
            (_) => AppLogger.debug('🗑️  Invitation deleted'),
          );
          
          // 4. Key Packageを強制公開（Forward Secrecy確保）
          // MLS Protocol推奨: 招待受諾時は即座にKey Packageを更新
          AppLogger.info('🔑 [AcceptGroupInvitationUseCase] Publishing Key Package (forceUpload)...');
          
          final publishResult = await _autoPublishKeyPackage(params.publicKey);
          
          publishResult.fold(
            (failure) => AppLogger.warning(
              '⚠️ [AcceptGroupInvitationUseCase] Failed to publish Key Package: ${failure.message}',
            ),
            (eventId) {
              if (eventId != null) {
                AppLogger.info('✅ [AcceptGroupInvitationUseCase] Key Package published: ${eventId.substring(0, 16)}...');
              } else {
                AppLogger.debug('   Key Package was already up-to-date');
              }
            },
          );
          
          return Right(mlsGroup);
        },
      );
      
    } catch (e, st) {
      AppLogger.error(
        '❌ [AcceptGroupInvitationUseCase] Unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待受諾中にエラーが発生しました: $e',
      ));
    }
  }
  
  /// Key Packageを自動公開（内部ヘルパー）
  Future<Either<Failure, String?>> _autoPublishKeyPackage(String publicKey) async {
    // AutoPublishKeyPackageUseCaseを直接呼び出し
    final useCase = AutoPublishKeyPackageUseCase(_keyPackageRepository);
    
    return useCase(AutoPublishKeyPackageParams(
      publicKey: publicKey,
      trigger: KeyPackagePublishTrigger.invitationAccept,
      forceUpload: true, // 招待受諾時は強制公開
    ));
  }
}

