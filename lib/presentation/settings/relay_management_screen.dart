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
  bool _isSyncing = false;

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

  Future<void> _addRelay() async {
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

    // AppSettingsにも反映（ローカルのみ）
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    // Nostrに明示的に保存（Kind 10002）
    try {
      await ref.read(appSettingsProvider.notifier).saveRelaysToNostr(updatedRelays);
      setState(() {
        _successMessage = 'リレーを追加し、Nostrに保存しました';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'リレーは追加されましたが、Nostrへの保存に失敗しました: $e';
        _successMessage = null;
      });
    }
  }

  Future<void> _removeRelay(String url) async {
    ref.read(relayStatusProvider.notifier).removeRelay(url);

    // AppSettingsにも反映（ローカルのみ）
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    // Nostrに明示的に保存（Kind 10002）
    try {
      // リレーが空の場合でも保存を試みる（削除を反映するため）
      if (updatedRelays.isNotEmpty) {
        await ref.read(appSettingsProvider.notifier).saveRelaysToNostr(updatedRelays);
      }
      setState(() {
        _successMessage = 'リレーを削除し、Nostrに保存しました';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'リレーは削除されましたが、Nostrへの保存に失敗しました: $e';
        _successMessage = null;
      });
    }
  }

  /// Nostrからリレーリストを同期（Kind 10002）
  Future<void> _syncFromNostr() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('🔄 Nostrからリレーリストを同期中...');
      
      // AppSettingsProviderの同期を実行（Kind 10002を取得）
      await ref.read(appSettingsProvider.notifier).syncFromNostr();
      
      // 同期後、リレーリストを再読み込み
      final appSettings = ref.read(appSettingsProvider);
      final settings = appSettings.valueOrNull;
      
      if (settings != null && settings.relays.isNotEmpty) {
        // 同期されたリレーリストでUIを更新
        final relayNotifier = ref.read(relayStatusProvider.notifier);
        relayNotifier.initializeWithRelays(settings.relays);
        
        setState(() {
          _successMessage = 'Nostrから${settings.relays.length}件のリレーを同期しました';
          _isSyncing = false;
        });
        print('✅ リレーリスト同期完了: ${settings.relays.length}件');
      } else {
        setState(() {
          _successMessage = 'Nostr上にリレーリストが見つかりませんでした';
          _isSyncing = false;
        });
      }
      
    } catch (e) {
      print('❌ リレーリスト同期失敗: $e');
      setState(() {
        _errorMessage = 'リレーリストの同期に失敗しました: $e';
        _isSyncing = false;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'リレーリスト',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncFromNostr,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_download, size: 18),
                  label: Text(_isSyncing ? '同期中...' : 'Nostrから同期'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
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
                      '• リレーを追加・削除するとNostr（Kind 10002）に保存されます\n'
                      '• 「Nostrから同期」ボタンで他のデバイスの設定を取得できます\n'
                      '• リレー変更は次回起動時に反映されます\n'
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

