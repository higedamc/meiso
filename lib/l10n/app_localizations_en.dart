// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Meiso';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Meiso';

  @override
  String get onboardingWelcomeDescription =>
      'Simple and beautiful To-Do app\nSync with Nostr, manage tasks everywhere';

  @override
  String get onboardingNostrSyncTitle => 'Sync with Nostr';

  @override
  String get onboardingNostrSyncDescription =>
      'Sync your tasks via Nostr network\nAutomatically stay up-to-date across multiple devices';

  @override
  String get onboardingSmartDateTitle => 'Smart Date Input';

  @override
  String get onboardingSmartDateDescription =>
      'Type \"tomorrow\" to create a task for tomorrow\nType \"every day\" to create recurring tasks easily';

  @override
  String get onboardingPrivacyTitle => 'Privacy First';

  @override
  String get onboardingPrivacyDescription =>
      'No central server. All data is under your control\nSecurely stored on Nostr\'s decentralized network';

  @override
  String get onboardingGetStartedTitle => 'Let\'s Get Started';

  @override
  String get onboardingGetStartedDescription =>
      'Log in with Amber or\ngenerate a new secret key to start';

  @override
  String get skipButton => 'Skip';

  @override
  String get nextButton => 'Next';

  @override
  String get startButton => 'Start';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get nostrConnected => 'Nostr Connected';

  @override
  String get nostrConnectedAmber => 'Nostr Connected (Amber)';

  @override
  String get nostrDisconnected => 'Nostr Disconnected';

  @override
  String get statusTapToReconnect => 'Tap to reconnect to relays';

  @override
  String relaysConnectedCount(int count, int total) {
    return 'Relays: $count/$total connected';
  }

  @override
  String get secretKeyManagement => 'Secret Key Management';

  @override
  String get secretKeyConfigured => 'Configured';

  @override
  String get secretKeyNotConfigured => 'Not Configured';

  @override
  String get relayServerManagement => 'Relay Server Management';

  @override
  String relayCountRegistered(int count) {
    return '$count registered';
  }

  @override
  String get appSettings => 'App Settings';

  @override
  String get appSettingsSubtitle => 'Theme, Calendar, Notifications, Tor';

  @override
  String get debugLogs => 'Debug Logs';

  @override
  String get debugLogsSubtitle => 'View log history';

  @override
  String get amberModeTitle => 'Amber Mode';

  @override
  String get amberModeInfo =>
      '✅ Connected with Amber mode\n\n🔒 Security features:\n• Sign tasks with Amber when creating/editing\n• Protect content with NIP-44 encryption\n• Secret key stored encrypted with ncryptsec in Amber\n\n⚡ Recommended Settings to Avoid UX Issues:\nGrant Meiso \"basic actions or higher permissions\" in Amber\nto avoid approval dialogs and ensure smooth usage.\n\n📝 How to set up:\n1. Open Amber app\n2. Go to Settings → Connected Apps → Select \"Meiso\"\n3. Set Basic actions (NIP-44 Decrypt/Encrypt, Sign Event) to \"Always allow\"';

  @override
  String get autoSyncInfoTitle => 'About Auto Sync';

  @override
  String get autoSyncInfo =>
      '• Task creation, editing, and deletion are automatically synced to Nostr\n• Latest data is automatically fetched on app startup\n• Always syncs in the background when relay is connected\n• Manual sync button is no longer needed';

  @override
  String get closeButton => 'Close';

  @override
  String get copyButton => 'Copy';

  @override
  String get fetchButton => 'Fetch';

  @override
  String get advancedSectionTitle => 'Advanced';

  @override
  String get advancedSectionSubtitle => 'Developer features';

  @override
  String get settingsNip89ClientTagTitle => 'NIP-89 client tag on events';

  @override
  String get settingsNip89ClientTagSubtitle =>
      'Helps relays and tools identify Meiso. Turn off if you prefer not to send this metadata.';

  @override
  String get keyPackagePublishTitle => 'Publish Key Package';

  @override
  String get keyPackagePublishSubtitle => 'Required to receive group invites';

  @override
  String get mlsIntegrationTestTitle => 'MLS Integration Test (PoC)';

  @override
  String get mlsIntegrationTestSubtitle =>
      'Option B: verify with 1-person group';

  @override
  String get keyPackagePublishDialogTitle => 'Publish Key Package';

  @override
  String get keyPackagePublishDialogBody =>
      'This will publish your Key Package to relays.\n\nOnce published, other users can invite you to groups.\n\nContinue?';

  @override
  String get publishButton => 'Publish';

  @override
  String get publishingKeyPackage => 'Publishing Key Package...';

  @override
  String get keyPackagePublishCompletedTitle => 'Publish completed';

  @override
  String get keyPackagePublishCompletedMessage =>
      'Published Key Package to relays!';

  @override
  String get keyPackagePublishCompletedDescription =>
      'Other users can now invite you to groups using your npub.';

  @override
  String get eventIdLabel => 'Event ID';

  @override
  String get keyPackagePublishFailedTitle => 'Publish failed';

  @override
  String keyPackagePublishFailedBody(String error) {
    return 'Failed to publish Key Package.\n\nError: $error';
  }

  @override
  String get keyPackagePublishNoEventIdError => 'Failed to get event id';

  @override
  String get mlsTestDialogTitle => 'MLS Integration Test';

  @override
  String get mlsTestDialogSubtitle => 'Option B PoC: 2-person group test';

  @override
  String get mlsYourKeyPackageLabel => '📋 Your Key Package:';

  @override
  String get keyPackageCopied => 'Key Package copied';

  @override
  String get mlsPeerNpubLabel => 'Peer npub';

  @override
  String get mlsPeerNpubHint => 'npub1...';

  @override
  String get mlsPressTestButton => 'Press a test button';

  @override
  String get mlsGenerateKpButton => 'Generate KP';

  @override
  String get mlsPublishKpButton => 'Publish KP';

  @override
  String get mlsCreate2PersonGroupButton => 'Create 2-person group';

  @override
  String get mlsSendTodoButton => 'Send TODO';

  @override
  String get mlsOnePersonTestButton => '1-person test';

  @override
  String get mlsRunning => 'Running...';

  @override
  String get mlsUserPublicKeyNotAvailable => 'User public key not available';

  @override
  String get mlsTwoPersonTestGroupName => '2 Person Test Group';

  @override
  String get mlsTestListName => 'MLS Test List';

  @override
  String get mlsTwoPersonTestTodoTitle => 'Test TODO for 2 Person Group';

  @override
  String get mlsOnePersonTestTodoTitle => 'Test TODO in MLS Group';

  @override
  String get deleteRecurringTodoTitle => 'Delete recurring task';

  @override
  String get removeThisInstance => 'Remove this instance';

  @override
  String get removeAllInstances => 'Remove all instances';

  @override
  String get updateRecurringTodoTitle => 'Update recurring task';

  @override
  String get updateThisInstance => 'Update this instance only';

  @override
  String get updateAllInstances => 'Update all instances';

  @override
  String get todoJsonTitle => 'Todo JSON';

  @override
  String get jsonCopied => 'JSON copied';

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
  String get addTaskPlaceholder => 'Add a task...';

  @override
  String get editTaskTitle => 'Edit Task';

  @override
  String get taskTitlePlaceholder => 'Task title';

  @override
  String get saveButton => 'Save';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteButton => 'Delete';

  @override
  String get undoButton => 'Undo';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String taskDeletedWithTitle(String title) {
    return '\"$title\" deleted';
  }

  @override
  String todoMovedToNextDay(String title) {
    return '\"$title\" moved to next day';
  }

  @override
  String allInstancesDeleted(String title) {
    return 'All instances of \"$title\" deleted';
  }

  @override
  String get languageSettings => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSpanish => 'Español';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeEnabled => 'Enabled';

  @override
  String get darkModeDisabled => 'Disabled';

  @override
  String get torSettings => 'Tor (Orbot)';

  @override
  String get torEnabled => 'Enabled';

  @override
  String get torDisabled => 'Disabled';

  @override
  String get mondayShort => 'Mon';

  @override
  String get tuesdayShort => 'Tue';

  @override
  String get wednesdayShort => 'Wed';

  @override
  String get thursdayShort => 'Thu';

  @override
  String get fridayShort => 'Fri';

  @override
  String get saturdayShort => 'Sat';

  @override
  String get sundayShort => 'Sun';

  @override
  String get loginMethodTitle => 'Choose Login Method';

  @override
  String get loginMethodDescription =>
      'Log in with Nostr account\nto sync your tasks';

  @override
  String get loginWithAmber => 'Login with Amber';

  @override
  String get or => 'or';

  @override
  String get generateNewKey => 'Generate New Key';

  @override
  String get keyStorageNote =>
      'Keys are stored securely.\nAmber provides enhanced security.';

  @override
  String get amberPermissionsNote =>
      '💡 To avoid UX issues:\nWhen logging in with Amber, we recommend granting \"basic actions or higher permissions\".\nYou can configure this in Settings → Connected Apps → Meiso.';

  @override
  String get amberRequired => 'Amber Required';

  @override
  String get amberNotInstalled =>
      'Amber app is not installed.\nWould you like to install it from Google Play?';

  @override
  String get install => 'Install';

  @override
  String get error => 'Error';

  @override
  String loginProcessError(String error) {
    return 'An error occurred during login process\n$error';
  }

  @override
  String get ok => 'OK';

  @override
  String get noPublicKeyReceived => 'Failed to retrieve public key from Amber';

  @override
  String amberConnectionFailed(String error) {
    return 'Failed to connect with Amber\n$error';
  }

  @override
  String get setPassword => 'Set Password';

  @override
  String get setPasswordDescription =>
      'Please set a password to encrypt your secret key.';

  @override
  String get password => 'Password';

  @override
  String get passwordConfirm => 'Password (Confirm)';

  @override
  String get passwordRequired => 'Please enter a password';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get secretKeyGenerated => 'Secret Key Generated';

  @override
  String get backupSecretKey =>
      'Please backup your secret key to a safe location.';

  @override
  String get secretKeyNsec => 'Secret Key (nsec):';

  @override
  String get publicKeyNpub => 'Public Key (npub):';

  @override
  String get secretKeyWarning =>
      'If you lose this secret key, you will lose access to your account. Please backup it.';

  @override
  String get backupCompleted => 'Backup Completed';

  @override
  String keypairGenerationFailed(String error) {
    return 'Failed to generate keypair\n\n$error';
  }

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get weekStartDay => 'Week Start Day';

  @override
  String get selectWeekStartDay => 'Select Week Start Day';

  @override
  String get calendarView => 'Calendar View';

  @override
  String get selectCalendarView => 'Select Calendar View';

  @override
  String get weekView => 'Week View';

  @override
  String get monthView => 'Month View';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Enable reminder notifications';

  @override
  String get torConnection => 'Connect via Tor (Orbot)';

  @override
  String torEnabledSubtitle(String proxyUrl) {
    return 'Connecting via Orbot proxy ($proxyUrl)';
  }

  @override
  String get torDisabledSubtitle => 'Not using Orbot (Direct connection)';

  @override
  String get torEnabledMessage =>
      'Tor enabled. Will apply from next connection.\nPlease start Orbot app.';

  @override
  String get torDisabledMessage =>
      'Tor disabled. Will apply from next connection.';

  @override
  String get proxyAddress => 'Proxy Address and Port';

  @override
  String get proxySettings => 'Proxy Settings';

  @override
  String get proxySettingsDescription =>
      'Configure SOCKS5 proxy address and port';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get hostRequired => 'Please enter host';

  @override
  String get portRequired => 'Please enter port';

  @override
  String get portRangeError => 'Port number must be between 1-65535';

  @override
  String proxyUrlUpdated(String url) {
    return 'Proxy URL updated: $url';
  }

  @override
  String get commonSettings =>
      'Common settings:\n• Orbot: 127.0.0.1:9050\n• Custom proxy: Enter host and port';

  @override
  String get proxyConnectionStatus => 'Proxy Connection Status';

  @override
  String get testButton => 'Test';

  @override
  String get untested => 'Untested';

  @override
  String get testing => 'Testing...';

  @override
  String get connectionSuccess => 'Connection Success';

  @override
  String get connectionFailed => 'Connection Failed (Please start Orbot)';

  @override
  String get appSettingsTitle => 'App Settings';

  @override
  String get appSettingsInfo => 'About App Settings';

  @override
  String get appSettingsInfoText =>
      '• App settings are stored locally\n• If Nostr is connected, settings sync automatically\n• You can share the same settings across multiple devices (NIP-78)\n• Changes are applied immediately\n\n🛡️ About Tor settings:\n• When Tor is enabled, connects to relays via Orbot proxy\n• Orbot app must be running\n• Privacy and security improve, but connection speed decreases\n• Reconnection required after changing settings';

  @override
  String get nostrAutoSync => 'Auto sync to Nostr relay (NIP-78 Kind 30078)';

  @override
  String get localStorageOnly => 'Local storage only (Nostr not connected)';

  @override
  String get languageSelection => 'Select Language';

  @override
  String syncingWithCount(int count) {
    return 'Syncing ($count)';
  }

  @override
  String get syncing => 'Syncing';

  @override
  String get syncCompleted => 'Sync Completed';

  @override
  String get syncError => 'Sync Error';

  @override
  String get timeout => 'Timeout';

  @override
  String get connectionError => 'Connection Error';

  @override
  String errorRetry(int count) {
    return 'Error (Retry $count)';
  }

  @override
  String get waiting => 'Waiting';

  @override
  String syncStep(int current, int total) {
    return 'Step $current / $total';
  }

  @override
  String get syncReconnectingRelays => 'Reconnecting relays...';

  @override
  String get syncPhaseDelta => 'Delta sync...';

  @override
  String get syncPhaseAppSettings => 'Syncing settings...';

  @override
  String get syncPhaseCustomLists => 'Syncing lists...';

  @override
  String get syncPhaseTodos => 'Syncing tasks...';

  @override
  String get syncPhaseMls => 'Syncing group tasks...';

  @override
  String get bootstrapPhaseContinueWithLocalCache =>
      'Continuing with local cache';

  @override
  String get bootstrapPhaseFetchingAccountRelays =>
      'Fetching relays linked to account...';

  @override
  String get bootstrapPhaseFetchingLocalTodos =>
      'Fetching tasks from local relay...';

  @override
  String get bootstrapPhaseFetchingLocalGroupTodos =>
      'Fetching group tasks from local relay...';

  @override
  String get bootstrapPhaseFetchingAllRelaysTodos =>
      'Fetching tasks from all relays...';

  @override
  String get bootstrapPhaseFetchingAllRelaysGroupTodos =>
      'Fetching group tasks from all relays...';

  @override
  String get bootstrapPhaseFetchingGroupInvitations =>
      'Fetching group invitations...';

  @override
  String get bootstrapPhaseCompleted => 'Sync completed';

  @override
  String get bootstrapPhaseFailed => 'Sync failed';

  @override
  String get bootstrapContinueWithLocalCacheButton =>
      'Continue with local cache';

  @override
  String get retryButton => 'Retry';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours hr ago';
  }

  @override
  String get secretKeyManagementTitle => 'Secret Key Management';

  @override
  String get enterPassword => 'Enter Password';

  @override
  String get enterPasswordToDecrypt => 'Enter password to decrypt secret key.';

  @override
  String get enterPasswordToEncrypt => 'Enter password to encrypt secret key.';

  @override
  String secretKeyEncrypted(String format) {
    return 'Secret key encrypted and saved ($format)';
  }

  @override
  String get formatUnknown => 'Unknown format';

  @override
  String get connectedToRelay => 'Connected to relay';

  @override
  String get connectedToRelayViaTor => 'Connected to relay (via Tor)';

  @override
  String get invalidSecretKeyFormat =>
      'Invalid secret key format. Please enter nsec or hex format.';

  @override
  String get encrypted => '🔒 Encrypted';

  @override
  String get relayManagementTitle => 'Relay Server Management';

  @override
  String get relayUrlError => 'Relay URL must start with wss:// or ws://';

  @override
  String get relayAddedAndSaved => 'Relay added and immediately saved to Nostr';

  @override
  String relayAddedButSaveFailed(String error) {
    return 'Relay added but failed to save to Nostr: $error';
  }

  @override
  String get relayRemovedAndSaved =>
      'Relay removed and immediately saved to Nostr';

  @override
  String relayRemovedButSaveFailed(String error) {
    return 'Relay removed but failed to save to Nostr: $error';
  }

  @override
  String get noRelayListOnNostr => 'No relay list found on Nostr';

  @override
  String relaySyncSuccess(int count) {
    return 'Successfully synced $count relays from Nostr';
  }

  @override
  String relaySyncError(String error) {
    return 'Failed to sync from Nostr: $error';
  }

  @override
  String get syncFromNostr => 'Sync from Nostr';

  @override
  String get addRelay => 'Add Relay';

  @override
  String get relayUrl => 'Relay URL';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get cryptographyTitle => 'Cryptography Details';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get logoutDescription =>
      'Encrypted secret key will be deleted.\nPlease save your secret key before logout.';

  @override
  String get torModeDisabled => 'Disabled';

  @override
  String get torModeInternal => 'Internal (Embedded)';

  @override
  String get torModeOrbot => 'Orbot (Proxy)';

  @override
  String get torModeDescriptionDisabled => 'Direct connection without Tor';

  @override
  String get torModeDescriptionInternal =>
      'Use embedded Tor client (under development, not available yet)';

  @override
  String get torModeDescriptionOrbot =>
      'Connect via Orbot app (requires Orbot installation)';

  @override
  String get torConnectionModeTitle => 'Tor Connection Mode';

  @override
  String get inDevelopment => '(in development)';

  @override
  String torModeUpdated(String mode) {
    return 'Tor mode updated: $mode';
  }

  @override
  String get orbotRequired => 'Orbot Required';

  @override
  String get orbotRequiredDescription =>
      'Orbot app must be installed and running to use this mode.';

  @override
  String get openGooglePlayOrbot => 'Open Google Play: Orbot';

  @override
  String get openFDroidOrbot => 'Open F-Droid: Orbot';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get fDroid => 'F-Droid';

  @override
  String get embeddedTorDescription =>
      'Using embedded Tor client. No additional apps required.';

  @override
  String get secretKeyNsecLabel => 'Secret Key (nsec)';

  @override
  String copiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get copyNpub => 'Copy npub';

  @override
  String get copyHex => 'Copy hex';

  @override
  String get generateButton => 'Generate';

  @override
  String get saveAndConnect => 'Save and Connect';

  @override
  String get nostrConnectedStatus => 'Nostr Connected';

  @override
  String get nostrConnectedViaTor => 'Nostr Connected (via Tor)';

  @override
  String get nostrDisconnectedStatus => 'Nostr Disconnected';

  @override
  String get passwordIncorrectOrDecryptFailed =>
      'Password is incorrect or secret key decryption failed';

  @override
  String secretKeyDecryptFailed(String error) {
    return 'Secret key decryption failed: $error';
  }

  @override
  String secretKeyGenerationFailed(String error) {
    return 'Secret key generation failed: $error';
  }

  @override
  String secretKeySaveFailed(String error) {
    return 'Secret key save failed: $error';
  }

  @override
  String relayConnectionError(String error) {
    return 'Relay connection error: $error';
  }

  @override
  String logoutFailed(String error) {
    return 'Logout failed: $error';
  }

  @override
  String get loggingInAmber => 'Logging in (Amber)';

  @override
  String get amberModeConnected => '✅ Connected with Amber mode\n\n';

  @override
  String get secretKeySaveAutoConnect =>
      '• Saving secret key will automatically connect to relay\n';

  @override
  String get multipleRelaysRedundancy =>
      '• Connecting to multiple relays improves redundancy\n';

  @override
  String get nostrNotInitialized =>
      'Nostr is not initialized. Please connect from settings screen.';

  @override
  String sendError(String error) {
    return '❌ Send error: $error';
  }

  @override
  String get syncLoadingData => 'Loading data...';

  @override
  String get syncMigratingData => 'Migrating data...';

  @override
  String get syncSyncingData => 'Syncing data...';

  @override
  String get syncPreparingMigration => 'Preparing data migration...';

  @override
  String get syncFetchingOldData => 'Fetching old data...';

  @override
  String get syncConvertingToNewFormat => 'Converting to new format...';

  @override
  String get syncDeletingOldData => 'Deleting old data...';

  @override
  String get syncMigrationCompleted => 'Data migration completed';

  @override
  String get aboutRelays => 'About Relays';

  @override
  String get amberMode => 'Amber Mode';

  @override
  String get cryptographyInUse => 'Cryptography in Use';

  @override
  String get cryptographyDetailsUsedInMeiso =>
      'Details of Cryptography Used in Meiso';

  @override
  String get cryptographyIntroTitle =>
      'Meiso adopts the highest standards of modern cryptography.';

  @override
  String get cryptographyIntroDescription =>
      'This document explains the details of the cryptographic technologies used in Meiso for Bitcoiners and Nostriches.';

  @override
  String get cryptoArchitectureTitle => '1. Architecture Overview';

  @override
  String get cryptoArgon2idTitle =>
      '2. Argon2id - Password Derivation Function';

  @override
  String get cryptoAes256GcmTitle => '3. AES-256-GCM - Encryption Algorithm';

  @override
  String get cryptoNip44Title => '4. NIP-44 - Nostr Encryption Standard';

  @override
  String get cryptoEd25519Title => '5. Ed25519 - Digital Signature';

  @override
  String get cryptoAmberIntegrationTitle =>
      '6. Amber Integration - Hardware Wallet-like Security';

  @override
  String get cryptoSecureStorageTitle =>
      '7. Secure Storage - Rust Implementation';

  @override
  String get cryptoThreatModelTitle => '8. Threat Model and Limitations';

  @override
  String get relayList => 'Relay List';

  @override
  String get noRelaysRegistered => 'No relays registered';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get aboutRelaysDescription =>
      '• Relays are servers on the Nostr network\n• Connecting to multiple relays improves redundancy\n• Relay URLs must start with wss:// or ws://\n• Adding/removing relays are immediately saved to Nostr (Kind 10002)\n• Relay changes take effect immediately (no restart required)\n• Use the \"Sync from Nostr\" button to fetch settings from other devices\n• During sync, only updates if remote and local differ';

  @override
  String get currentlyConnectedViaTor =>
      '• Currently connected via Tor (using Orbot proxy)';

  @override
  String get localRelayCitrine => 'Local Relay (Citrine)';

  @override
  String get localRelayDescription =>
      'A local relay running on your device for fast caching and offline support. Events are mirrored here after successful global sync.';

  @override
  String get localRelayEnabled => 'Enabled';

  @override
  String get localRelayUrl => 'Local relay URL';

  @override
  String get globalRelays => 'Global Relays';

  @override
  String get cryptoArchPara1 =>
      'Meiso adopts a \"Zero-Knowledge Architecture\" and never sends your secret keys or task data to servers. All encryption processing is performed on your device.';

  @override
  String get cryptoArchSecurityModel =>
      'Security Model:\n• End-to-End Encryption (E2EE)\n• Client-side encryption\n• Server stores only encrypted data\n• Only you hold the secret keys';

  @override
  String get cryptoArgon2Intro =>
      'Argon2id is the latest and strongest password hashing algorithm, winner of the 2015 Password Hashing Competition (PHC).';

  @override
  String get cryptoArgon2WhyTitle => 'Why Argon2id?';

  @override
  String get cryptoArgon2BruteForce => 'Brute-force attack resistance';

  @override
  String get cryptoArgon2BruteForceDesc =>
      'Requires both computational and memory costs, making it extremely resistant to parallel attacks using GPUs or ASICs.';

  @override
  String get cryptoArgon2SideChannel => 'Side-channel attack resistance';

  @override
  String get cryptoArgon2SideChannelDesc =>
      'A \"hybrid\" combining Argon2i\'s unpredictable memory access patterns with Argon2d\'s computational efficiency.';

  @override
  String get cryptoArgon2Standard => 'Industry standard';

  @override
  String get cryptoArgon2StandardDesc =>
      'Recommended by OWASP, NIST, and the Cryptography Engineering community. Next-generation standard surpassing bcrypt and PBKDF2.';

  @override
  String get cryptoArgon2Params =>
      'Implementation parameters in Meiso:\n• Memory cost: 19 MiB (optimized)\n• Iterations: 2 times\n• Parallelism: 1 thread\n• Output length: 32 bytes (256 bits)\n• Salt: Random generation (16 bytes)';

  @override
  String get cryptoArgon2Reference => '📚 Reference: Argon2 RFC 9106';

  @override
  String get cryptoAesIntro =>
      'AES-256-GCM is an \"Authenticated Encryption with Associated Data (AEAD)\" algorithm used by the U.S. government to protect classified information.';

  @override
  String get cryptoAesStrengthTitle => 'Strength of AES-256';

  @override
  String get cryptoAesStrengthDesc =>
      'AES-256 has a key space of 2^256, making brute-force attacks practically impossible even with modern supercomputers. It maintains 128-bit effective security even in the quantum computing era.';

  @override
  String get cryptoAesGcmAdvantagesTitle => 'Advantages of GCM Mode';

  @override
  String get cryptoAesAead => 'Authenticated Encryption (AEAD)';

  @override
  String get cryptoAesAeadDesc =>
      'Generates a Message Authentication Code (MAC) simultaneously with encryption. Enables detection of data tampering.';

  @override
  String get cryptoAesPerformance => 'High-speed processing';

  @override
  String get cryptoAesPerformanceDesc =>
      'Enables parallel processing and is hardware-accelerated by modern CPUs\' AES-NI instructions.';

  @override
  String get cryptoAesPaddingResistance => 'Padding attack resistance';

  @override
  String get cryptoAesPaddingResistanceDesc =>
      'As a stream cipher mode, there is no risk of padding oracle attacks.';

  @override
  String get cryptoAesParams =>
      'Implementation in Meiso:\n• Encryption algorithm: AES-256-GCM\n• Key length: 256 bits (derived from Argon2id)\n• Nonce: Random generation (96 bits)\n• Tag length: 128 bits (for tamper detection)\n• Purpose: Encrypted storage of secret keys';

  @override
  String get cryptoAesReference => '📚 Reference: NIST SP 800-38D (GCM)';

  @override
  String get cryptoNip44Intro =>
      'NIP-44 is the standard specification for encrypted messages in the Nostr protocol. It provides secure end-to-end encryption using Elliptic Curve Cryptography (ECC).';

  @override
  String get cryptoNip44MechanismTitle => 'Encryption Mechanism';

  @override
  String get cryptoNip44MechanismDesc =>
      'NIP-44 generates a \"shared secret\" from your secret key and the recipient\'s public key, and uses it to encrypt messages.';

  @override
  String get cryptoNip44Process =>
      'Encryption Process:\n1. ECDH (Elliptic Curve Diffie-Hellman)\n   → Generate shared secret with secp256k1 curve\n\n2. Key derivation with HMAC-SHA256 (HKDF)\n   → Generate encryption key and message authentication key\n\n3. Encrypt with ChaCha20-Poly1305\n   → Fast and secure AEAD encryption\n\n4. Base64 encode and transmit';

  @override
  String get cryptoNip44UsageTitle => 'Usage in Meiso';

  @override
  String get cryptoNip44UsageDesc =>
      'In Meiso, all Todo data is encrypted with NIP-44 and stored on Nostr relays. This prevents relay servers from reading your task contents.';

  @override
  String get cryptoNip44SecurityTitle =>
      '🔐 Important Security Characteristics';

  @override
  String get cryptoNip44SecurityDesc =>
      '• Relay servers can only see ciphertext\n• Cannot be decrypted without your own secret key\n• Forward Secrecy is not provided\n• If the secret key is leaked, all past messages can be decrypted';

  @override
  String get cryptoNip44Reference => '📚 Reference: NIP-44 Specification';

  @override
  String get cryptoEd25519Intro =>
      'Ed25519 is a modern signature algorithm based on Elliptic Curve Cryptography (ECC). It is widely adopted in modern security protocols such as Bitcoin, SSH, and TLS 1.3.';

  @override
  String get cryptoEd25519AdvantagesTitle => 'Advantages of Ed25519';

  @override
  String get cryptoEd25519Speed => 'Fast';

  @override
  String get cryptoEd25519SpeedDesc =>
      'More than 10 times faster than RSA-2048 for signing and verification. Runs fast even on mobile devices.';

  @override
  String get cryptoEd25519Compact => 'Compact';

  @override
  String get cryptoEd25519CompactDesc =>
      'Public key: 32 bytes, Private key: 32 bytes, Signature: 64 bytes. 1/8 the size of RSA with equal or better security.';

  @override
  String get cryptoEd25519Deterministic => 'Deterministic';

  @override
  String get cryptoEd25519DeterministicDesc =>
      'Always generates the same signature for the same message. No risk of random number generator vulnerabilities.';

  @override
  String get cryptoEd25519SafeImpl => 'Safe implementation';

  @override
  String get cryptoEd25519SafeImplDesc =>
      'Resistance to side-channel attacks is built in from the design stage.';

  @override
  String get cryptoEd25519NostrRoleTitle => 'Role in Nostr';

  @override
  String get cryptoEd25519NostrRoleDesc =>
      'In Nostr, all events (messages, Todos, profile updates, etc.) are signed with Ed25519. This guarantees the authenticity of the event creator and the integrity of the data.';

  @override
  String get cryptoEd25519SigningProcess =>
      'Nostr signing process:\n1. Serialize event in JSON format\n2. Hash with SHA-256\n3. Sign with Ed25519 private key\n4. Attach signature to event and send';

  @override
  String get cryptoEd25519Reference => '📚 Reference: RFC 8032 (EdDSA)';

  @override
  String get cryptoAmberIntro =>
      'Amber is a dedicated app for securely managing Nostr secret keys. It does not share secret keys with other apps and only processes signing requests.';

  @override
  String get cryptoAmberNcryptsecTitle => 'ncryptsec Format';

  @override
  String get cryptoAmberNcryptsecDesc =>
      'Amber stores secret keys in \"ncryptsec\" format. This is a Bech32-encoded string containing a secret key encrypted with AES-256-CBC.';

  @override
  String get cryptoAmberNcryptsecStructure =>
      'ncryptsec structure:\nncryptsec1... ← Bech32 prefix\n├─ Version (1 byte)\n├─ Salt (16 bytes)\n├─ Nonce/IV (16 bytes)\n├─ Encrypted secret key (32 bytes)\n└─ Tamper detection tag';

  @override
  String get cryptoAmberBenefitsTitle => 'Benefits of Amber Mode';

  @override
  String get cryptoAmberIsolation => 'Secret key isolation';

  @override
  String get cryptoAmberIsolationDesc =>
      'Meiso does not hold secret keys and only requests Amber when signing is needed.';

  @override
  String get cryptoAmberBiometric => 'Biometric authentication';

  @override
  String get cryptoAmberBiometricDesc =>
      'Can require fingerprint authentication or PIN when signing with Amber.';

  @override
  String get cryptoAmberAuditable => 'Auditable';

  @override
  String get cryptoAmberAuditableDesc =>
      'Can review and approve all signing requests in the Amber app.';

  @override
  String get cryptoAmberKeyReuse => 'Key reuse';

  @override
  String get cryptoAmberKeyReuseDesc =>
      'Can securely share one secret key across multiple Nostr apps.';

  @override
  String get cryptoAmberHardwareWalletTitle =>
      '💡 Similarity to Hardware Wallets';

  @override
  String get cryptoAmberHardwareWalletDesc =>
      'Amber adopts the same \"never export secret keys\" architecture as Bitcoin hardware wallets (Ledger, Trezor).';

  @override
  String get cryptoAmberReference => '🔗 Amber on GitHub';

  @override
  String get cryptoSecureStorageIntro =>
      'Meiso\'s secret key management is entirely implemented in Rust. Rust is a secure systems programming language with memory safety guaranteed at the language level.';

  @override
  String get cryptoStorageWhyRustTitle => 'Why Rust?';

  @override
  String get cryptoStorageMemorySafety => 'Memory safety';

  @override
  String get cryptoStorageMemorySafetyDesc =>
      'Memory-related vulnerabilities such as buffer overflow, use-after-free, and data races are fundamentally impossible.';

  @override
  String get cryptoStorageZeroCost => 'Zero-cost abstractions';

  @override
  String get cryptoStorageZeroCostDesc =>
      'Achieves C/C++ equivalent performance while writing high-level code.';

  @override
  String get cryptoStorageTypeSystem => 'Strong type system';

  @override
  String get cryptoStorageTypeSystemDesc =>
      'Option and Result types enforce error handling.';

  @override
  String get cryptoStorageImplTitle => 'Storage Implementation';

  @override
  String get cryptoStorageImplDesc =>
      'Meiso stores encrypted secret keys in Flutter\'s \"ApplicationSupportDirectory\". This directory is protected by the OS from access by other apps.';

  @override
  String get cryptoStoragePath =>
      'Storage path (Android):\n/data/data/com.example.meiso/files/encrypted_key.bin\n\nFile contents:\n• JSON format\n• Fields: salt, nonce, ciphertext\n• All Base64 encoded';

  @override
  String get cryptoStorageMemorySecurityTitle => 'Memory Security';

  @override
  String get cryptoStorageZeroize => 'Zeroize';

  @override
  String get cryptoStorageZeroizeDesc =>
      'Safely erases secret keys from memory after use.';

  @override
  String get cryptoStorageStackAllocation => 'Stack allocation';

  @override
  String get cryptoStorageStackAllocationDesc =>
      'Places secret keys on the stack rather than the heap, minimizing lifetime.';

  @override
  String get cryptoStorageMemoryDump => 'Memory dump countermeasures';

  @override
  String get cryptoStorageMemoryDumpDesc =>
      'Rust code is optimized even in debug builds, making sensitive data less likely to remain.';

  @override
  String get cryptoThreatModelIntro =>
      'Meiso uses very strong cryptographic technologies, but perfect security does not exist. Please understand the following threats.';

  @override
  String get cryptoThreatWhatWeCanProtectTitle => 'What We Can Protect';

  @override
  String get cryptoThreatNetworkEavesdropping => 'Network eavesdropping';

  @override
  String get cryptoThreatNetworkEavesdroppingDesc =>
      'TLS + E2EE encryption neutralizes eavesdropping on communication paths.';

  @override
  String get cryptoThreatMaliciousRelay => 'Malicious relay servers';

  @override
  String get cryptoThreatMaliciousRelayDesc =>
      'Relays can only see encrypted data.';

  @override
  String get cryptoThreatBruteForce => 'Brute-force attacks';

  @override
  String get cryptoThreatBruteForceDesc =>
      'Argon2id + AES-256 makes decryption impossible in realistic time.';

  @override
  String get cryptoThreatWhatWeCannotProtectTitle => 'What We Cannot Protect';

  @override
  String get cryptoThreatWarningTitle =>
      '⚠️ The following threats require attention';

  @override
  String get cryptoThreatWarningDesc =>
      '• Physical device theft + password leak\n• Keylogger or screen capture malware\n• Rooted/Jailbroken devices\n• OS or firmware vulnerabilities\n• Social engineering attacks\n• Future threats from quantum computers (RSA/ECC breakdown)';

  @override
  String get cryptoThreatBestPracticesTitle => 'Best Practices';

  @override
  String get cryptoThreatStrongPassword => 'Strong password';

  @override
  String get cryptoThreatStrongPasswordDesc =>
      'Use a random password of 20 characters or more.';

  @override
  String get cryptoThreatDeviceEncryption => 'Device encryption';

  @override
  String get cryptoThreatDeviceEncryptionDesc =>
      'Enable full disk encryption on Android/iOS.';

  @override
  String get cryptoThreatKeepOsUpdated => 'Keep OS up to date';

  @override
  String get cryptoThreatKeepOsUpdatedDesc =>
      'Apply security patches regularly.';

  @override
  String get cryptoThreatRecommendAmber => 'Amber mode recommended';

  @override
  String get cryptoThreatRecommendAmberDesc =>
      'If higher security is required, use Amber mode.';

  @override
  String get cryptoTableOfContents => '📖 Table of Contents';

  @override
  String get cryptoTocItem1 => '1. Architecture Overview';

  @override
  String get cryptoTocItem2 => '2. Argon2id - Password Derivation Function';

  @override
  String get cryptoTocItem3 => '3. AES-256-GCM - Encryption Algorithm';

  @override
  String get cryptoTocItem4 => '4. NIP-44 - Nostr Encryption Standard';

  @override
  String get cryptoTocItem5 => '5. Ed25519 - Digital Signatures';

  @override
  String get cryptoTocItem6 =>
      '6. Amber Integration - Hardware Wallet-like Security';

  @override
  String get cryptoTocItem7 => '7. Secure Storage - Rust Implementation';

  @override
  String get cryptoTocItem8 => '8. Threat Model and Limitations';

  @override
  String get cryptoFooterSecurityTitle => '🔒 Security Questions and Reports';

  @override
  String get cryptoFooterSecurityDesc =>
      'If you discover a security issue, please report it via GitHub Issues or Nostr (DM).';

  @override
  String get cryptoFooterOpenSource => 'All code is open source';

  @override
  String get cryptographyDetailsDescription =>
      'Details of cryptographic technologies used in Meiso';

  @override
  String get synced => 'Synced';

  @override
  String syncedWithEventId(String eventId) {
    return 'Synced (Event ID: $eventId...)';
  }

  @override
  String get sendingToRelay => 'Sending to relay...';

  @override
  String get sentToRelay => '✅ Sent to relay';

  @override
  String get sendToRelay => 'Send to relay';

  @override
  String get todoAddFeatureInDevelopment =>
      'Todo add feature is under development';

  @override
  String get mlsGroupBackupTitle => 'MLS Group Backup';

  @override
  String get mlsGroupBackupSubtitle => 'Export/Import Key Package';

  @override
  String get mlsBackupDescription =>
      'Export/import Key Package to rejoin existing groups\nafter app reinstallation.';

  @override
  String get exportButton => 'Export';

  @override
  String get importButton => 'Import';

  @override
  String get mlsBackupImportInstruction =>
      'Please import from\nSettings > Advanced > MLS Group Backup.';

  @override
  String get exportingBackup => '📤 Exporting...';

  @override
  String get backupCopiedToClipboard =>
      '✅ Backup copied to clipboard\n\nPlease save it in a secure location.';

  @override
  String get clipboardCopied => '📋 Copied to clipboard';

  @override
  String exportFailed(String error) {
    return '❌ Export failed\n\n$error';
  }

  @override
  String get noBackupDataInClipboard => '❌ No backup data in clipboard';

  @override
  String get confirmImportBackup =>
      'Import backup?\n\n⚠️ Please restart the app after import.';

  @override
  String get importingBackup => '📥 Importing...';

  @override
  String get backupImportedRestart =>
      '✅ Backup imported\n\n🔄 Please restart the app.';

  @override
  String get importCompletedRestart =>
      '✅ Import completed. Please restart the app';

  @override
  String importFailed(String error) {
    return '❌ Import failed\n\n$error';
  }

  @override
  String get ifYouHaveBackup => 'If you have a backup';

  @override
  String get ifYouDontHaveBackup => 'If you don\'t have a backup';

  @override
  String get requestReinviteFromAdmin =>
      'Please request a re-invitation from the group admin.';

  @override
  String inviteAcceptanceFailed(String error) {
    return 'Invite acceptance failed\n\n$error';
  }

  @override
  String get subtasksHeader => 'SUBTASKS';

  @override
  String get noSubtasks => 'No subtasks yet';

  @override
  String get addSubtaskHint => 'Add subtask...';

  @override
  String get linkedTasksHeader => 'LINKED TASKS';

  @override
  String get noLinkedTasks => 'No linked tasks';

  @override
  String get linkTaskDialogTitle => 'LINK TASK';

  @override
  String get linkTypeBlocks => 'Blocks';

  @override
  String get linkTypeBlockedBy => 'Blocked by';

  @override
  String get linkTypeRelatedTo => 'Related to';

  @override
  String get linkTypeDuplicateOf => 'Duplicate of';

  @override
  String get linkRelationship => 'Relationship';

  @override
  String get linkTargetTask => 'Target task';

  @override
  String get linkButton => 'LINK';

  @override
  String get noTasksToLink => 'No tasks available to link';

  @override
  String get hideCompletedTasks => 'Hide Completed Tasks';

  @override
  String get hideCompletedTasksSubtitle => 'Hide completed tasks in all views';

  @override
  String get attachImage => 'Attach Image';

  @override
  String get removeImage => 'Remove Image';

  @override
  String get uploadingImage => 'Uploading image...';

  @override
  String imageUploadFailed(String reason) {
    return 'Image upload failed: $reason';
  }

  @override
  String get imageUploaded => 'Image attached successfully';

  @override
  String get imageSourceCamera => 'Camera';

  @override
  String get imageSourceGallery => 'Gallery';

  @override
  String get mediaServers => 'Media Servers';

  @override
  String get mediaServersSubtitle => 'Manage Blossom / NIP-96 upload servers';

  @override
  String get addMediaServer => 'Add Server';

  @override
  String get mediaServerUrl => 'Server URL';

  @override
  String get mediaServerType => 'Server Type';

  @override
  String get mediaServerManual => 'Manual';

  @override
  String get mediaServerAutoDiscovered => 'Auto-discovered (Kind 10063)';

  @override
  String get deleteMediaServer => 'Delete Server';

  @override
  String get noMediaServers =>
      'No media servers configured. Add a server or connect to Nostr to auto-discover.';

  @override
  String get mediaServerAdded => 'Media server added';

  @override
  String get mediaServerDeleted => 'Media server removed';

  @override
  String get invalidUrl => 'Please enter a valid URL';

  @override
  String get refreshServers => 'Refresh Servers';

  @override
  String get selectUploadServer => 'Upload to';

  @override
  String get noServersFound =>
      'No upload servers found. Add a server URL below.';

  @override
  String get addCustomServer => 'Use custom URL';

  @override
  String get customServerUrlHint => 'https://example.com';

  @override
  String get upload => 'Upload';

  @override
  String get parentTaskLabel => 'PARENT TASK';

  @override
  String get parentTaskNone => 'None';

  @override
  String get selectParentTask => 'Select parent task';

  @override
  String get removeParentTask => 'Remove parent';

  @override
  String get convertToSubtaskSuccess => 'Converted to subtask';

  @override
  String get promotedToRootSuccess => 'Promoted to root task';

  @override
  String get cannotDemoteHasSubtasks =>
      'Remove subtasks first to convert this task';

  @override
  String get addedByCollaborator => 'Added by a collaborator';

  @override
  String get addedBy => 'Added by';

  @override
  String get settingsSectionStatus => 'Status';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionAbout => 'About';
}
