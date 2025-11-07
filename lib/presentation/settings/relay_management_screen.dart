import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/logger_service.dart';
import '../../bridge_generated.dart/api.dart' as bridge;

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
        AppLogger.debug('✅ 保存されたリレーリストを読み込み: ${settings.relays.length}件');
      } else {
        // デフォルトリレーを使用
        relayNotifier.initializeWithRelays(defaultRelays);
        AppLogger.debug('✅ デフォルトリレーを使用');
      }
    });
  }

  Future<void> _addRelay() async {
    final url = _newRelayController.text.trim();
    if (url.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      setState(() {
        _errorMessage = l10n.relayUrlError;
        _successMessage = null;
      });
      return;
    }

    ref.read(relayStatusProvider.notifier).addRelay(url);
    _newRelayController.clear();

    // AppSettingsにも反映（ローカルのみ）
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    // Nostrクライアントのリレーリストをリアルタイム更新
    try {
      await bridge.updateRelayList(relays: updatedRelays);
      AppLogger.debug('✅ リレーリストをリアルタイム更新しました');
    } catch (e) {
      AppLogger.debug('⚠️ リレーリストのリアルタイム更新に失敗: $e');
    }

    // Nostrに明示的に保存（Kind 10002）
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(appSettingsProvider.notifier).saveRelaysToNostr(updatedRelays);
      setState(() {
        _successMessage = l10n.relayAddedAndSaved;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.relayAddedButSaveFailed(e.toString());
        _successMessage = null;
      });
    }
  }

  Future<void> _removeRelay(String url) async {
    ref.read(relayStatusProvider.notifier).removeRelay(url);

    // AppSettingsにも反映（ローカルのみ）
    final updatedRelays = ref.read(relayStatusProvider).keys.toList();
    await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);

    // Nostrクライアントのリレーリストをリアルタイム更新
    try {
      await bridge.updateRelayList(relays: updatedRelays);
      AppLogger.debug('✅ リレーリストをリアルタイム更新しました');
    } catch (e) {
      AppLogger.debug('⚠️ リレーリストのリアルタイム更新に失敗: $e');
    }

    // Nostrに明示的に保存（Kind 10002）
    final l10n = AppLocalizations.of(context)!;
    try {
      // リレーが空の場合でも保存を試みる（削除を反映するため）
      if (updatedRelays.isNotEmpty) {
        await ref.read(appSettingsProvider.notifier).saveRelaysToNostr(updatedRelays);
      }
      setState(() {
        _successMessage = l10n.relayRemovedAndSaved;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.relayRemovedButSaveFailed(e.toString());
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
      AppLogger.debug('🔄 Nostrからリレーリストを同期中...');
      
      // Kind 10002から直接リレーリストを取得
      final remoteRelays = await bridge.syncRelayList();
      
      if (remoteRelays.isEmpty) {
        setState(() {
          _successMessage = 'Nostr上にリレーリストが見つかりませんでした';
          _isSyncing = false;
        });
        return;
      }
      
      // 現在のローカルリレーリストを取得
      final currentRelays = ref.read(relayStatusProvider).keys.toList();
      
      // リレーリストを比較
      final isSame = _areRelayListsEqual(currentRelays, remoteRelays);
      
      if (isSame) {
        setState(() {
          _successMessage = 'リレーリストは既に最新です（${remoteRelays.length}件）';
          _isSyncing = false;
        });
        AppLogger.debug('✅ リレーリストは既に同期済み');
        return;
      }
      
      AppLogger.debug('📋 ローカルリレー: ${currentRelays.length}件');
      AppLogger.debug('📋 リモートリレー: ${remoteRelays.length}件');
      
      // リレーリストが異なる場合のみ更新
      
      // 1. AppSettingsを更新
      await ref.read(appSettingsProvider.notifier).updateRelays(remoteRelays);
      
      // 2. UIを更新
      final relayNotifier = ref.read(relayStatusProvider.notifier);
      relayNotifier.initializeWithRelays(remoteRelays);
      
      // 3. Nostrクライアントをリアルタイム更新
      try {
        await bridge.updateRelayList(relays: remoteRelays);
        AppLogger.debug('✅ Nostrクライアントのリレーリストを更新しました');
      } catch (e) {
        AppLogger.debug('⚠️ Nostrクライアントの更新に失敗: $e');
      }
      
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _successMessage = l10n.relaySyncSuccess(remoteRelays.length);
        _isSyncing = false;
      });
      AppLogger.debug('✅ リレーリスト同期完了: ${remoteRelays.length}件');
      
    } catch (e) {
      AppLogger.debug('❌ リレーリスト同期失敗: $e');
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.relaySyncError(e.toString());
        _isSyncing = false;
      });
    }
  }
  
  /// 2つのリレーリストが同じかどうかを判定
  bool _areRelayListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    
    return set1.difference(set2).isEmpty && set2.difference(set1).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.relayManagementTitle),
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
              l10n.addRelay,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newRelayController,
                    decoration: InputDecoration(
                      hintText: l10n.relayUrl,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addRelay,
                  icon: const Icon(Icons.add_circle),
                  tooltip: l10n.addRelay,
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
                  label: Text(_isSyncing ? l10n.syncing : l10n.syncFromNostr),
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
                      '• リレーを追加・削除すると即座にNostr（Kind 10002）に保存されます\n'
                      '• リレー変更は即座に反映されます（再起動不要）\n'
                      '• 「Nostrから同期」ボタンで他のデバイスの設定を取得できます\n'
                      '• 同期時、リモートとローカルが異なる場合のみ更新されます\n'
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

