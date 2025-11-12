import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/usecases/get_app_settings_usecase.dart';
import '../../application/usecases/save_relays_to_nostr_usecase.dart';
import '../../application/usecases/set_calendar_view_usecase.dart';
import '../../application/usecases/set_week_start_day_usecase.dart';
import '../../application/usecases/sync_from_nostr_usecase.dart';
import '../../application/usecases/sync_to_nostr_usecase.dart';
import '../../application/usecases/toggle_dark_mode_usecase.dart';
import '../../application/usecases/toggle_notifications_usecase.dart';
import '../../application/usecases/update_app_settings_usecase.dart';
import '../../application/usecases/update_relays_usecase.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../infrastructure/datasources/app_settings_local_datasource.dart';
import '../../infrastructure/datasources/app_settings_remote_datasource.dart';
import '../../infrastructure/repositories/app_settings_repository_impl.dart';
import '../view_models/app_settings_state.dart';
import '../view_models/app_settings_view_model.dart';

// ============================================================================
// Infrastructure層 Providers
// ============================================================================

/// AppSettingsLocalDataSourceのProvider
final appSettingsLocalDataSourceProvider = Provider<AppSettingsLocalDataSource>((ref) {
  return AppSettingsLocalDataSourceHive(boxName: 'settings');
});

/// AppSettingsRemoteDataSourceのProvider
final appSettingsRemoteDataSourceProvider = Provider<AppSettingsRemoteDataSource>((ref) {
  return const AppSettingsRemoteDataSourceNostr();
});

/// AppSettingsRepositoryのProvider
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepositoryImpl(
    localDataSource: ref.watch(appSettingsLocalDataSourceProvider),
    remoteDataSource: ref.watch(appSettingsRemoteDataSourceProvider),
  );
});

// ============================================================================
// Application層 Providers (UseCases)
// ============================================================================

final getAppSettingsUseCaseProvider = Provider<GetAppSettingsUseCase>((ref) {
  return GetAppSettingsUseCase(ref.watch(appSettingsRepositoryProvider));
});

final updateAppSettingsUseCaseProvider = Provider<UpdateAppSettingsUseCase>((ref) {
  return UpdateAppSettingsUseCase(ref.watch(appSettingsRepositoryProvider));
});

final toggleDarkModeUseCaseProvider = Provider<ToggleDarkModeUseCase>((ref) {
  return ToggleDarkModeUseCase(ref.watch(appSettingsRepositoryProvider));
});

final setWeekStartDayUseCaseProvider = Provider<SetWeekStartDayUseCase>((ref) {
  return SetWeekStartDayUseCase(ref.watch(appSettingsRepositoryProvider));
});

final setCalendarViewUseCaseProvider = Provider<SetCalendarViewUseCase>((ref) {
  return SetCalendarViewUseCase(ref.watch(appSettingsRepositoryProvider));
});

final toggleNotificationsUseCaseProvider = Provider<ToggleNotificationsUseCase>((ref) {
  return ToggleNotificationsUseCase(ref.watch(appSettingsRepositoryProvider));
});

final updateRelaysUseCaseProvider = Provider<UpdateRelaysUseCase>((ref) {
  return UpdateRelaysUseCase(ref.watch(appSettingsRepositoryProvider));
});

final saveRelaysToNostrUseCaseProvider = Provider<SaveRelaysToNostrUseCase>((ref) {
  return SaveRelaysToNostrUseCase(ref.watch(appSettingsRepositoryProvider));
});

final syncFromNostrUseCaseProvider = Provider<SyncFromNostrUseCase>((ref) {
  return SyncFromNostrUseCase(ref.watch(appSettingsRepositoryProvider));
});

final syncToNostrUseCaseProvider = Provider<SyncToNostrUseCase>((ref) {
  return SyncToNostrUseCase(ref.watch(appSettingsRepositoryProvider));
});

// ============================================================================
// Presentation層 Providers (ViewModel)
// ============================================================================

final appSettingsViewModelProvider =
    StateNotifierProvider<AppSettingsViewModel, AppSettingsState>((ref) {
  return AppSettingsViewModel(
    getAppSettingsUseCase: ref.watch(getAppSettingsUseCaseProvider),
    updateAppSettingsUseCase: ref.watch(updateAppSettingsUseCaseProvider),
    toggleDarkModeUseCase: ref.watch(toggleDarkModeUseCaseProvider),
    setWeekStartDayUseCase: ref.watch(setWeekStartDayUseCaseProvider),
    setCalendarViewUseCase: ref.watch(setCalendarViewUseCaseProvider),
    toggleNotificationsUseCase: ref.watch(toggleNotificationsUseCaseProvider),
    updateRelaysUseCase: ref.watch(updateRelaysUseCaseProvider),
    saveRelaysToNostrUseCase: ref.watch(saveRelaysToNostrUseCaseProvider),
    syncFromNostrUseCase: ref.watch(syncFromNostrUseCaseProvider),
    syncToNostrUseCase: ref.watch(syncToNostrUseCaseProvider),
  );
});

