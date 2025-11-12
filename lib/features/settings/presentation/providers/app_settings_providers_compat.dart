import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/app_settings.dart' as legacy;
import '../../../../providers/app_settings_provider.dart' as old;
import '../../domain/entities/app_settings.dart' as domain;
import '../view_models/app_settings_view_model.dart';
import 'app_settings_providers.dart';

/// 既存UIとの互換性レイヤー
/// 
/// AppSettingsStateをAsyncValue<AppSettings>に変換し、
/// 既存のappSettingsProviderと同じインターフェースを提供する

// ============================================================================
// 互換Provider（AsyncValue変換）
// ============================================================================

/// 既存のappSettingsProviderと互換性のあるProvider
/// 
/// AppSettingsState → AsyncValue<legacy.AppSettings> に変換
final appSettingsProviderCompat = Provider<AsyncValue<legacy.AppSettings>>((ref) {
  final state = ref.watch(appSettingsViewModelProvider);
  
  return state.maybeMap(
    initial: (_) => const AsyncValue.loading(),
    loading: (_) => const AsyncValue.loading(),
    loaded: (loadedState) {
      // domain.AppSettings → legacy.AppSettings に変換
      final legacySettings = _convertDomainToLegacy(loadedState.settings);
      return AsyncValue.data(legacySettings);
    },
    error: (errorState) => AsyncValue.error(
      errorState.failure.message,
      StackTrace.current,
    ),
    orElse: () => const AsyncValue.loading(),
  );
});

/// 既存の.notifier アクセス用の互換ラッパー
/// 
/// 使用例: ref.read(appSettingsProviderNotifierCompat).toggleDarkMode()
final appSettingsProviderNotifierCompat = Provider<AppSettingsViewModelCompat>((ref) {
  final viewModel = ref.watch(appSettingsViewModelProvider.notifier);
  return AppSettingsViewModelCompat(viewModel, ref);
});

// ============================================================================
// Domain → Legacy 変換関数
// ============================================================================

/// Domain層のAppSettingsをLegacy層のAppSettingsに変換
legacy.AppSettings _convertDomainToLegacy(domain.AppSettings domainSettings) {
  return legacy.AppSettings(
    darkMode: domainSettings.darkMode,
    weekStartDay: domainSettings.weekStartDay,
    calendarView: domainSettings.calendarView,
    notificationsEnabled: domainSettings.notificationsEnabled,
    relays: domainSettings.relays,
    torEnabled: domainSettings.torEnabled,
    proxyUrl: domainSettings.proxyUrl,
    customListOrder: domainSettings.customListOrder,
    lastViewedCustomListId: domainSettings.lastViewedCustomListId,
    updatedAt: domainSettings.updatedAt,
  );
}

// ============================================================================
// ViewModel互換ラッパー
// ============================================================================

/// AppSettingsViewModelをラップして互換メソッドを提供
class AppSettingsViewModelCompat {
  AppSettingsViewModelCompat(this._viewModel, this._ref);
  
  final AppSettingsViewModel _viewModel;
  final Ref _ref;
  
  /// 設定を更新（既存メソッド互換）
  Future<void> updateSettings(legacy.AppSettings settings) async {
    final domainSettings = _convertLegacyToDomain(settings);
    await _viewModel.updateSettings(domainSettings);
  }
  
  /// ダークモードを切り替え（既存メソッド互換）
  Future<void> toggleDarkMode() async {
    await _viewModel.toggleDarkMode();
  }
  
  /// 週の開始曜日を変更（既存メソッド互換）
  Future<void> setWeekStartDay(int day) async {
    await _viewModel.setWeekStartDay(day);
  }
  
  /// カレンダー表示形式を変更（既存メソッド互換）
  Future<void> setCalendarView(String view) async {
    await _viewModel.setCalendarView(view);
  }
  
  /// 通知設定を切り替え（既存メソッド互換）
  Future<void> toggleNotifications() async {
    await _viewModel.toggleNotifications();
  }
  
  /// リレーリストを更新（既存メソッド互換）
  Future<void> updateRelays(List<String> relays) async {
    await _viewModel.updateRelays(relays);
  }
  
  /// リレーリストをNostrに保存（複雑な実装は旧Providerに委譲）
  Future<void> saveRelaysToNostr(List<String> relays) async {
    // 【暫定実装】複雑なNostr/Amber連携は旧Providerに委譲
    await _ref.read(old.appSettingsProvider.notifier).saveRelaysToNostr(relays);
  }
  
  /// Nostrから同期（複雑な実装は旧Providerに委譲）
  Future<void> syncFromNostr() async {
    // 【暫定実装】複雑なNostr/Amber連携は旧Providerに委譲
    await _ref.read(old.appSettingsProvider.notifier).syncFromNostr();
  }
  
  /// Tor設定を切り替え（旧Providerに委譲）
  Future<void> toggleTor() async {
    await _ref.read(old.appSettingsProvider.notifier).toggleTor();
  }
  
  /// プロキシURLを変更（旧Providerに委譲）
  Future<void> setProxyUrl(String url) async {
    await _ref.read(old.appSettingsProvider.notifier).setProxyUrl(url);
  }
  
  /// 最後に見ていたカスタムリストIDを更新（旧Providerに委譲）
  Future<void> setLastViewedCustomListId(String? listId) async {
    await _ref.read(old.appSettingsProvider.notifier).setLastViewedCustomListId(listId);
  }
  
  /// Legacy → Domain 変換ヘルパー
  domain.AppSettings _convertLegacyToDomain(legacy.AppSettings legacySettings) {
    return domain.AppSettings(
      darkMode: legacySettings.darkMode,
      weekStartDay: legacySettings.weekStartDay,
      calendarView: legacySettings.calendarView,
      notificationsEnabled: legacySettings.notificationsEnabled,
      relays: legacySettings.relays,
      torEnabled: legacySettings.torEnabled,
      proxyUrl: legacySettings.proxyUrl,
      customListOrder: legacySettings.customListOrder,
      lastViewedCustomListId: legacySettings.lastViewedCustomListId,
      updatedAt: legacySettings.updatedAt,
    );
  }
}

