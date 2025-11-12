import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// アプリ設定を更新するUseCase
class UpdateAppSettingsUseCase implements UseCase<AppSettings, AppSettings> {
  const UpdateAppSettingsUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(AppSettings settings) {
    return repository.updateAppSettings(settings);
  }
}

