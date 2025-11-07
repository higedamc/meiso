import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ja'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Meiso'**
  String get appTitle;

  /// Title for the first onboarding page
  ///
  /// In en, this message translates to:
  /// **'Welcome to Meiso'**
  String get onboardingWelcomeTitle;

  /// Description for the first onboarding page
  ///
  /// In en, this message translates to:
  /// **'Simple and beautiful To-Do app\nSync with Nostr, manage tasks everywhere'**
  String get onboardingWelcomeDescription;

  /// Title for the Nostr sync onboarding page
  ///
  /// In en, this message translates to:
  /// **'Sync with Nostr'**
  String get onboardingNostrSyncTitle;

  /// Description for the Nostr sync onboarding page
  ///
  /// In en, this message translates to:
  /// **'Sync your tasks via Nostr network\nAutomatically stay up-to-date across multiple devices'**
  String get onboardingNostrSyncDescription;

  /// Title for the smart date input onboarding page
  ///
  /// In en, this message translates to:
  /// **'Smart Date Input'**
  String get onboardingSmartDateTitle;

  /// Description for the smart date input onboarding page
  ///
  /// In en, this message translates to:
  /// **'Type \"tomorrow\" to create a task for tomorrow\nType \"every day\" to create recurring tasks easily'**
  String get onboardingSmartDateDescription;

  /// Title for the privacy onboarding page
  ///
  /// In en, this message translates to:
  /// **'Privacy First'**
  String get onboardingPrivacyTitle;

  /// Description for the privacy onboarding page
  ///
  /// In en, this message translates to:
  /// **'No central server. All data is under your control\nSecurely stored on Nostr\'s decentralized network'**
  String get onboardingPrivacyDescription;

  /// Title for the final onboarding page
  ///
  /// In en, this message translates to:
  /// **'Let\'s Get Started'**
  String get onboardingGetStartedTitle;

  /// Description for the final onboarding page
  ///
  /// In en, this message translates to:
  /// **'Log in with Amber or\ngenerate a new secret key to start'**
  String get onboardingGetStartedDescription;

  /// Button to skip onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipButton;

  /// Button to go to next page
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// Button to start using the app
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// Title for settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Status text when Nostr is connected
  ///
  /// In en, this message translates to:
  /// **'Nostr Connected'**
  String get nostrConnected;

  /// Status text when Nostr is connected via Amber
  ///
  /// In en, this message translates to:
  /// **'Nostr Connected (Amber)'**
  String get nostrConnectedAmber;

  /// Status text when Nostr is disconnected
  ///
  /// In en, this message translates to:
  /// **'Nostr Disconnected'**
  String get nostrDisconnected;

  /// Shows how many relays are connected
  ///
  /// In en, this message translates to:
  /// **'Relays: {count}/{total} connected'**
  String relaysConnectedCount(int count, int total);

  /// Menu item for secret key management
  ///
  /// In en, this message translates to:
  /// **'Secret Key Management'**
  String get secretKeyManagement;

  /// Status when secret key is configured
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get secretKeyConfigured;

  /// Status when secret key is not configured
  ///
  /// In en, this message translates to:
  /// **'Not Configured'**
  String get secretKeyNotConfigured;

  /// Menu item for relay management
  ///
  /// In en, this message translates to:
  /// **'Relay Server Management'**
  String get relayServerManagement;

  /// Shows how many relays are registered
  ///
  /// In en, this message translates to:
  /// **'{count} registered'**
  String relayCountRegistered(int count);

  /// Menu item for app settings
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// Subtitle for app settings
  ///
  /// In en, this message translates to:
  /// **'Theme, Calendar, Notifications, Tor'**
  String get appSettingsSubtitle;

  /// Menu item for debug logs
  ///
  /// In en, this message translates to:
  /// **'Debug Logs'**
  String get debugLogs;

  /// Subtitle for debug logs
  ///
  /// In en, this message translates to:
  /// **'View log history'**
  String get debugLogsSubtitle;

  /// Title for Amber mode info card
  ///
  /// In en, this message translates to:
  /// **'Amber Mode'**
  String get amberModeTitle;

  /// Information about Amber mode
  ///
  /// In en, this message translates to:
  /// **'✅ Connected with Amber mode\n\n🔒 Security features:\n• Sign todos with Amber when creating/editing\n• Protect content with NIP-44 encryption\n• Secret key stored encrypted with ncryptsec in Amber\n\n⚡ Decryption optimization:\nApproval is required when syncing todos.\nTo avoid approving every time, we recommend\nsetting \"Always allow Meiso app\" in Amber.\n\n📝 How to set up:\n1. Open Amber app\n2. Select \"Meiso\" from app list\n3. Set \"NIP-44 Decrypt\" to always allow'**
  String get amberModeInfo;

  /// Title for auto sync info card
  ///
  /// In en, this message translates to:
  /// **'About Auto Sync'**
  String get autoSyncInfoTitle;

  /// Information about auto sync
  ///
  /// In en, this message translates to:
  /// **'• Task creation, editing, and deletion are automatically synced to Nostr\n• Latest data is automatically fetched on app startup\n• Always syncs in the background when relay is connected\n• Manual sync button is no longer needed'**
  String get autoSyncInfo;

  /// Version information text
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String versionInfo(String version, String buildNumber);

  /// Label for today's tasks
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayLabel;

  /// Label for tomorrow's tasks
  ///
  /// In en, this message translates to:
  /// **'TOMORROW'**
  String get tomorrowLabel;

  /// Label for someday tasks
  ///
  /// In en, this message translates to:
  /// **'SOMEDAY'**
  String get somedayLabel;

  /// Placeholder text for adding a task
  ///
  /// In en, this message translates to:
  /// **'Add a task...'**
  String get addTaskPlaceholder;

  /// Title for edit task dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTaskTitle;

  /// Placeholder for task title input
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitlePlaceholder;

  /// Button to save changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// Button to cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Button to delete item
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// Button to undo action
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// Message when task is deleted
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// Language settings menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettings;

  /// Option to use system language
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Japanese language option
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// Spanish language option
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Dark mode setting
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Dark mode is enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get darkModeEnabled;

  /// Dark mode is disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get darkModeDisabled;

  /// Tor settings
  ///
  /// In en, this message translates to:
  /// **'Tor (Orbot)'**
  String get torSettings;

  /// Tor is enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get torEnabled;

  /// Tor is disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get torDisabled;

  /// Short name for Monday
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mondayShort;

  /// Short name for Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesdayShort;

  /// Short name for Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesdayShort;

  /// Short name for Thursday
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursdayShort;

  /// Short name for Friday
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fridayShort;

  /// Short name for Saturday
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturdayShort;

  /// Short name for Sunday
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sundayShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
