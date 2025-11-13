import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/group_invitation.dart';
import '../../domain/errors/mls_errors.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../../../../services/logger_service.dart';

/// グループ招待同期のパラメータ
class SyncGroupInvitationsParams {
  final String recipientPublicKey;
  
  const SyncGroupInvitationsParams({
    required this.recipientPublicKey,
  });
}

/// グループ招待同期UseCase
/// 
/// Nostrリレーから未読のグループ招待を取得し、ローカルに保存する。
/// Phase 6.4で実装された`syncGroupInvitations()`をUseCase化。
/// 
/// 招待はNIP-17 Gift Wrapで暗号化されて送信されており、
/// Rust APIがこれを復号化してWelcome Messageを取得する。
class SyncGroupInvitationsUseCase 
    implements UseCase<List<GroupInvitation>, SyncGroupInvitationsParams> {
  final MlsGroupRepository _repository;
  
  const SyncGroupInvitationsUseCase(this._repository);
  
  @override
  Future<Either<Failure, List<GroupInvitation>>> call(
    SyncGroupInvitationsParams params,
  ) async {
    try {
      AppLogger.info('📥 [SyncGroupInvitationsUseCase] Syncing group invitations...');
      
      // Nostrから招待を同期
      final invitationsResult = await _repository.syncGroupInvitations(
        recipientPublicKey: params.recipientPublicKey,
      );
      
      return invitationsResult.fold(
        (failure) {
          AppLogger.error('❌ [SyncGroupInvitationsUseCase] Failed to sync: ${failure.message}');
          return Left(failure);
        },
        (invitations) async {
          AppLogger.info('✅ [SyncGroupInvitationsUseCase] Found ${invitations.length} pending invitations');
          
          if (invitations.isEmpty) {
            return Right(invitations);
          }
          
          // 招待をローカルストレージに保存
          for (final invitation in invitations) {
            final saveResult = await _repository.saveInvitationToLocal(invitation);
            
            saveResult.fold(
              (failure) => AppLogger.warning(
                '⚠️ [SyncGroupInvitationsUseCase] Failed to save invitation ${invitation.groupId}: ${failure.message}',
              ),
              (_) => AppLogger.debug(
                '💾 [SyncGroupInvitationsUseCase] Saved invitation: ${invitation.groupName}',
              ),
            );
          }
          
          AppLogger.info('✅ [SyncGroupInvitationsUseCase] Synced ${invitations.length} group invitations');
          return Right(invitations);
        },
      );
      
    } catch (e, st) {
      AppLogger.error(
        '❌ [SyncGroupInvitationsUseCase] Unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        'グループ招待同期中にエラーが発生しました: $e',
      ));
    }
  }
}

