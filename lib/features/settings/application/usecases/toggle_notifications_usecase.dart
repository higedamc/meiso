import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// 通知設定を切り替えるUseCase
class ToggleNotificationsUseCase implements UseCase<AppSettings, NoParams> {
  const ToggleNotificationsUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) {
    return repository.toggleNotifications();
  }
}

