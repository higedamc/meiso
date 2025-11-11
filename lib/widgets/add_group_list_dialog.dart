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

class _AddGroupListDialogState extends ConsumerState<AddGroupListDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberNpubController = TextEditingController();
  final List<Map<String, String>> _members = []; // {npub, keyPackage}
  bool _isLoading = false;
  bool _isFetchingKeyPackage = false;

  @override
  void initState() {
    super.initState();
    // Phase 8.1: 自分はデフォルトメンバーに含めない
    // MLSグループは自動的に自分を含む
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNpubController.dispose();
    super.dispose();
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
    
    setState(() {
      _isFetchingKeyPackage = true;
    });
    
    try {
      AppLogger.info('🔍 [AddGroupListDialog] Fetching Key Package for: ${npub.substring(0, 20)}...');
      
      final nostrService = ref.read(nostrServiceProvider);
      final keyPackage = await nostrService.fetchKeyPackageByNpub(npub);
      
      if (keyPackage != null) {
        setState(() {
          _members.add({
            'npub': npub,
            'keyPackage': keyPackage,
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
        throw Exception('Key Packageが見つかりません。相手がまだKey Packageを公開していない可能性があります。');
      }
      
    } catch (e) {
      AppLogger.error('❌ [AddGroupListDialog] Failed to fetch Key Package', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Key Package取得失敗: $e'),
            duration: const Duration(seconds: 3),
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

  /// Phase 8.1: MLSグループ作成
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

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.info('🚀 [AddGroupListDialog] Creating MLS group: ${_groupNameController.text}');
      AppLogger.info('   Members: ${_members.length}');
      
      // Key Packagesを抽出
      final keyPackages = _members.map((m) => m['keyPackage']!).toList();
      
      final groupList = await ref.read(customListsProvider.notifier).createMlsGroupList(
            name: _groupNameController.text.trim(),
            keyPackages: keyPackages,
          );

      if (groupList != null && mounted) {
        AppLogger.info('✅ [AddGroupListDialog] MLS group created: ${groupList.name}');
        Navigator.pop(context, true);
        
        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ グループ「${groupList.name}」を作成しました'),
            duration: const Duration(seconds: 2),
          ),
        );
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
            Text(
              'Phase 8.1: Add Member (MLS)',
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
            if (_members.isNotEmpty) ...[
              Text(
                'Members: ${_members.length}',
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
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final npub = member['npub']!;
                    final shortNpub = npub.length > 20 ? '${npub.substring(0, 16)}...' : npub;
                    
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      title: Text(
                        shortNpub,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () {
                          setState(() {
                            _members.removeAt(index);
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

