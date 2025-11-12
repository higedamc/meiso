import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// カレンダー表示形式を設定するUseCase
class SetCalendarViewUseCase implements UseCase<AppSettings, String> {
  const SetCalendarViewUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(String view) {
    return repository.setCalendarView(view);
  }
}

