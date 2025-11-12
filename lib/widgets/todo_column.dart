import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../providers/todos_provider.dart';
import 'add_todo_field.dart';
import 'todo_item.dart';

/// Todo列ウィジェット（Today / Tomorrow / Someday）
class TodoColumn extends StatelessWidget {
  const TodoColumn({
    required this.title,
    required this.date,
    super.key,
  });

  final String title;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: _buildTodoList(),
          ),
          AddTodoField(date: date),
        ],
      ),
    );
  }

  /// ヘッダー部分
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.columnTitle(context),
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('M/d (E)', 'ja_JP').format(date!),
              style: AppTheme.dateHeader(context),
            ),
          ],
        ],
      ),
    );
  }

  /// Todoリスト部分
  Widget _buildTodoList() {
    return Consumer(
      builder: (context, ref, child) {
        final todos = ref.watch(todosForDateProvider(date));

        if (todos.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Text(
              'タスクがありません',
              style: TextStyle(
                color: isDark 
                    ? AppTheme.darkTextDisabled
                    : AppTheme.lightTextDisabled,
                fontSize: 14,
              ),
            ),
          );
        }

        return ReorderableListView.builder(
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
      },
    );
  }
}

