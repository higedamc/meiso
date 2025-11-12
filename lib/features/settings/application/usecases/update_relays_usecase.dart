import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// リレーリストを更新するUseCase（ローカルのみ）
class UpdateRelaysUseCase implements UseCase<AppSettings, List<String>> {
  const UpdateRelaysUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(List<String> relays) {
    return repository.updateRelays(relays);
  }
}

