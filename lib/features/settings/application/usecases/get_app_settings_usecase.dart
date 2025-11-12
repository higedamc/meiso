import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// アプリ設定を取得するUseCase
class GetAppSettingsUseCase implements UseCase<AppSettings, NoParams> {
  const GetAppSettingsUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) {
    return repository.getAppSettings();
  }
}

