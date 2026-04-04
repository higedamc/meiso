import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// Tor接続モード
enum TorMode {
  /// Tor無効（直接接続）
  disabled,
  
  /// 内蔵Tor (Embedded Tor)
  internal,
  
  /// Orbot経由 (SOCKS5 Proxy)
  orbot,
}

/// タスクUIモード
enum TaskUiMode {
  reminders,
  asana,
  wunderlist,
  kanban,
}

/// アプリ設定データ（NIP-78 Application-specific data - Kind 30078）
@Freezed(makeCollectionsUnmodifiable: false)
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
    
    /// Tor接続モード
    @Default(TorMode.disabled) TorMode torMode,
    
    /// プロキシURL（Orbotモード使用時、通常は socks5://127.0.0.1:9050）
    @Default('socks5://127.0.0.1:9050') String proxyUrl,
    
    /// カスタムリストの順番（リストIDの配列）
    @Default([]) List<String> customListOrder,
    
    /// 最後に見ていたカスタムリストID
    String? lastViewedCustomListId,

    /// タスクUIモード（既定: Reminders）
    @Default(TaskUiMode.reminders) TaskUiMode taskUiMode,

    /// 実験機能フラグ（feature_id -> enabled）
    @Default(<String, bool>{}) Map<String, bool> featureFlags,

    /// 完了済みタスクを非表示にする
    @Default(false) bool hideCompletedTasks,

    /// NIP-89 `client` タグをイベントに付与する（false = オプトアウト）
    @Default(true) bool nip89ClientTagEnabled,
    
    /// 最終更新日時
    required DateTime updatedAt,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  
  /// デフォルト設定を取得
  factory AppSettings.defaultSettings() {
    return AppSettings(
      weekStartDay: 1, // 月曜日始まり
      notificationsEnabled: true,
      relays: [], // デフォルトは空（初回起動時にdefaultRelaysが適用される）
      customListOrder: [], // デフォルトは空
      updatedAt: DateTime.now(),
    );
  }
}

