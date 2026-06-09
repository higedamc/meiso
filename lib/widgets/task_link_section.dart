import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/todo.dart';
import '../models/task_link.dart';
import '../providers/todos_provider.dart';

/// タスク詳細画面内のタスクリンクセクション
class TaskLinkSection extends ConsumerWidget {
  const TaskLinkSection({required this.todo, super.key});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final todosAsync = ref.watch(todosProvider);
        return todosAsync.when(
          data: (_) {
            final currentTodo = ref.read(todosProvider.notifier).findTodoById(todo.id);
            final links = currentTodo?.taskLinks ?? [];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 18,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.linkedTasksHeader,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_link, size: 20),
                        color: AppTheme.primaryPurple,
                        onPressed: () => _showAddLinkDialog(context, ref),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),

                  if (links.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.noLinkedTasks,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary.withOpacity(0.5)
                              : AppTheme.lightTextSecondary.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  ...links.map((link) =>
                      _buildLinkItem(context, ref, link, isDark, theme)),

                  const SizedBox(height: 8),
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

  Widget _buildLinkItem(
    BuildContext context,
    WidgetRef ref,
    TaskLink link,
    bool isDark,
    ThemeData theme,
  ) {
    final target = ref.read(todosProvider.notifier).findTodoById(link.targetTaskId);
    final targetTitle = target?.title ?? '(deleted)';
    final isCompleted = target?.completed ?? false;

    return Dismissible(
      key: Key('link-${todo.id}-${link.targetTaskId}-${link.linkType.name}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        color: Colors.red.shade100,
        child: Icon(Icons.link_off, color: Colors.red.shade700, size: 20),
      ),
      onDismissed: (_) {
        ref.read(todosProvider.notifier).removeTaskLink(
              todo.id,
              link.targetTaskId,
              link.linkType,
            );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _linkTypeIcon(link.linkType, isDark),
            const SizedBox(width: 8),
            Text(
              link.linkType.displayLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _linkTypeColor(link.linkType),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                targetTitle,
                style: TextStyle(
                  fontSize: 14,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? (isDark
                          ? AppTheme.darkTextSecondary.withOpacity(0.5)
                          : AppTheme.lightTextSecondary.withOpacity(0.5))
                      : theme.textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkTypeIcon(TaskLinkType type, bool isDark) {
    switch (type) {
      case TaskLinkType.blocks:
        return Icon(Icons.block, size: 16, color: Colors.red.shade400);
      case TaskLinkType.blockedBy:
        return Icon(Icons.pause_circle_outline,
            size: 16, color: Colors.orange.shade400);
      case TaskLinkType.relatedTo:
        return Icon(Icons.swap_horiz, size: 16, color: Colors.blue.shade400);
      case TaskLinkType.duplicateOf:
        return Icon(Icons.content_copy, size: 16, color: Colors.grey.shade500);
    }
  }

  Color _linkTypeColor(TaskLinkType type) {
    switch (type) {
      case TaskLinkType.blocks:
        return Colors.red.shade400;
      case TaskLinkType.blockedBy:
        return Colors.orange.shade400;
      case TaskLinkType.relatedTo:
        return Colors.blue.shade400;
      case TaskLinkType.duplicateOf:
        return Colors.grey.shade500;
    }
  }

  Future<void> _showAddLinkDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final allTodos = ref.read(todosProvider.notifier).allTodosFlat;
    // 自分自身と既にリンクしているタスクを除外
    final existingTargets =
        todo.taskLinks.map((l) => l.targetTaskId).toSet();
    final candidates = allTodos
        .where((t) =>
            t.id != todo.id &&
            !existingTargets.contains(t.id) &&
            t.parentTaskId == null)
        .toList();

    if (candidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noTasksToLink)),
        );
      }
      return;
    }

    TaskLinkType? selectedType;
    Todo? selectedTarget;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                l10n.linkTaskDialogTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // リンクタイプ選択
                    Text(
                      l10n.linkRelationship,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: TaskLinkType.values.map((type) {
                        final isSelected = selectedType == type;
                        return ChoiceChip(
                          label: Text(
                            type.displayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: _linkTypeColor(type),
                          onSelected: (val) {
                            setDialogState(() => selectedType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ターゲットタスク選択
                    Text(
                      l10n.linkTargetTask,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (ctx, i) {
                          final c = candidates[i];
                          final isSelected = selectedTarget?.id == c.id;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor:
                                AppTheme.primaryPurple.withOpacity(0.1),
                            title: Text(
                              c.title,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setDialogState(() => selectedTarget = c);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancelButton),
                ),
                ElevatedButton(
                  onPressed: selectedType != null && selectedTarget != null
                      ? () => Navigator.pop(ctx, {
                            'type': selectedType,
                            'target': selectedTarget,
                          })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.linkButton),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      final type = result['type'] as TaskLinkType;
      final target = result['target'] as Todo;
      ref.read(todosProvider.notifier).addTaskLink(
            todo.id,
            target.id,
            type,
          );
    }
  }
}
