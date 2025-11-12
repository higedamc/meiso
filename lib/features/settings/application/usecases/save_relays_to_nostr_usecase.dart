import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// リレーリストをNostr（Kind 10002）に保存するUseCase
/// 
/// 【暫定実装】複雑なNostr/Amber連携は互換レイヤーから旧Providerに委譲
class SaveRelaysToNostrUseCase implements UseCase<void, List<String>> {
  const SaveRelaysToNostrUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, void>> call(List<String> relays) {
    return repository.saveRelaysToNostr(relays);
  }
}

