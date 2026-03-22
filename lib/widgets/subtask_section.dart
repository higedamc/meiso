import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';
import 'circular_checkbox.dart';

/// タスク詳細画面内のサブタスクセクション
class SubtaskSection extends ConsumerStatefulWidget {
  const SubtaskSection({required this.parentTodo, super.key});

  final Todo parentTodo;

  @override
  ConsumerState<SubtaskSection> createState() => _SubtaskSectionState();
}

class _SubtaskSectionState extends ConsumerState<SubtaskSection> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  bool _isAdding = false;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final todosAsync = ref.watch(todosProvider);
        return todosAsync.when(
          data: (todos) {
            final subtasks =
                ref.read(todosProvider.notifier).getSubtasks(widget.parentTodo.id);
            final progress = ref
                .read(todosProvider.notifier)
                .getSubtaskProgress(widget.parentTodo.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // ヘッダー
                  Row(
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: 18,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SUBTASKS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (subtasks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${subtasks.where((s) => s.completed).length}/${subtasks.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary.withOpacity(0.7)
                                : AppTheme.lightTextSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // 追加ボタン
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        color: AppTheme.primaryPurple,
                        onPressed: () {
                          setState(() => _isAdding = true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _addFocusNode.requestFocus();
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),

                  // プログレスバー
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? Colors.green
                              : AppTheme.primaryPurple,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // サブタスクリスト
                  ...subtasks.map((subtask) => _buildSubtaskItem(
                        context,
                        ref,
                        subtask,
                        isDark,
                        theme,
                      )),

                  // 追加フィールド
                  if (_isAdding) _buildAddField(context, ref, isDark, theme),

                  if (subtasks.isEmpty && !_isAdding)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No subtasks yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary.withOpacity(0.5)
                              : AppTheme.lightTextSecondary.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  Divider(
                    color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSubtaskItem(
    BuildContext context,
    WidgetRef ref,
    Todo subtask,
    bool isDark,
    ThemeData theme,
  ) {
    return Dismissible(
      key: Key('subtask-${subtask.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        color: Colors.red.shade100,
        child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
      ),
      onDismissed: (_) {
        ref.read(todosProvider.notifier).softDeleteTodo(subtask);
        ref
            .read(todosProvider.notifier)
            .scheduleDeleteConfirmation(const Duration(seconds: 3));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircularCheckbox(
              value: subtask.completed,
              onChanged: (_) {
                ref
                    .read(todosProvider.notifier)
                    .toggleTodo(subtask.id, subtask.date);
              },
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration:
                      subtask.completed ? TextDecoration.lineThrough : null,
                  color: subtask.completed
                      ? (isDark
                          ? AppTheme.darkTextSecondary.withOpacity(0.5)
                          : AppTheme.lightTextSecondary.withOpacity(0.5))
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddField(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: TextField(
              controller: _addController,
              focusNode: _addFocusNode,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Add subtask...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary.withOpacity(0.5)
                      : AppTheme.lightTextSecondary.withOpacity(0.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              minLines: 1,
              maxLines: null,
              textInputAction: TextInputAction.newline,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            onPressed: () => _submitSubtask(ref, _addController.text),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Add subtask',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              _addController.clear();
              setState(() => _isAdding = false);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  void _submitSubtask(WidgetRef ref, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _isAdding = false);
      return;
    }

    ref.read(todosProvider.notifier).addSubtask(
          widget.parentTodo.id,
          trimmed,
          widget.parentTodo.date,
        );

    _addController.clear();
    _addFocusNode.requestFocus();
  }
}
