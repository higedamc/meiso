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
  String get onboardingWelcomeDescription =>
      'Aplicación de tareas simple y hermosa\nSincroniza con Nostr, gestiona tareas en cualquier lugar';

  @override
  String get onboardingNostrSyncTitle => 'Sincronizar con Nostr';

  @override
  String get onboardingNostrSyncDescription =>
      'Sincroniza tus tareas a través de la red Nostr\nMantente actualizado automáticamente en múltiples dispositivos';

  @override
  String get onboardingSmartDateTitle => 'Entrada de Fecha Inteligente';

  @override
  String get onboardingSmartDateDescription =>
      'Escribe \"tomorrow\" para crear una tarea para mañana\nEscribe \"every day\" para crear tareas recurrentes fácilmente';

  @override
  String get onboardingPrivacyTitle => 'Privacidad Primero';

  @override
  String get onboardingPrivacyDescription =>
      'Sin servidor central. Todos los datos están bajo tu control\nAlmacenado de forma segura en la red descentralizada de Nostr';

  @override
  String get onboardingGetStartedTitle => 'Comencemos';

  @override
  String get onboardingGetStartedDescription =>
      'Inicia sesión con Amber o\ngenera una nueva clave secreta para comenzar';

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
  String get amberModeInfo =>
      '✅ Conectado con modo Amber\n\n🔒 Características de seguridad:\n• Firmar tareas con Amber al crear/editar\n• Proteger contenido con cifrado NIP-44\n• Clave secreta almacenada cifrada con ncryptsec en Amber\n\n⚡ Optimización de descifrado:\nSe requiere aprobación al sincronizar tareas.\nPara evitar aprobar cada vez, recomendamos\nconfigurar \"Permitir siempre la aplicación Meiso\" en Amber.\n\n📝 Cómo configurar:\n1. Abrir la aplicación Amber\n2. Seleccionar \"Meiso\" de la lista de aplicaciones\n3. Configurar \"NIP-44 Decrypt\" para permitir siempre';

  @override
  String get autoSyncInfoTitle => 'Acerca de la Sincronización Automática';

  @override
  String get autoSyncInfo =>
      '• La creación, edición y eliminación de tareas se sincronizan automáticamente con Nostr\n• Los últimos datos se obtienen automáticamente al iniciar la aplicación\n• Siempre se sincroniza en segundo plano cuando el relay está conectado\n• Ya no se necesita el botón de sincronización manual';

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
}
