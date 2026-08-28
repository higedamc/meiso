import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'add_group_list_dialog.dart';
import 'add_list_screen.dart';
import 'slide_up_route.dart';

/// 「リストを追加」の選択ダイアログ（Personal List / Group List）。
///
/// SOMEDAY コンテキストでの追加導線を SomedayScreen と HomeScreen の
/// 永続ボトムバーの双方から共有するための共通関数。
void showAddListChooser(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: Text(
          'ADD LIST',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color:
                isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            letterSpacing: 1.2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 通常のカスタムリスト
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Personal List'),
              subtitle: const Text('個人用のタスクリスト'),
              onTap: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).push(
                  slideUpRoute<void>(
                    const AddListScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
            const Divider(),
            // グループリスト
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Group List'),
              subtitle: const Text('共有可能なグループタスクリスト'),
              onTap: () {
                Navigator.pop(dialogContext);
                showDialog<void>(
                  context: context,
                  builder: (context) => const AddGroupListDialog(),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
