import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/todos_provider.dart';
import '../../widgets/todo_item.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/todo_edit_screen.dart';

/// カスタムリスト詳細画面
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({
    required this.customList,
    super.key,
  });

  final CustomList customList;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  @override
  void initState() {
    super.initState();
    
    // Phase D.5: グループリストの場合、初期化時にグループタスクを同期
    if (widget.customList.isGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(todosProvider.notifier).syncGroupTodos(widget.customList.id);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ヘッダー（戻るボタンなし）
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 12,
              top: statusBarHeight + 12,
              bottom: 16,
            ),
            color: theme.cardTheme.color,
            child: Row(
              children: [
                // グループアイコン（グループリストの場合）
                if (widget.customList.isGroup) ...[
                  Icon(
                    Icons.group,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                // リスト名
                Expanded(
                  child: Text(
                    widget.customList.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                // 編集ボタン
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: 20,
                  color: isDark
                      ? AppTheme.darkTextPrimary.withOpacity(0.7)
                      : AppTheme.lightTextPrimary.withOpacity(0.7),
                  onPressed: () => _showEditDialog(context),
                  tooltip: 'リスト名を編集',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),

                // 削除ボタン
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: isDark
                      ? AppTheme.darkTextPrimary.withOpacity(0.7)
                      : AppTheme.lightTextPrimary.withOpacity(0.7),
                  onPressed: () => _showDeleteDialog(context),
                  tooltip: 'リストを削除',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Todoリスト
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final todosAsync = ref.watch(todosProvider);
                
                return todosAsync.when(
                  data: (allTodos) {
                    // このリストに属するTodoを抽出
                    final listTodos = <Todo>[];
                    for (final dateGroup in allTodos.values) {
                      for (final todo in dateGroup) {
                        if (todo.customListId == widget.customList.id) {
                          listTodos.add(todo);
                        }
                      }
                    }

                    // 未完了と完了済みに分ける
                    final incomplete = listTodos.where((t) => !t.completed).toList();
                    final completed = listTodos.where((t) => t.completed).toList();

                    // order順にソート
                    incomplete.sort((a, b) => a.order.compareTo(b.order));
                    completed.sort((a, b) => a.order.compareTo(b.order));

                    final sortedTodos = [...incomplete, ...completed];

                    if (sortedTodos.isEmpty) {
                      return Center(
                        child: Text(
                          'タスクがありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: sortedTodos.length,
                      onReorder: (oldIndex, newIndex) {
                        _handleReorder(
                          context,
                          ref,
                          sortedTodos,
                          oldIndex,
                          newIndex,
                        );
                      },
                      itemBuilder: (context, index) {
                        final todo = sortedTodos[index];
                        
                        return TodoItem(
                          key: ValueKey(todo.id),
                          todo: todo,
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
                onAddTap: () => _showAddTodoScreen(context),
                onSomedayTap: () => Navigator.of(context).pop(),
                isSomedayActive: true,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 並び替え処理
  void _handleReorder(
    BuildContext context,
    WidgetRef ref,
    List<Todo> todos,
    int oldIndex,
    int newIndex,
  ) {
    // TODO: カスタムリスト内での並び替えロジックを実装
    // 現在はdate内での並び替えのみ対応
    final todo = todos[oldIndex];
    ref.read(todosProvider.notifier).reorderTodo(
      todo.date,
      oldIndex,
      newIndex,
    );
  }

  /// リスト名編集ダイアログ
  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.customList.name);

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) => AlertDialog(
          title: const Text('リスト名を編集'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'リスト名を入力',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(customListsProvider.notifier).updateList(
                  widget.customList.copyWith(name: value.trim().toUpperCase()),
                );
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  ref.read(customListsProvider.notifier).updateList(
                    widget.customList.copyWith(name: text.toUpperCase()),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// リスト削除確認ダイアログ
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) => AlertDialog(
          title: const Text('リストを削除'),
          content: Text('「${widget.customList.name}」を削除しますか？\n\nこのリストに属するタスクは削除されません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                ref.read(customListsProvider.notifier).deleteList(widget.customList.id);
                Navigator.pop(context); // ダイアログを閉じる
                Navigator.pop(context); // 詳細画面を閉じる
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        ),
      ),
    );
  }

  /// Todo追加画面を表示
  void _showAddTodoScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TodoEditScreen(
          date: null, // カスタムリストに属するTodoは date=null（Someday）
          customListId: widget.customList.id,
          customListName: widget.customList.name,
          isGroupList: widget.customList.isGroup,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

