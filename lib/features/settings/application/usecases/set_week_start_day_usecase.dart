import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../core/common/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

/// 週の開始曜日を設定するUseCase
class SetWeekStartDayUseCase implements UseCase<AppSettings, int> {
  const SetWeekStartDayUseCase(this.repository);
  
  final AppSettingsRepository repository;
  
  @override
  Future<Either<Failure, AppSettings>> call(int day) {
    return repository.setWeekStartDay(day);
  }
}

