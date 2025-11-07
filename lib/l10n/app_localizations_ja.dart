// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Meiso';

  @override
  String get onboardingWelcomeTitle => 'Meisoへようこそ';

  @override
  String get onboardingWelcomeDescription =>
      'シンプルで美しいToDoアプリ\nNostrで同期して、どこでもタスク管理';

  @override
  String get onboardingNostrSyncTitle => 'Nostrで同期';

  @override
  String get onboardingNostrSyncDescription =>
      'あなたのタスクをNostrネットワークで同期\n複数デバイスで自動的に最新状態を保ちます';

  @override
  String get onboardingSmartDateTitle => 'スマートな日付入力';

  @override
  String get onboardingSmartDateDescription =>
      'タスクに \"tomorrow\" と入力すれば明日のタスクに\n\"every day\" で繰り返しタスクも簡単に作成';

  @override
  String get onboardingPrivacyTitle => 'プライバシー第一';

  @override
  String get onboardingPrivacyDescription =>
      '中央サーバーなし。すべてのデータはあなたの管理下に\nNostrの分散型ネットワークで安全に保管';

  @override
  String get onboardingGetStartedTitle => 'さあ、始めましょう';

  @override
  String get onboardingGetStartedDescription =>
      'Amberでログインするか、\n新しい秘密鍵を生成してスタート';

  @override
  String get skipButton => 'スキップ';

  @override
  String get nextButton => '次へ';

  @override
  String get startButton => 'スタート';

  @override
  String get settingsTitle => '設定';

  @override
  String get nostrConnected => 'Nostr接続中';

  @override
  String get nostrConnectedAmber => 'Nostr接続中 (Amber)';

  @override
  String get nostrDisconnected => 'Nostr未接続';

  @override
  String relaysConnectedCount(int count, int total) {
    return 'リレー: $count/$total 接続中';
  }

  @override
  String get secretKeyManagement => '秘密鍵管理';

  @override
  String get secretKeyConfigured => '設定済み';

  @override
  String get secretKeyNotConfigured => '未設定';

  @override
  String get relayServerManagement => 'リレーサーバー管理';

  @override
  String relayCountRegistered(int count) {
    return '$count件登録済み';
  }

  @override
  String get appSettings => 'アプリ設定';

  @override
  String get appSettingsSubtitle => 'テーマ、カレンダー、通知、Tor';

  @override
  String get debugLogs => 'デバッグログ';

  @override
  String get debugLogsSubtitle => 'ログ履歴を表示';

  @override
  String get amberModeTitle => 'Amberモード';

  @override
  String get amberModeInfo =>
      '✅ Amberモードで接続中\n\n🔒 セキュリティ機能:\n• Todoの作成・編集時にAmberで署名\n• NIP-44暗号化でコンテンツを保護\n• 秘密鍵はAmber内でncryptsec準拠で暗号化保存\n\n⚡ 復号化の最適化:\nTodoの同期時に復号化の承認が必要です。\n毎回承認するのを避けるために、Amberアプリで\n「Meisoアプリを常に許可」を設定することを推奨します。\n\n📝 設定方法:\n1. Amberアプリを開く\n2. アプリ一覧から「Meiso」を選択\n3. 「NIP-44 Decrypt」を常に許可に設定';

  @override
  String get autoSyncInfoTitle => '自動同期について';

  @override
  String get autoSyncInfo =>
      '• タスクの作成・編集・削除は自動的にNostrに同期されます\n• アプリ起動時に最新のデータが自動取得されます\n• リレー接続中は常にバックグラウンドで同期します\n• 手動同期ボタンは不要になりました';

  @override
  String versionInfo(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get todayLabel => 'TODAY';

  @override
  String get tomorrowLabel => 'TOMORROW';

  @override
  String get somedayLabel => 'SOMEDAY';

  @override
  String get addTaskPlaceholder => 'タスクを追加...';

  @override
  String get editTaskTitle => 'タスクを編集';

  @override
  String get taskTitlePlaceholder => 'タスクのタイトル';

  @override
  String get saveButton => '保存';

  @override
  String get cancelButton => 'キャンセル';

  @override
  String get deleteButton => '削除';

  @override
  String get undoButton => '元に戻す';

  @override
  String get taskDeleted => 'タスクを削除しました';

  @override
  String get languageSettings => '言語';

  @override
  String get languageSystem => 'システムのデフォルト';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSpanish => 'Español';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get darkModeEnabled => '有効';

  @override
  String get darkModeDisabled => '無効';

  @override
  String get torSettings => 'Tor (Orbot)';

  @override
  String get torEnabled => '有効';

  @override
  String get torDisabled => '無効';

  @override
  String get mondayShort => '月';

  @override
  String get tuesdayShort => '火';

  @override
  String get wednesdayShort => '水';

  @override
  String get thursdayShort => '木';

  @override
  String get fridayShort => '金';

  @override
  String get saturdayShort => '土';

  @override
  String get sundayShort => '日';
}
