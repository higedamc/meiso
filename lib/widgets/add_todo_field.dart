import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/todos_provider.dart';

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
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(
              top: BorderSide(
                color: AppTheme.dividerColor,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.add,
                color: AppTheme.textDisabled,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'タスクを追加',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTheme.todoTitle,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      ref
                          .read(todosProvider.notifier)
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

