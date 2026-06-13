import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/todos_provider.dart';
import '../../services/logger_service.dart';
import '../../widgets/todo_item.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/list_settings_sheet.dart';
import '../../widgets/slide_up_route.dart';
import '../../widgets/todo_edit_screen.dart';

/// カスタムリスト詳細画面
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({
    required this.customList,
    this.embedded = false,
    super.key,
  });

  final CustomList customList;

  /// Home のコンテンツ領域に埋め込む場合は true。Scaffold と独自の
  /// ボトムナビゲーションを描画せず、ヘッダー + Todo リストのみを返す。
  final bool embedded;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  TodosNotifier? _todosNotifier;
  int _subscriptionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _todosNotifier = ref.read(todosProvider.notifier);
    
    // Phase D.5修正: 招待受諾時に既にsyncGroupTodos()を実行しているため、
    // 画面を開いた時の自動同期は不要（二重実行を防止）
    // 
    // 理由:
    // - someday_screen.dart (line 641) で招待受諾時に既に同期済み
    // - 二重実行によりローディングインジケータが表示され続ける問題が発生
    // 
    // 将来的な改善案:
    // - Pull-to-refreshでの手動同期機能を追加
    // - または、最終同期時刻を記録して一定時間経過後のみ自動同期

    // ✅ 即反映: グループリストの場合はリアルタイム購読を開始
    if (widget.customList.isGroup) {
      final generation = ++_subscriptionGeneration;
      Future<void>(() async {
        if (!mounted || generation != _subscriptionGeneration) return;
        try {
          await _todosNotifier?.startRealtimeGroupTodos(widget.customList.id);
        } catch (e) {
          // 失敗しても画面は表示する（購読なしでpull-to-refresh運用可能）
          AppLogger.warning('⚠️ [ListDetailScreen] Failed to start realtime group subscription: ${widget.customList.id} ($e)');
        }
      });
    }
  }

  @override
  void dispose() {
    _subscriptionGeneration++;
    // ✅ 即反映: 画面を閉じたら購読を停止
    if (widget.customList.isGroup) {
      final todoNotifier = _todosNotifier;
      Future<void>(() async {
        await todoNotifier?.stopRealtimeGroupTodos(widget.customList.id);
      });
    }
    _todosNotifier = null;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Home に埋め込まれる場合は、Scaffold も独自のボトムバーも描画しない。
    // Home 側がボトムバー（永続）とコンテンツ領域を提供するため、ここでは
    // ヘッダー + Todo リストのみを返し、ボトムバーの上に収める。
    if (widget.embedded) {
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildTodoArea(context)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildTodoArea(context)),
          // ボトムナビゲーション
          Consumer(
            builder: (context, ref, child) {
              return BottomNavigation(
                onTodayTap: () => Navigator.of(context).pop(),
                onAddTap: () => _showAddTodoScreen(context),
                onSomedayTap: () => Navigator.of(context).pop(),
                // リスト詳細表示中はリスト固有の設定シートを開く
                onSettingsTap: () => showListSettingsSheet(
                  context,
                  customList: widget.customList,
                  onDeleted: () => Navigator.of(context).pop(),
                ),
                isSomedayActive: true,
                settingsContextual: true,
              );
            },
          ),
        ],
      ),
    );
  }

  /// リスト名・編集・削除のヘッダー。
  Widget _buildHeader(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    return Container(
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
            const Icon(
              Icons.group,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
          ],
          // リスト名
          // 編集・削除はボトムバーの設定ボタン（リスト設定シート）へ移設済み
          Expanded(
            child: Text(
              widget.customList.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// このリストの Todo 一覧領域。
  Widget _buildTodoArea(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(
      builder: (context, ref, child) {
        final todosAsync = ref.watch(todosProvider);
        final expandedParents = ref.watch(subtaskExpansionProvider);
        final hideCompleted = ref.watch(appSettingsProvider).valueOrNull?.hideCompletedTasks ?? false;

        return todosAsync.when(
          data: (allTodos) {
            // このリストに属するTodoを抽出
            final listTodos = <Todo>[];
            for (final dateGroup in allTodos.values) {
              for (final todo in dateGroup) {
                if (todo.customListId == widget.customList.id) {
                  if (hideCompleted && todo.completed) continue;
                  listTodos.add(todo);
                }
              }
            }

            final sortedTodos = _arrangeTodosForDisplay(
              listTodos,
              expandedParents,
            );

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
              buildDefaultDragHandles: false,
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
                  index: index,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('エラーが発生しました')),
        );
      },
    );
  }

  List<Todo> _arrangeTodosForDisplay(List<Todo> listTodos, Set<String> expandedParents) {
    final rootTodos = listTodos.where((t) => !t.isSubtask).toList();
    final rootById = <String, Todo>{
      for (final todo in rootTodos) todo.id: todo,
    };

    final subtasksByParent = <String, List<Todo>>{};
    final orphanSubtasks = <Todo>[];
    for (final todo in listTodos.where((t) => t.isSubtask)) {
      final parentId = todo.parentTaskId;
      if (parentId != null && rootById.containsKey(parentId)) {
        subtasksByParent.putIfAbsent(parentId, () => <Todo>[]).add(todo);
      } else {
        orphanSubtasks.add(todo);
      }
    }

    for (final subtasks in subtasksByParent.values) {
      subtasks.sort((a, b) => a.order.compareTo(b.order));
    }

    final incompleteRoots = rootTodos.where((t) => !t.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final completedRoots = rootTodos.where((t) => t.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final arranged = <Todo>[];

    void appendRootWithChildren(Todo root) {
      arranged.add(root);
      if (!expandedParents.contains(root.id)) {
        return;
      }
      final subtasks = subtasksByParent[root.id];
      if (subtasks == null || subtasks.isEmpty) {
        return;
      }
      arranged.addAll(subtasks);
    }

    for (final root in incompleteRoots) {
      appendRootWithChildren(root);
    }
    for (final root in completedRoots) {
      appendRootWithChildren(root);
    }

    if (orphanSubtasks.isNotEmpty) {
      final incompleteOrphans = orphanSubtasks.where((t) => !t.completed).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final completedOrphans = orphanSubtasks.where((t) => t.completed).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      arranged.addAll(incompleteOrphans);
      arranged.addAll(completedOrphans);
    }

    return arranged;
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
      todos,
    );
  }

  // リスト名編集・削除ダイアログは ListSettingsSheet へ移植済み

  /// Todo追加画面を表示
  void _showAddTodoScreen(BuildContext context) {
    Navigator.of(context).push(
      slideUpRoute<void>(
        TodoEditScreen(
          customListId: widget.customList.id,
          customListName: widget.customList.name,
          isGroupList: widget.customList.isGroup,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

