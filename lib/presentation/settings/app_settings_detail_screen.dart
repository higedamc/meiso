import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';

import '../../providers/nostr_provider.dart';
import '../../providers/proxy_status_provider.dart';
import '../../providers/locale_provider.dart';

class AppSettingsDetailScreen extends ConsumerWidget {
  const AppSettingsDetailScreen({super.key});

  /// 曜日名を取得
  String _getWeekDayName(BuildContext context, int day) {
    final l10n = AppLocalizations.of(context);
    final days = [
      l10n.sunday,
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
    ];
    return days[day % 7];
  }

  /// 週の開始曜日選択ダイアログ
  Future<void> _showWeekStartDayDialog(
      BuildContext context, WidgetRef ref, int currentDay) async {
    final l10n = AppLocalizations.of(context);
    
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.selectWeekStartDay),
        children: List.generate(7, (index) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, index),
            child: Text(
              _getWeekDayName(context, index),
              style: TextStyle(
                fontWeight:
                    index == currentDay ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
    );

    if (selected != null) {
      await ref.read(appSettingsProvider.notifier).setWeekStartDay(selected);
    }
  }

  /// カレンダー表示形式選択ダイアログ
  Future<void> _showCalendarViewDialog(
      BuildContext context, WidgetRef ref, String currentView) async {
    final l10n = AppLocalizations.of(context);
    
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.selectCalendarView),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'week'),
            child: Text(
              l10n.weekView,
              style: TextStyle(
                fontWeight: currentView == 'week'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'month'),
            child: Text(
              l10n.monthView,
              style: TextStyle(
                fontWeight: currentView == 'month'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (selected != null) {
      await ref.read(appSettingsProvider.notifier).setCalendarView(selected);
    }
  }

  /// プロキシ接続状態インジケーターを構築
  Widget _buildProxyStatusIndicator(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final proxyStatus = ref.watch(proxyStatusProvider);
    
    // 状態に応じた色とアイコン、メッセージを設定
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (proxyStatus) {
      case ProxyConnectionStatus.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = l10n.untested;
      case ProxyConnectionStatus.testing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = l10n.testing;
      case ProxyConnectionStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = l10n.connectionSuccess;
      case ProxyConnectionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = l10n.connectionFailed;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.proxyConnectionStatus,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (proxyStatus != ProxyConnectionStatus.testing)
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(proxyStatusProvider.notifier).testProxyConnection();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.testButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
              ),
            )
          else
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// 言語選択ダイアログ
  Future<void> _showLanguageDialog(
      BuildContext context, WidgetRef ref, Locale? currentLocale) async {
    final l10n = AppLocalizations.of(context);
    
    final selected = await showDialog<Locale?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.languageSelection),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: Row(
              children: [
                if (currentLocale == null)
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(l10n.languageSystem),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, const Locale('en')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'en')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(l10n.languageEnglish),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, const Locale('ja')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'ja')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(l10n.languageJapanese),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, const Locale('es')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'es')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(l10n.languageSpanish),
              ],
            ),
          ),
        ],
      ),
    );

    if (selected != null || selected == null && currentLocale != null) {
      await ref.read(localeProvider.notifier).setLocale(selected);
    }
  }

  /// プロキシURL編集ダイアログ
  Future<void> _showProxyUrlDialog(
      BuildContext context, WidgetRef ref, String currentProxyUrl) async {
    // 現在のプロキシURLをパース
    var host = '127.0.0.1';
    var port = '9050';
    
    try {
      final uri = Uri.parse(currentProxyUrl);
      if (uri.host.isNotEmpty) {
        host = uri.host;
      }
      if (uri.port != 0) {
        port = uri.port.toString();
      }
    } catch (e) {
      // パースエラー時はデフォルト値を使用
    }

    final hostController = TextEditingController(text: host);
    final portController = TextEditingController(text: port);
    String? errorMessage;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final dialogL10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(dialogL10n.proxySettings),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dialogL10n.proxySettingsDescription,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hostController,
                    decoration: InputDecoration(
                      labelText: dialogL10n.host,
                      hintText: '127.0.0.1',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: portController,
                    decoration: InputDecoration(
                      labelText: dialogL10n.port,
                      hintText: '9050',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    dialogL10n.commonSettings,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogL10n.cancelButton),
              ),
              TextButton(
                onPressed: () {
                  final enteredHost = hostController.text.trim();
                  final enteredPort = portController.text.trim();
                  
                  // バリデーション
                  if (enteredHost.isEmpty) {
                    setState(() {
                      errorMessage = dialogL10n.hostRequired;
                    });
                    return;
                  }
                  
                  if (enteredPort.isEmpty) {
                    setState(() {
                      errorMessage = dialogL10n.portRequired;
                    });
                    return;
                  }
                  
                  final portNum = int.tryParse(enteredPort);
                  if (portNum == null || portNum < 1 || portNum > 65535) {
                    setState(() {
                      errorMessage = dialogL10n.portRangeError;
                    });
                    return;
                  }
                  
                  Navigator.pop(dialogContext, {
                    'host': enteredHost,
                    'port': enteredPort,
                  });
                },
                child: Text(dialogL10n.saveButton),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final newProxyUrl = 'socks5://${result['host']}:${result['port']}';
      await ref.read(appSettingsProvider.notifier).setProxyUrl(newProxyUrl);
      
      if (context.mounted) {
        final snackbarL10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackbarL10n.proxyUrlUpdated(newProxyUrl)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// ロケールの表示名を取得
  String _getLocaleName(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context);
    if (locale == null) return l10n.languageSystem;
    switch (locale.languageCode) {
      case 'en':
        return l10n.languageEnglish;
      case 'ja':
        return l10n.languageJapanese;
      case 'es':
        return l10n.languageSpanish;
      default:
        return locale.languageCode;
    }
  }

  /// TorModeの表示名を取得
  String _getTorModeName(BuildContext context, TorMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case TorMode.disabled:
        return l10n.torModeDisabled;
      case TorMode.internal:
        return l10n.torModeInternal;
      case TorMode.orbot:
        return l10n.torModeOrbot;
    }
  }

  /// TorModeの説明を取得
  String _getTorModeDescription(BuildContext context, TorMode mode) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case TorMode.disabled:
        return l10n.torModeDescriptionDisabled;
      case TorMode.internal:
        return l10n.torModeDescriptionInternal;
      case TorMode.orbot:
        return l10n.torModeDescriptionOrbot;
    }
  }

  /// Torモード選択ダイアログ
  Future<void> _showTorModeDialog(
      BuildContext context, WidgetRef ref, TorMode currentMode) async {
    final selected = await showDialog<TorMode>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return SimpleDialog(
        title: Text(dialogL10n.torConnectionModeTitle),
        children: [
          // Disabled
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, TorMode.disabled),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      currentMode == TorMode.disabled ? Icons.check_circle : Icons.circle_outlined,
                      color: currentMode == TorMode.disabled ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getTorModeName(context, TorMode.disabled),
                        style: TextStyle(
                          fontWeight: currentMode == TorMode.disabled 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 28, top: 4),
                  child: Text(
                    _getTorModeDescription(context, TorMode.disabled),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Internal (Embedded Tor) - 開発中のため無効化
          SimpleDialogOption(
            onPressed: null, // 無効化
            child: Opacity(
              opacity: 0.5, // グレーアウト
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentMode == TorMode.internal ? Icons.check_circle : Icons.circle_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              _getTorModeName(context, TorMode.internal),
                              style: TextStyle(
                                fontWeight: currentMode == TorMode.internal 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dialogL10n.inDevelopment,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      _getTorModeDescription(context, TorMode.internal),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Orbot (SOCKS5 Proxy)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, TorMode.orbot),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      currentMode == TorMode.orbot ? Icons.check_circle : Icons.circle_outlined,
                      color: currentMode == TorMode.orbot ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getTorModeName(context, TorMode.orbot),
                        style: TextStyle(
                          fontWeight: currentMode == TorMode.orbot 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 28, top: 4),
                  child: Text(
                    _getTorModeDescription(context, TorMode.orbot),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      },
    );

    if (selected != null && selected != currentMode) {
      await ref.read(appSettingsProvider.notifier).setTorMode(selected);
      
      if (context.mounted) {
        final snackbarL10n = AppLocalizations.of(context);
        final modeName = _getTorModeName(context, selected);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackbarL10n.torModeUpdated(modeName)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appSettingsAsync = ref.watch(appSettingsProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final currentLocale = ref.watch(localeProvider);

    // Torモード変更時に自動的にプロキシテストを実行
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (previous, next) {
      final prevSettings = previous?.value;
      final nextSettings = next.value;
      
      // Torモード設定が変更された場合のみ実行
      if (prevSettings?.torMode != nextSettings?.torMode) {
        if (nextSettings?.torMode == TorMode.orbot) {
          // Orbotモード時はプロキシテストを実行
          Future.delayed(const Duration(milliseconds: 500), () {
            ref.read(proxyStatusProvider.notifier).testProxyConnection();
          });
        } else {
          // Orbot以外のモード時は状態をリセット
          ref.read(proxyStatusProvider.notifier).reset();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appSettingsTitle),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Nostr同期ステータス
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isNostrInitialized
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    isNostrInitialized ? Icons.cloud : Icons.cloud_off,
                    size: 20,
                    color: isNostrInitialized
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isNostrInitialized
                          ? l10n.nostrAutoSync
                          : l10n.localStorageOnly,
                      style: TextStyle(
                        fontSize: 12,
                        color: isNostrInitialized
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 設定項目
            appSettingsAsync.when(
              data: (settings) => Column(
                children: [
                  // 言語設定
                  ListTile(
                    leading: Icon(Icons.language, color: Colors.purple.shade700),
                    title: Text(l10n.languageSettings),
                    subtitle: Text(_getLocaleName(context, currentLocale)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showLanguageDialog(context, ref, currentLocale),
                  ),

                  const Divider(height: 1),

                  // ダークモード設定
                  SwitchListTile(
                    title: Text(l10n.darkMode),
                    subtitle: Text(settings.darkMode ? l10n.darkModeEnabled : l10n.darkModeDisabled),
                    value: settings.darkMode,
                    onChanged: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .toggleDarkMode();
                    },
                    secondary: Icon(
                      settings.darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.purple.shade700,
                    ),
                  ),

                  const Divider(height: 1),

                  // 週の開始曜日
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(l10n.weekStartDay),
                    subtitle: Text(_getWeekDayName(context, settings.weekStartDay)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showWeekStartDayDialog(context, ref, settings.weekStartDay),
                  ),

                  const Divider(height: 1),

                  // カレンダー表示形式（ステージング版では無効化）
                  ListTile(
                    enabled: false,
                    leading: Icon(Icons.view_week, color: Colors.grey.shade400),
                    title: Text(
                      l10n.calendarView,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    subtitle: Text(
                      '${settings.calendarView == 'week' ? l10n.weekView : l10n.monthView} ${l10n.inDevelopment}',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                  ),

                  const Divider(height: 1),

                  // 通知設定（ステージング版では無効化）
                  SwitchListTile(
                    title: Text(
                      l10n.notifications,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    subtitle: Text(
                      '${l10n.notificationsSubtitle} ${l10n.inDevelopment}',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    value: settings.notificationsEnabled,
                    onChanged: null,
                    secondary: Icon(
                      settings.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: Colors.grey.shade400,
                    ),
                  ),

                  const Divider(height: 1),

                  // Tor接続モード設定
                  ListTile(
                    leading: Icon(
                      settings.torMode == TorMode.disabled 
                          ? Icons.shield_outlined 
                          : Icons.shield,
                      color: settings.torMode == TorMode.disabled 
                          ? Colors.purple.shade700 
                          : Colors.green.shade700,
                    ),
                    title: Text(l10n.torConnection),
                    subtitle: Text(
                      _getTorModeName(context, settings.torMode),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showTorModeDialog(context, ref, settings.torMode),
                  ),

                  // Orbotモード時の設定とガイド
                  if (settings.torMode == TorMode.orbot) ...[
                    // Orbot インストールガイド
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.orbotRequired,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.orbotRequiredDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Google Play ストアへのリンク
                                  // url_launcher を使用する場合はここに実装
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.openGooglePlayOrbot),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.shop, size: 16),
                                label: Text(l10n.googlePlay, style: const TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // F-Droid へのリンク
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.openFDroidOrbot),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.download, size: 16),
                                label: Text(l10n.fDroid, style: const TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    ListTile(
                      leading: Icon(Icons.settings_ethernet, color: Colors.purple.shade700),
                      title: Text(l10n.proxyAddress),
                      subtitle: Text(
                        settings.proxyUrl,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: () => _showProxyUrlDialog(context, ref, settings.proxyUrl),
                    ),
                    
                    // プロキシ接続状態インジケーター
                    _buildProxyStatusIndicator(context, ref),
                  ],
                  
                  // Internal Torモード時の説明
                  if (settings.torMode == TorMode.internal) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.embeddedTorDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // 注意事項
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.appSettingsInfo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.appSettingsInfoText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${l10n.error}: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

