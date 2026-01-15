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
  /// **'✅ Connected with Amber mode\n\n🔒 Security features:\n• Sign tasks with Amber when creating/editing\n• Protect content with NIP-44 encryption\n• Secret key stored encrypted with ncryptsec in Amber\n\n⚡ Decryption optimization:\nApproval is required when syncing tasks.\nTo avoid approving every time, we recommend\nsetting \"Always allow Meiso app\" in Amber.\n\n📝 How to set up:\n1. Open Amber app\n2. Select \"Meiso\" from app list\n3. Set \"NIP-44 Decrypt\" to always allow'**
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

  /// Button to close a dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// Button to copy content
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// Button to fetch/receive data
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get fetchButton;

  /// Title for advanced section in settings
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSectionTitle;

  /// Subtitle for advanced section in settings
  ///
  /// In en, this message translates to:
  /// **'Developer features'**
  String get advancedSectionSubtitle;

  /// Menu title for publishing Key Package
  ///
  /// In en, this message translates to:
  /// **'Publish Key Package'**
  String get keyPackagePublishTitle;

  /// Menu subtitle for publishing Key Package
  ///
  /// In en, this message translates to:
  /// **'Required to receive group invites'**
  String get keyPackagePublishSubtitle;

  /// Menu title for MLS integration test
  ///
  /// In en, this message translates to:
  /// **'MLS Integration Test (PoC)'**
  String get mlsIntegrationTestTitle;

  /// Menu subtitle for MLS integration test
  ///
  /// In en, this message translates to:
  /// **'Option B: verify with 1-person group'**
  String get mlsIntegrationTestSubtitle;

  /// Dialog title for publishing Key Package
  ///
  /// In en, this message translates to:
  /// **'Publish Key Package'**
  String get keyPackagePublishDialogTitle;

  /// Dialog body for publishing Key Package
  ///
  /// In en, this message translates to:
  /// **'This will publish your Key Package to relays.\n\nOnce published, other users can invite you to groups.\n\nContinue?'**
  String get keyPackagePublishDialogBody;

  /// Button to publish
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishButton;

  /// Text shown while publishing Key Package
  ///
  /// In en, this message translates to:
  /// **'Publishing Key Package...'**
  String get publishingKeyPackage;

  /// Dialog title for successful Key Package publish
  ///
  /// In en, this message translates to:
  /// **'Publish completed'**
  String get keyPackagePublishCompletedTitle;

  /// Message shown after successful Key Package publish
  ///
  /// In en, this message translates to:
  /// **'Published Key Package to relays!'**
  String get keyPackagePublishCompletedMessage;

  /// Description shown after successful Key Package publish
  ///
  /// In en, this message translates to:
  /// **'Other users can now invite you to groups using your npub.'**
  String get keyPackagePublishCompletedDescription;

  /// Label for event id
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get eventIdLabel;

  /// Dialog title for failed Key Package publish
  ///
  /// In en, this message translates to:
  /// **'Publish failed'**
  String get keyPackagePublishFailedTitle;

  /// Dialog body for failed Key Package publish
  ///
  /// In en, this message translates to:
  /// **'Failed to publish Key Package.\n\nError: {error}'**
  String keyPackagePublishFailedBody(String error);

  /// Error when event id is missing
  ///
  /// In en, this message translates to:
  /// **'Failed to get event id'**
  String get keyPackagePublishNoEventIdError;

  /// Title for MLS test dialog
  ///
  /// In en, this message translates to:
  /// **'MLS Integration Test'**
  String get mlsTestDialogTitle;

  /// Subtitle for MLS test dialog
  ///
  /// In en, this message translates to:
  /// **'Option B PoC: 2-person group test'**
  String get mlsTestDialogSubtitle;

  /// Label for your key package
  ///
  /// In en, this message translates to:
  /// **'📋 Your Key Package:'**
  String get mlsYourKeyPackageLabel;

  /// Snackbar message after copying key package
  ///
  /// In en, this message translates to:
  /// **'Key Package copied'**
  String get keyPackageCopied;

  /// Label for peer npub input
  ///
  /// In en, this message translates to:
  /// **'Peer npub'**
  String get mlsPeerNpubLabel;

  /// Hint for peer npub input
  ///
  /// In en, this message translates to:
  /// **'npub1...'**
  String get mlsPeerNpubHint;

  /// Placeholder message when no logs
  ///
  /// In en, this message translates to:
  /// **'Press a test button'**
  String get mlsPressTestButton;

  /// Button to generate key package
  ///
  /// In en, this message translates to:
  /// **'Generate KP'**
  String get mlsGenerateKpButton;

  /// Button to publish key package
  ///
  /// In en, this message translates to:
  /// **'Publish KP'**
  String get mlsPublishKpButton;

  /// Button to create 2-person group
  ///
  /// In en, this message translates to:
  /// **'Create 2-person group'**
  String get mlsCreate2PersonGroupButton;

  /// Button to send a test todo
  ///
  /// In en, this message translates to:
  /// **'Send TODO'**
  String get mlsSendTodoButton;

  /// Button to run 1-person MLS test
  ///
  /// In en, this message translates to:
  /// **'1-person test'**
  String get mlsOnePersonTestButton;

  /// Label shown while MLS test is running
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get mlsRunning;

  /// Error when user public key is not available
  ///
  /// In en, this message translates to:
  /// **'User public key not available'**
  String get mlsUserPublicKeyNotAvailable;

  /// Default group name for 2-person MLS test
  ///
  /// In en, this message translates to:
  /// **'2 Person Test Group'**
  String get mlsTwoPersonTestGroupName;

  /// Default list name for 1-person MLS test
  ///
  /// In en, this message translates to:
  /// **'MLS Test List'**
  String get mlsTestListName;

  /// Default todo title for 2-person MLS test
  ///
  /// In en, this message translates to:
  /// **'Test TODO for 2 Person Group'**
  String get mlsTwoPersonTestTodoTitle;

  /// Default todo title for 1-person MLS test
  ///
  /// In en, this message translates to:
  /// **'Test TODO in MLS Group'**
  String get mlsOnePersonTestTodoTitle;

  /// Title for recurring delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete recurring task'**
  String get deleteRecurringTodoTitle;

  /// Option to delete only this instance of a recurring todo
  ///
  /// In en, this message translates to:
  /// **'Remove this instance'**
  String get removeThisInstance;

  /// Option to delete all instances of a recurring todo
  ///
  /// In en, this message translates to:
  /// **'Remove all instances'**
  String get removeAllInstances;

  /// Title for recurring update confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Update recurring task'**
  String get updateRecurringTodoTitle;

  /// Option to update only this instance of a recurring todo
  ///
  /// In en, this message translates to:
  /// **'Update this instance only'**
  String get updateThisInstance;

  /// Option to update all instances of a recurring todo
  ///
  /// In en, this message translates to:
  /// **'Update all instances'**
  String get updateAllInstances;

  /// Title for the Todo JSON dialog
  ///
  /// In en, this message translates to:
  /// **'Todo JSON'**
  String get todoJsonTitle;

  /// Snackbar message after copying JSON
  ///
  /// In en, this message translates to:
  /// **'JSON copied'**
  String get jsonCopied;

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

  /// Title for login method selection
  ///
  /// In en, this message translates to:
  /// **'Choose Login Method'**
  String get loginMethodTitle;

  /// Description for login method
  ///
  /// In en, this message translates to:
  /// **'Log in with Nostr account\nto sync your tasks'**
  String get loginMethodDescription;

  /// Button to login with Amber
  ///
  /// In en, this message translates to:
  /// **'Login with Amber'**
  String get loginWithAmber;

  /// Separator text
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// Button to generate new secret key
  ///
  /// In en, this message translates to:
  /// **'Generate New Key'**
  String get generateNewKey;

  /// Note about key storage
  ///
  /// In en, this message translates to:
  /// **'Keys are stored securely.\nAmber provides enhanced security.'**
  String get keyStorageNote;

  /// Dialog title when Amber is not installed
  ///
  /// In en, this message translates to:
  /// **'Amber Required'**
  String get amberRequired;

  /// Message when Amber is not installed
  ///
  /// In en, this message translates to:
  /// **'Amber app is not installed.\nWould you like to install it from Google Play?'**
  String get amberNotInstalled;

  /// Button to install
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// Error dialog title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Error message during login
  ///
  /// In en, this message translates to:
  /// **'An error occurred during login process\n{error}'**
  String loginProcessError(String error);

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Error when no public key received
  ///
  /// In en, this message translates to:
  /// **'Failed to retrieve public key from Amber'**
  String get noPublicKeyReceived;

  /// Error when Amber connection fails
  ///
  /// In en, this message translates to:
  /// **'Failed to connect with Amber\n{error}'**
  String amberConnectionFailed(String error);

  /// Dialog title for setting password
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get setPassword;

  /// Description for password setting
  ///
  /// In en, this message translates to:
  /// **'Please set a password to encrypt your secret key.'**
  String get setPasswordDescription;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Password confirmation field label
  ///
  /// In en, this message translates to:
  /// **'Password (Confirm)'**
  String get passwordConfirm;

  /// Validation error for empty password
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get passwordRequired;

  /// Validation error for short password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// Validation error for mismatched passwords
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// Dialog title when key is generated
  ///
  /// In en, this message translates to:
  /// **'Secret Key Generated'**
  String get secretKeyGenerated;

  /// Instruction to backup secret key
  ///
  /// In en, this message translates to:
  /// **'Please backup your secret key to a safe location.'**
  String get backupSecretKey;

  /// Label for secret key in nsec format
  ///
  /// In en, this message translates to:
  /// **'Secret Key (nsec):'**
  String get secretKeyNsec;

  /// Label for public key in npub format
  ///
  /// In en, this message translates to:
  /// **'Public Key (npub):'**
  String get publicKeyNpub;

  /// Warning about losing secret key
  ///
  /// In en, this message translates to:
  /// **'If you lose this secret key, you will lose access to your account. Please backup it.'**
  String get secretKeyWarning;

  /// Button text after backing up key
  ///
  /// In en, this message translates to:
  /// **'Backup Completed'**
  String get backupCompleted;

  /// Error when keypair generation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to generate keypair\n\n{error}'**
  String keypairGenerationFailed(String error);

  /// Full name for Sunday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Full name for Monday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Full name for Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// Full name for Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// Full name for Thursday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// Full name for Friday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// Full name for Saturday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// Setting for week start day
  ///
  /// In en, this message translates to:
  /// **'Week Start Day'**
  String get weekStartDay;

  /// Dialog title for selecting week start day
  ///
  /// In en, this message translates to:
  /// **'Select Week Start Day'**
  String get selectWeekStartDay;

  /// Setting for calendar view
  ///
  /// In en, this message translates to:
  /// **'Calendar View'**
  String get calendarView;

  /// Dialog title for selecting calendar view
  ///
  /// In en, this message translates to:
  /// **'Select Calendar View'**
  String get selectCalendarView;

  /// Week view option
  ///
  /// In en, this message translates to:
  /// **'Week View'**
  String get weekView;

  /// Month view option
  ///
  /// In en, this message translates to:
  /// **'Month View'**
  String get monthView;

  /// Notifications setting
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Subtitle for notifications setting
  ///
  /// In en, this message translates to:
  /// **'Enable reminder notifications'**
  String get notificationsSubtitle;

  /// Setting for Tor connection
  ///
  /// In en, this message translates to:
  /// **'Connect via Tor (Orbot)'**
  String get torConnection;

  /// Subtitle when Tor is enabled
  ///
  /// In en, this message translates to:
  /// **'Connecting via Orbot proxy ({proxyUrl})'**
  String torEnabledSubtitle(String proxyUrl);

  /// Subtitle when Tor is disabled
  ///
  /// In en, this message translates to:
  /// **'Not using Orbot (Direct connection)'**
  String get torDisabledSubtitle;

  /// Message when Tor is enabled
  ///
  /// In en, this message translates to:
  /// **'Tor enabled. Will apply from next connection.\nPlease start Orbot app.'**
  String get torEnabledMessage;

  /// Message when Tor is disabled
  ///
  /// In en, this message translates to:
  /// **'Tor disabled. Will apply from next connection.'**
  String get torDisabledMessage;

  /// Setting for proxy address
  ///
  /// In en, this message translates to:
  /// **'Proxy Address and Port'**
  String get proxyAddress;

  /// Dialog title for proxy settings
  ///
  /// In en, this message translates to:
  /// **'Proxy Settings'**
  String get proxySettings;

  /// Description for proxy settings
  ///
  /// In en, this message translates to:
  /// **'Configure SOCKS5 proxy address and port'**
  String get proxySettingsDescription;

  /// Host field label
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// Port field label
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// Validation error for empty host
  ///
  /// In en, this message translates to:
  /// **'Please enter host'**
  String get hostRequired;

  /// Validation error for empty port
  ///
  /// In en, this message translates to:
  /// **'Please enter port'**
  String get portRequired;

  /// Validation error for invalid port range
  ///
  /// In en, this message translates to:
  /// **'Port number must be between 1-65535'**
  String get portRangeError;

  /// Message when proxy URL is updated
  ///
  /// In en, this message translates to:
  /// **'Proxy URL updated: {url}'**
  String proxyUrlUpdated(String url);

  /// Common proxy settings examples
  ///
  /// In en, this message translates to:
  /// **'Common settings:\n• Orbot: 127.0.0.1:9050\n• Custom proxy: Enter host and port'**
  String get commonSettings;

  /// Label for proxy connection status
  ///
  /// In en, this message translates to:
  /// **'Proxy Connection Status'**
  String get proxyConnectionStatus;

  /// Button to test connection
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testButton;

  /// Status when not tested
  ///
  /// In en, this message translates to:
  /// **'Untested'**
  String get untested;

  /// Status when testing
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// Status when connection succeeds
  ///
  /// In en, this message translates to:
  /// **'Connection Success'**
  String get connectionSuccess;

  /// Status when connection fails
  ///
  /// In en, this message translates to:
  /// **'Connection Failed (Please start Orbot)'**
  String get connectionFailed;

  /// Title for app settings screen
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettingsTitle;

  /// Title for app settings info
  ///
  /// In en, this message translates to:
  /// **'About App Settings'**
  String get appSettingsInfo;

  /// Information about app settings
  ///
  /// In en, this message translates to:
  /// **'• App settings are stored locally\n• If Nostr is connected, settings sync automatically\n• You can share the same settings across multiple devices (NIP-78)\n• Changes are applied immediately\n\n🛡️ About Tor settings:\n• When Tor is enabled, connects to relays via Orbot proxy\n• Orbot app must be running\n• Privacy and security improve, but connection speed decreases\n• Reconnection required after changing settings'**
  String get appSettingsInfoText;

  /// Status when Nostr auto sync is enabled
  ///
  /// In en, this message translates to:
  /// **'Auto sync to Nostr relay (NIP-78 Kind 30078)'**
  String get nostrAutoSync;

  /// Status when using local storage only
  ///
  /// In en, this message translates to:
  /// **'Local storage only (Nostr not connected)'**
  String get localStorageOnly;

  /// Dialog title for language selection
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get languageSelection;

  /// Syncing status with pending count
  ///
  /// In en, this message translates to:
  /// **'Syncing ({count})'**
  String syncingWithCount(int count);

  /// Syncing status
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncing;

  /// Sync completed status
  ///
  /// In en, this message translates to:
  /// **'Sync Completed'**
  String get syncCompleted;

  /// Sync error status
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get syncError;

  /// Timeout error
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get timeout;

  /// Connection error
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// Error with retry count
  ///
  /// In en, this message translates to:
  /// **'Error (Retry {count})'**
  String errorRetry(int count);

  /// Waiting status
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// Sync step counter
  ///
  /// In en, this message translates to:
  /// **'Step {current} / {total}'**
  String syncStep(int current, int total);

  /// Sync: reconnecting relays
  ///
  /// In en, this message translates to:
  /// **'Reconnecting relays...'**
  String get syncReconnectingRelays;

  /// Sync phase: delta
  ///
  /// In en, this message translates to:
  /// **'Delta sync...'**
  String get syncPhaseDelta;

  /// Sync phase: app settings
  ///
  /// In en, this message translates to:
  /// **'Syncing settings...'**
  String get syncPhaseAppSettings;

  /// Sync phase: custom lists
  ///
  /// In en, this message translates to:
  /// **'Syncing lists...'**
  String get syncPhaseCustomLists;

  /// Sync phase: tasks
  ///
  /// In en, this message translates to:
  /// **'Syncing tasks...'**
  String get syncPhaseTodos;

  /// Sync phase: MLS group tasks
  ///
  /// In en, this message translates to:
  /// **'Syncing group tasks...'**
  String get syncPhaseMls;

  /// Time indicator for recent sync
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Minutes ago time indicator
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// Hours ago time indicator
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String hoursAgo(int hours);

  /// Title for secret key management screen
  ///
  /// In en, this message translates to:
  /// **'Secret Key Management'**
  String get secretKeyManagementTitle;

  /// Dialog title for password entry
  ///
  /// In en, this message translates to:
  /// **'Enter Password'**
  String get enterPassword;

  /// Message for password entry
  ///
  /// In en, this message translates to:
  /// **'Enter password to decrypt secret key.'**
  String get enterPasswordToDecrypt;

  /// Message for password encryption
  ///
  /// In en, this message translates to:
  /// **'Enter password to encrypt secret key.'**
  String get enterPasswordToEncrypt;

  /// Success message for key encryption
  ///
  /// In en, this message translates to:
  /// **'Secret key encrypted and saved ({format})'**
  String secretKeyEncrypted(String format);

  /// Unknown key format
  ///
  /// In en, this message translates to:
  /// **'Unknown format'**
  String get formatUnknown;

  /// Success message for relay connection
  ///
  /// In en, this message translates to:
  /// **'Connected to relay'**
  String get connectedToRelay;

  /// Success message for relay connection via Tor
  ///
  /// In en, this message translates to:
  /// **'Connected to relay (via Tor)'**
  String get connectedToRelayViaTor;

  /// Error for invalid key format
  ///
  /// In en, this message translates to:
  /// **'Invalid secret key format. Please enter nsec or hex format.'**
  String get invalidSecretKeyFormat;

  /// Placeholder for encrypted key
  ///
  /// In en, this message translates to:
  /// **'🔒 Encrypted'**
  String get encrypted;

  /// Title for relay management screen
  ///
  /// In en, this message translates to:
  /// **'Relay Server Management'**
  String get relayManagementTitle;

  /// Error for invalid relay URL
  ///
  /// In en, this message translates to:
  /// **'Relay URL must start with wss:// or ws://'**
  String get relayUrlError;

  /// Success message for relay addition
  ///
  /// In en, this message translates to:
  /// **'Relay added and immediately saved to Nostr'**
  String get relayAddedAndSaved;

  /// Error message for relay save failure
  ///
  /// In en, this message translates to:
  /// **'Relay added but failed to save to Nostr: {error}'**
  String relayAddedButSaveFailed(String error);

  /// Success message for relay removal
  ///
  /// In en, this message translates to:
  /// **'Relay removed and immediately saved to Nostr'**
  String get relayRemovedAndSaved;

  /// Error message for relay removal save failure
  ///
  /// In en, this message translates to:
  /// **'Relay removed but failed to save to Nostr: {error}'**
  String relayRemovedButSaveFailed(String error);

  /// Message when no relay list on Nostr
  ///
  /// In en, this message translates to:
  /// **'No relay list found on Nostr'**
  String get noRelayListOnNostr;

  /// Success message for relay sync
  ///
  /// In en, this message translates to:
  /// **'Successfully synced {count} relays from Nostr'**
  String relaySyncSuccess(int count);

  /// Error message for relay sync failure
  ///
  /// In en, this message translates to:
  /// **'Failed to sync from Nostr: {error}'**
  String relaySyncError(String error);

  /// Button text to sync from Nostr
  ///
  /// In en, this message translates to:
  /// **'Sync from Nostr'**
  String get syncFromNostr;

  /// Button text to add relay
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get addRelay;

  /// Label for relay URL input
  ///
  /// In en, this message translates to:
  /// **'Relay URL'**
  String get relayUrl;

  /// Status for connected relay
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Status for connecting relay
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// Status for disconnected relay
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Title for cryptography details screen
  ///
  /// In en, this message translates to:
  /// **'Cryptography Details'**
  String get cryptographyTitle;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// Logout warning description
  ///
  /// In en, this message translates to:
  /// **'Encrypted secret key will be deleted.\nPlease save your secret key before logout.'**
  String get logoutDescription;

  /// Tor mode: Disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get torModeDisabled;

  /// Tor mode: Internal embedded Tor client
  ///
  /// In en, this message translates to:
  /// **'Internal (Embedded)'**
  String get torModeInternal;

  /// Tor mode: Orbot proxy
  ///
  /// In en, this message translates to:
  /// **'Orbot (Proxy)'**
  String get torModeOrbot;

  /// Description for disabled Tor mode
  ///
  /// In en, this message translates to:
  /// **'Direct connection without Tor'**
  String get torModeDescriptionDisabled;

  /// Description for internal Tor mode
  ///
  /// In en, this message translates to:
  /// **'Use embedded Tor client (under development, not available yet)'**
  String get torModeDescriptionInternal;

  /// Description for Orbot Tor mode
  ///
  /// In en, this message translates to:
  /// **'Connect via Orbot app (requires Orbot installation)'**
  String get torModeDescriptionOrbot;

  /// Title for Tor connection mode dialog
  ///
  /// In en, this message translates to:
  /// **'Tor Connection Mode'**
  String get torConnectionModeTitle;

  /// Label for features under development
  ///
  /// In en, this message translates to:
  /// **'(in development)'**
  String get inDevelopment;

  /// Message when Tor mode is updated
  ///
  /// In en, this message translates to:
  /// **'Tor mode updated: {mode}'**
  String torModeUpdated(String mode);

  /// Title for Orbot requirement notice
  ///
  /// In en, this message translates to:
  /// **'Orbot Required'**
  String get orbotRequired;

  /// Description for Orbot requirement
  ///
  /// In en, this message translates to:
  /// **'Orbot app must be installed and running to use this mode.'**
  String get orbotRequiredDescription;

  /// Snackbar message for Google Play link
  ///
  /// In en, this message translates to:
  /// **'Open Google Play: Orbot'**
  String get openGooglePlayOrbot;

  /// Snackbar message for F-Droid link
  ///
  /// In en, this message translates to:
  /// **'Open F-Droid: Orbot'**
  String get openFDroidOrbot;

  /// Google Play button label
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get googlePlay;

  /// F-Droid button label
  ///
  /// In en, this message translates to:
  /// **'F-Droid'**
  String get fDroid;

  /// Description for embedded Tor mode
  ///
  /// In en, this message translates to:
  /// **'Using embedded Tor client. No additional apps required.'**
  String get embeddedTorDescription;

  /// Label for secret key in nsec format
  ///
  /// In en, this message translates to:
  /// **'Secret Key (nsec)'**
  String get secretKeyNsecLabel;

  /// Message when text is copied
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// Button to copy npub
  ///
  /// In en, this message translates to:
  /// **'Copy npub'**
  String get copyNpub;

  /// Button to copy hex format
  ///
  /// In en, this message translates to:
  /// **'Copy hex'**
  String get copyHex;

  /// Button to generate new key
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generateButton;

  /// Button to save and connect
  ///
  /// In en, this message translates to:
  /// **'Save and Connect'**
  String get saveAndConnect;

  /// Status when Nostr is connected
  ///
  /// In en, this message translates to:
  /// **'Nostr Connected'**
  String get nostrConnectedStatus;

  /// Status when Nostr is connected via Tor
  ///
  /// In en, this message translates to:
  /// **'Nostr Connected (via Tor)'**
  String get nostrConnectedViaTor;

  /// Status when Nostr is disconnected
  ///
  /// In en, this message translates to:
  /// **'Nostr Disconnected'**
  String get nostrDisconnectedStatus;

  /// Error when password is wrong or decryption fails
  ///
  /// In en, this message translates to:
  /// **'Password is incorrect or secret key decryption failed'**
  String get passwordIncorrectOrDecryptFailed;

  /// Error message for decryption failure
  ///
  /// In en, this message translates to:
  /// **'Secret key decryption failed: {error}'**
  String secretKeyDecryptFailed(String error);

  /// Error message for key generation failure
  ///
  /// In en, this message translates to:
  /// **'Secret key generation failed: {error}'**
  String secretKeyGenerationFailed(String error);

  /// Error message for key save failure
  ///
  /// In en, this message translates to:
  /// **'Secret key save failed: {error}'**
  String secretKeySaveFailed(String error);

  /// Error message for relay connection failure
  ///
  /// In en, this message translates to:
  /// **'Relay connection error: {error}'**
  String relayConnectionError(String error);

  /// Error message for logout failure
  ///
  /// In en, this message translates to:
  /// **'Logout failed: {error}'**
  String logoutFailed(String error);

  /// Status when logging in via Amber
  ///
  /// In en, this message translates to:
  /// **'Logging in (Amber)'**
  String get loggingInAmber;

  /// Status prefix for Amber mode
  ///
  /// In en, this message translates to:
  /// **'✅ Connected with Amber mode\n\n'**
  String get amberModeConnected;

  /// Information about auto-connect
  ///
  /// In en, this message translates to:
  /// **'• Saving secret key will automatically connect to relay\n'**
  String get secretKeySaveAutoConnect;

  /// Information about relay redundancy
  ///
  /// In en, this message translates to:
  /// **'• Connecting to multiple relays improves redundancy\n'**
  String get multipleRelaysRedundancy;

  /// Error when Nostr is not initialized
  ///
  /// In en, this message translates to:
  /// **'Nostr is not initialized. Please connect from settings screen.'**
  String get nostrNotInitialized;

  /// Error message when sending fails
  ///
  /// In en, this message translates to:
  /// **'❌ Send error: {error}'**
  String sendError(String error);

  /// Message when loading data during sync
  ///
  /// In en, this message translates to:
  /// **'Loading data...'**
  String get syncLoadingData;

  /// Message when migrating data during sync
  ///
  /// In en, this message translates to:
  /// **'Migrating data...'**
  String get syncMigratingData;

  /// Message when syncing data
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get syncSyncingData;

  /// Message when preparing migration
  ///
  /// In en, this message translates to:
  /// **'Preparing data migration...'**
  String get syncPreparingMigration;

  /// Message when fetching old format data
  ///
  /// In en, this message translates to:
  /// **'Fetching old data...'**
  String get syncFetchingOldData;

  /// Message when converting data to new format
  ///
  /// In en, this message translates to:
  /// **'Converting to new format...'**
  String get syncConvertingToNewFormat;

  /// Message when deleting old format data
  ///
  /// In en, this message translates to:
  /// **'Deleting old data...'**
  String get syncDeletingOldData;

  /// Message when migration is completed
  ///
  /// In en, this message translates to:
  /// **'Data migration completed'**
  String get syncMigrationCompleted;

  /// Title for relay information section
  ///
  /// In en, this message translates to:
  /// **'About Relays'**
  String get aboutRelays;

  /// Title for Amber mode
  ///
  /// In en, this message translates to:
  /// **'Amber Mode'**
  String get amberMode;

  /// Title for cryptography section
  ///
  /// In en, this message translates to:
  /// **'Cryptography in Use'**
  String get cryptographyInUse;

  /// Detailed cryptography documentation intro
  ///
  /// In en, this message translates to:
  /// **'Details of Cryptography Used in Meiso'**
  String get cryptographyDetailsUsedInMeiso;

  /// Introduction title for cryptography details
  ///
  /// In en, this message translates to:
  /// **'Meiso adopts the highest standards of modern cryptography.'**
  String get cryptographyIntroTitle;

  /// Introduction description for cryptography details
  ///
  /// In en, this message translates to:
  /// **'This document explains the details of the cryptographic technologies used in Meiso for Bitcoiners and Nostriches.'**
  String get cryptographyIntroDescription;

  /// Section title for architecture
  ///
  /// In en, this message translates to:
  /// **'1. Architecture Overview'**
  String get cryptoArchitectureTitle;

  /// Section title for Argon2id
  ///
  /// In en, this message translates to:
  /// **'2. Argon2id - Password Derivation Function'**
  String get cryptoArgon2idTitle;

  /// Section title for AES-256-GCM
  ///
  /// In en, this message translates to:
  /// **'3. AES-256-GCM - Encryption Algorithm'**
  String get cryptoAes256GcmTitle;

  /// Section title for NIP-44
  ///
  /// In en, this message translates to:
  /// **'4. NIP-44 - Nostr Encryption Standard'**
  String get cryptoNip44Title;

  /// Section title for Ed25519
  ///
  /// In en, this message translates to:
  /// **'5. Ed25519 - Digital Signature'**
  String get cryptoEd25519Title;

  /// Section title for Amber integration
  ///
  /// In en, this message translates to:
  /// **'6. Amber Integration - Hardware Wallet-like Security'**
  String get cryptoAmberIntegrationTitle;

  /// Section title for secure storage
  ///
  /// In en, this message translates to:
  /// **'7. Secure Storage - Rust Implementation'**
  String get cryptoSecureStorageTitle;

  /// Section title for threat model
  ///
  /// In en, this message translates to:
  /// **'8. Threat Model and Limitations'**
  String get cryptoThreatModelTitle;

  /// Title for relay list section
  ///
  /// In en, this message translates to:
  /// **'Relay List'**
  String get relayList;

  /// Message when no relays are registered
  ///
  /// In en, this message translates to:
  /// **'No relays registered'**
  String get noRelaysRegistered;

  /// Tooltip for delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// Description of relay functionality
  ///
  /// In en, this message translates to:
  /// **'• Relays are servers on the Nostr network\n• Connecting to multiple relays improves redundancy\n• Relay URLs must start with wss:// or ws://\n• Adding/removing relays are immediately saved to Nostr (Kind 10002)\n• Relay changes take effect immediately (no restart required)\n• Use the \"Sync from Nostr\" button to fetch settings from other devices\n• During sync, only updates if remote and local differ'**
  String get aboutRelaysDescription;

  /// Message shown when connected via Tor
  ///
  /// In en, this message translates to:
  /// **'• Currently connected via Tor (using Orbot proxy)'**
  String get currentlyConnectedViaTor;

  /// Architecture section paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Meiso adopts a \"Zero-Knowledge Architecture\" and never sends your secret keys or task data to servers. All encryption processing is performed on your device.'**
  String get cryptoArchPara1;

  /// Architecture security model
  ///
  /// In en, this message translates to:
  /// **'Security Model:\n• End-to-End Encryption (E2EE)\n• Client-side encryption\n• Server stores only encrypted data\n• Only you hold the secret keys'**
  String get cryptoArchSecurityModel;

  /// Argon2id introduction
  ///
  /// In en, this message translates to:
  /// **'Argon2id is the latest and strongest password hashing algorithm, winner of the 2015 Password Hashing Competition (PHC).'**
  String get cryptoArgon2Intro;

  /// Argon2id why section title
  ///
  /// In en, this message translates to:
  /// **'Why Argon2id?'**
  String get cryptoArgon2WhyTitle;

  /// Argon2id feature title
  ///
  /// In en, this message translates to:
  /// **'Brute-force attack resistance'**
  String get cryptoArgon2BruteForce;

  /// Argon2id brute-force description
  ///
  /// In en, this message translates to:
  /// **'Requires both computational and memory costs, making it extremely resistant to parallel attacks using GPUs or ASICs.'**
  String get cryptoArgon2BruteForceDesc;

  /// Argon2id feature title
  ///
  /// In en, this message translates to:
  /// **'Side-channel attack resistance'**
  String get cryptoArgon2SideChannel;

  /// Argon2id side-channel description
  ///
  /// In en, this message translates to:
  /// **'A \"hybrid\" combining Argon2i\'s unpredictable memory access patterns with Argon2d\'s computational efficiency.'**
  String get cryptoArgon2SideChannelDesc;

  /// Argon2id feature title
  ///
  /// In en, this message translates to:
  /// **'Industry standard'**
  String get cryptoArgon2Standard;

  /// Argon2id standard description
  ///
  /// In en, this message translates to:
  /// **'Recommended by OWASP, NIST, and the Cryptography Engineering community. Next-generation standard surpassing bcrypt and PBKDF2.'**
  String get cryptoArgon2StandardDesc;

  /// Argon2id parameters
  ///
  /// In en, this message translates to:
  /// **'Implementation parameters in Meiso:\n• Memory cost: 19 MiB (optimized)\n• Iterations: 2 times\n• Parallelism: 1 thread\n• Output length: 32 bytes (256 bits)\n• Salt: Random generation (16 bytes)'**
  String get cryptoArgon2Params;

  /// Argon2id reference link text
  ///
  /// In en, this message translates to:
  /// **'📚 Reference: Argon2 RFC 9106'**
  String get cryptoArgon2Reference;

  /// AES-256-GCM introduction
  ///
  /// In en, this message translates to:
  /// **'AES-256-GCM is an \"Authenticated Encryption with Associated Data (AEAD)\" algorithm used by the U.S. government to protect classified information.'**
  String get cryptoAesIntro;

  /// AES-256 strength section title
  ///
  /// In en, this message translates to:
  /// **'Strength of AES-256'**
  String get cryptoAesStrengthTitle;

  /// AES-256 strength description
  ///
  /// In en, this message translates to:
  /// **'AES-256 has a key space of 2^256, making brute-force attacks practically impossible even with modern supercomputers. It maintains 128-bit effective security even in the quantum computing era.'**
  String get cryptoAesStrengthDesc;

  /// GCM mode advantages section title
  ///
  /// In en, this message translates to:
  /// **'Advantages of GCM Mode'**
  String get cryptoAesGcmAdvantagesTitle;

  /// AES-GCM feature title
  ///
  /// In en, this message translates to:
  /// **'Authenticated Encryption (AEAD)'**
  String get cryptoAesAead;

  /// AES-GCM AEAD description
  ///
  /// In en, this message translates to:
  /// **'Generates a Message Authentication Code (MAC) simultaneously with encryption. Enables detection of data tampering.'**
  String get cryptoAesAeadDesc;

  /// AES-GCM feature title
  ///
  /// In en, this message translates to:
  /// **'High-speed processing'**
  String get cryptoAesPerformance;

  /// AES-GCM performance description
  ///
  /// In en, this message translates to:
  /// **'Enables parallel processing and is hardware-accelerated by modern CPUs\' AES-NI instructions.'**
  String get cryptoAesPerformanceDesc;

  /// AES-GCM feature title
  ///
  /// In en, this message translates to:
  /// **'Padding attack resistance'**
  String get cryptoAesPaddingResistance;

  /// AES-GCM padding resistance description
  ///
  /// In en, this message translates to:
  /// **'As a stream cipher mode, there is no risk of padding oracle attacks.'**
  String get cryptoAesPaddingResistanceDesc;

  /// AES-256-GCM parameters
  ///
  /// In en, this message translates to:
  /// **'Implementation in Meiso:\n• Encryption algorithm: AES-256-GCM\n• Key length: 256 bits (derived from Argon2id)\n• Nonce: Random generation (96 bits)\n• Tag length: 128 bits (for tamper detection)\n• Purpose: Encrypted storage of secret keys'**
  String get cryptoAesParams;

  /// AES-GCM reference link text
  ///
  /// In en, this message translates to:
  /// **'📚 Reference: NIST SP 800-38D (GCM)'**
  String get cryptoAesReference;

  /// NIP-44 introduction
  ///
  /// In en, this message translates to:
  /// **'NIP-44 is the standard specification for encrypted messages in the Nostr protocol. It provides secure end-to-end encryption using Elliptic Curve Cryptography (ECC).'**
  String get cryptoNip44Intro;

  /// NIP-44 mechanism section title
  ///
  /// In en, this message translates to:
  /// **'Encryption Mechanism'**
  String get cryptoNip44MechanismTitle;

  /// NIP-44 mechanism description
  ///
  /// In en, this message translates to:
  /// **'NIP-44 generates a \"shared secret\" from your secret key and the recipient\'s public key, and uses it to encrypt messages.'**
  String get cryptoNip44MechanismDesc;

  /// NIP-44 encryption process
  ///
  /// In en, this message translates to:
  /// **'Encryption Process:\n1. ECDH (Elliptic Curve Diffie-Hellman)\n   → Generate shared secret with secp256k1 curve\n\n2. Key derivation with HMAC-SHA256 (HKDF)\n   → Generate encryption key and message authentication key\n\n3. Encrypt with ChaCha20-Poly1305\n   → Fast and secure AEAD encryption\n\n4. Base64 encode and transmit'**
  String get cryptoNip44Process;

  /// NIP-44 usage section title
  ///
  /// In en, this message translates to:
  /// **'Usage in Meiso'**
  String get cryptoNip44UsageTitle;

  /// NIP-44 usage description
  ///
  /// In en, this message translates to:
  /// **'In Meiso, all Todo data is encrypted with NIP-44 and stored on Nostr relays. This prevents relay servers from reading your task contents.'**
  String get cryptoNip44UsageDesc;

  /// NIP-44 security warning title
  ///
  /// In en, this message translates to:
  /// **'🔐 Important Security Characteristics'**
  String get cryptoNip44SecurityTitle;

  /// NIP-44 security characteristics
  ///
  /// In en, this message translates to:
  /// **'• Relay servers can only see ciphertext\n• Cannot be decrypted without your own secret key\n• Forward Secrecy is not provided\n• If the secret key is leaked, all past messages can be decrypted'**
  String get cryptoNip44SecurityDesc;

  /// NIP-44 reference link text
  ///
  /// In en, this message translates to:
  /// **'📚 Reference: NIP-44 Specification'**
  String get cryptoNip44Reference;

  /// Ed25519 introduction
  ///
  /// In en, this message translates to:
  /// **'Ed25519 is a modern signature algorithm based on Elliptic Curve Cryptography (ECC). It is widely adopted in modern security protocols such as Bitcoin, SSH, and TLS 1.3.'**
  String get cryptoEd25519Intro;

  /// Ed25519 advantages section title
  ///
  /// In en, this message translates to:
  /// **'Advantages of Ed25519'**
  String get cryptoEd25519AdvantagesTitle;

  /// Ed25519 feature title
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get cryptoEd25519Speed;

  /// Ed25519 speed description
  ///
  /// In en, this message translates to:
  /// **'More than 10 times faster than RSA-2048 for signing and verification. Runs fast even on mobile devices.'**
  String get cryptoEd25519SpeedDesc;

  /// Ed25519 feature title
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get cryptoEd25519Compact;

  /// Ed25519 compact description
  ///
  /// In en, this message translates to:
  /// **'Public key: 32 bytes, Private key: 32 bytes, Signature: 64 bytes. 1/8 the size of RSA with equal or better security.'**
  String get cryptoEd25519CompactDesc;

  /// Ed25519 feature title
  ///
  /// In en, this message translates to:
  /// **'Deterministic'**
  String get cryptoEd25519Deterministic;

  /// Ed25519 deterministic description
  ///
  /// In en, this message translates to:
  /// **'Always generates the same signature for the same message. No risk of random number generator vulnerabilities.'**
  String get cryptoEd25519DeterministicDesc;

  /// Ed25519 feature title
  ///
  /// In en, this message translates to:
  /// **'Safe implementation'**
  String get cryptoEd25519SafeImpl;

  /// Ed25519 safe implementation description
  ///
  /// In en, this message translates to:
  /// **'Resistance to side-channel attacks is built in from the design stage.'**
  String get cryptoEd25519SafeImplDesc;

  /// Ed25519 Nostr role section title
  ///
  /// In en, this message translates to:
  /// **'Role in Nostr'**
  String get cryptoEd25519NostrRoleTitle;

  /// Ed25519 Nostr role description
  ///
  /// In en, this message translates to:
  /// **'In Nostr, all events (messages, Todos, profile updates, etc.) are signed with Ed25519. This guarantees the authenticity of the event creator and the integrity of the data.'**
  String get cryptoEd25519NostrRoleDesc;

  /// Ed25519 signing process
  ///
  /// In en, this message translates to:
  /// **'Nostr signing process:\n1. Serialize event in JSON format\n2. Hash with SHA-256\n3. Sign with Ed25519 private key\n4. Attach signature to event and send'**
  String get cryptoEd25519SigningProcess;

  /// Ed25519 reference link text
  ///
  /// In en, this message translates to:
  /// **'📚 Reference: RFC 8032 (EdDSA)'**
  String get cryptoEd25519Reference;

  /// Amber introduction
  ///
  /// In en, this message translates to:
  /// **'Amber is a dedicated app for securely managing Nostr secret keys. It does not share secret keys with other apps and only processes signing requests.'**
  String get cryptoAmberIntro;

  /// Amber ncryptsec section title
  ///
  /// In en, this message translates to:
  /// **'ncryptsec Format'**
  String get cryptoAmberNcryptsecTitle;

  /// Amber ncryptsec description
  ///
  /// In en, this message translates to:
  /// **'Amber stores secret keys in \"ncryptsec\" format. This is a Bech32-encoded string containing a secret key encrypted with AES-256-CBC.'**
  String get cryptoAmberNcryptsecDesc;

  /// Amber ncryptsec structure
  ///
  /// In en, this message translates to:
  /// **'ncryptsec structure:\nncryptsec1... ← Bech32 prefix\n├─ Version (1 byte)\n├─ Salt (16 bytes)\n├─ Nonce/IV (16 bytes)\n├─ Encrypted secret key (32 bytes)\n└─ Tamper detection tag'**
  String get cryptoAmberNcryptsecStructure;

  /// Amber benefits section title
  ///
  /// In en, this message translates to:
  /// **'Benefits of Amber Mode'**
  String get cryptoAmberBenefitsTitle;

  /// Amber feature title
  ///
  /// In en, this message translates to:
  /// **'Secret key isolation'**
  String get cryptoAmberIsolation;

  /// Amber isolation description
  ///
  /// In en, this message translates to:
  /// **'Meiso does not hold secret keys and only requests Amber when signing is needed.'**
  String get cryptoAmberIsolationDesc;

  /// Amber feature title
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication'**
  String get cryptoAmberBiometric;

  /// Amber biometric description
  ///
  /// In en, this message translates to:
  /// **'Can require fingerprint authentication or PIN when signing with Amber.'**
  String get cryptoAmberBiometricDesc;

  /// Amber feature title
  ///
  /// In en, this message translates to:
  /// **'Auditable'**
  String get cryptoAmberAuditable;

  /// Amber auditable description
  ///
  /// In en, this message translates to:
  /// **'Can review and approve all signing requests in the Amber app.'**
  String get cryptoAmberAuditableDesc;

  /// Amber feature title
  ///
  /// In en, this message translates to:
  /// **'Key reuse'**
  String get cryptoAmberKeyReuse;

  /// Amber key reuse description
  ///
  /// In en, this message translates to:
  /// **'Can securely share one secret key across multiple Nostr apps.'**
  String get cryptoAmberKeyReuseDesc;

  /// Amber hardware wallet info title
  ///
  /// In en, this message translates to:
  /// **'💡 Similarity to Hardware Wallets'**
  String get cryptoAmberHardwareWalletTitle;

  /// Amber hardware wallet description
  ///
  /// In en, this message translates to:
  /// **'Amber adopts the same \"never export secret keys\" architecture as Bitcoin hardware wallets (Ledger, Trezor).'**
  String get cryptoAmberHardwareWalletDesc;

  /// Amber reference link text
  ///
  /// In en, this message translates to:
  /// **'🔗 Amber on GitHub'**
  String get cryptoAmberReference;

  /// Secure storage introduction
  ///
  /// In en, this message translates to:
  /// **'Meiso\'s secret key management is entirely implemented in Rust. Rust is a secure systems programming language with memory safety guaranteed at the language level.'**
  String get cryptoSecureStorageIntro;

  /// Why Rust section title
  ///
  /// In en, this message translates to:
  /// **'Why Rust?'**
  String get cryptoStorageWhyRustTitle;

  /// Rust feature title
  ///
  /// In en, this message translates to:
  /// **'Memory safety'**
  String get cryptoStorageMemorySafety;

  /// Rust memory safety description
  ///
  /// In en, this message translates to:
  /// **'Memory-related vulnerabilities such as buffer overflow, use-after-free, and data races are fundamentally impossible.'**
  String get cryptoStorageMemorySafetyDesc;

  /// Rust feature title
  ///
  /// In en, this message translates to:
  /// **'Zero-cost abstractions'**
  String get cryptoStorageZeroCost;

  /// Rust zero-cost description
  ///
  /// In en, this message translates to:
  /// **'Achieves C/C++ equivalent performance while writing high-level code.'**
  String get cryptoStorageZeroCostDesc;

  /// Rust feature title
  ///
  /// In en, this message translates to:
  /// **'Strong type system'**
  String get cryptoStorageTypeSystem;

  /// Rust type system description
  ///
  /// In en, this message translates to:
  /// **'Option and Result types enforce error handling.'**
  String get cryptoStorageTypeSystemDesc;

  /// Storage implementation section title
  ///
  /// In en, this message translates to:
  /// **'Storage Implementation'**
  String get cryptoStorageImplTitle;

  /// Storage implementation description
  ///
  /// In en, this message translates to:
  /// **'Meiso stores encrypted secret keys in Flutter\'s \"ApplicationSupportDirectory\". This directory is protected by the OS from access by other apps.'**
  String get cryptoStorageImplDesc;

  /// Storage path details
  ///
  /// In en, this message translates to:
  /// **'Storage path (Android):\n/data/data/com.example.meiso/files/encrypted_key.bin\n\nFile contents:\n• JSON format\n• Fields: salt, nonce, ciphertext\n• All Base64 encoded'**
  String get cryptoStoragePath;

  /// Memory security section title
  ///
  /// In en, this message translates to:
  /// **'Memory Security'**
  String get cryptoStorageMemorySecurityTitle;

  /// Memory security feature title
  ///
  /// In en, this message translates to:
  /// **'Zeroize'**
  String get cryptoStorageZeroize;

  /// Zeroize description
  ///
  /// In en, this message translates to:
  /// **'Safely erases secret keys from memory after use.'**
  String get cryptoStorageZeroizeDesc;

  /// Memory security feature title
  ///
  /// In en, this message translates to:
  /// **'Stack allocation'**
  String get cryptoStorageStackAllocation;

  /// Stack allocation description
  ///
  /// In en, this message translates to:
  /// **'Places secret keys on the stack rather than the heap, minimizing lifetime.'**
  String get cryptoStorageStackAllocationDesc;

  /// Memory security feature title
  ///
  /// In en, this message translates to:
  /// **'Memory dump countermeasures'**
  String get cryptoStorageMemoryDump;

  /// Memory dump description
  ///
  /// In en, this message translates to:
  /// **'Rust code is optimized even in debug builds, making sensitive data less likely to remain.'**
  String get cryptoStorageMemoryDumpDesc;

  /// Threat model introduction
  ///
  /// In en, this message translates to:
  /// **'Meiso uses very strong cryptographic technologies, but perfect security does not exist. Please understand the following threats.'**
  String get cryptoThreatModelIntro;

  /// What we can protect section title
  ///
  /// In en, this message translates to:
  /// **'What We Can Protect'**
  String get cryptoThreatWhatWeCanProtectTitle;

  /// Threat model protection title
  ///
  /// In en, this message translates to:
  /// **'Network eavesdropping'**
  String get cryptoThreatNetworkEavesdropping;

  /// Network eavesdropping description
  ///
  /// In en, this message translates to:
  /// **'TLS + E2EE encryption neutralizes eavesdropping on communication paths.'**
  String get cryptoThreatNetworkEavesdroppingDesc;

  /// Threat model protection title
  ///
  /// In en, this message translates to:
  /// **'Malicious relay servers'**
  String get cryptoThreatMaliciousRelay;

  /// Malicious relay description
  ///
  /// In en, this message translates to:
  /// **'Relays can only see encrypted data.'**
  String get cryptoThreatMaliciousRelayDesc;

  /// Threat model protection title
  ///
  /// In en, this message translates to:
  /// **'Brute-force attacks'**
  String get cryptoThreatBruteForce;

  /// Brute-force description
  ///
  /// In en, this message translates to:
  /// **'Argon2id + AES-256 makes decryption impossible in realistic time.'**
  String get cryptoThreatBruteForceDesc;

  /// What we cannot protect section title
  ///
  /// In en, this message translates to:
  /// **'What We Cannot Protect'**
  String get cryptoThreatWhatWeCannotProtectTitle;

  /// Threat warning title
  ///
  /// In en, this message translates to:
  /// **'⚠️ The following threats require attention'**
  String get cryptoThreatWarningTitle;

  /// Threat warning description
  ///
  /// In en, this message translates to:
  /// **'• Physical device theft + password leak\n• Keylogger or screen capture malware\n• Rooted/Jailbroken devices\n• OS or firmware vulnerabilities\n• Social engineering attacks\n• Future threats from quantum computers (RSA/ECC breakdown)'**
  String get cryptoThreatWarningDesc;

  /// Best practices section title
  ///
  /// In en, this message translates to:
  /// **'Best Practices'**
  String get cryptoThreatBestPracticesTitle;

  /// Best practice title
  ///
  /// In en, this message translates to:
  /// **'Strong password'**
  String get cryptoThreatStrongPassword;

  /// Strong password description
  ///
  /// In en, this message translates to:
  /// **'Use a random password of 20 characters or more.'**
  String get cryptoThreatStrongPasswordDesc;

  /// Best practice title
  ///
  /// In en, this message translates to:
  /// **'Device encryption'**
  String get cryptoThreatDeviceEncryption;

  /// Device encryption description
  ///
  /// In en, this message translates to:
  /// **'Enable full disk encryption on Android/iOS.'**
  String get cryptoThreatDeviceEncryptionDesc;

  /// Best practice title
  ///
  /// In en, this message translates to:
  /// **'Keep OS up to date'**
  String get cryptoThreatKeepOsUpdated;

  /// Keep OS updated description
  ///
  /// In en, this message translates to:
  /// **'Apply security patches regularly.'**
  String get cryptoThreatKeepOsUpdatedDesc;

  /// Best practice title
  ///
  /// In en, this message translates to:
  /// **'Amber mode recommended'**
  String get cryptoThreatRecommendAmber;

  /// Recommend Amber description
  ///
  /// In en, this message translates to:
  /// **'If higher security is required, use Amber mode.'**
  String get cryptoThreatRecommendAmberDesc;

  /// Table of contents title
  ///
  /// In en, this message translates to:
  /// **'📖 Table of Contents'**
  String get cryptoTableOfContents;

  /// Table of contents item 1
  ///
  /// In en, this message translates to:
  /// **'1. Architecture Overview'**
  String get cryptoTocItem1;

  /// Table of contents item 2
  ///
  /// In en, this message translates to:
  /// **'2. Argon2id - Password Derivation Function'**
  String get cryptoTocItem2;

  /// Table of contents item 3
  ///
  /// In en, this message translates to:
  /// **'3. AES-256-GCM - Encryption Algorithm'**
  String get cryptoTocItem3;

  /// Table of contents item 4
  ///
  /// In en, this message translates to:
  /// **'4. NIP-44 - Nostr Encryption Standard'**
  String get cryptoTocItem4;

  /// Table of contents item 5
  ///
  /// In en, this message translates to:
  /// **'5. Ed25519 - Digital Signatures'**
  String get cryptoTocItem5;

  /// Table of contents item 6
  ///
  /// In en, this message translates to:
  /// **'6. Amber Integration - Hardware Wallet-like Security'**
  String get cryptoTocItem6;

  /// Table of contents item 7
  ///
  /// In en, this message translates to:
  /// **'7. Secure Storage - Rust Implementation'**
  String get cryptoTocItem7;

  /// Table of contents item 8
  ///
  /// In en, this message translates to:
  /// **'8. Threat Model and Limitations'**
  String get cryptoTocItem8;

  /// Footer security title
  ///
  /// In en, this message translates to:
  /// **'🔒 Security Questions and Reports'**
  String get cryptoFooterSecurityTitle;

  /// Footer security description
  ///
  /// In en, this message translates to:
  /// **'If you discover a security issue, please report it via GitHub Issues or Nostr (DM).'**
  String get cryptoFooterSecurityDesc;

  /// Footer open source text
  ///
  /// In en, this message translates to:
  /// **'All code is open source'**
  String get cryptoFooterOpenSource;

  /// Cryptography details description in Secret Key Management
  ///
  /// In en, this message translates to:
  /// **'Details of cryptographic technologies used in Meiso'**
  String get cryptographyDetailsDescription;

  /// Status indicating task is synced
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// Status message with event ID
  ///
  /// In en, this message translates to:
  /// **'Synced (Event ID: {eventId}...)'**
  String syncedWithEventId(String eventId);

  /// Snackbar message when sending to relay
  ///
  /// In en, this message translates to:
  /// **'Sending to relay...'**
  String get sendingToRelay;

  /// Snackbar message when successfully sent to relay
  ///
  /// In en, this message translates to:
  /// **'✅ Sent to relay'**
  String get sentToRelay;

  /// Button label to send to relay
  ///
  /// In en, this message translates to:
  /// **'Send to relay'**
  String get sendToRelay;
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
