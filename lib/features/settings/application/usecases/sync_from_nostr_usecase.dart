import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// Nostrから設定を同期するUseCase（NIP-78 Kind 30078）
/// 
/// 【暫定実装】複雑なNostr/Amber連携は互換レイヤーから旧Providerに委譲
class SyncFromNostrUseCase implements UseCase<AppSettings, NoParams> {
  const SyncFromNostrUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) {
    return repository.syncFromNostr();
  }
}

