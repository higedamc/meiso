import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
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
}
