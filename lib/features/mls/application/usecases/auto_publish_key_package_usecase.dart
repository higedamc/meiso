import 'package:dartz/dartz.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../domain/errors/mls_errors.dart';
import '../../domain/repositories/key_package_repository.dart';
import '../../domain/value_objects/key_package_publish_policy.dart';
import '../../../../services/logger_service.dart';

/// Key Package自動公開のパラメータ
class AutoPublishKeyPackageParams {
  final String publicKey;
  final KeyPackagePublishTrigger trigger;
  final bool forceUpload;
  
  const AutoPublishKeyPackageParams({
    required this.publicKey,
    required this.trigger,
    this.forceUpload = false,
  });
}

/// Key Package自動公開UseCase
/// 
/// KeyPackagePublishPolicyに基づいてKey Packageを自動公開する。
/// MLS Protocol準拠（RFC 9420）の公開ポリシーを適用。
/// 
/// 公開タイミング:
/// - アプリ起動時: 7日経過していれば公開
/// - 招待受諾時: 強制公開（forceUpload=true）
/// - グループメッセージ送信前: 3日経過していれば公開
class AutoPublishKeyPackageUseCase 
    implements UseCase<String?, AutoPublishKeyPackageParams> {
  final KeyPackageRepository _repository;
  final KeyPackagePublishPolicy _policy;
  
  const AutoPublishKeyPackageUseCase(
    this._repository, {
    KeyPackagePublishPolicy? policy,
  }) : _policy = policy ?? const KeyPackagePublishPolicy();
  
  @override
  Future<Either<Failure, String?>> call(AutoPublishKeyPackageParams params) async {
    try {
      AppLogger.info(
        '🔑 [AutoPublishKeyPackageUseCase] Checking Key Package publish status...',
      );
      AppLogger.debug('   Trigger: ${params.trigger}');
      AppLogger.debug('   Force upload: ${params.forceUpload}');
      
      // 1. 最後の公開時刻を取得
      final lastPublishedResult = await _repository.loadLastPublishTime();
      
      final lastPublished = lastPublishedResult.fold(
        (failure) {
          AppLogger.warning('⚠️ Failed to load last publish time: ${failure.message}');
          return null;
        },
        (dateTime) => dateTime,
      );
      
      if (lastPublished != null) {
        final elapsed = DateTime.now().difference(lastPublished);
        AppLogger.debug('   Last published: ${elapsed.inHours} hours ago');
      } else {
        AppLogger.debug('   Last published: Never');
      }
      
      // 2. ポリシーで判定
      if (!_policy.shouldPublish(
        trigger: params.trigger,
        lastPublished: lastPublished,
        forceUpload: params.forceUpload,
      )) {
        AppLogger.info('⏭️  [AutoPublishKeyPackageUseCase] Key Package is up-to-date, skipping publish');
        return Right(null); // 公開不要
      }
      
      AppLogger.info('📦 [AutoPublishKeyPackageUseCase] Publishing Key Package...');
      
      // 3. Key Package生成
      final keyPackageResult = await _repository.generateKeyPackage(
        publicKey: params.publicKey,
      );
      
      return keyPackageResult.fold(
        (failure) {
          AppLogger.error('❌ [AutoPublishKeyPackageUseCase] Failed to generate Key Package: ${failure.message}');
          return Left(failure);
        },
        (keyPackage) async {
          // 4. Key Package公開
          final publishResult = await _repository.publishKeyPackage(keyPackage);
          
          return publishResult.fold(
            (failure) {
              AppLogger.error('❌ [AutoPublishKeyPackageUseCase] Failed to publish Key Package: ${failure.message}');
              return Left(failure);
            },
            (eventId) async {
              // 5. 公開時刻を保存
              final now = DateTime.now();
              final saveResult = await _repository.saveLastPublishTime(now);
              
              saveResult.fold(
                (failure) => AppLogger.warning('⚠️ Failed to save last publish time: ${failure.message}'),
                (_) => AppLogger.debug('   Last publish time saved'),
              );
              
              AppLogger.info('✅ [AutoPublishKeyPackageUseCase] Key Package published successfully');
              AppLogger.debug('   Event ID: ${eventId.substring(0, 16)}...');
              
              return Right(eventId);
            },
          );
        },
      );
      
    } catch (e, st) {
      AppLogger.error(
        '❌ [AutoPublishKeyPackageUseCase] Unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(KeyPackageFailure(
        MlsError.unknown,
        'Key Package自動公開中にエラーが発生しました: $e',
      ));
    }
  }
}

