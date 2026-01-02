import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/amber_service.dart';
import '../../bridge_generated.dart/api.dart' as rust_api;
import 'mls_backup_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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

          // デバッグログ表示（debugモードのみ）
          if (kDebugMode) ...[
            const Divider(height: 1),
            _buildSettingTile(
              context,
              icon: Icons.bug_report,
              title: l10n.debugLogs,
              subtitle: l10n.debugLogsSubtitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
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
                          const Icon(Icons.security, color: AppTheme.primaryPurple),
                          const SizedBox(width: 8),
                          Text(
                            l10n.amberModeTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.amberModeInfo,
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
                        const Icon(Icons.info, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Text(
                          l10n.autoSyncInfoTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.autoSyncInfo,
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
          const SizedBox(height: 24),

          // Advanced セクション（MLS機能を格納）
          if (isNostrInitialized) ...[
            const Divider(height: 1),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: const Icon(Icons.keyboard_arrow_right, color: AppTheme.primaryPurple),
                title: Text(l10n.advancedSectionTitle),
                subtitle: Text(l10n.advancedSectionSubtitle, style: const TextStyle(fontSize: 12)),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  _buildSettingTile(
                    context,
                    icon: Icons.vpn_key,
                    title: l10n.keyPackagePublishTitle,
                    subtitle: l10n.keyPackagePublishSubtitle,
                    onTap: () => _publishKeyPackage(context, ref),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    context,
                    icon: Icons.science,
                    title: l10n.mlsIntegrationTestTitle,
                    subtitle: l10n.mlsIntegrationTestSubtitle,
                    onTap: () => _showMlsTestDialog(context, ref),
                  ),
                  const Divider(height: 1),
                  // Phase 2.5A: MLS Backup/Restore
                  _buildSettingTile(
                    context,
                    icon: Icons.backup,
                    title: 'MLSグループバックアップ',
                    subtitle: 'Key Packageをエクスポート/インポート',
                    onTap: () => showMlsBackupDialog(context, ref),
                  ),
                ],
              ),
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

  /// Key Package公開
  Future<void> _publishKeyPackage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.keyPackagePublishDialogTitle),
        content: Text(l10n.keyPackagePublishDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.publishButton),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // ローディング表示
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.publishingKeyPackage),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // Key Package公開
      final nostrService = ref.read(nostrServiceProvider);
      final eventId = await nostrService.publishKeyPackage();
      
      // ローディング閉じる
      if (context.mounted) Navigator.pop(context);
      
      if (eventId != null) {
        // 成功ダイアログ
        if (context.mounted) {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(l10n.keyPackagePublishCompletedTitle),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.keyPackagePublishCompletedMessage),
                  const SizedBox(height: 16),
                  Text(
                    l10n.keyPackagePublishCompletedDescription,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.eventIdLabel}: ${eventId.substring(0, 16)}...',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.closeButton),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(l10n.keyPackagePublishNoEventIdError);
      }
      
    } catch (e) {
      // ローディング閉じる
      if (context.mounted) Navigator.pop(context);
      
      // エラーダイアログ
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(l10n.keyPackagePublishFailedTitle),
              ],
            ),
            content: Text(l10n.keyPackagePublishFailedBody(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.closeButton),
              ),
            ],
          ),
        );
      }
    }
  }
  
  void _showMlsTestDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _MlsTestDialog(ref: ref),
    );
  }
}

/// MLS統合テストダイアログ（Option B PoC）
class _MlsTestDialog extends StatefulWidget {

  const _MlsTestDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_MlsTestDialog> createState() => _MlsTestDialogState();
}

class _MlsTestDialogState extends State<_MlsTestDialog> {
  final _logs = <String>[];
  bool _isRunning = false;
  String? _myKeyPackage;
  String? _groupId;
  String? _inviteeNpub;  // 招待した相手のnpub
  final _keyPackageController = TextEditingController();

  @override
  void dispose() {
    _keyPackageController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  // Key Package生成
  Future<void> _generateKeyPackage() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final l10n = AppLocalizations.of(context);
      _addLog('🔑 Key Package生成開始');
      
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception(l10n.mlsUserPublicKeyNotAvailable);
      }
      
      // MLS初期化
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      await todosNotifier.createMlsGroupList(
        listId: 'init-${DateTime.now().millisecondsSinceEpoch}',
        listName: 'Init',
      );
      
      // Key Package生成（直接Rust API呼び出し）
      final result = await rust_api.mlsCreateKeyPackage(nostrId: userPubkey);
      
      setState(() {
        _myKeyPackage = result.keyPackage;
      });
      
