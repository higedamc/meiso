import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// アプリ設定データ（NIP-78 Application-specific data - Kind 30078）
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// ダークモード設定
    @Default(false) bool darkMode,
    
    /// 週の開始曜日 (0=日曜, 1=月曜, ...)
    @Default(1) int weekStartDay,
    
    /// カレンダー表示形式 ("week" | "month")
    @Default('week') String calendarView,
    
    /// 通知設定
    @Default(true) bool notificationsEnabled,
    
    /// リレーリスト（NIP-65 kind 10002から同期）
    @Default([]) List<String> relays,
    
    /// 最終更新日時
    required DateTime updatedAt,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  
  /// デフォルト設定を取得
  factory AppSettings.defaultSettings() {
    return AppSettings(
      darkMode: false,
      weekStartDay: 1, // 月曜日始まり
      calendarView: 'week',
      notificationsEnabled: true,
      relays: [], // デフォルトは空（初回起動時にdefaultRelaysが適用される）
      updatedAt: DateTime.now(),
    );
  }
}

