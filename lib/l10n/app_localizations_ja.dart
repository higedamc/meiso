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

  @override
  String get loginMethodTitle => 'ログイン方法を選択';

  @override
  String get loginMethodDescription => 'Nostrアカウントでログインして、\nタスクを同期しましょう';

  @override
  String get loginWithAmber => 'Amberでログイン';

  @override
  String get or => 'または';

  @override
  String get generateNewKey => '新しい秘密鍵を生成';

  @override
  String get keyStorageNote => '秘密鍵は安全に保管されます。\nAmberを使用すると、より安全に管理できます。';

  @override
  String get amberRequired => 'Amberが必要です';

  @override
  String get amberNotInstalled =>
      'Amberアプリがインストールされていません。\nGoogle Playからインストールしますか？';

  @override
  String get install => 'インストール';

  @override
  String get error => 'エラー';

  @override
  String loginProcessError(String error) {
    return 'ログイン処理中にエラーが発生しました\n$error';
  }

  @override
  String get ok => 'OK';

  @override
  String get noPublicKeyReceived => 'Amberから公開鍵を取得できませんでした';

  @override
  String amberConnectionFailed(String error) {
    return 'Amberとの連携に失敗しました\n$error';
  }

  @override
  String get setPassword => 'パスワードを設定';

  @override
  String get setPasswordDescription => '秘密鍵を暗号化するためのパスワードを設定してください。';

  @override
  String get password => 'パスワード';

  @override
  String get passwordConfirm => 'パスワード（確認）';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get passwordMinLength => '8文字以上で入力してください';

  @override
  String get passwordMismatch => 'パスワードが一致しません';

  @override
  String get secretKeyGenerated => '秘密鍵が生成されました';

  @override
  String get backupSecretKey => '以下の秘密鍵を安全な場所にバックアップしてください。';

  @override
  String get secretKeyNsec => '秘密鍵 (nsec):';

  @override
  String get publicKeyNpub => '公開鍵 (npub):';

  @override
  String get secretKeyWarning => 'この秘密鍵を失うと、アカウントにアクセスできなくなります。必ずバックアップしてください。';

  @override
  String get backupCompleted => 'バックアップしました';

  @override
  String keypairGenerationFailed(String error) {
    return '秘密鍵の生成に失敗しました\n\n$error';
  }

  @override
  String get sunday => '日曜日';

  @override
  String get monday => '月曜日';

  @override
  String get tuesday => '火曜日';

  @override
  String get wednesday => '水曜日';

  @override
  String get thursday => '木曜日';

  @override
  String get friday => '金曜日';

  @override
  String get saturday => '土曜日';

  @override
  String get weekStartDay => '週の開始曜日';

  @override
  String get selectWeekStartDay => '週の開始曜日を選択';

  @override
  String get calendarView => 'カレンダー表示';

  @override
  String get selectCalendarView => 'カレンダー表示を選択';

  @override
  String get weekView => '週表示';

  @override
  String get monthView => '月表示';

  @override
  String get notifications => '通知';

  @override
  String get notificationsSubtitle => 'リマインダー通知を有効化';

  @override
  String get torConnection => 'Tor経由で接続 (Orbot)';

  @override
  String torEnabledSubtitle(String proxyUrl) {
    return 'Orbotプロキシ経由で接続中 ($proxyUrl)';
  }

  @override
  String get torDisabledSubtitle => 'Orbot未使用（直接接続）';

  @override
  String get torEnabledMessage =>
      'Torを有効にしました。次回接続時から適用されます。\nOrbotアプリを起動してください。';

  @override
  String get torDisabledMessage => 'Torを無効にしました。次回接続時から適用されます。';

  @override
  String get proxyAddress => 'プロキシアドレスとポート';

  @override
  String get proxySettings => 'プロキシ設定';

  @override
  String get proxySettingsDescription => 'SOCKS5プロキシのアドレスとポートを設定してください';

  @override
  String get host => 'ホスト';

  @override
  String get port => 'ポート';

  @override
  String get hostRequired => 'ホストを入力してください';

  @override
  String get portRequired => 'ポートを入力してください';

  @override
  String get portRangeError => 'ポート番号は 1-65535 の範囲で入力してください';

  @override
  String proxyUrlUpdated(String url) {
    return 'プロキシURLを更新しました: $url';
  }

  @override
  String get commonSettings =>
      '一般的な設定:\n• Orbot: 127.0.0.1:9050\n• カスタムプロキシ: ホストとポートを入力';

  @override
  String get proxyConnectionStatus => 'プロキシ接続状態';

  @override
  String get testButton => 'テスト';

  @override
  String get untested => '未テスト';

  @override
  String get testing => 'テスト中...';

  @override
  String get connectionSuccess => '接続成功';

  @override
  String get connectionFailed => '接続失敗（Orbotを起動してください）';

  @override
  String get appSettingsTitle => 'アプリ設定';

  @override
  String get appSettingsInfo => 'アプリ設定について';

  @override
  String get appSettingsInfoText =>
      '• アプリ設定はローカルに保存されます\n• Nostr接続中の場合、設定は自動的に同期されます\n• 複数デバイスで同じ設定を共有できます（NIP-78）\n• 設定変更は即座に反映されます\n\n🛡️ Tor設定について:\n• Torを有効にすると、Orbotプロキシ経由でリレーに接続します\n• Orbotアプリが起動している必要があります\n• プライバシーとセキュリティが向上しますが、接続速度は遅くなります\n• 設定変更後、再接続が必要です';

  @override
  String get nostrAutoSync => 'Nostrリレーに自動同期（NIP-78 Kind 30078）';

  @override
  String get localStorageOnly => 'ローカル保存のみ（Nostr未接続）';

  @override
  String get languageSelection => '言語を選択';
}
