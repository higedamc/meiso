import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/custom_list.dart';
import '../models/todo.dart';
import '../providers/custom_lists_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/app_settings_provider.dart';
import '../presentation/list_detail/list_detail_screen.dart';
import '../presentation/planning_detail/planning_detail_screen.dart';
import 'add_list_screen.dart';

/// 展開可能なカスタムリストモーダル（画面全体）
class ExpandableCustomListModal extends ConsumerWidget {
  const ExpandableCustomListModal({
    required this.isVisible,
    required this.onListSelected,
    super.key,
  });

  final bool isVisible;
  final VoidCallback onListSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customListsAsync = ref.watch(customListsProvider);
    final todosAsync = ref.watch(todosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        heightFactor: isVisible ? 1.0 : 0.0,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? AppTheme.darkPurple : AppTheme.primaryPurple,
                isDark ? AppTheme.darkPurple.withOpacity(0.9) : AppTheme.primaryPurple.withOpacity(0.9),
              ],
            ),
          ),
          child: customListsAsync.when(
            data: (customLists) => todosAsync.when(
              data: (todos) => _buildContent(
                context,
                ref,
                customLists,
                todos,
                isDark,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text(
                  'エラーが発生しました',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text(
                'エラーが発生しました',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomList> customLists,
    Map<DateTime?, List<Todo>> todos,
    bool isDark,
  ) {
    return SafeArea(
      child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SOMEDAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 28),
                  onPressed: () => _showAddListScreen(context, ref),
                ),
              ],
            ),
          ),

          // スクロール可能なリスト
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // MY LISTSセクション
                _buildSectionHeader('MY LISTS'),
                const SizedBox(height: 16),
                
                // カスタムリスト（並び替え可能）
                ...customLists.map((list) {
                  return _buildListItem(
                    context,
                    ref,
                    list.name,
                    _getListTodoCount(list.id, todos),
                    onTap: () async {
                      // 最後に見たリストIDを保存
                      await ref.read(appSettingsProvider.notifier).updateSettings(
                        ref.read(appSettingsProvider).value!.copyWith(
                          lastViewedCustomListId: list.id,
                        ),
                      );
                      
                      onListSelected();
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListDetailScreen(
                              customList: list,
                            ),
                          ),
                        );
                      }
                    },
                  );
                }),

                const SizedBox(height: 32),

                // PLANNINGセクション
                _buildSectionHeader('PLANNING'),
                const SizedBox(height: 16),
                ...PlanningCategory.values.map((category) {
                  final count = _getPlanningCategoryCount(category, todos);
                  return _buildListItem(
                    context,
                    ref,
                    category.label,
                    count,
                    onTap: () {
                      onListSelected();
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
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// セクションヘッダー
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.7),
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
    int count, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.2),
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // カウント
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
    
    for (final entry in todos.entries) {
      for (final todo in entry.value) {
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

