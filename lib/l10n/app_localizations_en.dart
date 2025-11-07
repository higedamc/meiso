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
}
