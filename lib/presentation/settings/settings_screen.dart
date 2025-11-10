import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/todos_provider.dart';
import '../../services/logger_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final publicKeyHex = ref.watch(publicKeyProvider);
    final publicKeyNpubAsync = ref.watch(publicKeyNpubProvider);
    final isAmberMode = ref.watch(isAmberModeProvider);
    final relayStatuses = ref.watch(relayStatusProvider);

    // 接続中のリレー数をカウント
    final connectedRelaysCount = relayStatuses.values
        .where((relay) => relay.state == RelayConnectionState.connected)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Nostr接続ステータス
          Container(
            padding: const EdgeInsets.all(16),
            color: isNostrInitialized
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: Column(
              children: [
                Icon(
                  isNostrInitialized ? Icons.check_circle : Icons.warning,
                  size: 40,
                  color:
                      isNostrInitialized ? Colors.green : Colors.orange.shade700,
                ),
                const SizedBox(height: 8),
                Text(
                  isNostrInitialized
                      ? (isAmberMode ? l10n.nostrConnectedAmber : l10n.nostrConnected)
                      : l10n.nostrDisconnected,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isNostrInitialized && publicKeyHex != null) ...[
                  const SizedBox(height: 8),
                  publicKeyNpubAsync.when(
                    data: (npubKey) => npubKey != null
                        ? Text(
                            'npub: ${npubKey.substring(0, 16)}...',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                          )
                        : Text(
                            'hex: ${publicKeyHex.substring(0, 16)}...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                    loading: () => const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => Text(
                      'hex: ${publicKeyHex.substring(0, 16)}...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                if (isNostrInitialized) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.relaysConnectedCount(connectedRelaysCount, relayStatuses.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 設定項目リスト
          _buildSettingTile(
            context,
            icon: Icons.vpn_key,
            title: l10n.secretKeyManagement,
            subtitle: isNostrInitialized ? l10n.secretKeyConfigured : l10n.secretKeyNotConfigured,
            onTap: () => context.push('/settings/secret-key'),
          ),

          const Divider(height: 1),

          _buildSettingTile(
            context,
            icon: Icons.dns,
            title: l10n.relayServerManagement,
            subtitle: l10n.relayCountRegistered(relayStatuses.length),
            onTap: () => context.push('/settings/relays'),
          ),

          const Divider(height: 1),

          _buildSettingTile(
            context,
            icon: Icons.settings_applications,
            title: l10n.appSettings,
            subtitle: l10n.appSettingsSubtitle,
            onTap: () => context.push('/settings/app'),
          ),

          // デバッグログ表示（デバッグビルドのみ）
          if (kDebugMode) ...[
            const Divider(height: 1),
            _buildSettingTile(
              context,
              icon: Icons.bug_report,
              title: l10n.debugLogs,
              subtitle: l10n.debugLogsSubtitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TalkerScreen(talker: talker),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),

          // Amberモード情報
          if (isAmberMode)
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
                          Icon(Icons.security, color: AppTheme.primaryPurple),
                          const SizedBox(width: 8),
                          Text(
                            l10n.amberModeTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.amberModeInfo,
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
          if (isAmberMode) const SizedBox(height: 16),

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
                          l10n.autoSyncInfoTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.autoSyncInfo,
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
          const SizedBox(height: 24),

          // MLS統合テスト（開発者向け）
          if (kDebugMode && isNostrInitialized) ...[
            _buildSettingTile(
              context,
              icon: Icons.science,
              title: 'MLS統合テスト (PoC)',
              subtitle: 'Option B: 1人グループでの動作確認',
              onTap: () => _showMlsTestDialog(context, ref),
            ),
            const Divider(height: 1),
          ],

          const SizedBox(height: 24),

          // バージョン情報
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final info = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        l10n.versionInfo(info.version, info.buildNumber),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.appName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryPurple),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showMlsTestDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _MlsTestDialog(ref: ref),
    );
  }
}

/// MLS統合テストダイアログ（Option B PoC）
class _MlsTestDialog extends StatefulWidget {
  final WidgetRef ref;

  const _MlsTestDialog({required this.ref});

  @override
  State<_MlsTestDialog> createState() => _MlsTestDialogState();
}

class _MlsTestDialogState extends State<_MlsTestDialog> {
  final _logs = <String>[];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  Future<void> _runMlsTest() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      
      _addLog('🚀 MLS統合テスト開始');
      
      // Step 1: グループ作成
      _addLog('📦 Step 1: グループ作成');
      final groupId = 'test-mls-group-${DateTime.now().millisecondsSinceEpoch}';
      await todosNotifier.createMlsGroupList(
        listId: groupId,
        listName: 'MLS Test List',
      );
      _addLog('✅ グループ作成完了: $groupId');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 2: TODO暗号化
      _addLog('🔒 Step 2: TODO暗号化');
      final testTodo = {
        'id': 'test-todo-001',
        'title': 'Test TODO in MLS Group',
        'completed': false,
        'date': DateTime.now().toIso8601String(),
        'order': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final encrypted = await todosNotifier.encryptMlsTodo(
        groupId: groupId,
        todoJson: testTodo.toString(),
      );
      _addLog('✅ TODO暗号化完了: ${encrypted.substring(0, 32)}...');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 3: TODO復号化
      _addLog('🔓 Step 3: TODO復号化');
      final decrypted = await todosNotifier.decryptMlsTodo(
        groupId: groupId,
        encryptedMsg: encrypted,
      );
      _addLog('✅ TODO復号化完了: ${decrypted.substring(0, 50)}...');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 完了
      _addLog('');
      _addLog('🎉 MLS統合テスト完了！');
      _addLog('✅ グループ作成: OK');
      _addLog('✅ TODO暗号化: OK');
      _addLog('✅ TODO復号化: OK');
      _addLog('');
      _addLog('📝 次のステップ:');
      _addLog('  - 他のアカウントからKey Package取得');
      _addLog('  - メンバー追加機能実装');
      _addLog('  - 2人以上でのTODO共有テスト');
      
    } catch (e, stackTrace) {
      _addLog('❌ エラー: $e');
      _addLog('Stack trace: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.science, color: Colors.blue),
          SizedBox(width: 8),
          Text('MLS統合テスト'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Option B PoC: 1人グループでの動作確認',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'テスト実行ボタンを押してください',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRunning ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _runMlsTest,
          icon: _isRunning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isRunning ? '実行中...' : 'テスト実行'),
        ),
      ],
    );
  }
}
