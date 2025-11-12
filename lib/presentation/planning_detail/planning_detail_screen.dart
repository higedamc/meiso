import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
// import '../../providers/todos_provider.dart'; // 旧Provider（Phase 7で置き換え）
import '../../features/todo/presentation/providers/todo_providers_compat.dart'; // 新Provider
import '../../widgets/todo_item.dart';
import '../../widgets/bottom_navigation.dart';
import 'package:intl/intl.dart';

/// プランニングカテゴリー詳細画面
class PlanningDetailScreen extends StatelessWidget {
  const PlanningDetailScreen({
    required this.category,
    super.key,
  });

  final PlanningCategory category;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final dateRange = category.getDateRange();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ヘッダー（戻るボタンなし）
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: statusBarHeight + 12,
              bottom: 16,
            ),
            color: theme.cardTheme.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // カテゴリー名
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
                
                // 期間表示
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDateRange(dateRange),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Todoリスト（日付ごとにグループ化）
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final todosAsync = ref.watch(todosProviderCompat);
                
                return todosAsync.when(
                  data: (allTodos) {
                    // 期間内のTodoを日付ごとに抽出
                    final Map<DateTime, List<Todo>> periodTodos = {};
                    
                    for (final entry in allTodos.entries) {
                      final date = entry.key;
                      if (date != null && dateRange.contains(date)) {
                        periodTodos[date] = entry.value
                            .where((todo) => !todo.completed)
                            .toList()
                          ..sort((a, b) => a.order.compareTo(b.order));
                      }
                    }

                    if (periodTodos.isEmpty) {
                      return Center(
                        child: Text(
                          'この期間にタスクがありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      );
                    }

                    // 日付順にソート
                    final sortedDates = periodTodos.keys.toList()
                      ..sort((a, b) => a.compareTo(b));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final date = sortedDates[dateIndex];
                        final todos = periodTodos[date]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 日付ヘッダー
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                _formatDate(date),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                              ),
                            ),

                            // その日のTodoリスト
                            ...todos.map<Widget>((todo) {
                              return TodoItem(
                                key: ValueKey(todo.id),
                                todo: todo,
                              );
                            }),

                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('エラーが発生しました')),
                );
              },
            ),
          ),

          // ボトムナビゲーション
          Consumer(
            builder: (context, ref, child) {
              return BottomNavigation(
                onTodayTap: () => Navigator.of(context).pop(),
                onAddTap: () {
                  // TODO追加ダイアログを表示（日付はカテゴリーの範囲内から選択）
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Todo追加機能は開発中です')),
                  );
                },
                onSomedayTap: () => Navigator.of(context).pop(),
                isSomedayActive: true,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 日付範囲をフォーマット
  String _formatDateRange(DateRange dateRange) {
    final formatter = DateFormat('M/d');
    return '${formatter.format(dateRange.start)} - ${formatter.format(dateRange.end)}';
  }

  /// 日付をフォーマット（曜日付き）
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today (${DateFormat('M/d').format(date)})';
    } else if (date.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow (${DateFormat('M/d').format(date)})';
    } else {
      final weekday = ['月', '火', '水', '木', '金', '土', '日'][date.weekday - 1];
      return '${DateFormat('M/d').format(date)} ($weekday)';
    }
  }
}

