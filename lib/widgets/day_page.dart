import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../providers/todos_provider.dart';
import '../providers/nostr_provider.dart';
import 'todo_item.dart';

/// 1日分のTodoページ
class DayPage extends ConsumerWidget {
  const DayPage({
    required this.date,
    this.onSettingsTap,
    super.key,
  });

  final DateTime? date;
  final VoidCallback? onSettingsTap;

  /// Pull-to-refreshで同期を実行
  Future<void> _onRefresh(WidgetRef ref) async {
    // Nostr未初期化の場合はスキップ
    if (!ref.read(nostrInitializedProvider)) {
      return;
    }

    try {
      final todoNotifier = ref.read(todosProvider.notifier);
      
      // 1. ローカルの未送信Todoをアップロード
      await todoNotifier.uploadPendingTodos();
      
      // 2. Nostrから最新のTodoをダウンロード
      final nostrService = ref.read(nostrServiceProvider);
      final todos = await nostrService.syncTodosFromNostr();
      await todoNotifier.mergeTodosFromNostr(todos);
    } catch (e) {
      debugPrint('⚠️ 同期エラー: $e');
      // エラーは表示せずに静かに失敗させる（UX改善のため）
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _onRefresh(ref),
            child: _buildTodoList(ref),
          ),
        ),
      ],
    );
  }

  /// ヘッダー部分（日付表示と設定アイコン）
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // 日付（左寄せ）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date != null) ...[
                  Text(
                    DateFormat('EEEE, MMMM d', 'en_US').format(date!).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'SOMEDAY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 設定アイコン（右端）
          if (onSettingsTap != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              iconSize: 24,
              color: AppTheme.textPrimary,
              onPressed: onSettingsTap,
              tooltip: '設定',
            ),
        ],
      ),
    );
  }

  /// Todoリスト部分
  Widget _buildTodoList(WidgetRef ref) {
    final todos = ref.watch(todosForDateProvider(date));

    // リストが空の場合は、pull-to-refreshが動くようにCustomScrollViewを使用
    if (todos.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Container(),
          ),
        ],
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.zero,
      itemCount: todos.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(todosProvider.notifier)
            .reorderTodo(date, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final todo = todos[index];
        return TodoItem(
          key: Key(todo.id),
          todo: todo,
        );
      },
    );
  }
}

