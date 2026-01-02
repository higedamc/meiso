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
  String get closeButton => 'Cerrar';

  @override
  String get copyButton => 'Copiar';

  @override
  String get fetchButton => 'Obtener';

  @override
  String get advancedSectionTitle => 'Avanzado';

  @override
  String get advancedSectionSubtitle => 'Funciones de desarrollador';

  @override
  String get keyPackagePublishTitle => 'Publicar Key Package';

  @override
  String get keyPackagePublishSubtitle =>
      'Requerido para recibir invitaciones de grupo';

  @override
  String get mlsIntegrationTestTitle => 'Prueba de Integración MLS (PoC)';

  @override
  String get mlsIntegrationTestSubtitle =>
      'Opción B: verificar con grupo de 1 persona';

  @override
  String get keyPackagePublishDialogTitle => 'Publicar Key Package';

  @override
  String get keyPackagePublishDialogBody =>
      'Esto publicará tu Key Package en los relays.\n\nUna vez publicado, otros usuarios podrán invitarte a grupos.\n\n¿Continuar?';

  @override
  String get publishButton => 'Publicar';

  @override
  String get publishingKeyPackage => 'Publicando Key Package...';

  @override
  String get keyPackagePublishCompletedTitle => 'Publicación completada';

  @override
  String get keyPackagePublishCompletedMessage =>
      '¡Key Package publicado en los relays!';

  @override
  String get keyPackagePublishCompletedDescription =>
      'Otros usuarios ahora pueden invitarte a grupos usando tu npub.';

  @override
  String get eventIdLabel => 'ID de Evento';

  @override
  String get keyPackagePublishFailedTitle => 'Publicación fallida';

  @override
  String keyPackagePublishFailedBody(String error) {
    return 'Error al publicar Key Package.\n\nError: $error';
  }

  @override
  String get keyPackagePublishNoEventIdError =>
      'Error al obtener el ID de evento';

  @override
  String get mlsTestDialogTitle => 'Prueba de Integración MLS';

  @override
  String get mlsTestDialogSubtitle =>
      'PoC Opción B: prueba de grupo de 2 personas';

  @override
  String get mlsYourKeyPackageLabel => '📋 Tu Key Package:';

  @override
  String get keyPackageCopied => 'Key Package copiado';

  @override
  String get mlsPeerNpubLabel => 'npub del par';

  @override
  String get mlsPeerNpubHint => 'npub1...';

  @override
  String get mlsPressTestButton => 'Presiona un botón de prueba';

  @override
  String get mlsGenerateKpButton => 'Generar KP';

  @override
  String get mlsPublishKpButton => 'Publicar KP';

  @override
  String get mlsCreate2PersonGroupButton => 'Crear grupo de 2 personas';

  @override
  String get mlsSendTodoButton => 'Enviar TODO';

  @override
  String get mlsOnePersonTestButton => 'Prueba de 1 persona';

  @override
  String get mlsRunning => 'Ejecutando...';

  @override
  String get mlsUserPublicKeyNotAvailable =>
      'Clave pública del usuario no disponible';

  @override
  String get mlsTwoPersonTestGroupName => 'Grupo de Prueba de 2 Personas';

  @override
  String get mlsTestListName => 'Lista de Prueba MLS';

  @override
  String get mlsTwoPersonTestTodoTitle =>
      'TODO de Prueba para Grupo de 2 Personas';

  @override
  String get mlsOnePersonTestTodoTitle => 'TODO de Prueba en Grupo MLS';

  @override
  String get deleteRecurringTodoTitle => 'Eliminar tarea recurrente';

  @override
  String get removeThisInstance => 'Eliminar esta instancia';

  @override
  String get removeAllInstances => 'Eliminar todas las instancias';

  @override
  String get todoJsonTitle => 'Todo JSON';

  @override
  String get jsonCopied => 'JSON copiado';

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
  String get loginMethodTitle => 'Elegir Método de Inicio de Sesión';

  @override
  String get loginMethodDescription =>
      'Inicia sesión con tu cuenta Nostr\npara sincronizar tus tareas';

  @override
  String get loginWithAmber => 'Iniciar con Amber';

  @override
  String get or => 'o';

  @override
  String get generateNewKey => 'Generar Nueva Clave';

  @override
  String get keyStorageNote =>
      'Las claves se almacenan de forma segura.\nAmber proporciona seguridad mejorada.';

  @override
  String get amberRequired => 'Amber Requerido';

  @override
  String get amberNotInstalled =>
      'La aplicación Amber no está instalada.\n¿Deseas instalarla desde Google Play?';

  @override
  String get install => 'Instalar';

  @override
  String get error => 'Error';

  @override
  String loginProcessError(String error) {
    return 'Ocurrió un error durante el proceso de inicio de sesión\n$error';
  }

  @override
  String get ok => 'OK';

  @override
  String get noPublicKeyReceived =>
      'Error al obtener la clave pública de Amber';

  @override
  String amberConnectionFailed(String error) {
    return 'Error al conectar con Amber\n$error';
  }

  @override
  String get setPassword => 'Establecer Contraseña';

  @override
  String get setPasswordDescription =>
      'Por favor, establece una contraseña para cifrar tu clave secreta.';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordConfirm => 'Contraseña (Confirmar)';

  @override
  String get passwordRequired => 'Por favor, ingresa una contraseña';

  @override
  String get passwordMinLength =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get passwordMismatch => 'Las contraseñas no coinciden';

  @override
  String get secretKeyGenerated => 'Clave Secreta Generada';

  @override
  String get backupSecretKey =>
      'Por favor, respalda tu clave secreta en un lugar seguro.';

  @override
  String get secretKeyNsec => 'Clave Secreta (nsec):';

  @override
  String get publicKeyNpub => 'Clave Pública (npub):';

  @override
  String get secretKeyWarning =>
      'Si pierdes esta clave secreta, perderás el acceso a tu cuenta. Por favor, respáldala.';

  @override
  String get backupCompleted => 'Respaldo Completado';

  @override
  String keypairGenerationFailed(String error) {
    return 'Error al generar el par de claves\n\n$error';
  }

  @override
  String get sunday => 'Domingo';

  @override
  String get monday => 'Lunes';

  @override
  String get tuesday => 'Martes';

  @override
  String get wednesday => 'Miércoles';

  @override
  String get thursday => 'Jueves';

  @override
  String get friday => 'Viernes';

  @override
  String get saturday => 'Sábado';

  @override
  String get weekStartDay => 'Día de Inicio de Semana';

  @override
  String get selectWeekStartDay => 'Seleccionar Día de Inicio de Semana';

  @override
  String get calendarView => 'Vista de Calendario';

  @override
  String get selectCalendarView => 'Seleccionar Vista de Calendario';

  @override
  String get weekView => 'Vista Semanal';

  @override
  String get monthView => 'Vista Mensual';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationsSubtitle =>
      'Habilitar notificaciones de recordatorio';

  @override
  String get torConnection => 'Conectar vía Tor (Orbot)';

  @override
  String torEnabledSubtitle(String proxyUrl) {
    return 'Conectando vía proxy Orbot ($proxyUrl)';
  }

  @override
  String get torDisabledSubtitle => 'No usando Orbot (Conexión directa)';

  @override
  String get torEnabledMessage =>
      'Tor habilitado. Se aplicará desde la próxima conexión.\nPor favor, inicia la aplicación Orbot.';

  @override
  String get torDisabledMessage =>
      'Tor deshabilitado. Se aplicará desde la próxima conexión.';

  @override
  String get proxyAddress => 'Dirección y Puerto del Proxy';

  @override
  String get proxySettings => 'Configuración de Proxy';

  @override
  String get proxySettingsDescription =>
      'Configurar dirección y puerto del proxy SOCKS5';

  @override
  String get host => 'Host';

  @override
  String get port => 'Puerto';

  @override
  String get hostRequired => 'Por favor, ingresa el host';

  @override
  String get portRequired => 'Por favor, ingresa el puerto';

  @override
  String get portRangeError => 'El número de puerto debe estar entre 1-65535';

  @override
  String proxyUrlUpdated(String url) {
    return 'URL del proxy actualizada: $url';
  }

  @override
  String get commonSettings =>
      'Configuraciones comunes:\n• Orbot: 127.0.0.1:9050\n• Proxy personalizado: Ingresa host y puerto';

  @override
  String get proxyConnectionStatus => 'Estado de Conexión del Proxy';

  @override
  String get testButton => 'Probar';

  @override
  String get untested => 'Sin probar';

  @override
  String get testing => 'Probando...';

  @override
  String get connectionSuccess => 'Conexión Exitosa';

  @override
  String get connectionFailed => 'Conexión Fallida (Por favor, inicia Orbot)';

  @override
  String get appSettingsTitle => 'Configuración de la Aplicación';

  @override
  String get appSettingsInfo => 'Acerca de la Configuración de la Aplicación';

  @override
  String get appSettingsInfoText =>
      '• La configuración de la aplicación se almacena localmente\n• Si Nostr está conectado, la configuración se sincroniza automáticamente\n• Puedes compartir la misma configuración en múltiples dispositivos (NIP-78)\n• Los cambios se aplican inmediatamente\n\n🛡️ Acerca de la configuración de Tor:\n• Cuando Tor está habilitado, se conecta a los relays vía proxy Orbot\n• La aplicación Orbot debe estar en ejecución\n• La privacidad y seguridad mejoran, pero la velocidad de conexión disminuye\n• Se requiere reconexión después de cambiar la configuración';

  @override
  String get nostrAutoSync =>
      'Sincronización automática con relay Nostr (NIP-78 Kind 30078)';

  @override
  String get localStorageOnly =>
      'Solo almacenamiento local (Nostr no conectado)';

  @override
  String get languageSelection => 'Seleccionar Idioma';

  @override
  String syncingWithCount(int count) {
    return 'Sincronizando ($count)';
  }

  @override
  String get syncing => 'Sincronizando';

  @override
  String get syncCompleted => 'Sincronización Completada';

  @override
  String get syncError => 'Error de Sincronización';

  @override
  String get timeout => 'Tiempo de Espera Agotado';

  @override
  String get connectionError => 'Error de Conexión';

  @override
  String errorRetry(int count) {
    return 'Error (Reintento $count)';
  }

  @override
  String get waiting => 'Esperando';

  @override
  String syncStep(int current, int total) {
    return 'Paso $current / $total';
  }

  @override
  String get syncReconnectingRelays => 'Reconectando relays...';

  @override
  String get syncPhaseDelta => 'Sincronización delta...';

  @override
  String get syncPhaseAppSettings => 'Sincronizando configuración...';

  @override
  String get syncPhaseCustomLists => 'Sincronizando listas...';

  @override
  String get syncPhaseTodos => 'Sincronizando tareas...';

  @override
  String get syncPhaseMls => 'Sincronizando tareas de grupo...';

  @override
  String get justNow => 'Justo ahora';

  @override
  String minutesAgo(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'hace $hours hr';
  }

  @override
  String get secretKeyManagementTitle => 'Gestión de Clave Secreta';

  @override
  String get enterPassword => 'Ingresar Contraseña';

  @override
  String get enterPasswordToDecrypt =>
      'Ingresa la contraseña para descifrar la clave secreta.';

  @override
  String get enterPasswordToEncrypt =>
      'Ingresa la contraseña para cifrar la clave secreta.';

  @override
  String secretKeyEncrypted(String format) {
    return 'Clave secreta cifrada y guardada ($format)';
  }

  @override
  String get formatUnknown => 'Formato desconocido';

  @override
  String get connectedToRelay => 'Conectado al relay';

  @override
  String get connectedToRelayViaTor => 'Conectado al relay (vía Tor)';

  @override
  String get invalidSecretKeyFormat =>
      'Formato de clave secreta inválido. Por favor, ingresa formato nsec o hex.';

  @override
  String get encrypted => '🔒 Cifrado';

  @override
  String get relayManagementTitle => 'Gestión de Servidores Relay';

  @override
  String get relayUrlError =>
      'La URL del relay debe comenzar con wss:// o ws://';

  @override
  String get relayAddedAndSaved =>
      'Relay agregado y guardado inmediatamente en Nostr';

  @override
  String relayAddedButSaveFailed(String error) {
    return 'Relay agregado pero falló el guardado en Nostr: $error';
  }

  @override
  String get relayRemovedAndSaved =>
      'Relay eliminado y guardado inmediatamente en Nostr';

  @override
  String relayRemovedButSaveFailed(String error) {
    return 'Relay eliminado pero falló el guardado en Nostr: $error';
  }

  @override
  String get noRelayListOnNostr => 'No se encontró lista de relays en Nostr';

  @override
  String relaySyncSuccess(int count) {
    return 'Se sincronizaron exitosamente $count relays desde Nostr';
  }

  @override
  String relaySyncError(String error) {
    return 'Error al sincronizar desde Nostr: $error';
  }

  @override
  String get syncFromNostr => 'Sincronizar desde Nostr';

  @override
  String get addRelay => 'Agregar Relay';

  @override
  String get relayUrl => 'URL del Relay';

  @override
  String get connected => 'Conectado';

  @override
  String get connecting => 'Conectando';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get cryptographyTitle => 'Detalles de Criptografía';

  @override
  String get logout => 'Cerrar Sesión';

  @override
  String get logoutConfirm => '¿Estás seguro de que deseas cerrar sesión?';

  @override
  String get logoutDescription =>
      'La clave secreta cifrada será eliminada.\nPor favor, guarda tu clave secreta antes de cerrar sesión.';

  @override
  String get torModeDisabled => 'Deshabilitado';

  @override
  String get torModeInternal => 'Interno (Integrado)';

  @override
  String get torModeOrbot => 'Orbot (Proxy)';

  @override
  String get torModeDescriptionDisabled => 'Conexión directa sin Tor';

  @override
  String get torModeDescriptionInternal =>
      'Usar cliente Tor integrado (en desarrollo, aún no disponible)';

  @override
  String get torModeDescriptionOrbot =>
      'Conectar vía aplicación Orbot (requiere instalación de Orbot)';

  @override
  String get torConnectionModeTitle => 'Modo de Conexión Tor';

  @override
  String get inDevelopment => '(en desarrollo)';

  @override
  String torModeUpdated(String mode) {
    return 'Modo Tor actualizado: $mode';
  }

  @override
  String get orbotRequired => 'Orbot Requerido';

  @override
  String get orbotRequiredDescription =>
      'La aplicación Orbot debe estar instalada y en ejecución para usar este modo.';

  @override
  String get openGooglePlayOrbot => 'Abrir Google Play: Orbot';

  @override
  String get openFDroidOrbot => 'Abrir F-Droid: Orbot';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get fDroid => 'F-Droid';

  @override
  String get embeddedTorDescription =>
      'Usando cliente Tor integrado. No se requieren aplicaciones adicionales.';

  @override
  String get secretKeyNsecLabel => 'Clave Secreta (nsec)';

  @override
  String copiedToClipboard(String label) {
    return '$label copiado al portapapeles';
  }

  @override
  String get copyNpub => 'Copiar npub';

  @override
  String get copyHex => 'Copiar hex';

  @override
  String get generateButton => 'Generar';

  @override
  String get saveAndConnect => 'Guardar y Conectar';

  @override
  String get nostrConnectedStatus => 'Nostr Conectado';

  @override
  String get nostrConnectedViaTor => 'Nostr Conectado (vía Tor)';

  @override
  String get nostrDisconnectedStatus => 'Nostr Desconectado';

  @override
  String get passwordIncorrectOrDecryptFailed =>
      'La contraseña es incorrecta o falló el descifrado de la clave secreta';

  @override
  String secretKeyDecryptFailed(String error) {
    return 'Error al descifrar la clave secreta: $error';
  }

  @override
  String secretKeyGenerationFailed(String error) {
    return 'Error al generar la clave secreta: $error';
  }

  @override
  String secretKeySaveFailed(String error) {
    return 'Error al guardar la clave secreta: $error';
  }

  @override
  String relayConnectionError(String error) {
    return 'Error de conexión al relay: $error';
  }

  @override
  String logoutFailed(String error) {
    return 'Error al cerrar sesión: $error';
  }

  @override
  String get loggingInAmber => 'Iniciando sesión (Amber)';

  @override
  String get amberModeConnected => '✅ Conectado con modo Amber\n\n';

  @override
  String get secretKeySaveAutoConnect =>
      '• Guardar la clave secreta conectará automáticamente al relay\n';

  @override
  String get multipleRelaysRedundancy =>
      '• Conectarse a múltiples relays mejora la redundancia\n';

  @override
  String get nostrNotInitialized =>
      'Nostr no está inicializado. Por favor, conéctate desde la pantalla de configuración.';

  @override
  String sendError(String error) {
    return '❌ Error de envío: $error';
  }
}
