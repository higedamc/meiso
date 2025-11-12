import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/errors/app_settings_errors.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/app_settings_local_datasource.dart';
import '../datasources/app_settings_remote_datasource.dart';

/// AppSettingsRepositoryの実装
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  const AppSettingsRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });
  
  final AppSettingsLocalDataSource localDataSource;
  final AppSettingsRemoteDataSource remoteDataSource;
  
  @override
  Future<Either<Failure, AppSettings>> getAppSettings() async {
    try {
      final settings = await localDataSource.getAppSettings();
      
      if (settings == null) {
        // デフォルト設定を返す
        final defaultSettings = AppSettings.defaultSettings();
        await localDataSource.saveAppSettings(defaultSettings);
        return Right(defaultSettings);
      }
      
      return Right(settings);
    } catch (e) {
      AppLogger.error('❌ [AppSettingsRepository] getAppSettings failed: $e');
      return Left(AppSettingsError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, AppSettings>> updateAppSettings(
    AppSettings settings,
  ) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      await localDataSource.saveAppSettings(updatedSettings);
      AppLogger.info('✅ [AppSettingsRepository] Updated settings');
      return Right(updatedSettings);
    } catch (e) {
      AppLogger.error('❌ [AppSettingsRepository] updateAppSettings failed: $e');
      return Left(AppSettingsError.storageError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, AppSettings>> toggleDarkMode() async {
    final result = await getAppSettings();
    
    return result.fold(
      (failure) => Left(failure),
      (settings) async {
        final updated = settings.copyWith(
          darkMode: !settings.darkMode,
          updatedAt: DateTime.now(),
        );
        return updateAppSettings(updated);
      },
    );
  }
  
  @override
  Future<Either<Failure, AppSettings>> setWeekStartDay(int day) async {
    if (day < 0 || day > 6) {
      return Left(AppSettingsError.invalidValue.toFailure('週の開始曜日は0-6の範囲で指定してください'));
    }
    
    final result = await getAppSettings();
    
    return result.fold(
      (failure) => Left(failure),
      (settings) async {
        final updated = settings.copyWith(
          weekStartDay: day,
          updatedAt: DateTime.now(),
        );
        return updateAppSettings(updated);
      },
    );
  }
  
  @override
  Future<Either<Failure, AppSettings>> setCalendarView(String view) async {
    if (view != 'week' && view != 'month') {
      return Left(AppSettingsError.invalidValue.toFailure('カレンダー表示形式はweekまたはmonthを指定してください'));
    }
    
    final result = await getAppSettings();
    
    return result.fold(
      (failure) => Left(failure),
      (settings) async {
        final updated = settings.copyWith(
          calendarView: view,
          updatedAt: DateTime.now(),
        );
        return updateAppSettings(updated);
      },
    );
  }
  
  @override
  Future<Either<Failure, AppSettings>> toggleNotifications() async {
    final result = await getAppSettings();
    
    return result.fold(
      (failure) => Left(failure),
      (settings) async {
        final updated = settings.copyWith(
          notificationsEnabled: !settings.notificationsEnabled,
          updatedAt: DateTime.now(),
        );
        return updateAppSettings(updated);
      },
    );
  }
  
  @override
  Future<Either<Failure, AppSettings>> updateRelays(List<String> relays) async {
    final result = await getAppSettings();
    
    return result.fold(
      (failure) => Left(failure),
      (settings) async {
        final updated = settings.copyWith(
          relays: relays,
          updatedAt: DateTime.now(),
        );
        return updateAppSettings(updated);
      },
    );
  }
  
  @override
  Future<Either<Failure, void>> saveRelaysToNostr(List<String> relays) async {
    try {
      // 【暫定実装】複雑なNostr/Amber連携ロジックは互換レイヤーから旧Providerに委譲
      throw UnimplementedError('Use compat layer');
    } catch (e) {
      AppLogger.error('❌ [AppSettingsRepository] saveRelaysToNostr failed: $e');
      return Left(AppSettingsError.syncError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, AppSettings>> syncFromNostr() async {
    try {
      // 【暫定実装】複雑なNostr/Amber連携ロジックは互換レイヤーから旧Providerに委譲
      throw UnimplementedError('Use compat layer');
    } catch (e) {
      AppLogger.error('❌ [AppSettingsRepository] syncFromNostr failed: $e');
      return Left(AppSettingsError.syncError.toFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> syncToNostr(AppSettings settings) async {
    try {
      // 【暫定実装】複雑なNostr/Amber連携ロジックは互換レイヤーから旧Providerに委譲
      throw UnimplementedError('Use compat layer');
    } catch (e) {
      AppLogger.error('❌ [AppSettingsRepository] syncToNostr failed: $e');
      return Left(AppSettingsError.syncError.toFailure(e.toString()));
    }
  }
}

