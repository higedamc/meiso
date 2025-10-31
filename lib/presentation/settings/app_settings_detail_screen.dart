import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/nostr_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettingsAsync = ref.watch(appSettingsProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);

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

