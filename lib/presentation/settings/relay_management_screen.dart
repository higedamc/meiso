import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/app_settings_provider.dart';

class RelayManagementScreen extends ConsumerStatefulWidget {
  const RelayManagementScreen({super.key});

  @override
  ConsumerState<RelayManagementScreen> createState() =>
      _RelayManagementScreenState();
}

class _RelayManagementScreenState extends ConsumerState<RelayManagementScreen> {
  final _newRelayController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // リレー状態を初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRelayStates();
    });
  }

  @override
  void dispose() {
    _newRelayController.dispose();
    super.dispose();
  }

  void _initializeRelayStates() {
    final relayNotifier = ref.read(relayStatusProvider.notifier);

    // AppSettingsからリレーリストを取得（保存されている場合）
    final appSettings = ref.read(appSettingsProvider);
    appSettings.whenData((settings) {
      if (settings.relays.isNotEmpty) {
        // 保存されたリレーリストを使用
        relayNotifier.initializeWithRelays(settings.relays);
        print('✅ 保存されたリレーリストを読み込み: ${settings.relays.length}件');
      } else {
        // デフォルトリレーを使用
        relayNotifier.initializeWithRelays(defaultRelays);
        print('✅ デフォルトリレーを使用');
      }
    });
  }

  void _addRelay() {
    final url = _newRelayController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      setState(() {
        _errorMessage = 'リレーURLは wss:// または ws:// で始まる必要があります';
        _successMessage = null;
      });
      return;
    }

    ref.read(relayStatusProvider.notifier).addRelay(url);
    _newRelayController.clear();

    // AppSettingsにも反映
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    setState(() {
      _successMessage = 'リレーを追加しました';
      _errorMessage = null;
    });

    // 接続済みの場合は新しいリレーにも接続
    if (ref.read(nostrInitializedProvider)) {
      _reconnectToRelays();
    }
  }

  void _removeRelay(String url) {
    ref.read(relayStatusProvider.notifier).removeRelay(url);

    // AppSettingsにも反映
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    setState(() {
      _successMessage = 'リレーを削除しました';
      _errorMessage = null;
    });
  }

  /// リレーに再接続（Amberモード・Tor対応）
  Future<void> _reconnectToRelays() async {
    try {
      final nostrService = ref.read(nostrServiceProvider);
      final publicKey = ref.read(nostrPublicKeyProvider);
      final relayList = ref.read(relayStatusProvider).keys.toList();
      
      // アプリ設定からTor/プロキシ設定を取得
      final appSettingsAsync = ref.read(appSettingsProvider);
      final proxyUrl = appSettingsAsync.maybeWhen(
        data: (settings) => settings.torEnabled ? settings.proxyUrl : null,
        orElse: () => null,
      );

      // Amberモード（公開鍵のみ）の場合
      if (publicKey != null && publicKey.isNotEmpty) {
        print('🔗 Reconnecting to relays in Amber mode${proxyUrl != null ? " via proxy" : ""}...');

        if (relayList.isEmpty) {
          await nostrService.initializeNostrWithPubkey(
            publicKeyHex: publicKey,
            proxyUrl: proxyUrl,
          );
        } else {
          await nostrService.initializeNostrWithPubkey(
            publicKeyHex: publicKey,
            relays: relayList,
            proxyUrl: proxyUrl,
          );
        }
        
        print('✅ Reconnected to relays (Amber mode${proxyUrl != null ? " / Tor" : ""})');
      }
    } catch (e) {
      print('❌ Failed to reconnect to relays: $e');
      setState(() {
        _errorMessage = 'リレー再接続エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final relayStatuses = ref.watch(relayStatusProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final appSettingsAsync = ref.watch(appSettingsProvider);
    
    // Tor有効状態を取得
    final torEnabled = appSettingsAsync.maybeWhen(
      data: (settings) => settings.torEnabled,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('リレーサーバー管理'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ステータス表示
            if (isNostrInitialized)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Nostr接続中${torEnabled ? " (Tor経由)" : ""}'),
                    ],
                  ),
                ),
              )
            else
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text('Nostr未接続'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // エラー/成功メッセージ
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            if (_successMessage != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _successMessage!,
                    style: TextStyle(color: Colors.green.shade900),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // リレー追加
            Text(
              'リレーを追加',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newRelayController,
                    decoration: const InputDecoration(
                      hintText: 'wss://relay.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addRelay,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'リレーを追加',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // リレーリスト
            Text(
              'リレーリスト',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            if (relayStatuses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'リレーが登録されていません',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
              )
            else
              ...relayStatuses.values.map((relay) => Card(
                    child: ListTile(
                      leading: _buildRelayStatusIcon(relay.state),
                      title: Text(
                        relay.url,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: relay.errorMessage != null
                          ? Text(
                              relay.errorMessage!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _removeRelay(relay.url),
                        tooltip: '削除',
                      ),
                    ),
                  )),

            const SizedBox(height: 24),

            // 注意事項
            Card(
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
                          'リレーについて',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• リレーはNostrネットワーク上のサーバーです\n'
                      '• 複数のリレーに接続することで冗長性が向上します\n'
                      '• リレーURLは wss:// または ws:// で始める必要があります\n'
                      '• リレーの追加・削除は自動的にNostrに同期されます\n'
                      '${torEnabled ? "• 現在Tor経由で接続しています（Orbotプロキシ使用）" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// リレー状態アイコン
  Widget _buildRelayStatusIcon(RelayConnectionState state) {
    switch (state) {
      case RelayConnectionState.connected:
        return Icon(Icons.cloud_done, color: Colors.green.shade400, size: 20);
      case RelayConnectionState.connecting:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
          ),
        );
      case RelayConnectionState.error:
        return Icon(Icons.error, color: Colors.red.shade600, size: 20);
      case RelayConnectionState.disconnected:
        return Icon(Icons.circle_outlined,
            color: Colors.grey.shade400, size: 20);
    }
  }
}

