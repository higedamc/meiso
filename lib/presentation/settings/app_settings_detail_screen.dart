import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/proxy_status_provider.dart';
import '../../providers/locale_provider.dart';

class AppSettingsDetailScreen extends ConsumerWidget {
  const AppSettingsDetailScreen({super.key});

  /// 曜日名を取得
  String _getWeekDayName(int day) {
    const days = ['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日'];
    return days[day % 7];
  }

  /// 週の開始曜日選択ダイアログ
  Future<void> _showWeekStartDayDialog(
      BuildContext context, WidgetRef ref, int currentDay) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('週の開始曜日を選択'),
        children: List.generate(7, (index) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, index),
            child: Text(
              _getWeekDayName(index),
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
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('カレンダー表示を選択'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'week'),
            child: Text(
              '週表示',
              style: TextStyle(
                fontWeight: currentView == 'week'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'month'),
            child: Text(
              '月表示',
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
    final proxyStatus = ref.watch(proxyStatusProvider);
    
    // 状態に応じた色とアイコン、メッセージを設定
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (proxyStatus) {
      case ProxyConnectionStatus.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = '未テスト';
        break;
      case ProxyConnectionStatus.testing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'テスト中...';
        break;
      case ProxyConnectionStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '接続成功';
        break;
      case ProxyConnectionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = '接続失敗（Orbotを起動してください）';
        break;
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
                const Text(
                  'プロキシ接続状態',
                  style: TextStyle(
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
              label: const Text('テスト'),
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
    final selected = await showDialog<Locale?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('言語を選択'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, null),
            child: Row(
              children: [
                if (currentLocale == null)
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('システムのデフォルト'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const Locale('en')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'en')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('English'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const Locale('ja')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'ja')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('日本語'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const Locale('es')),
            child: Row(
              children: [
                if (currentLocale?.languageCode == 'es')
                  const Icon(Icons.check, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Español'),
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
    String host = '127.0.0.1';
    String port = '9050';
    
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('プロキシ設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOCKS5プロキシのアドレスとポートを設定してください',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: 'ホスト',
                    hintText: '127.0.0.1',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(
                    labelText: 'ポート',
                    hintText: '9050',
                    border: OutlineInputBorder(),
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
                const Text(
                  '一般的な設定:\n'
                  '• Orbot: 127.0.0.1:9050\n'
                  '• カスタムプロキシ: ホストとポートを入力',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final enteredHost = hostController.text.trim();
                final enteredPort = portController.text.trim();
                
                // バリデーション
                if (enteredHost.isEmpty) {
                  setState(() {
                    errorMessage = 'ホストを入力してください';
                  });
                  return;
                }
                
                if (enteredPort.isEmpty) {
                  setState(() {
                    errorMessage = 'ポートを入力してください';
                  });
                  return;
                }
                
                final portNum = int.tryParse(enteredPort);
                if (portNum == null || portNum < 1 || portNum > 65535) {
                  setState(() {
                    errorMessage = 'ポート番号は 1-65535 の範囲で入力してください';
                  });
                  return;
                }
                
                Navigator.pop(context, {
                  'host': enteredHost,
                  'port': enteredPort,
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final newProxyUrl = 'socks5://${result['host']}:${result['port']}';
      await ref.read(appSettingsProvider.notifier).setProxyUrl(newProxyUrl);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('プロキシURLを更新しました: $newProxyUrl'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// ロケールの表示名を取得
  String _getLocaleName(Locale? locale) {
    if (locale == null) return 'システムのデフォルト';
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'es':
        return 'Español';
      default:
        return locale.languageCode;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettingsAsync = ref.watch(appSettingsProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final currentLocale = ref.watch(localeProvider);

    // Tor有効時に自動的にプロキシテストを実行
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (previous, next) {
      final prevSettings = previous?.value;
      final nextSettings = next.value;
      
      // Tor設定が変更された場合のみ実行
      if (prevSettings?.torEnabled != nextSettings?.torEnabled) {
        if (nextSettings?.torEnabled == true) {
          // 少し遅延させてからテスト実行
          Future.delayed(const Duration(milliseconds: 500), () {
            ref.read(proxyStatusProvider.notifier).testProxyConnection();
          });
        } else {
          // Tor無効時は状態をリセット
          ref.read(proxyStatusProvider.notifier).reset();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリ設定'),
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
                          ? 'Nostrリレーに自動同期（NIP-78 Kind 30078）'
                          : 'ローカル保存のみ（Nostr未接続）',
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
                    title: const Text('言語'),
                    subtitle: Text(_getLocaleName(currentLocale)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showLanguageDialog(context, ref, currentLocale),
                  ),

                  const Divider(height: 1),

                  // ダークモード設定
                  SwitchListTile(
                    title: const Text('ダークモード'),
                    subtitle: const Text('アプリのテーマを変更'),
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
                    leading:
                        Icon(Icons.calendar_today, color: Colors.purple.shade700),
                    title: const Text('週の開始曜日'),
                    subtitle: Text(_getWeekDayName(settings.weekStartDay)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showWeekStartDayDialog(
                        context, ref, settings.weekStartDay),
                  ),

                  const Divider(height: 1),

                  // カレンダー表示形式
                  ListTile(
                    leading:
                        Icon(Icons.view_week, color: Colors.purple.shade700),
                    title: const Text('カレンダー表示'),
                    subtitle: Text(
                        settings.calendarView == 'week' ? '週表示' : '月表示'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showCalendarViewDialog(
                        context, ref, settings.calendarView),
                  ),

                  const Divider(height: 1),

                  // 通知設定
                  SwitchListTile(
                    title: const Text('通知'),
                    subtitle: const Text('リマインダー通知を有効化'),
                    value: settings.notificationsEnabled,
                    onChanged: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .toggleNotifications();
                    },
                    secondary: Icon(
                      settings.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: Colors.purple.shade700,
                    ),
                  ),

                  const Divider(height: 1),

                  // Tor設定（Orbot経由）
                  SwitchListTile(
                    title: const Text('Tor経由で接続 (Orbot)'),
                    subtitle: Text(
                      settings.torEnabled 
                        ? 'Orbotプロキシ経由で接続中 (${settings.proxyUrl})'
                        : 'Orbot未使用（直接接続）',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: settings.torEnabled,
                    onChanged: (value) async {
                      await ref.read(appSettingsProvider.notifier).toggleTor();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                ? 'Torを有効にしました。次回接続時から適用されます。\nOrbotアプリを起動してください。'
                                : 'Torを無効にしました。次回接続時から適用されます。',
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    secondary: Icon(
                      settings.torEnabled ? Icons.shield : Icons.shield_outlined,
                      color: settings.torEnabled ? Colors.green.shade700 : Colors.purple.shade700,
                    ),
                  ),

                  // プロキシURL設定（Tor有効時のみ表示）
                  if (settings.torEnabled) ...[
                    ListTile(
                      leading: Icon(Icons.settings_ethernet, color: Colors.purple.shade700),
                      title: const Text('プロキシアドレスとポート'),
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
                                Icon(Icons.info, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  'アプリ設定について',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• アプリ設定はローカルに保存されます\n'
                              '• Nostr接続中の場合、設定は自動的に同期されます\n'
                              '• 複数デバイスで同じ設定を共有できます（NIP-78）\n'
                              '• 設定変更は即座に反映されます\n\n'
                              '🛡️ Tor設定について:\n'
                              '• Torを有効にすると、Orbotプロキシ経由でリレーに接続します\n'
                              '• Orbotアプリが起動している必要があります\n'
                              '• プライバシーとセキュリティが向上しますが、接続速度は遅くなります\n'
                              '• 設定変更後、再接続が必要です',
                              style: TextStyle(
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
                  child: Text('エラー: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

