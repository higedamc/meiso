/// アプリケーション全体の設定
class AppConfig {
  const AppConfig._();

  /// アプリ名
  static const String appName = 'Meiso';

  /// アプリバージョン
  static const String appVersion = '1.0.0';

  /// Nostr デフォルトリレー
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nostr.band',
  ];

  /// Todoの最大タイトル文字数
  static const int maxTodoTitleLength = 500;

  /// カスタムリストの最大名前文字数
  static const int maxListNameLength = 100;

  /// Nostr同期間隔（秒）
  static const int syncIntervalSeconds = 30;

  /// バッチ同期の最大待機時間（ミリ秒）
  static const int batchSyncDelayMillis = 500;

  /// Amber署名タイムアウト（秒）
  static const int amberSignTimeoutSeconds = 120;

  /// リンクプレビューのタイムアウト（秒）
  static const int linkPreviewTimeoutSeconds = 10;

  /// キャッシュの有効期限（日）
  static const int cacheExpirationDays = 7;
}

