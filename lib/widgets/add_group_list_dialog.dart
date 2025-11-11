import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/custom_lists_provider.dart';
import '../providers/nostr_provider.dart';
import '../services/logger_service.dart';

/// グループリスト作成ダイアログ
class AddGroupListDialog extends ConsumerStatefulWidget {
  const AddGroupListDialog({super.key});

  @override
  ConsumerState<AddGroupListDialog> createState() => _AddGroupListDialogState();
}

enum GroupListType {
  legacy, // kind: 30001
  mls,    // MLS (Phase 8.1)
}

class _AddGroupListDialogState extends ConsumerState<AddGroupListDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberPubkeyController = TextEditingController(); // Legacy用
  final TextEditingController _memberNpubController = TextEditingController(); // MLS用
  final List<String> _legacyMembers = []; // hex形式
  final List<Map<String, dynamic>> _mlsMembers = []; // {npub, keyPackage, hasWarning}
  bool _isLoading = false;
  bool _isFetchingKeyPackage = false;
  GroupListType _selectedType = GroupListType.mls; // デフォルトはMLS

  @override
  void initState() {
    super.initState();
    // Legacy: 自分の公開鍵をデフォルトで追加（hex形式）
    Future.microtask(() async {
      final ownPubkeyNpub = ref.read(nostrPublicKeyProvider);
      if (ownPubkeyNpub != null && mounted) {
        try {
          // npub形式をhex形式に変換
          final nostrService = ref.read(nostrServiceProvider);
          final ownPubkeyHex = await nostrService.npubToHex(ownPubkeyNpub);
          if (mounted) {
            setState(() {
              _legacyMembers.add(ownPubkeyHex);
            });
          }
        } catch (e) {
          AppLogger.error('❌ Failed to convert npub to hex: $e', error: e);
        }
      }
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberPubkeyController.dispose();
    _memberNpubController.dispose();
    super.dispose();
  }
  
  /// Legacy: メンバー追加（npub/hex対応）
  Future<void> _addLegacyMember() async {
    final pubkey = _memberPubkeyController.text.trim();
    if (pubkey.isEmpty) return;
    
    try {
      String hexPubkey;
      
      // npub形式かhex形式かを判定
      if (pubkey.startsWith('npub1')) {
        // npub形式をhex形式に変換
        final nostrService = ref.read(nostrServiceProvider);
        hexPubkey = await nostrService.npubToHex(pubkey);
        AppLogger.debug('🔑 Converted npub to hex: ${hexPubkey.substring(0, 16)}...');
      } else if (pubkey.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(pubkey)) {
        // 既にhex形式
        hexPubkey = pubkey.toLowerCase();
      } else {
        // 無効な形式
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無効な公開鍵形式です（npub形式またはhex形式のみ）'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // 重複チェック
      if (_legacyMembers.contains(hexPubkey)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('このメンバーは既に追加されています'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      setState(() {
        _legacyMembers.add(hexPubkey);
        _memberPubkeyController.clear();
      });
    } catch (e) {
      AppLogger.error('❌ Failed to add member: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('公開鍵の変換に失敗しました: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Phase 8.1: Key Package取得
  Future<void> _fetchKeyPackage() async {
    final npub = _memberNpubController.text.trim();
    
    if (npub.isEmpty || !npub.startsWith('npub')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('有効なnpubを入力してください'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 重複チェック
    if (_mlsMembers.any((m) => m['npub'] == npub)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('このメンバーは既に追加されています'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    setState(() {
      _isFetchingKeyPackage = true;
    });
    
    try {
      AppLogger.info('🔍 [AddGroupListDialog] Fetching Key Package for: ${npub.substring(0, 20)}...');
      
      final nostrService = ref.read(nostrServiceProvider);
      final keyPackage = await nostrService.fetchKeyPackageByNpub(npub);
      
      if (keyPackage != null) {
        setState(() {
          _mlsMembers.add({
            'npub': npub,
            'keyPackage': keyPackage,
            'hasWarning': false,
          });
          _memberNpubController.clear();
        });
        
        AppLogger.info('✅ [AddGroupListDialog] Key Package fetched successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${npub.substring(0, 20)}... を追加しました'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Key Package未公開: 警告状態で追加
        setState(() {
          _mlsMembers.add({
            'npub': npub,
            'keyPackage': null,
            'hasWarning': true,
          });
          _memberNpubController.clear();
        });
        
        AppLogger.warning('⚠️ [AddGroupListDialog] Key Package not found for: ${npub.substring(0, 20)}...');
        
        // KeyChat風の警告ダイアログを表示
        if (mounted) {
          _showKeyPackageWarningDialog(npub);
        }
      }
      
    } catch (e) {
      AppLogger.error('❌ [AddGroupListDialog] Failed to fetch Key Package', error: e);
      
      // エラー時も警告状態で追加
      setState(() {
        _mlsMembers.add({
          'npub': npub,
          'keyPackage': null,
          'hasWarning': true,
        });
        _memberNpubController.clear();
      });
      
      if (mounted) {
        _showKeyPackageWarningDialog(npub);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingKeyPackage = false;
        });
      }
    }
  }
  
  /// Phase 8.1.1: Key Package警告ダイアログ（KeyChatパターン）
  void _showKeyPackageWarningDialog(String npub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Key Package未公開',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '${npub.substring(0, 20)}...\n\n'
          'Key Packageが見つかりません。\n'
          '相手にアプリを起動してもらうと、自動的にKey Packageが公開されます。\n\n'
          '※ このメンバーはグループ作成時に除外されます',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.primaryPurple),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retryFetchKeyPackage(npub);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
  
  /// Phase 8.1.1: 警告メンバー確認ダイアログ
  Future<bool?> _showWarningMembersConfirmDialog(int warningCount, int validCount) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: Text(
          '一部のメンバーのKey Packageが未公開です',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Key Packageが未公開: $warningCount人\n'
          '招待可能なメンバー: $validCount人\n\n'
          'Key Packageが未公開のメンバーは招待できません。\n'
          'それでもグループを作成しますか？',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: AppTheme.primaryPurple),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('作成する'),
          ),
        ],
      ),
    );
  }
  
  /// Phase 8.1.1: Key Package再取得
  Future<void> _retryFetchKeyPackage(String npub) async {
    final memberIndex = _mlsMembers.indexWhere((m) => m['npub'] == npub);
    if (memberIndex == -1) return;
    
    setState(() {
      _isFetchingKeyPackage = true;
    });
    
    try {
      AppLogger.info('🔄 [AddGroupListDialog] Retrying Key Package fetch for: ${npub.substring(0, 20)}...');
      
      final nostrService = ref.read(nostrServiceProvider);
      final keyPackage = await nostrService.fetchKeyPackageByNpub(npub);
      
      if (keyPackage != null) {
        setState(() {
          _mlsMembers[memberIndex] = {
            'npub': npub,
            'keyPackage': keyPackage,
            'hasWarning': false,
          };
        });
        
        AppLogger.info('✅ [AddGroupListDialog] Key Package fetched successfully on retry');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${npub.substring(0, 20)}... のKey Packageを取得しました'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 再試行でも失敗
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ まだKey Packageが公開されていません'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('❌ [AddGroupListDialog] Retry failed', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 再試行失敗: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingKeyPackage = false;
        });
      }
    }
  }

  /// グループ作成（Legacy / MLS対応）
  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('グループ名を入力してください'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // メンバーチェック（Legacyの場合のみ）
    if (_selectedType == GroupListType.legacy && _legacyMembers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('グループ名とメンバーを入力してください'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Phase 8.1.1: MLS - 警告メンバーの検証
    if (_selectedType == GroupListType.mls) {
      final hasWarning = _mlsMembers.any((m) => m['hasWarning'] == true);
      
      if (hasWarning) {
        final warningCount = _mlsMembers.where((m) => m['hasWarning'] == true).length;
        final validCount = _mlsMembers.where((m) => m['hasWarning'] != true).length;
        
        if (validCount == 0) {
          // 全員が警告状態の場合はグループ作成不可
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Key Packageが取得できたメンバーが必要です'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        // 一部が警告状態の場合は確認ダイアログ
        final confirmed = await _showWarningMembersConfirmDialog(warningCount, validCount);
        if (confirmed != true) {
          return;
        }
        
        // 警告メンバーを除外
        _mlsMembers.removeWhere((m) => m['hasWarning'] == true);
        AppLogger.info('⚠️ [AddGroupListDialog] Excluded $warningCount member(s) without Key Package');
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedType == GroupListType.mls) {
        // MLS実装
        AppLogger.info('🚀 [AddGroupListDialog] Creating MLS group: ${_groupNameController.text}');
        AppLogger.info('   Members: ${_mlsMembers.length}');
        
        final keyPackages = _mlsMembers
            .where((m) => m['keyPackage'] != null)
            .map((m) => m['keyPackage'] as String)
            .toList();
        final memberNpubs = _mlsMembers
            .where((m) => m['keyPackage'] != null)
            .map((m) => m['npub'] as String)
            .toList();
        
        final groupList = await ref.read(customListsProvider.notifier).createMlsGroupList(
              name: _groupNameController.text.trim(),
              keyPackages: keyPackages,
              memberNpubs: memberNpubs, // Phase 8.4: 招待送信用
            );

        if (groupList != null && mounted) {
          AppLogger.info('✅ [AddGroupListDialog] MLS group created: ${groupList.name}');
          Navigator.pop(context, true);
        }
      } else {
        // Legacy実装 (kind: 30001)
        AppLogger.info('🚀 [AddGroupListDialog] Creating Legacy group: ${_groupNameController.text}');
        AppLogger.info('   Members: ${_legacyMembers.length}');
        
        final groupList = await ref.read(customListsProvider.notifier).createGroupList(
              name: _groupNameController.text.trim(),
              memberPubkeys: _legacyMembers,
            );

        if (groupList != null && mounted) {
          AppLogger.info('✅ [AddGroupListDialog] Legacy group created: ${groupList.name}');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      AppLogger.error('❌ [AddGroupListDialog] Failed to create group: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ グループ作成失敗: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      title: Text(
        'CREATE GROUP LIST',
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
            const SizedBox(height: 16),
            
            // トグルボタン (Legacy / MLS)
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkDivider.withOpacity(0.3) : AppTheme.lightDivider.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = GroupListType.legacy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedType == GroupListType.legacy
                              ? AppTheme.primaryPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Legacy (kind: 30001)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedType == GroupListType.legacy
                                ? Colors.white
                                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = GroupListType.mls),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedType == GroupListType.mls
                              ? AppTheme.primaryPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'MLS (Beta)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedType == GroupListType.mls
                                ? Colors.white
                                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // メンバー入力（タイプに応じて表示）
            if (_selectedType == GroupListType.mls) ...[
              Text(
                'Add Member (MLS)',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberNpubController,
                    decoration: InputDecoration(
                      labelText: 'Member npub',
                      hintText: 'npub1...',
                      labelStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary.withOpacity(0.5) : AppTheme.lightTextSecondary.withOpacity(0.5)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryPurple),
                      ),
                    ),
                    style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  ),
                ),
                if (_isFetchingKeyPackage)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Fetch Key Package',
                    onPressed: _fetchKeyPackage,
                  ),
              ],
            ),
              const SizedBox(height: 8),
              if (_mlsMembers.isNotEmpty) ...[
                Text(
                  'Members: ${_mlsMembers.length}',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mlsMembers.length,
                    itemBuilder: (context, index) {
                      final member = _mlsMembers[index];
                      final npub = member['npub'] as String;
                      final hasWarning = member['hasWarning'] == true;
                      final shortNpub = npub.length > 20 ? '${npub.substring(0, 16)}...' : npub;
                      
                      return ListTile(
                        dense: true,
                        leading: hasWarning
                            ? const Icon(Icons.warning, color: Colors.orange, size: 16)
                            : const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        title: Text(
                          shortNpub,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: hasWarning
                            ? Text(
                                'Key Package未公開',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasWarning)
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18, color: Colors.orange),
                                tooltip: '再試行',
                                onPressed: () => _retryFetchKeyPackage(npub),
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: () {
                                setState(() {
                                  _mlsMembers.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else if (_selectedType == GroupListType.legacy) ...[
              // Legacy用メンバー入力（既存実装を復元）
              Text(
                'Members (Public Keys)',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberPubkeyController,
                      decoration: InputDecoration(
                        labelText: 'Add Member npub/hex',
                        labelStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryPurple),
                        ),
                      ),
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addLegacyMember,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_legacyMembers.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _legacyMembers.length,
                    itemBuilder: (context, index) {
                      final pubkey = _legacyMembers[index];
                      return ListTile(
                        title: Text(
                          pubkey.length > 20 ? '${pubkey.substring(0, 10)}...${pubkey.substring(pubkey.length - 10)}' : pubkey,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              _legacyMembers.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: AppTheme.primaryPurple),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('CREATE'),
        ),
      ],
    );
  }
}

