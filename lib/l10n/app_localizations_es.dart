// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Meiso';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a Meiso';

  @override
  String get onboardingWelcomeDescription => 'Aplicación de tareas simple y hermosa\nSincroniza con Nostr, gestiona tareas en cualquier lugar';

  @override
  String get onboardingNostrSyncTitle => 'Sincronizar con Nostr';

  @override
  String get onboardingNostrSyncDescription => 'Sincroniza tus tareas a través de la red Nostr\nMantente actualizado automáticamente en múltiples dispositivos';

  @override
  String get onboardingSmartDateTitle => 'Entrada de Fecha Inteligente';

  @override
  String get onboardingSmartDateDescription => 'Escribe \"tomorrow\" para crear una tarea para mañana\nEscribe \"every day\" para crear tareas recurrentes fácilmente';

  @override
  String get onboardingPrivacyTitle => 'Privacidad Primero';

  @override
  String get onboardingPrivacyDescription => 'Sin servidor central. Todos los datos están bajo tu control\nAlmacenado de forma segura en la red descentralizada de Nostr';

  @override
  String get onboardingGetStartedTitle => 'Comencemos';

  @override
  String get onboardingGetStartedDescription => 'Inicia sesión con Amber o\ngenera una nueva clave secreta para comenzar';

  @override
  String get skipButton => 'Saltar';

  @override
  String get nextButton => 'Siguiente';

  @override
  String get startButton => 'Iniciar';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get nostrConnected => 'Nostr Conectado';

  @override
  String get nostrConnectedAmber => 'Nostr Conectado (Amber)';

  @override
  String get nostrDisconnected => 'Nostr Desconectado';

  @override
  String relaysConnectedCount(int count, int total) {
    return 'Relays: $count/$total conectados';
  }

  @override
  String get secretKeyManagement => 'Gestión de Clave Secreta';

  @override
  String get secretKeyConfigured => 'Configurado';

  @override
  String get secretKeyNotConfigured => 'No Configurado';

  @override
  String get relayServerManagement => 'Gestión de Servidores Relay';

  @override
  String relayCountRegistered(int count) {
    return '$count registrados';
  }

  @override
  String get appSettings => 'Configuración de la Aplicación';

  @override
  String get appSettingsSubtitle => 'Tema, Calendario, Notificaciones, Tor';

  @override
  String get debugLogs => 'Registros de Depuración';

  @override
  String get debugLogsSubtitle => 'Ver historial de registros';

  @override
  String get amberModeTitle => 'Modo Amber';

  @override
  String get amberModeInfo => '✅ Conectado con modo Amber\n\n🔒 Características de seguridad:\n• Firmar tareas con Amber al crear/editar\n• Proteger contenido con cifrado NIP-44\n• Clave secreta almacenada cifrada con ncryptsec en Amber\n\n⚡ Optimización de descifrado:\nSe requiere aprobación al sincronizar tareas.\nPara evitar aprobar cada vez, recomendamos\nconfigurar \"Permitir siempre la aplicación Meiso\" en Amber.\n\n📝 Cómo configurar:\n1. Abrir la aplicación Amber\n2. Seleccionar \"Meiso\" de la lista de aplicaciones\n3. Configurar \"NIP-44 Decrypt\" para permitir siempre';

  @override
  String get autoSyncInfoTitle => 'Acerca de la Sincronización Automática';

  @override
  String get autoSyncInfo => '• La creación, edición y eliminación de tareas se sincronizan automáticamente con Nostr\n• Los últimos datos se obtienen automáticamente al iniciar la aplicación\n• Siempre se sincroniza en segundo plano cuando el relay está conectado\n• Ya no se necesita el botón de sincronización manual';

  @override
  String versionInfo(String version, String buildNumber) {
    return 'Versión $version ($buildNumber)';
  }

  @override
  String get todayLabel => 'HOY';

  @override
  String get tomorrowLabel => 'MAÑANA';

  @override
  String get somedayLabel => 'ALGÚN DÍA';

  @override
  String get addTaskPlaceholder => 'Agregar una tarea...';

  @override
  String get editTaskTitle => 'Editar Tarea';

  @override
  String get taskTitlePlaceholder => 'Título de la tarea';

  @override
  String get saveButton => 'Guardar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get undoButton => 'Deshacer';

  @override
  String get taskDeleted => 'Tarea eliminada';

  @override
  String get languageSettings => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del Sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSpanish => 'Español';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get darkModeEnabled => 'Habilitado';

  @override
  String get darkModeDisabled => 'Deshabilitado';

  @override
  String get torSettings => 'Tor (Orbot)';

  @override
  String get torEnabled => 'Habilitado';

  @override
  String get torDisabled => 'Deshabilitado';

  @override
  String get mondayShort => 'Lun';

  @override
  String get tuesdayShort => 'Mar';

  @override
  String get wednesdayShort => 'Mié';

  @override
  String get thursdayShort => 'Jue';

  @override
  String get fridayShort => 'Vie';

  @override
  String get saturdayShort => 'Sáb';

  @override
  String get sundayShort => 'Dom';

  @override
  String get loginMethodTitle => 'Choose Login Method';

  @override
  String get loginMethodDescription => 'Log in with Nostr account\nto sync your tasks';

  @override
  String get loginWithAmber => 'Login with Amber';

  @override
  String get or => 'or';

  @override
  String get generateNewKey => 'Generate New Key';

  @override
  String get keyStorageNote => 'Keys are stored securely.\nAmber provides enhanced security.';

  @override
  String get amberRequired => 'Amber Required';

  @override
  String get amberNotInstalled => 'Amber app is not installed.\nWould you like to install it from Google Play?';

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
  String get setPasswordDescription => 'Please set a password to encrypt your secret key.';

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
  String get backupSecretKey => 'Please backup your secret key to a safe location.';

  @override
  String get secretKeyNsec => 'Secret Key (nsec):';

  @override
  String get publicKeyNpub => 'Public Key (npub):';

  @override
  String get secretKeyWarning => 'If you lose this secret key, you will lose access to your account. Please backup it.';

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
  String get torEnabledMessage => 'Tor enabled. Will apply from next connection.\nPlease start Orbot app.';

  @override
  String get torDisabledMessage => 'Tor disabled. Will apply from next connection.';

  @override
  String get proxyAddress => 'Proxy Address and Port';

  @override
  String get proxySettings => 'Proxy Settings';

  @override
  String get proxySettingsDescription => 'Configure SOCKS5 proxy address and port';

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
  String get commonSettings => 'Common settings:\n• Orbot: 127.0.0.1:9050\n• Custom proxy: Enter host and port';

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
  String get appSettingsInfoText => '• App settings are stored locally\n• If Nostr is connected, settings sync automatically\n• You can share the same settings across multiple devices (NIP-78)\n• Changes are applied immediately\n\n🛡️ About Tor settings:\n• When Tor is enabled, connects to relays via Orbot proxy\n• Orbot app must be running\n• Privacy and security improve, but connection speed decreases\n• Reconnection required after changing settings';

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
  String get invalidSecretKeyFormat => 'Invalid secret key format. Please enter nsec or hex format.';

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
  String get relayRemovedAndSaved => 'Relay removed and immediately saved to Nostr';

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
  String get logoutDescription => 'Encrypted secret key will be deleted.\nPlease save your secret key before logout.';
}
