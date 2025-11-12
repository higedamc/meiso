import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/common/usecase.dart';
import '../../../../services/logger_service.dart';
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
import '../../domain/entities/app_settings.dart';
import 'app_settings_state.dart';

/// AppSettingsのViewModel (StateNotifier)
///
/// UseCaseを使用してAppSettingsの状態を管理する
class AppSettingsViewModel extends StateNotifier<AppSettingsState> {
  AppSettingsViewModel({
    required GetAppSettingsUseCase getAppSettingsUseCase,
    required UpdateAppSettingsUseCase updateAppSettingsUseCase,
    required ToggleDarkModeUseCase toggleDarkModeUseCase,
    required SetWeekStartDayUseCase setWeekStartDayUseCase,
    required SetCalendarViewUseCase setCalendarViewUseCase,
    required ToggleNotificationsUseCase toggleNotificationsUseCase,
    required UpdateRelaysUseCase updateRelaysUseCase,
    required SaveRelaysToNostrUseCase saveRelaysToNostrUseCase,
    required SyncFromNostrUseCase syncFromNostrUseCase,
    required SyncToNostrUseCase syncToNostrUseCase,
    bool autoLoad = true,
  })  : _getAppSettingsUseCase = getAppSettingsUseCase,
        _updateAppSettingsUseCase = updateAppSettingsUseCase,
        _toggleDarkModeUseCase = toggleDarkModeUseCase,
        _setWeekStartDayUseCase = setWeekStartDayUseCase,
        _setCalendarViewUseCase = setCalendarViewUseCase,
        _toggleNotificationsUseCase = toggleNotificationsUseCase,
        _updateRelaysUseCase = updateRelaysUseCase,
        _saveRelaysToNostrUseCase = saveRelaysToNostrUseCase,
        _syncFromNostrUseCase = syncFromNostrUseCase,
        _syncToNostrUseCase = syncToNostrUseCase,
        super(const AppSettingsState.initial()) {
    if (autoLoad) {
      loadSettings();
    }
  }

  final GetAppSettingsUseCase _getAppSettingsUseCase;
  final UpdateAppSettingsUseCase _updateAppSettingsUseCase;
  final ToggleDarkModeUseCase _toggleDarkModeUseCase;
  final SetWeekStartDayUseCase _setWeekStartDayUseCase;
  final SetCalendarViewUseCase _setCalendarViewUseCase;
  final ToggleNotificationsUseCase _toggleNotificationsUseCase;
  final UpdateRelaysUseCase _updateRelaysUseCase;
  final SaveRelaysToNostrUseCase _saveRelaysToNostrUseCase;
  final SyncFromNostrUseCase _syncFromNostrUseCase;
  final SyncToNostrUseCase _syncToNostrUseCase;

  /// 設定を読み込む
  Future<void> loadSettings() async {
    state = const AppSettingsState.loading();

    final result = await _getAppSettingsUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] 設定読み込みエラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] 設定を読み込みました');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// 設定を更新
  Future<void> updateSettings(AppSettings settings) async {
    final result = await _updateAppSettingsUseCase(settings);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] 設定更新エラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (updatedSettings) {
        AppLogger.info('[AppSettingsViewModel] 設定更新成功');
        state = AppSettingsState.loaded(settings: updatedSettings);
      },
    );
  }

  /// ダークモードを切り替え
  Future<void> toggleDarkMode() async {
    final result = await _toggleDarkModeUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] ダークモード切り替えエラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] ダークモード切り替え成功: ${settings.darkMode}');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// 週の開始曜日を変更
  Future<void> setWeekStartDay(int day) async {
    final result = await _setWeekStartDayUseCase(day);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] 週の開始曜日変更エラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] 週の開始曜日変更成功: $day');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// カレンダー表示形式を変更
  Future<void> setCalendarView(String view) async {
    final result = await _setCalendarViewUseCase(view);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] カレンダー表示形式変更エラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] カレンダー表示形式変更成功: $view');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// 通知設定を切り替え
  Future<void> toggleNotifications() async {
    final result = await _toggleNotificationsUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] 通知設定切り替えエラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] 通知設定切り替え成功: ${settings.notificationsEnabled}');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// リレーリストを更新（ローカルのみ）
  Future<void> updateRelays(List<String> relays) async {
    final result = await _updateRelaysUseCase(relays);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] リレーリスト更新エラー: ${failure.message}');
        state = AppSettingsState.error(failure);
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] リレーリスト更新成功: ${relays.length}件');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// リレーリストをNostrに保存（互換レイヤー委譲）
  Future<void> saveRelaysToNostr(List<String> relays) async {
    final result = await _saveRelaysToNostrUseCase(relays);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] リレーリストNostr保存エラー: ${failure.message}');
        // エラーでも現在の状態を保持
      },
      (_) {
        AppLogger.info('[AppSettingsViewModel] リレーリストNostr保存成功');
      },
    );
  }

  /// Nostrから同期（互換レイヤー委譲）
  Future<void> syncFromNostr() async {
    final result = await _syncFromNostrUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] Nostr同期エラー: ${failure.message}');
        // エラーでも現在の状態を保持
      },
      (settings) {
        AppLogger.info('[AppSettingsViewModel] Nostr同期成功');
        state = AppSettingsState.loaded(settings: settings);
      },
    );
  }

  /// Nostrに同期（互換レイヤー委譲）
  Future<void> syncToNostr(AppSettings settings) async {
    final result = await _syncToNostrUseCase(settings);

    result.fold(
      (failure) {
        AppLogger.error('[AppSettingsViewModel] Nostr送信エラー: ${failure.message}');
        // エラーでも現在の状態を保持
      },
      (_) {
        AppLogger.info('[AppSettingsViewModel] Nostr送信成功');
      },
    );
  }
}

