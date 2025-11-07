import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/todos_provider.dart';
import '../../services/logger_service.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/add_list_screen.dart';
import '../../widgets/add_group_list_dialog.dart';
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
              showDragHandle: true, // ドラッグハンドルを表示
              isGroup: list.isGroup, // グループリストフラグ
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
    bool showDragHandle = false,
    bool isGroup = false,
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
            // ドラッグハンドル（カスタムリストのみ表示）
            if (showDragHandle) ...[
              Icon(
                Icons.drag_handle,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : AppTheme.lightTextSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
            ],
            // グループアイコン（グループリストの場合）
            if (isGroup) ...[
              Icon(
                Icons.group,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
            ],
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
    int totalTodosInMap = 0;
    int todosWithCustomListId = 0;
    
    // デバッグ: 日付nullのTodoを確認
    if (todos.containsKey(null)) {
      AppLogger.debug('🔍 [SomedayScreen] date=null group has ${todos[null]!.length} todos');
      for (final todo in todos[null]!) {
        AppLogger.debug('   - "${todo.title}" (customListId: ${todo.customListId}, completed: ${todo.completed})');
      }
    } else {
      AppLogger.debug('⚠️ [SomedayScreen] No date=null group found in todos map!');
    }
    
    for (final entry in todos.entries) {
      AppLogger.debug('🔍 [SomedayScreen] Date key: ${entry.key}, ${entry.value.length} todos');
      for (final todo in entry.value) {
        totalTodosInMap++;
        if (todo.customListId != null) {
          todosWithCustomListId++;
          AppLogger.debug('   - "${todo.title}" → customListId: ${todo.customListId}');
        }
        if (todo.customListId == listId && !todo.completed) {
          count++;
          AppLogger.debug('   ✅ Matched for list $listId: "${todo.title}"');
        }
      }
    }
    
    AppLogger.debug('📊 [SomedayScreen] _getListTodoCount for list $listId:');
    AppLogger.debug('   - Total todos in map: $totalTodosInMap');
    AppLogger.debug('   - Todos with customListId: $todosWithCustomListId');
    AppLogger.debug('   - Matched todos: $count');
    
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

  /// リスト追加画面を表示（通常リストorグループリスト）
  void _showAddListScreen(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: Text(
            'ADD LIST',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
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
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddListScreen(),
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
                  Navigator.pop(context);
                  showDialog(
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
}

