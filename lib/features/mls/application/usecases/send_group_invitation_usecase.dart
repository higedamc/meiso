import 'package:dartz/dartz.dart';
import '../../../core/common/usecase.dart';
import '../../../core/common/failure.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../../../../services/logger_service.dart';
import '../../../../utils/error_handler.dart';

/// グループ招待送信のパラメータ
class SendGroupInvitationParams {
  final String recipientNpub;
  final String groupId;
  final String groupName;
  final String welcomeMessage;
  
  const SendGroupInvitationParams({
    required this.recipientNpub,
    required this.groupId,
    required this.groupName,
    required this.welcomeMessage,
  });
}

/// グループ招待送信の結果
class SendGroupInvitationResult {
  final String? eventId;
  final bool success;
  
  const SendGroupInvitationResult({
    this.eventId,
    required this.success,
  });
}

/// グループ招待送信UseCase
/// 
/// Welcome MessageをNIP-17 Gift Wrapで暗号化して指定されたnpubに送信する。
/// Phase 8.4で実装された招待送信ロジックをUseCase化。
/// 
/// リトライ機能あり（最大2回、1秒間隔）。
class SendGroupInvitationUseCase 
    implements UseCase<SendGroupInvitationResult, SendGroupInvitationParams> {
  final MlsGroupRepository _repository;
  
  const SendGroupInvitationUseCase(this._repository);
  
  @override
  Future<Either<Failure, SendGroupInvitationResult>> call(
    SendGroupInvitationParams params,
  ) async {
    try {
      AppLogger.info(
        '📤 [SendGroupInvitationUseCase] Sending invitation to ${params.recipientNpub.substring(0, 20)}...',
      );
      
      // Phase 8.2.1: リトライ付きで招待送信
      final result = await ErrorHandler.retryWithBackoff<String?>(
        operation: () => _repository.sendGroupInvitation(
          recipientNpub: params.recipientNpub,
          groupId: params.groupId,
          groupName: params.groupName,
          welcomeMessage: params.welcomeMessage,
        ).then((either) => either.fold(
          (failure) => throw Exception(failure.message),
          (eventId) => eventId,
        )),
        operationName: 'sendGroupInvitation',
        maxAttempts: 2,
        initialDelay: const Duration(seconds: 1),
      );
      
      if (result != null) {
        AppLogger.info('  ✅ Invitation sent successfully! Event ID: ${result.substring(0, 16)}...');
        return Right(SendGroupInvitationResult(
          eventId: result,
          success: true,
        ));
      } else {
        AppLogger.warning('  ⚠️ Invitation failed (returned null)');
        return Right(const SendGroupInvitationResult(
          eventId: null,
          success: false,
        ));
      }
      
    } catch (e, st) {
      final appError = ErrorHandler.classify(e, stackTrace: st);
      AppLogger.error(
        '  ❌ Invitation error: ${appError.userMessage}',
        error: e,
        stackTrace: st,
      );
      
      return Right(const SendGroupInvitationResult(
        eventId: null,
        success: false,
      ));
    }
  }
}

