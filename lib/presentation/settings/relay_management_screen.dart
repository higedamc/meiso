import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../models/app_settings.dart';
import '../../providers/nostr_provider.dart';
import '../../providers/relay_status_provider.dart';
import '../../providers/app_settings_provider.dart';

import '../../models/relay_config.dart';
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
  final _citrineUrlController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;
  bool _isSyncing = false;
  bool _citrineEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRelayStates();
      _initializeCitrineState();
    });
  }

  @override
  void dispose() {
    _newRelayController.dispose();
    _citrineUrlController.dispose();
    super.dispose();
  }

  void _initializeCitrineState() {
    final appSettings = ref.read(appSettingsProvider);
    appSettings.whenData((settings) {
      final hasLocalRelay = settings.relays.any(isLikelyLocalRelayUrl);
      final localUrl = hasLocalRelay
          ? settings.relays.firstWhere(isLikelyLocalRelayUrl)
          : defaultCitrineUrl;
      setState(() {
        _citrineEnabled = hasLocalRelay;
        _citrineUrlController.text = localUrl;
      });
    });
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

    final l10n = AppLocalizations.of(context);
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
    final l10n = AppLocalizations.of(context);
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
    
    final l10n = AppLocalizations.of(context);
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
          _successMessage = l10n.noRelayListOnNostr;
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
          _successMessage = l10n.relaySyncSuccess(remoteRelays.length);
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
      
      setState(() {
        _successMessage = l10n.relaySyncSuccess(remoteRelays.length);
        _isSyncing = false;
      });
      AppLogger.debug('✅ リレーリスト同期完了: ${remoteRelays.length}件');
      
    } catch (e) {
      AppLogger.debug('❌ リレーリスト同期失敗: $e');
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
    final l10n = AppLocalizations.of(context);
    final relayStatuses = ref.watch(relayStatusProvider);
    final isNostrInitialized = ref.watch(nostrInitializedProvider);
    final appSettingsAsync = ref.watch(appSettingsProvider);
    
    // Torモードを取得
    final torMode = appSettingsAsync.maybeWhen(
      data: (settings) => settings.torMode,
      orElse: () => TorMode.disabled,
    );
    final torEnabled = torMode != TorMode.disabled;

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
                      Text(torEnabled ? l10n.nostrConnectedViaTor : l10n.nostrConnectedStatus),
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
                      Text(l10n.nostrDisconnectedStatus),
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

            // Citrine / Local Relay section
            Text(
              l10n.localRelayCitrine,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.localRelayDescription,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(l10n.localRelayEnabled),
                      value: _citrineEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (enabled) async {
                        setState(() => _citrineEnabled = enabled);
                        final currentRelays = ref.read(relayStatusProvider).keys.toList();
                        final citrineUrl = _citrineUrlController.text.trim().isNotEmpty
                            ? _citrineUrlController.text.trim()
                            : defaultCitrineUrl;

                        List<String> updatedRelays;
                        if (enabled) {
                          updatedRelays = [...currentRelays, citrineUrl];
                        } else {
                          updatedRelays = currentRelays.where((r) => !isLikelyLocalRelayUrl(r)).toList();
                        }
                        await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
                        // 接続成否はまだ不明なので connecting でシードし、実状態で補正する
                        ref.read(relayStatusProvider.notifier).initializeWithRelays(
                              updatedRelays,
                              initialState: RelayConnectionState.connecting,
                            );
                        try {
                          await bridge.updateRelayList(relays: updatedRelays);
                        } catch (e) {
                          AppLogger.debug('Citrine toggle relay update: $e');
                        }
                        await ref.read(nostrServiceProvider).refreshRelayStatus();
                      },
                    ),
                    if (_citrineEnabled) ...[
                      TextField(
                        controller: _citrineUrlController,
                        decoration: InputDecoration(
                          hintText: defaultCitrineUrl,
                          labelText: l10n.localRelayUrl,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Global relay list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.globalRelays,
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
                    l10n.noRelaysRegistered,
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
                        tooltip: l10n.deleteTooltip,
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
                        const Icon(Icons.info, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Text(
                          l10n.aboutRelays,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.aboutRelaysDescription}\n'
                      '${torEnabled ? l10n.currentlyConnectedViaTor : ""}',
                      style: const TextStyle(
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
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
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

