import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// アプリ設定のドメインエンティティ
///
/// NIP-78 Application-specific data (Kind 30078) として保存される
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// ダークモード設定
    required bool darkMode,
    
    /// 週の開始曜日 (0=日曜, 1=月曜, ...)
    required int weekStartDay,
    
    /// カレンダー表示形式 ("week" | "month")
    required String calendarView,
    
    /// 通知設定
    required bool notificationsEnabled,
    
    /// リレーリスト（NIP-65 kind 10002から同期）
    required List<String> relays,
    
    /// Tor有効/無効（Orbot経由での接続）
    required bool torEnabled,
    
    /// プロキシURL（通常は socks5://127.0.0.1:9050）
    required String proxyUrl,
    
    /// カスタムリストの順番（リストIDの配列）
    required List<String> customListOrder,
    
    /// 最後に見ていたカスタムリストID
    String? lastViewedCustomListId,
    
    /// 最終更新日時
    required DateTime updatedAt,
  }) = _AppSettings;
  
  const AppSettings._();
  
  /// デフォルト設定を取得
  factory AppSettings.defaultSettings() {
    return AppSettings(
      darkMode: false,
      weekStartDay: 1, // 月曜日始まり
      calendarView: 'week',
      notificationsEnabled: true,
      relays: [], // デフォルトは空（初回起動時にdefaultRelaysが適用される）
      torEnabled: false, // デフォルトはTor無効
      proxyUrl: 'socks5://127.0.0.1:9050', // Orbotのデフォルトプロキシ
      customListOrder: [], // デフォルトは空
      lastViewedCustomListId: null, // デフォルトはなし
      updatedAt: DateTime.now(),
    );
  }
}

