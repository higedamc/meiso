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
      '✅ Amberモードで接続中\n\n🔒 セキュリティ機能:\n• タスクの作成・編集時にAmberで署名\n• NIP-44暗号化でコンテンツを保護\n• 秘密鍵はAmber内でncryptsec準拠で暗号化保存\n\n⚡ 復号化の最適化:\nタスクの同期時に復号化の承認が必要です。\n毎回承認するのを避けるために、Amberアプリで\n「Meisoアプリを常に許可」を設定することを推奨します。\n\n📝 設定方法:\n1. Amberアプリを開く\n2. アプリ一覧から「Meiso」を選択\n3. 「NIP-44 Decrypt」を常に許可に設定';

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
}
