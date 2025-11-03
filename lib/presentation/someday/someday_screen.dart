import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/todos_provider.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/add_list_screen.dart';
import '../list_detail/list_detail_screen.dart';
import '../planning_detail/planning_detail_screen.dart';

/// SOMEDAYページ（リスト管理画面）- モーダル版
class SomedayScreen extends ConsumerWidget {
  const SomedayScreen({
    this.onClose,
    super.key,
  });

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customListsAsync = ref.watch(customListsProvider);
    final todosAsync = ref.watch(todosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // リストコンテンツ（ヘッダーなし）
          Expanded(
            child: customListsAsync.when(
              data: (customLists) => todosAsync.when(
                data: (todos) => _buildListContent(
                  context,
                  ref,
                  customLists,
                  todos,
                  isDark,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('エラーが発生しました')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('エラーが発生しました')),
            ),
          ),

          // ボトムナビゲーション
          BottomNavigation(
            onTodayTap: () {
              if (onClose != null) {
                onClose!();
              }
            },
            onAddTap: () => _showAddListScreen(context, ref),
            onSomedayTap: () {
              // 既にSOMEDAYページなので何もしない
            },
            isSomedayActive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomList> customLists,
    Map<DateTime?, List<Todo>> todos,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // MY LISTSセクション
        _buildSectionHeader('MY LISTS', isDark),
        const SizedBox(height: 16),
        
        // カスタムリスト（並び替え可能）
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: customLists.length,
          onReorder: (oldIndex, newIndex) {
            ref.read(customListsProvider.notifier).reorderLists(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final list = customLists[index];
            return _buildListItem(
              context,
              ref,
              list.name,
              _getListTodoCount(list.id, todos),
              isDark,
              key: ValueKey(list.id),
              onTap: () {
                // リスト詳細画面に遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListDetailScreen(
                      customList: list,
                    ),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 32),

        // PLANNINGセクション
        _buildSectionHeader('PLANNING', isDark),
        const SizedBox(height: 16),
        ...PlanningCategory.values.map((category) {
          final count = _getPlanningCategoryCount(category, todos);
          return _buildListItem(
            context,
            ref,
            category.label,
            count,
            isDark,
            key: ValueKey(category.name),
            onTap: () {
              // プランニングカテゴリー詳細画面に遷移
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlanningDetailScreen(
                    category: category,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  /// セクションヘッダー
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppTheme.darkTextSecondary.withOpacity(0.5)
              : AppTheme.lightTextSecondary.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// リストアイテム
  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref,
    String title,
    int count,
    bool isDark, {
    Key? key,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // リスト名
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // カウント
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// カスタムリストのTodo数を取得
  int _getListTodoCount(String listId, Map<DateTime?, List<Todo>> todos) {
    int count = 0;
    for (final dateGroup in todos.values) {
      for (final todo in dateGroup) {
        if (todo.customListId == listId && !todo.completed) {
          count++;
        }
      }
    }
    return count;
  }

  /// プランニングカテゴリーのTodo数を取得
  int _getPlanningCategoryCount(
    PlanningCategory category,
    Map<DateTime?, List<Todo>> todos,
  ) {
    final dateRange = category.getDateRange();
    int count = 0;

    for (final entry in todos.entries) {
      final date = entry.key;
      if (date != null && dateRange.contains(date)) {
        // 未完了のTodoのみカウント
        count += entry.value.where((todo) => !todo.completed).length;
      }
    }

    return count;
  }

  /// リスト追加画面を表示
  void _showAddListScreen(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddListScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

