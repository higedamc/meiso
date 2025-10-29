import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';

/// 個別のTodoアイテムウィジェット
class TodoItem extends StatelessWidget {
  const TodoItem({
    required this.todo,
    super.key,
  });

  final Todo todo;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Dismissible(
          key: Key(todo.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red.shade100,
            child: Icon(
              Icons.delete_outline,
              color: Colors.red.shade700,
            ),
          ),
          onDismissed: (_) {
            ref.read(todosProvider.notifier).deleteTodo(todo.id, todo.date);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「${todo.title}」を削除しました'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // チェックボックス
                Checkbox(
                  value: todo.completed,
                  onChanged: (_) {
                    ref
                        .read(todosProvider.notifier)
                        .toggleTodo(todo.id, todo.date);
                  },
                ),
                
                // タイトル
                Expanded(
                  child: Text(
                    todo.title,
                    style: todo.completed
                        ? AppTheme.todoTitleCompleted
                        : AppTheme.todoTitle,
                  ),
                ),
                
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

