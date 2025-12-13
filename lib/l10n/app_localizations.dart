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
  /// **'Delete recurring to-do'**
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

  /// Sync phase: todos
  ///
  /// In en, this message translates to:
  /// **'Syncing todos...'**
  String get syncPhaseTodos;

  /// Sync phase: MLS group todos
  ///
  /// In en, this message translates to:
  /// **'Syncing group todos...'**
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
