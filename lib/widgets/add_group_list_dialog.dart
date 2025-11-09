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
  final TextEditingController _memberPubkeyController = TextEditingController();
  final List<String> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 自分の公開鍵をデフォルトで追加（hex形式）
    Future.microtask(() async {
      final ownPubkeyNpub = ref.read(nostrPublicKeyProvider);
      if (ownPubkeyNpub != null && mounted) {
        try {
          // npub形式をhex形式に変換
          final nostrService = ref.read(nostrServiceProvider);
          final ownPubkeyHex = await nostrService.npubToHex(ownPubkeyNpub);
          if (mounted) {
            setState(() {
              _members.add(ownPubkeyHex);
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
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _members.isEmpty) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final groupList = await ref.read(customListsProvider.notifier).createGroupList(
            name: _groupNameController.text.trim(),
            memberPubkeys: _members,
          );

      if (groupList != null && mounted) {
        AppLogger.info('✅ Group list created: ${groupList.name}');
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppLogger.error('❌ Failed to create group list: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループリスト作成に失敗しました: $e'),
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
                  onPressed: () async {
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
                      if (_members.contains(hexPubkey)) {
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
                        _members.add(hexPubkey);
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
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_members.isNotEmpty)
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
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final pubkey = _members[index];
                    return ListTile(
                      title: Text(
                        pubkey.length > 20 ? '${pubkey.substring(0, 10)}...${pubkey.substring(pubkey.length - 10)}' : pubkey,
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
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

