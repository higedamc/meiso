import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../models/custom_list.dart';
import '../providers/custom_lists_provider.dart';
import '../services/logger_service.dart';
import 'member_picker.dart';

/// カスタムリスト詳細表示中にボトムバーの設定ボタンから開く、
/// リスト固有の設定シート（M3 ボトムシート）。
///
/// - リスト名の変更
/// - メンバー追加（shared-v1 グループのみ）
/// - リスト削除
Future<void> showListSettingsSheet(
  BuildContext context, {
  required CustomList customList,
  VoidCallback? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => ListSettingsSheet(
      customList: customList,
      onDeleted: onDeleted,
    ),
  );
}

class ListSettingsSheet extends ConsumerWidget {
  const ListSettingsSheet({
    required this.customList,
    this.onDeleted,
    super.key,
  });

  final CustomList customList;

  /// リスト削除が確定したときに呼ばれる（詳細画面を閉じる用途）。
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                if (customList.isGroup) ...[
                  const Icon(
                    Icons.group,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    customList.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'LIST SETTINGS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('リスト名を変更'),
            onTap: () => _showRenameDialog(context, ref),
          ),

          if (customList.isSharedProtocol)
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('メンバーを追加'),
              subtitle: const Text(
                'フォローリスト・QR・npub 入力から招待',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () => _addMembers(context, ref),
            ),

          ListTile(
            leading: Icon(Icons.delete_outline, color: colorScheme.error),
            title: Text(
              'リストを削除',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () => _showDeleteDialog(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// リスト名変更ダイアログ（旧 ListDetailScreen._showEditDialog 移植）
  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: customList.name);

    void submit(String value) {
      final text = value.trim();
      if (text.isEmpty) {
        return;
      }
      ref.read(customListsProvider.notifier).updateList(
            customList.copyWith(name: text.toUpperCase()),
          );
      Navigator.pop(context); // ダイアログを閉じる
      Navigator.pop(context); // シートを閉じる
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('リスト名を編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'リスト名を入力',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          onSubmitted: submit,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => submit(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// member_picker からメンバーを選び、既存グループへ招待を送る
  Future<void> _addMembers(BuildContext context, WidgetRef ref) async {
    final picked = await showMemberPicker(context);
    if (picked == null || picked.isEmpty || !context.mounted) {
      return;
    }

    var successCount = 0;
    for (final npub in picked) {
      final ok = await ref
          .read(customListsProvider.notifier)
          .inviteMemberToSharedGroup(groupId: customList.id, npub: npub);
      if (ok) {
        successCount++;
      }
    }

    AppLogger.info(
      '📤 [ListSettings] Invitations sent: $successCount/${picked.length} for ${customList.id}',
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successCount == picked.length
              ? '招待を送信しました ($successCount人)'
              : '一部の招待送信に失敗しました ($successCount/${picked.length})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    if (successCount > 0) {
      Navigator.pop(context); // シートを閉じる
    }
  }

  /// リスト削除確認ダイアログ（旧 ListDetailScreen._showDeleteDialog 移植）
  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('リストを削除'),
        content: Text(
          '「${customList.name}」を削除しますか？\n\nこのリストに属するタスクは削除されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(customListsProvider.notifier)
                  .deleteList(customList.id);
              Navigator.pop(dialogContext); // ダイアログを閉じる
              Navigator.pop(context); // シートを閉じる
              onDeleted?.call(); // 詳細画面を閉じる
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
