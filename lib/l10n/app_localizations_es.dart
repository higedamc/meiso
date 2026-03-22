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
      '✅ Conectado con modo Amber\n\n🔒 Características de seguridad:\n• Firmar tareas con Amber al crear/editar\n• Proteger contenido con cifrado NIP-44\n• Clave secreta almacenada cifrada con ncryptsec en Amber\n\n⚡ Configuración Recomendada para Evitar Problemas de UX:\nOtorgue a Meiso \"permisos de basic actions o superiores\" en Amber\npara evitar diálogos de aprobación y garantizar un uso fluido.\n\n📝 Cómo configurar:\n1. Abrir la aplicación Amber\n2. Ir a Configuración → Aplicaciones Conectadas → Seleccionar \"Meiso\"\n3. Configurar Basic actions (NIP-44 Decrypt/Encrypt, Sign Event) a \"Permitir siempre\"';

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
  String get updateRecurringTodoTitle => 'Actualizar tarea recurrente';

  @override
  String get updateThisInstance => 'Actualizar solo esta instancia';

  @override
  String get updateAllInstances => 'Actualizar todas las instancias';

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
  String taskDeletedWithTitle(String title) {
    return '\"$title\" eliminada';
  }

  @override
  String todoMovedToNextDay(String title) {
    return '\"$title\" movida al día siguiente';
  }

  @override
  String allInstancesDeleted(String title) {
    return 'Todas las instancias de \"$title\" eliminadas';
  }

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
  String get amberPermissionsNote =>
      '💡 Para evitar problemas de UX:\nAl iniciar sesión con Amber, recomendamos otorgar \"permisos de basic actions o superiores\".\nPuede configurarlo en Configuración → Aplicaciones Conectadas → Meiso.';

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
  String get bootstrapPhaseContinueWithLocalCache =>
      'Continuando con caché local';

  @override
  String get bootstrapPhaseFetchingAccountRelays =>
      'Obteniendo relays vinculados a la cuenta...';

  @override
  String get bootstrapPhaseFetchingLocalTodos =>
      'Obteniendo tareas desde relay local...';

  @override
  String get bootstrapPhaseFetchingLocalGroupTodos =>
      'Obteniendo tareas de grupo desde relay local...';

  @override
  String get bootstrapPhaseFetchingAllRelaysTodos =>
      'Obteniendo tareas desde todos los relays...';

  @override
  String get bootstrapPhaseFetchingAllRelaysGroupTodos =>
      'Obteniendo tareas de grupo desde todos los relays...';

  @override
  String get bootstrapPhaseFetchingGroupInvitations =>
      'Obteniendo invitaciones de grupo...';

  @override
  String get bootstrapPhaseCompleted => 'Sincronización completada';

  @override
  String get bootstrapPhaseFailed => 'Sincronización fallida';

  @override
  String get bootstrapContinueWithLocalCacheButton =>
      'Continuar con caché local';

  @override
  String get retryButton => 'Reintentar';

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

  @override
  String get syncLoadingData => 'Cargando datos...';

  @override
  String get syncMigratingData => 'Migrando datos...';

  @override
  String get syncSyncingData => 'Sincronizando datos...';

  @override
  String get syncPreparingMigration => 'Preparando migración de datos...';

  @override
  String get syncFetchingOldData => 'Obteniendo datos antiguos...';

  @override
  String get syncConvertingToNewFormat => 'Convirtiendo a nuevo formato...';

  @override
  String get syncDeletingOldData => 'Eliminando datos antiguos...';

  @override
  String get syncMigrationCompleted => 'Migración de datos completada';

  @override
  String get aboutRelays => 'Acerca de los Relays';

  @override
  String get amberMode => 'Modo Amber';

  @override
  String get cryptographyInUse => 'Criptografía en Uso';

  @override
  String get cryptographyDetailsUsedInMeiso =>
      'Detalles de la Criptografía Utilizada en Meiso';

  @override
  String get cryptographyIntroTitle =>
      'Meiso adopta los más altos estándares de la criptografía moderna.';

  @override
  String get cryptographyIntroDescription =>
      'Este documento explica los detalles de las tecnologías criptográficas utilizadas en Meiso para Bitcoiners y Nostriches.';

  @override
  String get cryptoArchitectureTitle =>
      '1. Descripción General de la Arquitectura';

  @override
  String get cryptoArgon2idTitle =>
      '2. Argon2id - Función de Derivación de Contraseña';

  @override
  String get cryptoAes256GcmTitle => '3. AES-256-GCM - Algoritmo de Cifrado';

  @override
  String get cryptoNip44Title => '4. NIP-44 - Estándar de Cifrado de Nostr';

  @override
  String get cryptoEd25519Title => '5. Ed25519 - Firma Digital';

  @override
  String get cryptoAmberIntegrationTitle =>
      '6. Integración con Amber - Seguridad tipo Monedero de Hardware';

  @override
  String get cryptoSecureStorageTitle =>
      '7. Almacenamiento Seguro - Implementación en Rust';

  @override
  String get cryptoThreatModelTitle => '8. Modelo de Amenazas y Limitaciones';

  @override
  String get relayList => 'Lista de Relays';

  @override
  String get noRelaysRegistered => 'No hay relays registrados';

  @override
  String get deleteTooltip => 'Eliminar';

  @override
  String get aboutRelaysDescription =>
      '• Los relays son servidores en la red Nostr\n• Conectarse a múltiples relays mejora la redundancia\n• Las URLs de relay deben comenzar con wss:// o ws://\n• Agregar/eliminar relays se guarda inmediatamente en Nostr (Kind 10002)\n• Los cambios de relay toman efecto inmediatamente (no requiere reinicio)\n• Use el botón \"Sincronizar desde Nostr\" para obtener configuraciones de otros dispositivos\n• Durante la sincronización, solo actualiza si remoto y local difieren';

  @override
  String get currentlyConnectedViaTor =>
      '• Actualmente conectado a través de Tor (usando proxy Orbot)';

  @override
  String get cryptoArchPara1 =>
      'Meiso adopta una \"Arquitectura de Conocimiento Cero\" y nunca envía sus claves secretas o datos de tareas a servidores. Todo el procesamiento de cifrado se realiza en su dispositivo.';

  @override
  String get cryptoArchSecurityModel =>
      'Modelo de Seguridad:\n• Cifrado de Extremo a Extremo (E2EE)\n• Cifrado del lado del cliente\n• El servidor almacena solo datos cifrados\n• Solo usted posee las claves secretas';

  @override
  String get cryptoArgon2Intro =>
      'Argon2id es el algoritmo de hash de contraseñas más reciente y fuerte, ganador de la Competencia de Hash de Contraseñas (PHC) de 2015.';

  @override
  String get cryptoArgon2WhyTitle => '¿Por qué Argon2id?';

  @override
  String get cryptoArgon2BruteForce => 'Resistencia a ataques de fuerza bruta';

  @override
  String get cryptoArgon2BruteForceDesc =>
      'Requiere tanto costos computacionales como de memoria, lo que lo hace extremadamente resistente a ataques paralelos usando GPUs o ASICs.';

  @override
  String get cryptoArgon2SideChannel =>
      'Resistencia a ataques de canal lateral';

  @override
  String get cryptoArgon2SideChannelDesc =>
      'Un \"híbrido\" que combina los patrones de acceso a memoria impredecibles de Argon2i con la eficiencia computacional de Argon2d.';

  @override
  String get cryptoArgon2Standard => 'Estándar de la industria';

  @override
  String get cryptoArgon2StandardDesc =>
      'Recomendado por OWASP, NIST y la comunidad de Ingeniería Criptográfica. Estándar de próxima generación que supera a bcrypt y PBKDF2.';

  @override
  String get cryptoArgon2Params =>
      'Parámetros de implementación en Meiso:\n• Costo de memoria: 19 MiB (optimizado)\n• Iteraciones: 2 veces\n• Paralelismo: 1 hilo\n• Longitud de salida: 32 bytes (256 bits)\n• Sal: Generación aleatoria (16 bytes)';

  @override
  String get cryptoArgon2Reference => '📚 Referencia: Argon2 RFC 9106';

  @override
  String get cryptoAesIntro =>
      'AES-256-GCM es un algoritmo de \"Cifrado Autenticado con Datos Asociados (AEAD)\" utilizado por el gobierno de EE. UU. para proteger información clasificada.';

  @override
  String get cryptoAesStrengthTitle => 'Fortaleza de AES-256';

  @override
  String get cryptoAesStrengthDesc =>
      'AES-256 tiene un espacio de claves de 2^256, lo que hace que los ataques de fuerza bruta sean prácticamente imposibles incluso con las supercomputadoras modernas. Mantiene una seguridad efectiva de 128 bits incluso en la era de la computación cuántica.';

  @override
  String get cryptoAesGcmAdvantagesTitle => 'Ventajas del Modo GCM';

  @override
  String get cryptoAesAead => 'Cifrado Autenticado (AEAD)';

  @override
  String get cryptoAesAeadDesc =>
      'Genera un Código de Autenticación de Mensajes (MAC) simultáneamente con el cifrado. Permite la detección de manipulación de datos.';

  @override
  String get cryptoAesPerformance => 'Procesamiento de alta velocidad';

  @override
  String get cryptoAesPerformanceDesc =>
      'Permite el procesamiento paralelo y es acelerado por hardware mediante las instrucciones AES-NI de las CPUs modernas.';

  @override
  String get cryptoAesPaddingResistance => 'Resistencia a ataques de relleno';

  @override
  String get cryptoAesPaddingResistanceDesc =>
      'Como modo de cifrado de flujo, no hay riesgo de ataques de oráculo de relleno.';

  @override
  String get cryptoAesParams =>
      'Implementación en Meiso:\n• Algoritmo de cifrado: AES-256-GCM\n• Longitud de clave: 256 bits (derivada de Argon2id)\n• Nonce: Generación aleatoria (96 bits)\n• Longitud de etiqueta: 128 bits (para detección de manipulación)\n• Propósito: Almacenamiento cifrado de claves secretas';

  @override
  String get cryptoAesReference => '📚 Referencia: NIST SP 800-38D (GCM)';

  @override
  String get cryptoNip44Intro =>
      'NIP-44 es la especificación estándar para mensajes cifrados en el protocolo Nostr. Proporciona cifrado seguro de extremo a extremo utilizando Criptografía de Curva Elíptica (ECC).';

  @override
  String get cryptoNip44MechanismTitle => 'Mecanismo de Cifrado';

  @override
  String get cryptoNip44MechanismDesc =>
      'NIP-44 genera un \"secreto compartido\" a partir de su clave secreta y la clave pública del destinatario, y lo utiliza para cifrar mensajes.';

  @override
  String get cryptoNip44Process =>
      'Proceso de Cifrado:\n1. ECDH (Elliptic Curve Diffie-Hellman)\n   → Generar secreto compartido con curva secp256k1\n\n2. Derivación de clave con HMAC-SHA256 (HKDF)\n   → Generar clave de cifrado y clave de autenticación de mensajes\n\n3. Cifrar con ChaCha20-Poly1305\n   → Cifrado AEAD rápido y seguro\n\n4. Codificar en Base64 y transmitir';

  @override
  String get cryptoNip44UsageTitle => 'Uso en Meiso';

  @override
  String get cryptoNip44UsageDesc =>
      'En Meiso, todos los datos de tareas se cifran con NIP-44 y se almacenan en relays Nostr. Esto evita que los servidores relay lean el contenido de sus tareas.';

  @override
  String get cryptoNip44SecurityTitle =>
      '🔐 Características de Seguridad Importantes';

  @override
  String get cryptoNip44SecurityDesc =>
      '• Los servidores relay solo pueden ver texto cifrado\n• No se puede descifrar sin su propia clave secreta\n• No se proporciona Secreto Directo (Forward Secrecy)\n• Si la clave secreta se filtra, todos los mensajes pasados pueden descifrarse';

  @override
  String get cryptoNip44Reference => '📚 Referencia: Especificación NIP-44';

  @override
  String get cryptoEd25519Intro =>
      'Ed25519 es un algoritmo de firma moderno basado en Criptografía de Curva Elíptica (ECC). Se adopta ampliamente en protocolos de seguridad modernos como Bitcoin, SSH y TLS 1.3.';

  @override
  String get cryptoEd25519AdvantagesTitle => 'Ventajas de Ed25519';

  @override
  String get cryptoEd25519Speed => 'Rápido';

  @override
  String get cryptoEd25519SpeedDesc =>
      'Más de 10 veces más rápido que RSA-2048 para firmar y verificar. Funciona rápido incluso en dispositivos móviles.';

  @override
  String get cryptoEd25519Compact => 'Compacto';

  @override
  String get cryptoEd25519CompactDesc =>
      'Clave pública: 32 bytes, Clave privada: 32 bytes, Firma: 64 bytes. 1/8 del tamaño de RSA con seguridad igual o mejor.';

  @override
  String get cryptoEd25519Deterministic => 'Determinístico';

  @override
  String get cryptoEd25519DeterministicDesc =>
      'Siempre genera la misma firma para el mismo mensaje. Sin riesgo de vulnerabilidades del generador de números aleatorios.';

  @override
  String get cryptoEd25519SafeImpl => 'Implementación segura';

  @override
  String get cryptoEd25519SafeImplDesc =>
      'La resistencia a ataques de canal lateral está incorporada desde la etapa de diseño.';

  @override
  String get cryptoEd25519NostrRoleTitle => 'Rol en Nostr';

  @override
  String get cryptoEd25519NostrRoleDesc =>
      'En Nostr, todos los eventos (mensajes, tareas, actualizaciones de perfil, etc.) están firmados con Ed25519. Esto garantiza la autenticidad del creador del evento y la integridad de los datos.';

  @override
  String get cryptoEd25519SigningProcess =>
      'Proceso de firma Nostr:\n1. Serializar evento en formato JSON\n2. Hash con SHA-256\n3. Firmar con clave privada Ed25519\n4. Adjuntar firma al evento y enviar';

  @override
  String get cryptoEd25519Reference => '📚 Referencia: RFC 8032 (EdDSA)';

  @override
  String get cryptoAmberIntro =>
      'Amber es una aplicación dedicada para gestionar de forma segura las claves secretas de Nostr. No comparte claves secretas con otras aplicaciones y solo procesa solicitudes de firma.';

  @override
  String get cryptoAmberNcryptsecTitle => 'Formato ncryptsec';

  @override
  String get cryptoAmberNcryptsecDesc =>
      'Amber almacena claves secretas en formato \"ncryptsec\". Esta es una cadena codificada en Bech32 que contiene una clave secreta cifrada con AES-256-CBC.';

  @override
  String get cryptoAmberNcryptsecStructure =>
      'Estructura de ncryptsec:\nncryptsec1... ← Prefijo Bech32\n├─ Versión (1 byte)\n├─ Sal (16 bytes)\n├─ Nonce/IV (16 bytes)\n├─ Clave secreta cifrada (32 bytes)\n└─ Etiqueta de detección de manipulación';

  @override
  String get cryptoAmberBenefitsTitle => 'Beneficios del Modo Amber';

  @override
  String get cryptoAmberIsolation => 'Aislamiento de clave secreta';

  @override
  String get cryptoAmberIsolationDesc =>
      'Meiso no retiene claves secretas y solo solicita Amber cuando se necesita firmar.';

  @override
  String get cryptoAmberBiometric => 'Autenticación biométrica';

  @override
  String get cryptoAmberBiometricDesc =>
      'Puede requerir autenticación de huellas dactilares o PIN al firmar con Amber.';

  @override
  String get cryptoAmberAuditable => 'Auditable';

  @override
  String get cryptoAmberAuditableDesc =>
      'Puede revisar y aprobar todas las solicitudes de firma en la aplicación Amber.';

  @override
  String get cryptoAmberKeyReuse => 'Reutilización de claves';

  @override
  String get cryptoAmberKeyReuseDesc =>
      'Puede compartir de forma segura una clave secreta entre múltiples aplicaciones Nostr.';

  @override
  String get cryptoAmberHardwareWalletTitle =>
      '💡 Similitud con Billeteras de Hardware';

  @override
  String get cryptoAmberHardwareWalletDesc =>
      'Amber adopta la misma arquitectura de \"nunca exportar claves secretas\" que las billeteras de hardware de Bitcoin (Ledger, Trezor).';

  @override
  String get cryptoAmberReference => '🔗 Amber en GitHub';

  @override
  String get cryptoSecureStorageIntro =>
      'La gestión de claves secretas de Meiso está completamente implementada en Rust. Rust es un lenguaje de programación de sistemas seguro con seguridad de memoria garantizada a nivel de lenguaje.';

  @override
  String get cryptoStorageWhyRustTitle => '¿Por qué Rust?';

  @override
  String get cryptoStorageMemorySafety => 'Seguridad de memoria';

  @override
  String get cryptoStorageMemorySafetyDesc =>
      'Las vulnerabilidades relacionadas con la memoria, como desbordamiento de búfer, use-after-free y carreras de datos, son fundamentalmente imposibles.';

  @override
  String get cryptoStorageZeroCost => 'Abstracciones de costo cero';

  @override
  String get cryptoStorageZeroCostDesc =>
      'Logra un rendimiento equivalente a C/C++ mientras escribe código de alto nivel.';

  @override
  String get cryptoStorageTypeSystem => 'Sistema de tipos fuerte';

  @override
  String get cryptoStorageTypeSystemDesc =>
      'Los tipos Option y Result fuerzan el manejo de errores.';

  @override
  String get cryptoStorageImplTitle => 'Implementación de Almacenamiento';

  @override
  String get cryptoStorageImplDesc =>
      'Meiso almacena claves secretas cifradas en el \"ApplicationSupportDirectory\" de Flutter. Este directorio está protegido por el sistema operativo del acceso de otras aplicaciones.';

  @override
  String get cryptoStoragePath =>
      'Ruta de almacenamiento (Android):\n/data/data/com.example.meiso/files/encrypted_key.bin\n\nContenido del archivo:\n• Formato JSON\n• Campos: salt, nonce, ciphertext\n• Todo codificado en Base64';

  @override
  String get cryptoStorageMemorySecurityTitle => 'Seguridad de Memoria';

  @override
  String get cryptoStorageZeroize => 'Zeroize';

  @override
  String get cryptoStorageZeroizeDesc =>
      'Borra de forma segura las claves secretas de la memoria después del uso.';

  @override
  String get cryptoStorageStackAllocation => 'Asignación de pila';

  @override
  String get cryptoStorageStackAllocationDesc =>
      'Coloca las claves secretas en la pila en lugar del heap, minimizando la vida útil.';

  @override
  String get cryptoStorageMemoryDump => 'Contramedidas de volcado de memoria';

  @override
  String get cryptoStorageMemoryDumpDesc =>
      'El código Rust está optimizado incluso en compilaciones de depuración, lo que hace que los datos sensibles tengan menos probabilidades de permanecer.';

  @override
  String get cryptoThreatModelIntro =>
      'Meiso utiliza tecnologías criptográficas muy fuertes, pero la seguridad perfecta no existe. Por favor, comprenda las siguientes amenazas.';

  @override
  String get cryptoThreatWhatWeCanProtectTitle => 'Lo Que Podemos Proteger';

  @override
  String get cryptoThreatNetworkEavesdropping => 'Espionaje de red';

  @override
  String get cryptoThreatNetworkEavesdroppingDesc =>
      'TLS + cifrado E2EE neutraliza el espionaje en rutas de comunicación.';

  @override
  String get cryptoThreatMaliciousRelay => 'Servidores relay maliciosos';

  @override
  String get cryptoThreatMaliciousRelayDesc =>
      'Los relays solo pueden ver datos cifrados.';

  @override
  String get cryptoThreatBruteForce => 'Ataques de fuerza bruta';

  @override
  String get cryptoThreatBruteForceDesc =>
      'Argon2id + AES-256 hace que el descifrado sea imposible en tiempo realista.';

  @override
  String get cryptoThreatWhatWeCannotProtectTitle =>
      'Lo Que No Podemos Proteger';

  @override
  String get cryptoThreatWarningTitle =>
      '⚠️ Las siguientes amenazas requieren atención';

  @override
  String get cryptoThreatWarningDesc =>
      '• Robo físico del dispositivo + fuga de contraseña\n• Malware de registro de teclas o captura de pantalla\n• Dispositivos rooteados/Jailbreak\n• Vulnerabilidades del sistema operativo o firmware\n• Ataques de ingeniería social\n• Amenazas futuras de computadoras cuánticas (colapso de RSA/ECC)';

  @override
  String get cryptoThreatBestPracticesTitle => 'Mejores Prácticas';

  @override
  String get cryptoThreatStrongPassword => 'Contraseña fuerte';

  @override
  String get cryptoThreatStrongPasswordDesc =>
      'Use una contraseña aleatoria de 20 caracteres o más.';

  @override
  String get cryptoThreatDeviceEncryption => 'Cifrado del dispositivo';

  @override
  String get cryptoThreatDeviceEncryptionDesc =>
      'Habilite el cifrado de disco completo en Android/iOS.';

  @override
  String get cryptoThreatKeepOsUpdated =>
      'Mantener el sistema operativo actualizado';

  @override
  String get cryptoThreatKeepOsUpdatedDesc =>
      'Aplique parches de seguridad regularmente.';

  @override
  String get cryptoThreatRecommendAmber => 'Modo Amber recomendado';

  @override
  String get cryptoThreatRecommendAmberDesc =>
      'Si se requiere mayor seguridad, use el modo Amber.';

  @override
  String get cryptoTableOfContents => '📖 Tabla de Contenidos';

  @override
  String get cryptoTocItem1 => '1. Descripción de la Arquitectura';

  @override
  String get cryptoTocItem2 =>
      '2. Argon2id - Función de Derivación de Contraseña';

  @override
  String get cryptoTocItem3 => '3. AES-256-GCM - Algoritmo de Cifrado';

  @override
  String get cryptoTocItem4 => '4. NIP-44 - Estándar de Cifrado Nostr';

  @override
  String get cryptoTocItem5 => '5. Ed25519 - Firmas Digitales';

  @override
  String get cryptoTocItem6 =>
      '6. Integración Amber - Seguridad Tipo Billetera de Hardware';

  @override
  String get cryptoTocItem7 => '7. Almacenamiento Seguro - Implementación Rust';

  @override
  String get cryptoTocItem8 => '8. Modelo de Amenazas y Limitaciones';

  @override
  String get cryptoFooterSecurityTitle =>
      '🔒 Preguntas y Reportes de Seguridad';

  @override
  String get cryptoFooterSecurityDesc =>
      'Si descubre un problema de seguridad, repórtelo a través de GitHub Issues o Nostr (DM).';

  @override
  String get cryptoFooterOpenSource => 'Todo el código es de código abierto';

  @override
  String get cryptographyDetailsDescription =>
      'Detalles de las tecnologías criptográficas utilizadas en Meiso';

  @override
  String get synced => 'Sincronizado';

  @override
  String syncedWithEventId(String eventId) {
    return 'Sincronizado (Event ID: $eventId...)';
  }

  @override
  String get sendingToRelay => 'Enviando al relay...';

  @override
  String get sentToRelay => '✅ Enviado al relay';

  @override
  String get sendToRelay => 'Enviar al relay';

  @override
  String get todoAddFeatureInDevelopment =>
      'La función de agregar tareas está en desarrollo';

  @override
  String get mlsGroupBackupTitle => 'Respaldo de Grupo MLS';

  @override
  String get mlsGroupBackupSubtitle => 'Exportar/Importar Key Package';

  @override
  String get mlsBackupDescription =>
      'Exportar/importar Key Package para volver a unirse\na grupos existentes después de reinstalar la app.';

  @override
  String get exportButton => 'Exportar';

  @override
  String get importButton => 'Importar';

  @override
  String get mlsBackupImportInstruction =>
      'Por favor importa desde\nConfiguración > Avanzado > Respaldo de Grupo MLS.';

  @override
  String get exportingBackup => '📤 Exportando...';

  @override
  String get backupCopiedToClipboard =>
      '✅ Respaldo copiado al portapapeles\n\nPor favor guárdalo en un lugar seguro.';

  @override
  String get clipboardCopied => '📋 Copiado al portapapeles';

  @override
  String exportFailed(String error) {
    return '❌ Exportación falló\n\n$error';
  }

  @override
  String get noBackupDataInClipboard =>
      '❌ No hay datos de respaldo en el portapapeles';

  @override
  String get confirmImportBackup =>
      '¿Importar respaldo?\n\n⚠️ Por favor reinicia la app después de importar.';

  @override
  String get importingBackup => '📥 Importando...';

  @override
  String get backupImportedRestart =>
      '✅ Respaldo importado\n\n🔄 Por favor reinicia la app.';

  @override
  String get importCompletedRestart =>
      '✅ Importación completada. Por favor reinicia la app';

  @override
  String importFailed(String error) {
    return '❌ Importación falló\n\n$error';
  }

  @override
  String get ifYouHaveBackup => 'Si tienes un respaldo';

  @override
  String get ifYouDontHaveBackup => 'Si no tienes un respaldo';

  @override
  String get requestReinviteFromAdmin =>
      'Por favor solicita una nueva invitación al administrador del grupo.';

  @override
  String inviteAcceptanceFailed(String error) {
    return 'Falló la aceptación de la invitación\n\n$error';
  }

  @override
  String get subtasksHeader => 'SUBTAREAS';

  @override
  String get noSubtasks => 'Aun no hay subtareas';

  @override
  String get addSubtaskHint => 'Agregar subtarea...';

  @override
  String get linkedTasksHeader => 'TAREAS VINCULADAS';

  @override
  String get noLinkedTasks => 'No hay tareas vinculadas';

  @override
  String get linkTaskDialogTitle => 'VINCULAR TAREA';

  @override
  String get linkTypeBlocks => 'Bloquea';

  @override
  String get linkTypeBlockedBy => 'Bloqueado por';

  @override
  String get linkTypeRelatedTo => 'Relacionado con';

  @override
  String get linkTypeDuplicateOf => 'Duplicado de';

  @override
  String get linkRelationship => 'Relacion';

  @override
  String get linkTargetTask => 'Tarea objetivo';

  @override
  String get linkButton => 'VINCULAR';

  @override
  String get noTasksToLink => 'No hay tareas disponibles para vincular';

  @override
  String get hideCompletedTasks => 'Ocultar Tareas Completadas';

  @override
  String get hideCompletedTasksSubtitle =>
      'Ocultar tareas completadas en todas las vistas';

  @override
  String get attachImage => 'Adjuntar Imagen';

  @override
  String get removeImage => 'Eliminar Imagen';

  @override
  String get uploadingImage => 'Subiendo imagen...';

  @override
  String imageUploadFailed(String reason) {
    return 'Error al subir imagen: $reason';
  }

  @override
  String get imageUploaded => 'Imagen adjuntada exitosamente';

  @override
  String get imageSourceCamera => 'Camara';

  @override
  String get imageSourceGallery => 'Galeria';

  @override
  String get mediaServers => 'Servidores de Medios';

  @override
  String get mediaServersSubtitle =>
      'Gestionar servidores de carga Blossom / NIP-96';

  @override
  String get addMediaServer => 'Agregar Servidor';

  @override
  String get mediaServerUrl => 'URL del Servidor';

  @override
  String get mediaServerType => 'Tipo de Servidor';

  @override
  String get mediaServerManual => 'Manual';

  @override
  String get mediaServerAutoDiscovered => 'Auto-descubierto (Kind 10063)';

  @override
  String get deleteMediaServer => 'Eliminar Servidor';

  @override
  String get noMediaServers =>
      'No hay servidores configurados. Agregue uno o conectese a Nostr para descubrirlos automaticamente.';

  @override
  String get mediaServerAdded => 'Servidor de medios agregado';

  @override
  String get mediaServerDeleted => 'Servidor de medios eliminado';

  @override
  String get invalidUrl => 'Ingrese una URL valida';

  @override
  String get refreshServers => 'Actualizar Servidores';

  @override
  String get selectUploadServer => 'Subir a';

  @override
  String get noServersFound =>
      'No se encontraron servidores. Ingrese una URL abajo.';

  @override
  String get addCustomServer => 'Usar URL personalizada';

  @override
  String get customServerUrlHint => 'https://example.com';

  @override
  String get upload => 'Subir';
}
