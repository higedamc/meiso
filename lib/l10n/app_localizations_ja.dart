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
      'シンプルで美しいTo-Doアプリ\nNostrで同期して、どこでもタスク管理';

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
      '✅ Amberモードで接続中\n\n🔒 セキュリティ機能:\n• タスクの作成・編集時にAmberで署名\n• NIP-44暗号化でコンテンツを保護\n• 秘密鍵はAmber内でncryptsec準拠で暗号化保存\n\n⚡ UXを損なわないための推奨設定:\nAmberアプリでMeisoに「basic actions 以上の権限」を持たせることで、\n毎回の承認ダイアログを回避し、スムーズに利用できます。\n\n📝 設定方法:\n1. Amberアプリを開く\n2. 設定 → 接続済みアプリ → 「Meiso」を選択\n3. Basic actions (NIP-44 Decrypt/Encrypt, Sign Event) を「常に許可」に設定';

  @override
  String get autoSyncInfoTitle => '自動同期について';

  @override
  String get autoSyncInfo =>
      '• タスクの作成・編集・削除は自動的にNostrに同期されます\n• アプリ起動時に最新のデータが自動取得されます\n• リレー接続中は常にバックグラウンドで同期します\n• 手動同期ボタンは不要になりました';

  @override
  String get closeButton => '閉じる';

  @override
  String get copyButton => 'コピー';

  @override
  String get fetchButton => '取得';

  @override
  String get advancedSectionTitle => '高度な設定';

  @override
  String get advancedSectionSubtitle => '開発者向け機能';

  @override
  String get keyPackagePublishTitle => 'Key Packageを公開';

  @override
  String get keyPackagePublishSubtitle => 'グループ招待を受けるために必要';

  @override
  String get mlsIntegrationTestTitle => 'MLS統合テスト (PoC)';

  @override
  String get mlsIntegrationTestSubtitle => 'Option B: 1人グループでの動作確認';

  @override
  String get keyPackagePublishDialogTitle => 'Key Packageを公開';

  @override
  String get keyPackagePublishDialogBody =>
      'Key Packageをリレーに公開します。\n\n公開することで、他のユーザーがあなたをグループに招待できるようになります。\n\n続行しますか？';

  @override
  String get publishButton => '公開する';

  @override
  String get publishingKeyPackage => 'Key Packageを公開中...';

  @override
  String get keyPackagePublishCompletedTitle => '公開完了';

  @override
  String get keyPackagePublishCompletedMessage => 'Key Packageをリレーに公開しました！';

  @override
  String get keyPackagePublishCompletedDescription =>
      '他のユーザーがあなたのnpubを使ってグループに招待できるようになりました。';

  @override
  String get eventIdLabel => 'Event ID';

  @override
  String get keyPackagePublishFailedTitle => '公開失敗';

  @override
  String keyPackagePublishFailedBody(String error) {
    return 'Key Packageの公開に失敗しました。\n\nエラー: $error';
  }

  @override
  String get keyPackagePublishNoEventIdError => 'イベントIDが取得できませんでした';

  @override
  String get mlsTestDialogTitle => 'MLS統合テスト';

  @override
  String get mlsTestDialogSubtitle => 'Option B PoC: 2人グループ対応テスト';

  @override
  String get mlsYourKeyPackageLabel => '📋 あなたのKey Package:';

  @override
  String get keyPackageCopied => 'Key Packageをコピーしました';

  @override
  String get mlsPeerNpubLabel => '相手のnpub';

  @override
  String get mlsPeerNpubHint => 'npub1...';

  @override
  String get mlsPressTestButton => 'テストボタンを押してください';

  @override
  String get mlsGenerateKpButton => 'KP生成';

  @override
  String get mlsPublishKpButton => 'KP公開';

  @override
  String get mlsCreate2PersonGroupButton => '2人グループ作成';

  @override
  String get mlsSendTodoButton => 'TODO送信';

  @override
  String get mlsOnePersonTestButton => '1人テスト';

  @override
  String get mlsRunning => '実行中...';

  @override
  String get mlsUserPublicKeyNotAvailable => 'ユーザーの公開鍵が取得できません';

  @override
  String get mlsTwoPersonTestGroupName => '2人グループテスト';

  @override
  String get mlsTestListName => 'MLSテストリスト';

  @override
  String get mlsTwoPersonTestTodoTitle => '2人グループ用テストTODO';

  @override
  String get mlsOnePersonTestTodoTitle => 'MLSグループ内テストTODO';

  @override
  String get deleteRecurringTodoTitle => '繰り返しタスクを削除';

  @override
  String get removeThisInstance => 'このインスタンスのみ削除';

  @override
  String get removeAllInstances => 'すべてのインスタンスを削除';

  @override
  String get updateRecurringTodoTitle => '繰り返しタスクを更新';

  @override
  String get updateThisInstance => 'このインスタンスのみ更新';

  @override
  String get updateAllInstances => 'すべてのインスタンスを更新';

  @override
  String get todoJsonTitle => 'Todo JSON';

  @override
  String get jsonCopied => 'JSONをコピーしました';

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
  String taskDeletedWithTitle(String title) {
    return '「$title」を削除しました';
  }

  @override
  String todoMovedToNextDay(String title) {
    return '「$title」を翌日に移動しました';
  }

  @override
  String allInstancesDeleted(String title) {
    return '「$title」のすべてのインスタンスを削除しました';
  }

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
  String get amberPermissionsNote =>
      '💡 UXを損なわないために:\nAmberでログインする際は、「basic actions 以上の権限」を設定することを推奨します。\n設定 → 接続済みアプリ → Meiso で設定可能です。';

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

  @override
  String syncingWithCount(int count) {
    return '同期中 ($count)';
  }

  @override
  String get syncing => '同期中';

  @override
  String get syncCompleted => '同期完了';

  @override
  String get syncError => '同期エラー';

  @override
  String get timeout => 'タイムアウト';

  @override
  String get connectionError => '接続エラー';

  @override
  String errorRetry(int count) {
    return 'エラー (リトライ$count回)';
  }

  @override
  String get waiting => '待機中';

  @override
  String syncStep(int current, int total) {
    return 'ステップ $current / $total';
  }

  @override
  String get syncReconnectingRelays => 'リレー再接続中...';

  @override
  String get syncPhaseDelta => '差分同期中...';

  @override
  String get syncPhaseAppSettings => '設定同期中...';

  @override
  String get syncPhaseCustomLists => 'リスト同期中...';

  @override
  String get syncPhaseTodos => 'タスク同期中...';

  @override
  String get syncPhaseMls => 'グループタスク同期中...';

  @override
  String get bootstrapPhaseContinueWithLocalCache => 'ローカルキャッシュで継続します';

  @override
  String get bootstrapPhaseFetchingAccountRelays => 'アカウントに紐づくリレーを取得しています...';

  @override
  String get bootstrapPhaseFetchingLocalTodos => 'ローカルリレーから通常タスクを取得しています...';

  @override
  String get bootstrapPhaseFetchingLocalGroupTodos =>
      'ローカルリレーからグループタスクを取得しています...';

  @override
  String get bootstrapPhaseFetchingAllRelaysTodos => '全リレーから通常タスクを取得しています...';

  @override
  String get bootstrapPhaseFetchingAllRelaysGroupTodos =>
      '全リレーからグループタスクを取得しています...';

  @override
  String get bootstrapPhaseFetchingGroupInvitations => 'グループ招待を取得しています...';

  @override
  String get bootstrapPhaseCompleted => '同期が完了しました';

  @override
  String get bootstrapPhaseFailed => '同期に失敗しました';

  @override
  String get bootstrapContinueWithLocalCacheButton => 'ローカルキャッシュで続行';

  @override
  String get retryButton => '再試行';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String get secretKeyManagementTitle => '秘密鍵管理';

  @override
  String get enterPassword => 'パスワードを入力';

  @override
  String get enterPasswordToDecrypt => '秘密鍵を復号化するためのパスワードを入力してください。';

  @override
  String get enterPasswordToEncrypt => '秘密鍵を暗号化するためのパスワードを入力してください。';

  @override
  String secretKeyEncrypted(String format) {
    return '秘密鍵を暗号化保存しました（$format）';
  }

  @override
  String get formatUnknown => 'フォーマット不明';

  @override
  String get connectedToRelay => 'リレーに接続しました';

  @override
  String get connectedToRelayViaTor => 'リレーに接続しました (Tor経由)';

  @override
  String get invalidSecretKeyFormat =>
      '秘密鍵のフォーマットが正しくありません。nsecまたはhex形式で入力してください。';

  @override
  String get encrypted => '🔒 暗号化されています';

  @override
  String get relayManagementTitle => 'リレーサーバー管理';

  @override
  String get relayUrlError => 'リレーURLは wss:// または ws:// で始まる必要があります';

  @override
  String get relayAddedAndSaved => 'リレーを追加し、即座にNostrに保存しました';

  @override
  String relayAddedButSaveFailed(String error) {
    return 'リレーは追加されましたが、Nostrへの保存に失敗しました: $error';
  }

  @override
  String get relayRemovedAndSaved => 'リレーを削除し、即座にNostrに保存しました';

  @override
  String relayRemovedButSaveFailed(String error) {
    return 'リレーは削除されましたが、Nostrへの保存に失敗しました: $error';
  }

  @override
  String get noRelayListOnNostr => 'Nostr上にリレーリストが見つかりませんでした';

  @override
  String relaySyncSuccess(int count) {
    return 'Nostrから$count件のリレーを同期しました';
  }

  @override
  String relaySyncError(String error) {
    return 'Nostrからの同期に失敗しました: $error';
  }

  @override
  String get syncFromNostr => 'Nostrから同期';

  @override
  String get addRelay => 'リレーを追加';

  @override
  String get relayUrl => 'リレーURL';

  @override
  String get connected => '接続済み';

  @override
  String get connecting => '接続中';

  @override
  String get disconnected => '未接続';

  @override
  String get cryptographyTitle => '暗号技術の詳細';

  @override
  String get logout => 'ログアウト';

  @override
  String get logoutConfirm => '本当にログアウトしますか？';

  @override
  String get logoutDescription => '暗号化された秘密鍵が削除されます。\nログアウト前に秘密鍵を保存してください。';

  @override
  String get torModeDisabled => '無効';

  @override
  String get torModeInternal => '内蔵 (組み込み)';

  @override
  String get torModeOrbot => 'Orbot (プロキシ)';

  @override
  String get torModeDescriptionDisabled => 'Torを使用せず直接接続';

  @override
  String get torModeDescriptionInternal => '組み込みTorクライアントを使用（開発中、まだ利用できません）';

  @override
  String get torModeDescriptionOrbot => 'Orbotアプリ経由で接続（Orbotのインストールが必要）';

  @override
  String get torConnectionModeTitle => 'Tor接続モード';

  @override
  String get inDevelopment => '（開発中）';

  @override
  String torModeUpdated(String mode) {
    return 'Torモードを更新しました: $mode';
  }

  @override
  String get orbotRequired => 'Orbot が必要です';

  @override
  String get orbotRequiredDescription =>
      'このモードを使用するには、Orbotアプリをインストールして起動する必要があります。';

  @override
  String get openGooglePlayOrbot => 'Google Playを開く: Orbot';

  @override
  String get openFDroidOrbot => 'F-Droidを開く: Orbot';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get fDroid => 'F-Droid';

  @override
  String get embeddedTorDescription => '組み込みTorクライアントを使用。追加のアプリは不要です。';

  @override
  String get secretKeyNsecLabel => '秘密鍵 (nsec)';

  @override
  String copiedToClipboard(String label) {
    return '$labelをコピーしました';
  }

  @override
  String get copyNpub => 'npubコピー';

  @override
  String get copyHex => 'hexコピー';

  @override
  String get generateButton => '生成';

  @override
  String get saveAndConnect => '保存して接続';

  @override
  String get nostrConnectedStatus => 'Nostr接続中';

  @override
  String get nostrConnectedViaTor => 'Nostr接続中 (Tor経由)';

  @override
  String get nostrDisconnectedStatus => 'Nostr未接続';

  @override
  String get passwordIncorrectOrDecryptFailed => 'パスワードが間違っているか、秘密鍵の復号に失敗しました';

  @override
  String secretKeyDecryptFailed(String error) {
    return '秘密鍵の復号に失敗: $error';
  }

  @override
  String secretKeyGenerationFailed(String error) {
    return '秘密鍵の生成に失敗: $error';
  }

  @override
  String secretKeySaveFailed(String error) {
    return '秘密鍵の保存に失敗: $error';
  }

  @override
  String relayConnectionError(String error) {
    return 'リレー接続エラー: $error';
  }

  @override
  String logoutFailed(String error) {
    return 'ログアウト失敗: $error';
  }

  @override
  String get loggingInAmber => 'ログイン中 (Amber)';

  @override
  String get amberModeConnected => '✅ Amberモードで接続中\n\n';

  @override
  String get secretKeySaveAutoConnect => '• 秘密鍵を保存すると自動的にリレーに接続します\n';

  @override
  String get multipleRelaysRedundancy => '• 複数のリレーに接続することで冗長性が向上します\n';

  @override
  String get nostrNotInitialized => 'Nostrが初期化されていません。設定画面で接続してください。';

  @override
  String sendError(String error) {
    return '❌ 送信エラー: $error';
  }

  @override
  String get syncLoadingData => 'データ読み込み中...';

  @override
  String get syncMigratingData => 'データ移行中...';

  @override
  String get syncSyncingData => 'データ同期中...';

  @override
  String get syncPreparingMigration => 'データ移行準備中...';

  @override
  String get syncFetchingOldData => '旧データ取得中...';

  @override
  String get syncConvertingToNewFormat => '新形式に変換中...';

  @override
  String get syncDeletingOldData => '旧データ削除中...';

  @override
  String get syncMigrationCompleted => 'データ移行完了';

  @override
  String get aboutRelays => 'リレーについて';

  @override
  String get amberMode => 'Amberモード';

  @override
  String get cryptographyInUse => '使用している暗号技術';

  @override
  String get cryptographyDetailsUsedInMeiso => 'Meisoで採用している暗号技術の詳細';

  @override
  String get cryptographyIntroTitle => 'Meisoは、現代の暗号学における最高水準の技術を採用しています。';

  @override
  String get cryptographyIntroDescription =>
      'このドキュメントでは、ビットコイナーやNostrichの皆さんに向けて、Meisoで使用している暗号技術の詳細を説明します。';

  @override
  String get cryptoArchitectureTitle => '1. アーキテクチャ概要';

  @override
  String get cryptoArgon2idTitle => '2. Argon2id - パスワード派生関数';

  @override
  String get cryptoAes256GcmTitle => '3. AES-256-GCM - 暗号化アルゴリズム';

  @override
  String get cryptoNip44Title => '4. NIP-44 - Nostr暗号化規格';

  @override
  String get cryptoEd25519Title => '5. Ed25519 - デジタル署名';

  @override
  String get cryptoAmberIntegrationTitle => '6. Amber統合 - ハードウェアウォレット的セキュリティ';

  @override
  String get cryptoSecureStorageTitle => '7. セキュアストレージ - Rust実装';

  @override
  String get cryptoThreatModelTitle => '8. 脅威モデルと制限事項';

  @override
  String get relayList => 'リレーリスト';

  @override
  String get noRelaysRegistered => 'リレーが登録されていません';

  @override
  String get deleteTooltip => '削除';

  @override
  String get aboutRelaysDescription =>
      '• リレーはNostrネットワーク上のサーバーです\n• 複数のリレーに接続することで冗長性が向上します\n• リレーURLは wss:// または ws:// で始める必要があります\n• リレーを追加・削除すると即座にNostr（Kind 10002）に保存されます\n• リレー変更は即座に反映されます（再起動不要）\n• 「Nostrから同期」ボタンで他のデバイスの設定を取得できます\n• 同期時、リモートとローカルが異なる場合のみ更新されます';

  @override
  String get currentlyConnectedViaTor => '• 現在Tor経由で接続しています（Orbotプロキシ使用）';

  @override
  String get cryptoArchPara1 =>
      'Meisoは「Zero-Knowledge Architecture」を採用し、あなたの秘密鍵やタスクデータをサーバーに一切送信しません。全ての暗号化処理はあなたのデバイス上で実行されます。';

  @override
  String get cryptoArchSecurityModel =>
      'セキュリティモデル:\n• エンドツーエンド暗号化 (E2EE)\n• クライアントサイド暗号化\n• サーバーは暗号化済みデータのみを保管\n• 秘密鍵はあなただけが保有';

  @override
  String get cryptoArgon2Intro =>
      'Argon2idは、2015年のPassword Hashing Competition (PHC)で優勝した、最新かつ最強のパスワードハッシュアルゴリズムです。';

  @override
  String get cryptoArgon2WhyTitle => 'なぜArgon2idなのか？';

  @override
  String get cryptoArgon2BruteForce => '耐ブルートフォース攻撃';

  @override
  String get cryptoArgon2BruteForceDesc =>
      '計算コストとメモリコストの両方を必要とするため、GPUやASICによる並列攻撃に極めて強い耐性を持ちます。';

  @override
  String get cryptoArgon2SideChannel => 'サイドチャネル攻撃への耐性';

  @override
  String get cryptoArgon2SideChannelDesc =>
      'Argon2iのメモリアクセスパターンの予測不可能性と、Argon2dの計算効率を組み合わせた「ハイブリッド型」です。';

  @override
  String get cryptoArgon2Standard => '業界標準';

  @override
  String get cryptoArgon2StandardDesc =>
      'OWASP、NIST、CryptographyEngineering community推奨。bcryptやPBKDF2を上回る次世代標準です。';

  @override
  String get cryptoArgon2Params =>
      'Meisoでの実装パラメータ:\n• メモリコスト: 19 MiB (最適化済み)\n• 反復回数: 2回\n• 並列度: 1スレッド\n• 出力長: 32バイト (256ビット)\n• ソルト: ランダム生成 (16バイト)';

  @override
  String get cryptoArgon2Reference => '📚 参考: Argon2 RFC 9106';

  @override
  String get cryptoAesIntro =>
      'AES-256-GCMは、米国政府が機密情報の保護に使用する「認証付き暗号化 (AEAD)」アルゴリズムです。';

  @override
  String get cryptoAesStrengthTitle => 'AES-256の強度';

  @override
  String get cryptoAesStrengthDesc =>
      'AES-256は2^256通りの鍵空間を持ち、現代のスーパーコンピュータでも総当たり攻撃は事実上不可能です。量子コンピュータ時代でも128ビットの有効セキュリティを維持します。';

  @override
  String get cryptoAesGcmAdvantagesTitle => 'GCMモードの利点';

  @override
  String get cryptoAesAead => '認証付き暗号化 (AEAD)';

  @override
  String get cryptoAesAeadDesc => '暗号化と同時にメッセージ認証コード (MAC)を生成。データの改ざん検知が可能です。';

  @override
  String get cryptoAesPerformance => '高速処理';

  @override
  String get cryptoAesPerformanceDesc =>
      '並列処理が可能で、最新のCPUのAES-NI命令によりハードウェアアクセラレーションされます。';

  @override
  String get cryptoAesPaddingResistance => 'パディング攻撃への耐性';

  @override
  String get cryptoAesPaddingResistanceDesc =>
      'ストリーム暗号モードのため、パディングオラクル攻撃のリスクがありません。';

  @override
  String get cryptoAesParams =>
      'Meisoでの実装:\n• 暗号化アルゴリズム: AES-256-GCM\n• 鍵長: 256ビット (Argon2idから派生)\n• ノンス: ランダム生成 (96ビット)\n• タグ長: 128ビット (改ざん検知用)\n• 用途: 秘密鍵の暗号化保存';

  @override
  String get cryptoAesReference => '📚 参考: NIST SP 800-38D (GCM)';

  @override
  String get cryptoNip44Intro =>
      'NIP-44は、Nostrプロトコルにおける暗号化メッセージの標準規格です。楕円曲線暗号 (ECC) を使った安全なエンドツーエンド暗号化を提供します。';

  @override
  String get cryptoNip44MechanismTitle => '暗号化の仕組み';

  @override
  String get cryptoNip44MechanismDesc =>
      'NIP-44は、あなたの秘密鍵と受信者の公開鍵から「共有秘密 (shared secret)」を生成し、それを使ってメッセージを暗号化します。';

  @override
  String get cryptoNip44Process =>
      '暗号化プロセス:\n1. ECDH (Elliptic Curve Diffie-Hellman)\n   → secp256k1曲線で共有秘密を生成\n\n2. HMAC-SHA256による鍵派生 (HKDF)\n   → 暗号化鍵とメッセージ認証鍵を生成\n\n3. ChaCha20-Poly1305で暗号化\n   → 高速かつ安全なAEAD暗号化\n\n4. Base64エンコードして送信';

  @override
  String get cryptoNip44UsageTitle => 'Meisoでの利用';

  @override
  String get cryptoNip44UsageDesc =>
      'Meisoでは、全てのTodoデータをNIP-44で暗号化してNostrリレーに保存します。これにより、リレーサーバーはあなたのタスク内容を読み取ることができません。';

  @override
  String get cryptoNip44SecurityTitle => '🔐 重要なセキュリティ特性';

  @override
  String get cryptoNip44SecurityDesc =>
      '• リレーサーバーは暗号文しか見えません\n• あなた自身の秘密鍵がないと復号化できません\n• 前方秘匿性 (Forward Secrecy) は提供されません\n• 秘密鍵が漏洩すると過去の全メッセージが復号化されます';

  @override
  String get cryptoNip44Reference => '📚 参考: NIP-44 仕様';

  @override
  String get cryptoEd25519Intro =>
      'Ed25519は、楕円曲線暗号 (ECC) に基づく最新の署名アルゴリズムです。Bitcoin、SSH、TLS 1.3など、最新のセキュリティプロトコルで広く採用されています。';

  @override
  String get cryptoEd25519AdvantagesTitle => 'Ed25519の優位性';

  @override
  String get cryptoEd25519Speed => '高速';

  @override
  String get cryptoEd25519SpeedDesc =>
      'RSA-2048の10倍以上の速度で署名・検証が可能。モバイルデバイスでも高速動作します。';

  @override
  String get cryptoEd25519Compact => 'コンパクト';

  @override
  String get cryptoEd25519CompactDesc =>
      '公開鍵: 32バイト、秘密鍵: 32バイト、署名: 64バイト。RSAの1/8のサイズで同等以上のセキュリティ。';

  @override
  String get cryptoEd25519Deterministic => '決定論的';

  @override
  String get cryptoEd25519DeterministicDesc =>
      '同じメッセージに対して常に同じ署名を生成。乱数生成器の脆弱性リスクがありません。';

  @override
  String get cryptoEd25519SafeImpl => '実装が安全';

  @override
  String get cryptoEd25519SafeImplDesc => 'サイドチャネル攻撃に対する耐性が設計段階から組み込まれています。';

  @override
  String get cryptoEd25519NostrRoleTitle => 'Nostrでの役割';

  @override
  String get cryptoEd25519NostrRoleDesc =>
      'Nostrでは、全てのイベント (メッセージ、Todo、プロフィール更新など)にEd25519署名が付けられます。これにより、イベントの作成者の真正性と、データの完全性が保証されます。';

  @override
  String get cryptoEd25519SigningProcess =>
      'Nostr署名プロセス:\n1. イベントをJSON形式でシリアライズ\n2. SHA-256でハッシュ化\n3. Ed25519秘密鍵で署名\n4. 署名をイベントに添付して送信';

  @override
  String get cryptoEd25519Reference => '📚 参考: RFC 8032 (EdDSA)';

  @override
  String get cryptoAmberIntro =>
      'Amberは、Nostr秘密鍵を安全に管理するための専用アプリです。秘密鍵を他のアプリと共有せず、署名リクエストのみを処理します。';

  @override
  String get cryptoAmberNcryptsecTitle => 'ncryptsec形式';

  @override
  String get cryptoAmberNcryptsecDesc =>
      'Amberは、秘密鍵を「ncryptsec」形式で保存します。これは、AES-256-CBCで暗号化された秘密鍵を含むBech32エンコードされた文字列です。';

  @override
  String get cryptoAmberNcryptsecStructure =>
      'ncryptsec構造:\nncryptsec1... ← Bech32プレフィックス\n├─ バージョン (1バイト)\n├─ ソルト (16バイト)\n├─ ノンス/IV (16バイト)\n├─ 暗号化された秘密鍵 (32バイト)\n└─ 改ざん検知用タグ';

  @override
  String get cryptoAmberBenefitsTitle => 'Amberモードのメリット';

  @override
  String get cryptoAmberIsolation => '秘密鍵の隔離';

  @override
  String get cryptoAmberIsolationDesc => 'Meisoは秘密鍵を保持せず、署名が必要な時だけAmberに依頼します。';

  @override
  String get cryptoAmberBiometric => '生体認証';

  @override
  String get cryptoAmberBiometricDesc => 'Amberで署名時に指紋認証やPINを要求できます。';

  @override
  String get cryptoAmberAuditable => '監査可能';

  @override
  String get cryptoAmberAuditableDesc => 'Amberアプリで全ての署名リクエストを確認・承認できます。';

  @override
  String get cryptoAmberKeyReuse => '鍵の再利用';

  @override
  String get cryptoAmberKeyReuseDesc => '1つの秘密鍵を複数のNostrアプリで安全に共有できます。';

  @override
  String get cryptoAmberHardwareWalletTitle => '💡 ハードウェアウォレットとの類似性';

  @override
  String get cryptoAmberHardwareWalletDesc =>
      'Amberは、Bitcoinのハードウェアウォレット (Ledger、Trezor) と同じ「秘密鍵を外部に出さない」アーキテクチャを採用しています。';

  @override
  String get cryptoAmberReference => '🔗 Amber on GitHub';

  @override
  String get cryptoSecureStorageIntro =>
      'Meisoの秘密鍵管理は、全てRustで実装されています。Rustは、メモリ安全性が言語レベルで保証された、セキュアなシステムプログラミング言語です。';

  @override
  String get cryptoStorageWhyRustTitle => 'なぜRust？';

  @override
  String get cryptoStorageMemorySafety => 'メモリ安全性';

  @override
  String get cryptoStorageMemorySafetyDesc =>
      'バッファオーバーフロー、Use-after-free、データ競合などのメモリ関連の脆弱性が原理的に発生しません。';

  @override
  String get cryptoStorageZeroCost => 'ゼロコスト抽象化';

  @override
  String get cryptoStorageZeroCostDesc => '高レベルなコードを書きながら、C/C++と同等のパフォーマンスを実現。';

  @override
  String get cryptoStorageTypeSystem => '強力な型システム';

  @override
  String get cryptoStorageTypeSystemDesc =>
      'Option型やResult型により、エラーハンドリングが強制されます。';

  @override
  String get cryptoStorageImplTitle => 'ストレージの実装';

  @override
  String get cryptoStorageImplDesc =>
      'Meisoは、暗号化された秘密鍵をFlutterの「ApplicationSupportDirectory」に保存します。このディレクトリは、OSによって他のアプリからアクセスできないよう保護されています。';

  @override
  String get cryptoStoragePath =>
      'ストレージパス (Android):\n/data/data/com.example.meiso/files/encrypted_key.bin\n\nファイル内容:\n• JSON形式\n• フィールド: salt, nonce, ciphertext\n• 全て Base64 エンコード済み';

  @override
  String get cryptoStorageMemorySecurityTitle => 'メモリセキュリティ';

  @override
  String get cryptoStorageZeroize => 'Zeroize';

  @override
  String get cryptoStorageZeroizeDesc => '秘密鍵を使用後、メモリから安全に消去します。';

  @override
  String get cryptoStorageStackAllocation => 'スタック割り当て';

  @override
  String get cryptoStorageStackAllocationDesc => '秘密鍵をヒープではなくスタックに配置し、寿命を最小化。';

  @override
  String get cryptoStorageMemoryDump => 'メモリダンプ対策';

  @override
  String get cryptoStorageMemoryDumpDesc =>
      'デバッグビルドでもRustコードは最適化され、機密データが残りにくい。';

  @override
  String get cryptoThreatModelIntro =>
      'Meisoは非常に強力な暗号技術を使用していますが、完璧なセキュリティは存在しません。以下の脅威を理解してください。';

  @override
  String get cryptoThreatWhatWeCanProtectTitle => '保護できること';

  @override
  String get cryptoThreatNetworkEavesdropping => 'ネットワーク盗聴';

  @override
  String get cryptoThreatNetworkEavesdroppingDesc =>
      'TLS + E2EE暗号化により、通信経路での盗聴は無効化されます。';

  @override
  String get cryptoThreatMaliciousRelay => 'リレーサーバーの悪意';

  @override
  String get cryptoThreatMaliciousRelayDesc => 'リレーは暗号化されたデータしか見えません。';

  @override
  String get cryptoThreatBruteForce => 'ブルートフォース攻撃';

  @override
  String get cryptoThreatBruteForceDesc =>
      'Argon2id + AES-256により、現実的な時間での解読は不可能。';

  @override
  String get cryptoThreatWhatWeCannotProtectTitle => '保護できないこと';

  @override
  String get cryptoThreatWarningTitle => '⚠️ 以下の脅威には注意が必要です';

  @override
  String get cryptoThreatWarningDesc =>
      '• デバイスの物理的な盗難 + パスワード漏洩\n• キーロガーやスクリーンキャプチャマルウェア\n• ルート化/Jailbreak済みデバイス\n• OSやファームウェアの脆弱性\n• ソーシャルエンジニアリング攻撃\n• 量子コンピュータによる将来的な脅威 (RSA/ECCの破綻)';

  @override
  String get cryptoThreatBestPracticesTitle => 'ベストプラクティス';

  @override
  String get cryptoThreatStrongPassword => '強力なパスワード';

  @override
  String get cryptoThreatStrongPasswordDesc => '20文字以上のランダムなパスワードを使用してください。';

  @override
  String get cryptoThreatDeviceEncryption => 'デバイスの暗号化';

  @override
  String get cryptoThreatDeviceEncryptionDesc =>
      'Android/iOSのフルディスク暗号化を有効にしてください。';

  @override
  String get cryptoThreatKeepOsUpdated => 'OSを最新に保つ';

  @override
  String get cryptoThreatKeepOsUpdatedDesc => 'セキュリティパッチを定期的に適用してください。';

  @override
  String get cryptoThreatRecommendAmber => 'Amberモードの推奨';

  @override
  String get cryptoThreatRecommendAmberDesc =>
      'より高いセキュリティが必要な場合は、Amberモードを使用してください。';

  @override
  String get cryptoTableOfContents => '📖 目次';

  @override
  String get cryptoTocItem1 => '1. アーキテクチャ概要';

  @override
  String get cryptoTocItem2 => '2. Argon2id - パスワード派生関数';

  @override
  String get cryptoTocItem3 => '3. AES-256-GCM - 暗号化アルゴリズム';

  @override
  String get cryptoTocItem4 => '4. NIP-44 - Nostr暗号化規格';

  @override
  String get cryptoTocItem5 => '5. Ed25519 - デジタル署名';

  @override
  String get cryptoTocItem6 => '6. Amber統合 - ハードウェアウォレット的セキュリティ';

  @override
  String get cryptoTocItem7 => '7. セキュアストレージ - Rust実装';

  @override
  String get cryptoTocItem8 => '8. 脅威モデルと制限事項';

  @override
  String get cryptoFooterSecurityTitle => '🔒 セキュリティに関する質問や報告';

  @override
  String get cryptoFooterSecurityDesc =>
      'セキュリティ上の問題を発見した場合は、GitHubのIssueまたはNostr (DM) でご報告ください。';

  @override
  String get cryptoFooterOpenSource => 'すべてのコードはオープンソースです';

  @override
  String get cryptographyDetailsDescription => 'Meisoで採用している暗号技術の詳細';

  @override
  String get synced => '同期済み';

  @override
  String syncedWithEventId(String eventId) {
    return '同期済み (Event ID: $eventId...)';
  }

  @override
  String get sendingToRelay => 'リレーに送信中...';

  @override
  String get sentToRelay => '✅ リレーに送信しました';

  @override
  String get sendToRelay => 'リレーに送信する';

  @override
  String get todoAddFeatureInDevelopment => 'Todo追加機能は開発中です';

  @override
  String get mlsGroupBackupTitle => 'MLSグループバックアップ';

  @override
  String get mlsGroupBackupSubtitle => 'Key Packageをエクスポート/インポート';

  @override
  String get mlsBackupDescription =>
      'Key Packageをエクスポート/インポートして、\nアプリ再インストール後も既存のグループに再参加できます。';

  @override
  String get exportButton => 'エクスポート';

  @override
  String get importButton => 'インポート';

  @override
  String get mlsBackupImportInstruction =>
      'Settings > Advanced > MLSグループバックアップ\nからインポートしてください。';

  @override
  String get exportingBackup => '📤 エクスポート中...';

  @override
  String get backupCopiedToClipboard =>
      '✅ バックアップをクリップボードにコピーしました\n\n安全な場所に保存してください。';

  @override
  String get clipboardCopied => '📋 クリップボードにコピーしました';

  @override
  String exportFailed(String error) {
    return '❌ エクスポートに失敗しました\n\n$error';
  }

  @override
  String get noBackupDataInClipboard => '❌ クリップボードにバックアップデータがありません';

  @override
  String get confirmImportBackup =>
      'バックアップをインポートしますか？\n\n⚠️ インポート後、アプリを再起動してください。';

  @override
  String get importingBackup => '📥 インポート中...';

  @override
  String get backupImportedRestart => '✅ バックアップをインポートしました\n\n🔄 アプリを再起動してください。';

  @override
  String get importCompletedRestart => '✅ インポート完了。アプリを再起動してください';

  @override
  String importFailed(String error) {
    return '❌ インポートに失敗しました\n\n$error';
  }

  @override
  String get ifYouHaveBackup => 'バックアップがある場合';

  @override
  String get ifYouDontHaveBackup => 'バックアップがない場合';

  @override
  String get requestReinviteFromAdmin => 'グループ管理者に再度招待をリクエストしてください。';

  @override
  String inviteAcceptanceFailed(String error) {
    return '招待の受諾に失敗しました\n\n$error';
  }

  @override
  String get subtasksHeader => 'サブタスク';

  @override
  String get noSubtasks => 'サブタスクはまだありません';

  @override
  String get addSubtaskHint => 'サブタスクを追加...';

  @override
  String get linkedTasksHeader => 'リンクされたタスク';

  @override
  String get noLinkedTasks => 'リンクされたタスクはありません';

  @override
  String get linkTaskDialogTitle => 'タスクをリンク';

  @override
  String get linkTypeBlocks => 'ブロックしている';

  @override
  String get linkTypeBlockedBy => 'ブロックされている';

  @override
  String get linkTypeRelatedTo => '関連タスク';

  @override
  String get linkTypeDuplicateOf => '重複タスク';

  @override
  String get linkRelationship => '関係';

  @override
  String get linkTargetTask => '対象タスク';

  @override
  String get linkButton => 'リンク';

  @override
  String get noTasksToLink => 'リンクできるタスクがありません';
}
