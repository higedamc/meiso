import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/todo.dart';
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
      color: AppTheme.backgroundColor,
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
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.columnTitle,
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('M/d (E)', 'ja_JP').format(date!),
              style: AppTheme.dateHeader,
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
          return Center(
            child: Text(
              'タスクがありません',
              style: TextStyle(
                color: AppTheme.textDisabled,
                fontSize: 14,
              ),
            ),
          );
        }

        return ReorderableListView.builder(
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
      },
    );
  }
}

