import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
// import '../providers/todos_provider.dart'; // 旧Provider
import '../features/todo/presentation/providers/todo_providers_compat.dart';

/// Todo追加用のテキストフィールド
class AddTodoField extends StatefulWidget {
  const AddTodoField({
    required this.date,
    super.key,
  });

  final DateTime? date;

  @override
  State<AddTodoField> createState() => _AddTodoFieldState();
}

class _AddTodoFieldState extends State<AddTodoField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.add,
                color: isDark 
                    ? AppTheme.darkTextDisabled
                    : AppTheme.lightTextDisabled,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: 'タスクを追加',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTheme.todoTitle(context),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      ref
                          .read(todosProviderNotifierCompat)
                          .addTodo(value, widget.date);
                      _controller.clear();
                      _focusNode.requestFocus();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

