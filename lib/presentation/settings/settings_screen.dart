import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('設定'),
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
                      ? (isAmberMode ? 'Nostr接続中 (Amber)' : 'Nostr接続中')
                      : 'Nostr未接続',
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
                    'リレー: $connectedRelaysCount/${relayStatuses.length} 接続中',
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
            title: '秘密鍵管理',
            subtitle: isNostrInitialized ? '接続済み' : '未設定',
            onTap: () => context.push('/settings/secret-key'),
          ),

          const Divider(height: 1),

          _buildSettingTile(
            context,
            icon: Icons.dns,
            title: 'リレーサーバー管理',
            subtitle: '${relayStatuses.length}件登録済み',
            onTap: () => context.push('/settings/relays'),
          ),

          const Divider(height: 1),

          _buildSettingTile(
            context,
            icon: Icons.settings_applications,
            title: 'アプリ設定',
            subtitle: 'テーマ、カレンダー、通知、Tor',
            onTap: () => context.push('/settings/app'),
          ),

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
                            'Amberモード',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '✅ Amberモードで接続中\n\n'
                        '🔒 セキュリティ機能:\n'
                        '• Todoの作成・編集時にAmberで署名\n'
                        '• NIP-44暗号化でコンテンツを保護\n'
                        '• 秘密鍵はAmber内でncryptsec準拠で暗号化保存\n\n'
                        '⚡ 復号化の最適化:\n'
                        'Todoの同期時に復号化の承認が必要です。\n'
                        '毎回承認するのを避けるために、Amberアプリで\n'
                        '「Meisoアプリを常に許可」を設定することを推奨します。\n\n'
                        '📝 設定方法:\n'
                        '1. Amberアプリを開く\n'
                        '2. アプリ一覧から「Meiso」を選択\n'
                        '3. 「NIP-44 Decrypt」を常に許可に設定',
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
                          '自動同期について',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• タスクの作成・編集・削除は自動的にNostrに同期されます\n'
                      '• アプリ起動時に最新のデータが自動取得されます\n'
                      '• リレー接続中は常にバックグラウンドで同期します\n'
                      '• 手動同期ボタンは不要になりました',
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
}
