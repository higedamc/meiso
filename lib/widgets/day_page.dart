import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import 'package:intl/intl.dart';
import '../services/logger_service.dart';
import '../app_theme.dart';
import '../providers/todos_provider.dart';
import '../providers/nostr_provider.dart';
import '../services/logger_service.dart';
import 'todo_item.dart';
import '../services/logger_service.dart';
import 'sync_status_indicator.dart';
import '../services/logger_service.dart';

/// 1日分のTodoページ
class DayPage extends ConsumerWidget {
  const DayPage({
    required this.date,
    this.onSettingsTap,
    this.onBackFromSomeday,
    super.key,
  });

  final DateTime? date;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBackFromSomeday;

  /// Pull-to-refreshで同期を実行
  Future<void> _onRefresh(WidgetRef ref) async {
    // Nostr未初期化の場合はスキップ
    if (!ref.read(nostrInitializedProvider)) {
      return;
    }

    try {
      final todoNotifier = ref.read(todosProvider.notifier);
      
      // 新実装（Kind 30001）: Nostrから全Todoリストを同期
      await todoNotifier.syncFromNostr();
    } catch (e) {
      AppLogger.warning('⚠️ 同期エラー: $e');
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

  /// ヘッダー部分（日付表示、同期ステータス、設定アイコン）
  Widget _buildHeader(BuildContext context) {
    // ステータスバーの高さを取得
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final isSomeday = date == null;
    
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: EdgeInsets.only(
        left: isSomeday && onBackFromSomeday != null ? 12 : 20,
        right: 12,
        top: statusBarHeight + 12,
        bottom: 16,
      ),
      child: Row(
        children: [
          // SOMEDAYの場合は戻るボタンを表示
          if (isSomeday && onBackFromSomeday != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 24,
              color: textColor,
              onPressed: onBackFromSomeday,
              tooltip: '戻る',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          
          // 日付（左寄せ）
          if (date != null)
            Text(
              DateFormat('EEEE, MMMM d', 'en_US').format(date!).toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.6),
                letterSpacing: 1.0,
                height: 1.2,
              ),
            )
          else
            Text(
              'SOMEDAY',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.6),
                letterSpacing: 1.0,
                height: 1.2,
              ),
            ),
          
          // 中央の余白に同期ステータスインジケーターを配置
          const Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: SyncStatusIndicator(),
              ),
            ),
          ),
          
          // 設定アイコン（右端）
          if (onSettingsTap != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              iconSize: 24,
              color: textColor,
              onPressed: onSettingsTap,
              tooltip: '設定',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
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
        final todo = todos[oldIndex];
        // newIndexの調整（ReorderableListViewの仕様）
        final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
        ref
            .read(todosProvider.notifier)
            .reorderTodo(date, oldIndex, adjustedIndex);
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

