import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../providers/todos_provider.dart';
import 'add_todo_field.dart';
import 'todo_item.dart';

/// 1日分のTodoページ
class DayPage extends StatelessWidget {
  const DayPage({
    required this.date,
    super.key,
  });

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _buildTodoList(),
        ),
        AddTodoField(date: date),
      ],
    );
  }

  /// ヘッダー部分（日付表示と設定アイコン）
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'SOMEDAY',
                    style: TextStyle(
                      fontSize: 20,
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            iconSize: 24,
            color: AppTheme.textPrimary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('設定画面は後で実装します'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
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
          return const SizedBox.shrink();
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
      },
    );
  }
}

