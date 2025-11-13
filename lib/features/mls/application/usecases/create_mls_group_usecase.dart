import 'package:dartz/dartz.dart';
import '../../../core/common/usecase.dart';
import '../../../core/common/failure.dart';
import '../../domain/entities/mls_group.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../../../../services/logger_service.dart';

/// MLSグループ作成のパラメータ
class CreateMlsGroupParams {
  final String publicKey;
  final String groupId;
  final String groupName;
  final List<String> keyPackages;
  
  const CreateMlsGroupParams({
    required this.publicKey,
    required this.groupId,
    required this.groupName,
    required this.keyPackages,
  });
}

/// MLSグループ作成UseCase
/// 
/// Rust APIを呼び出してMLSグループを作成し、Welcome Messageを生成する。
/// Phase 8.1/8.4で実装された`createMlsGroupList()`の一部をUseCase化。
class CreateMlsGroupUseCase implements UseCase<MlsGroup, CreateMlsGroupParams> {
  final MlsGroupRepository _repository;
  
  const CreateMlsGroupUseCase(this._repository);
  
  @override
  Future<Either<Failure, MlsGroup>> call(CreateMlsGroupParams params) async {
    try {
      AppLogger.info('🔐 [CreateMlsGroupUseCase] Creating MLS group: "${params.groupName}"');
      AppLogger.info('   Group ID: ${params.groupId}');
      AppLogger.info('   Members: ${params.keyPackages.length}');
      
      // MLSグループを作成（Welcome Message生成）
      final welcomeResult = await _repository.createMlsGroup(
        publicKey: params.publicKey,
        groupId: params.groupId,
        groupName: params.groupName,
        keyPackages: params.keyPackages,
      );
      
      return welcomeResult.fold(
        (failure) {
          AppLogger.error('❌ [CreateMlsGroupUseCase] Failed to create MLS group: ${failure.message}');
          return Left(failure);
        },
        (welcomeMessage) {
          AppLogger.info('✅ [CreateMlsGroupUseCase] MLS group created successfully');
          AppLogger.debug('   Welcome Message size: ${welcomeMessage.length} bytes');
          
          // MLSグループエンティティを作成
          final now = DateTime.now();
          final mlsGroup = MlsGroup(
            groupId: params.groupId,
            groupName: params.groupName,
            memberPubkeys: [], // メンバーリストは後で更新
            welcomeMessage: welcomeMessage,
            createdAt: now,
            updatedAt: now,
          );
          
          return Right(mlsGroup);
        },
      );
      
    } catch (e, st) {
      AppLogger.error(
        '❌ [CreateMlsGroupUseCase] Unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(Failure('MLSグループ作成中にエラーが発生しました: $e'));
    }
  }
}

