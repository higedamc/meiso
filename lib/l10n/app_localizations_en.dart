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
      '✅ Connected with Amber mode\n\n🔒 Security features:\n• Sign todos with Amber when creating/editing\n• Protect content with NIP-44 encryption\n• Secret key stored encrypted with ncryptsec in Amber\n\n⚡ Decryption optimization:\nApproval is required when syncing todos.\nTo avoid approving every time, we recommend\nsetting \"Always allow Meiso app\" in Amber.\n\n📝 How to set up:\n1. Open Amber app\n2. Select \"Meiso\" from app list\n3. Set \"NIP-44 Decrypt\" to always allow';

  @override
  String get autoSyncInfoTitle => 'About Auto Sync';

  @override
  String get autoSyncInfo =>
      '• Task creation, editing, and deletion are automatically synced to Nostr\n• Latest data is automatically fetched on app startup\n• Always syncs in the background when relay is connected\n• Manual sync button is no longer needed';

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
}