      _addLog('✅ Key Package生成完了');
      _addLog('📋 Key Package: ${result.keyPackage.substring(0, 32)}...');
      _addLog('🔐 Protocol: ${result.mlsProtocolVersion}');
      _addLog('🔒 Ciphersuite: ${result.ciphersuite}');
      _addLog('');
      _addLog('📝 このKey Packageを相手に共有してください');
      
    } catch (e) {
      _addLog('❌ エラー: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  // 2人グループ作成（相手のKey Package追加）
  Future<void> _create2PersonGroup() async {
    final otherKeyPackage = _keyPackageController.text.trim();
    
    if (otherKeyPackage.isEmpty) {
      _addLog('❌ 相手のKey Packageを入力してください');
      return;
    }
    
    setState(() {
      _isRunning = true;
    });

    try {
      final l10n = AppLocalizations.of(context);
      _addLog('');
      _addLog('🚀 2人グループ作成開始');
      
      // グループ作成（相手のKey Package追加）
      _addLog('📦 Step 1: グループ作成 + メンバー追加');
      final groupId = 'group-2p-${DateTime.now().millisecondsSinceEpoch}';
      
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception(l10n.mlsUserPublicKeyNotAvailable);
      }
      
      final welcomeMsg = await rust_api.mlsCreateTodoGroup(
        nostrId: userPubkey,
        groupId: groupId,
        groupName: l10n.mlsTwoPersonTestGroupName,
        keyPackages: [otherKeyPackage],
      );
      
      setState(() {
        _groupId = groupId;
      });
      
      _addLog('✅ 2人グループ作成完了: $groupId');
      _addLog('📨 ウェルカムメッセージ: ${welcomeMsg.length} バイト');
      
      // Step 2: グループ招待通知送信
      if (_inviteeNpub != null) {
        _addLog('');
        _addLog('📤 Step 2: グループ招待通知送信');
        
        // Welcome Messageをbase64エンコード
        final welcomeMsgBase64 = base64Encode(welcomeMsg);
        
        // 未署名イベント作成
        _addLog('📝 Kind 30078イベント作成中...');
        final unsignedEvent = await rust_api.createUnsignedGroupInvitationEvent(
          senderPublicKeyHex: userPubkey,
          recipientNpub: _inviteeNpub!,
          groupId: groupId,
          groupName: l10n.mlsTwoPersonTestGroupName,
          welcomeMsgBase64: welcomeMsgBase64,
        );
        
        // Amber署名
        _addLog('✍️ Amberで署名中...');
        final amberService = AmberService();
        final signedEvent = await amberService.signEventWithTimeout(
          unsignedEvent,
        );
        
        // リレーに送信
        _addLog('📡 リレーに送信中...');
        final sendResult = await nostrService.sendSignedEvent(signedEvent);
        
        _addLog('✅ グループ招待通知送信完了！');
        _addLog('   Event ID: ${sendResult.eventId.substring(0, 16)}...');
        _addLog('');
        _addLog('🎉 相手のアプリでグループ招待を受信します');
      } else {
        _addLog('');
        _addLog('⚠️ 相手のnpubが不明のため、招待通知はスキップ');
      }
      
    } catch (e) {
      _addLog('❌ エラー: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  // TODO送信テスト（2人グループ）
  Future<void> _sendTodoIn2PersonGroup() async {
    if (_groupId == null) {
      _addLog('❌ 先に2人グループを作成してください');
      return;
    }
    
    setState(() {
      _isRunning = true;
    });

    try {
      final l10n = AppLocalizations.of(context);
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      
      _addLog('');
      _addLog('📤 TODO送信テスト開始');
      
      final testTodo = {
        'id': 'todo-2p-${DateTime.now().millisecondsSinceEpoch}',
        'title': l10n.mlsTwoPersonTestTodoTitle,
        'completed': false,
        'date': DateTime.now().toIso8601String(),
        'order': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final encrypted = await todosNotifier.encryptMlsTodo(
        groupId: _groupId!,
        todoJson: testTodo.toString(),
      );
      
      _addLog('✅ TODO暗号化完了: ${encrypted.substring(0, 32)}...');
      _addLog('');
      _addLog('📝 このメッセージをNostrリレーに送信');
      _addLog('   相手のデバイスで復号化テスト可能');
      
    } catch (e) {
      _addLog('❌ エラー: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  // Key Package取得テスト（npubから）
  Future<void> _fetchKeyPackageByNpub() async {
    final npub = _keyPackageController.text.trim();
    
    if (npub.isEmpty) {
      _addLog('❌ npubを入力してください');
      return;
    }
    
    if (!npub.startsWith('npub')) {
      _addLog('❌ 正しいnpub形式で入力してください');
      return;
    }
    
    setState(() {
      _isRunning = true;
    });
    
    try {
      _addLog('');
      _addLog('🔍 Key Package取得テスト開始');
      _addLog('📋 対象npub: ${npub.substring(0, 20)}...');
      
      // npubからKey Package取得
      _addLog('🔎 リレーからKey Packageを検索中...');
      final keyPackage = await rust_api.fetchKeyPackageByNpub(npub: npub);
      
      _addLog('✅ Key Package取得成功！');
      _addLog('📦 Key Package: ${keyPackage.substring(0, 40)}...');
      _addLog('📏 サイズ: ${keyPackage.length} bytes');
      _addLog('');
      _addLog('💡 このKey Packageを使ってグループに招待できます');
      
      // Key Packageを保存（2人グループ作成で使用）
      setState(() {
        _keyPackageController.text = keyPackage;
        _inviteeNpub = npub;  // npubも保存
      });
      
    } catch (e) {
      _addLog('❌ エラー: $e');
      _addLog('');
      _addLog('💡 相手がまだKey Packageを公開していない可能性があります');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  // Key Package公開（ダイアログ内）
  Future<void> _publishKeyPackageInDialog() async {
    if (_myKeyPackage == null) {
      _addLog('❌ 先に「KP生成」でKey Packageを生成してください');
      return;
    }
    
    setState(() {
      _isRunning = true;
    });
    
    try {
      _addLog('');
      _addLog('📤 Key Package公開開始...');
      
      final nostrService = widget.ref.read(nostrServiceProvider);
      final eventId = await nostrService.publishKeyPackage();
      
      if (eventId != null) {
        _addLog('✅ Key Package公開成功！');
        _addLog('📝 Event ID: ${eventId.substring(0, 16)}...');
        _addLog('');
        _addLog('🎉 相手があなたのnpubからKey Packageを取得できます');
      } else {
        _addLog('❌ Key Package公開失敗');
      }
    } catch (e) {
      _addLog('❌ エラー: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  Future<void> _runMlsTest() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final l10n = AppLocalizations.of(context);
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      
      _addLog('🚀 MLS統合テスト開始（1人グループ）');
      
      // Step 1: グループ作成
      _addLog('📦 Step 1: グループ作成');
      final groupId = 'test-mls-group-${DateTime.now().millisecondsSinceEpoch}';
      await todosNotifier.createMlsGroupList(
        listId: groupId,
        listName: l10n.mlsTestListName,
      );
      _addLog('✅ グループ作成完了: $groupId');
      
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      // Step 2: TODO暗号化
      _addLog('🔒 Step 2: TODO暗号化');
      final testTodo = {
        'id': 'test-todo-001',
        'title': l10n.mlsOnePersonTestTodoTitle,
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
      
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      // Step 3: スキップ（自分のメッセージは復号化不可）
      _addLog('⏭️  Step 3: TODO復号化（スキップ）');
      _addLog('ℹ️  MLSでは自分のメッセージは復号化できません');
      _addLog('   これは仕様通りの動作です');
      
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      // 完了
      _addLog('');
      _addLog('🎉 1人グループテスト完了！');
      _addLog('✅ グループ作成: OK');
      _addLog('✅ TODO暗号化: OK');
      _addLog('');
      _addLog('📝 2人グループテスト:');
      _addLog('  1. "Key Package生成"で自分のKPを生成');
      _addLog('  2. 相手にKey Packageを共有');
      _addLog('  3. 相手のKey Packageを入力して');
      _addLog('     "2人グループ作成"をタップ');
      
    } catch (e, stackTrace) {
      _addLog('❌ エラー: $e');
      _addLog('スタックトレース: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.science, color: Colors.blue),
          const SizedBox(width: 8),
          Text(l10n.mlsTestDialogTitle),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mlsTestDialogSubtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            
            // Key Package表示エリア
            if (_myKeyPackage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mlsYourKeyPackageLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_myKeyPackage!.substring(0, 40)}...',
                      style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _myKeyPackage!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.keyPackageCopied)),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: Text(l10n.copyButton, style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // 相手のnpub入力 + Key Package取得
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyPackageController,
                    decoration: InputDecoration(
                      labelText: l10n.mlsPeerNpubLabel,
                      hintText: l10n.mlsPeerNpubHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _fetchKeyPackageByNpub,
                  icon: const Icon(Icons.download, size: 14),
                  label: Text(l10n.fetchButton, style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          l10n.mlsPressTestButton,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
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
          child: Text(l10n.closeButton, style: const TextStyle(fontSize: 12)),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _generateKeyPackage,
          icon: const Icon(Icons.vpn_key, size: 16),
          label: Text(l10n.mlsGenerateKpButton, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _publishKeyPackageInDialog,
          icon: const Icon(Icons.cloud_upload, size: 16),
          label: Text(l10n.mlsPublishKpButton, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _create2PersonGroup,
          icon: const Icon(Icons.group_add, size: 16),
          label: Text(l10n.mlsCreate2PersonGroupButton, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _sendTodoIn2PersonGroup,
          icon: const Icon(Icons.send, size: 16),
          label: Text(l10n.mlsSendTodoButton, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _runMlsTest,
          icon: _isRunning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow, size: 16),
          label: Text(_isRunning ? l10n.mlsRunning : l10n.mlsOnePersonTestButton, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }
}
