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

          // MLS: Key Package公開
          if (isNostrInitialized) ...[
            _buildSettingTile(
              context,
              icon: Icons.vpn_key,
              title: 'Key Package公開',
              subtitle: 'グループ招待を受けるために必要',
              onTap: () => _publishKeyPackage(context, ref),
            ),
            const Divider(height: 1),
          ],
          
          // MLS統合テスト
          if (isNostrInitialized) ...[
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

  /// Key Package公開
  Future<void> _publishKeyPackage(BuildContext context, WidgetRef ref) async {
    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Key Package公開'),
        content: const Text(
          'Key Packageをリレーに公開します。\n\n'
          '公開することで、他のユーザーがあなたをグループに招待できるようになります。\n\n'
          '続行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('公開する'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Key Packageを公開中...'),
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
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('公開完了'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Key Packageをリレーに公開しました！'),
                  const SizedBox(height: 16),
                  const Text(
                    '他のユーザーがあなたのnpubを使ってグループに招待できるようになりました。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Event ID: ${eventId.substring(0, 16)}...',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('イベントIDが取得できませんでした');
      }
      
    } catch (e) {
      // ローディング閉じる
      if (context.mounted) Navigator.pop(context);
      
      // エラーダイアログ
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('公開失敗'),
              ],
            ),
            content: Text('Key Packageの公開に失敗しました。\n\nエラー: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }
    }
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
      _addLog('🔑 Key Package生成開始');
      
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception('User public key not available');
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
      _addLog('');
      _addLog('🚀 2人グループ作成開始');
      
      // グループ作成（相手のKey Package追加）
      _addLog('📦 Step 1: グループ作成 + メンバー追加');
      final groupId = 'group-2p-${DateTime.now().millisecondsSinceEpoch}';
      
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception('User public key not available');
      }
      
      final welcomeMsg = await rust_api.mlsCreateTodoGroup(
        nostrId: userPubkey,
        groupId: groupId,
        groupName: '2 Person Test Group',
        keyPackages: [otherKeyPackage],
      );
      
      setState(() {
        _groupId = groupId;
      });
      
      _addLog('✅ 2人グループ作成完了: $groupId');
      _addLog('📨 Welcome message: ${welcomeMsg.length} bytes');
      
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
          groupName: '2 Person Test Group',
          welcomeMsgBase64: welcomeMsgBase64,
          inviterName: null,
        );
        
        // Amber署名
        _addLog('✍️ Amberで署名中...');
        final amberService = AmberService();
        final signedEvent = await amberService.signEventWithTimeout(
          unsignedEvent,
          timeout: const Duration(minutes: 2),
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
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      
      _addLog('');
      _addLog('📤 TODO送信テスト開始');
      
      final testTodo = {
        'id': 'todo-2p-${DateTime.now().millisecondsSinceEpoch}',
        'title': 'Test TODO for 2 Person Group',
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
  
  Future<void> _runMlsTest() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final todosNotifier = widget.ref.read(todosProvider.notifier);
      
      _addLog('🚀 MLS統合テスト開始（1人グループ）');
      
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
      
      // Step 3: スキップ（自分のメッセージは復号化不可）
      _addLog('⏭️  Step 3: TODO復号化（スキップ）');
      _addLog('ℹ️  MLSでは自分のメッセージは復号化できません');
      _addLog('   これは仕様通りの動作です');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
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
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Option B PoC: 2人グループ対応テスト',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    const Text(
                      '📋 あなたのKey Package:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                          const SnackBar(content: Text('Key Packageをコピーしました')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('コピー', style: TextStyle(fontSize: 11)),
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
                    decoration: const InputDecoration(
                      labelText: '相手のnpub',
                      hintText: 'npub1...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _fetchKeyPackageByNpub,
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('取得', style: TextStyle(fontSize: 11)),
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
                    ? const Center(
                        child: Text(
                          'テストボタンを押してください',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
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
          child: const Text('閉じる', style: TextStyle(fontSize: 12)),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _generateKeyPackage,
          icon: const Icon(Icons.vpn_key, size: 16),
          label: const Text('Key Package生成', style: TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _create2PersonGroup,
          icon: const Icon(Icons.group_add, size: 16),
          label: const Text('2人グループ作成', style: TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _sendTodoIn2PersonGroup,
          icon: const Icon(Icons.send, size: 16),
          label: const Text('TODO送信', style: TextStyle(fontSize: 11)),
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
          label: Text(_isRunning ? '実行中...' : '1人テスト', style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }
}
