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

// Phase 8.4: Legacy (kind: 30001) は廃止
// enum GroupListType は削除

class _AddGroupListDialogState extends ConsumerState<AddGroupListDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberNpubController = TextEditingController(); // MLS用
  final List<Map<String, dynamic>> _mlsMembers = []; // {npub, keyPackage, hasWarning}
  bool _isLoading = false;
  bool _isFetchingKeyPackage = false;

  @override
  void initState() {
    super.initState();
    // Phase 8.4: Legacy初期化は削除
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNpubController.dispose();
    super.dispose();
  }
  
  // Phase 8.4: _addLegacyMember() 削除（kind: 30001廃止）
  
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
      // Nostrクライアント初期化確認（最大5秒待機）
      final isInitialized = ref.read(nostrInitializedProvider);
      if (!isInitialized) {
        AppLogger.warning('⚠️ [AddGroupListDialog] Nostrクライアントが初期化されていません。待機中...');
        
        // 最大10回（5秒）待機
        bool initCompleted = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (ref.read(nostrInitializedProvider)) {
            AppLogger.info('✅ [AddGroupListDialog] Nostrクライアント初期化完了');
            initCompleted = true;
            break;
          }
        }
        
        // まだ初期化されていない場合はエラー
        if (!initCompleted) {
          throw Exception('Nostrクライアントの初期化がタイムアウトしました。アプリを再起動してください。');
        }
      }
      
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
      // Nostrクライアント初期化確認（最大5秒待機）
      final isInitialized = ref.read(nostrInitializedProvider);
      if (!isInitialized) {
        AppLogger.warning('⚠️ [AddGroupListDialog] Nostrクライアントが初期化されていません。待機中...');
        
        // 最大10回（5秒）待機
        bool initCompleted = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (ref.read(nostrInitializedProvider)) {
            AppLogger.info('✅ [AddGroupListDialog] Nostrクライアント初期化完了');
            initCompleted = true;
            break;
          }
        }
        
        // まだ初期化されていない場合はエラー
        if (!initCompleted) {
          throw Exception('Nostrクライアントの初期化がタイムアウトしました。アプリを再起動してください。');
        }
      }
      
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

  /// Phase D.7補完: 自分のKey Packageを手動公開
  Future<void> _publishOwnKeyPackage() async {
    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: Text(
            'Key Package公開',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Key Packageをリレーに公開します。\n\n'
            '公開することで、他のユーザーがあなたをグループに招待できるようになります。\n\n'
            '続行しますか？',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル', style: TextStyle(color: AppTheme.primaryPurple)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('公開する'),
            ),
          ],
        );
      },
    );
    
    if (confirmed != true || !mounted) return;
    
    // ローディング表示
    showDialog<void>(
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
      if (mounted) Navigator.pop(context);
      
      if (eventId != null) {
        // 成功SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Key Packageを公開しました！ Event ID: ${eventId.substring(0, 16)}...'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        AppLogger.info('✅ [AddGroupListDialog] Key Package published: ${eventId.substring(0, 16)}...');
      } else {
        throw Exception('イベントIDが取得できませんでした');
      }
    } catch (e) {
      // ローディング閉じる
      if (mounted) Navigator.pop(context);
      
      // エラーSnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Key Package公開失敗: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      AppLogger.error('❌ [AddGroupListDialog] Failed to publish Key Package', error: e);
    }
  }
  
  /// Phase 8.4: MLSグループ作成（kind: 30001廃止）
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

    // Phase 8.4: MLS - 警告メンバーの検証
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Phase 8.4: MLSグループのみ作成（kind: 30001は廃止）
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
      
      AppLogger.info('🔍 [AddGroupListDialog] Debug: Key Packages count: ${keyPackages.length}');
      AppLogger.info('🔍 [AddGroupListDialog] Debug: Member npubs count: ${memberNpubs.length}');
      for (int i = 0; i < memberNpubs.length; i++) {
        AppLogger.info('   Member ${i + 1}: ${memberNpubs[i].substring(0, 20)}... (KP: ${keyPackages[i].length} bytes)');
      }
      
      AppLogger.info('📤 [AddGroupListDialog] Calling createMlsGroupList...');
      final groupList = await ref.read(customListsProvider.notifier).createMlsGroupList(
            name: _groupNameController.text.trim(),
            keyPackages: keyPackages,
            memberNpubs: memberNpubs,
          );
      
      AppLogger.info('🔍 [AddGroupListDialog] Debug: createMlsGroupList returned: ${groupList != null ? "SUCCESS" : "NULL"}');

      if (groupList != null && mounted) {
        AppLogger.info('✅ [AddGroupListDialog] MLS group created: ${groupList.name}');
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      AppLogger.error('❌ [AddGroupListDialog] Failed to create group: $e', error: e, stackTrace: st);
      AppLogger.error('🔍 [AddGroupListDialog] Debug: Stack trace:', stackTrace: st);
      
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
    final isNostrInitialized = ref.watch(nostrInitializedProvider);

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      title: Text(
        'CREATE GROUP LIST',
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          minWidth: 280,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Nostr初期化状態の表示
            if (!isNostrInitialized)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nostr接続を初期化中...\nKey Package取得は初期化完了後に可能です',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            
            // Phase 8.4: MLSグループのみに統一（kind: 30001廃止）
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryPurple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.security,
                    color: AppTheme.primaryPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MLS Encrypted Group',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Phase D.7補完: 手動Key Packageアップロード
                  if (isNostrInitialized)
                    IconButton(
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      tooltip: '自分のKey Packageを公開',
                      color: AppTheme.primaryPurple,
                      onPressed: _publishOwnKeyPackage,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Phase 8.4: MLSメンバー入力（kind: 30001は廃止）
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
                    tooltip: isNostrInitialized 
                        ? 'Fetch Key Package' 
                        : 'Nostr初期化中...',
                    color: isNostrInitialized 
                        ? null 
                        : Colors.grey,
                    onPressed: isNostrInitialized 
                        ? _fetchKeyPackage 
                        : null,
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
            // Phase 8.4: Legacy (kind: 30001) メンバー入力は削除
          ],
        ),
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

