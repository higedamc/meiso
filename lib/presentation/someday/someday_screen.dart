import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../models/custom_list.dart';
import '../../models/todo.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/todos_provider.dart';
import '../../providers/nostr_provider.dart';
import '../../services/logger_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/add_list_screen.dart';
import '../../widgets/add_group_list_dialog.dart';
import '../../widgets/sync_status_indicator.dart';
import '../list_detail/list_detail_screen.dart';
import '../planning_detail/planning_detail_screen.dart';
// Phase D.5: MLS UseCase統合
import '../../features/mls/application/providers/usecase_providers.dart';
import '../../features/mls/application/usecases/accept_group_invitation_usecase.dart';

/// SOMEDAYページ（リスト管理画面）- モーダル版
class SomedayScreen extends ConsumerStatefulWidget {
  const SomedayScreen({
    this.onClose,
    super.key,
  });

  final VoidCallback? onClose;

  @override
  ConsumerState<SomedayScreen> createState() => _SomedayScreenState();
}

class _SomedayScreenState extends ConsumerState<SomedayScreen> {
  ProviderSubscription<AsyncValue<List<CustomList>>>? _customListsSub;
  Set<String> _realtimeGroupIds = <String>{};
  int _reconcileGeneration = 0;
  TodosNotifier? _todosNotifier;

  @override
  void initState() {
    super.initState();
    // dispose中にrefを触らないため、notifier参照を保持しておく
    _todosNotifier = ref.read(todosProvider.notifier);

    // ✅ 即反映: Somedayを開いている間、受諾済みの全グループリストを購読
    _customListsSub = ref.listenManual<AsyncValue<List<CustomList>>>(
      customListsProvider,
      (prev, next) {
        final lists = next.valueOrNull;
        if (lists == null) return;
        // dispose後に走らないよう世代管理
        _reconcileRealtimeGroupSubscriptions(lists);
      },
    );

    // 初回も反映
    final initial = ref.read(customListsProvider).valueOrNull;
    if (initial != null) {
      Future<void>(() => _reconcileRealtimeGroupSubscriptions(initial));
    }
  }

  @override
  void dispose() {
    _reconcileGeneration++;
    // ✅ 即反映: Somedayを閉じたら購読を解除
    // dispose中はrefを触らない（"Cannot use ref after the widget was disposed" 対策）
    final groupIds = _realtimeGroupIds.toList();
    _realtimeGroupIds = <String>{};

    _customListsSub?.close();
    _customListsSub = null;

    // close後に購読解除（dispose中にrefを触らない）
    final todoNotifier = _todosNotifier;
    for (final gid in groupIds) {
      Future<void>(() async {
        await todoNotifier?.stopRealtimeGroupTodos(gid);
      });
    }
    _todosNotifier = null;
    super.dispose();
  }

  Future<void> _reconcileRealtimeGroupSubscriptions(List<CustomList> lists) async {
    if (!mounted) return;
    final generation = ++_reconcileGeneration;

    // 受諾済みグループのみ（pendingは復号できない可能性があるため購読しない）
    final desired = lists
        .where((l) => l.isGroup && !l.isPendingInvitation)
        .map((l) => l.id)
        .toSet();

    final toStart = desired.difference(_realtimeGroupIds);
    final toStop = _realtimeGroupIds.difference(desired);

    final todoNotifier = _todosNotifier;
    if (todoNotifier == null) return;

    AppLogger.info(
      '📡 [SomedayScreen] Reconcile realtime group subs: desired=${desired.length}, toStart=${toStart.length}, toStop=${toStop.length}',
    );

    for (final gid in toStart) {
      try {
        if (!mounted || generation != _reconcileGeneration) return;
        AppLogger.info('📡 [SomedayScreen] Starting realtime group subscription: $gid');
        await todoNotifier.startRealtimeGroupTodos(gid);
      } catch (e) {
        // 購読失敗してもSomedayは表示し続ける（pull-to-refresh運用可能）
        AppLogger.warning('⚠️ [SomedayScreen] Failed to start realtime group subscription: $gid ($e)');
      }
    }

    for (final gid in toStop) {
      if (!mounted || generation != _reconcileGeneration) return;
      await todoNotifier.stopRealtimeGroupTodos(gid);
    }

    if (!mounted || generation != _reconcileGeneration) return;
    _realtimeGroupIds = desired;
  }

  /// Pull-to-refreshで同期を実行
  Future<void> _onRefresh() async {
    AppLogger.info(' [SomedayScreen] 🔄 Pull-to-refresh triggered');
    
    // Nostr未初期化の場合はスキップ
    if (!mounted) return;
    if (!ref.read(nostrInitializedProvider)) {
      AppLogger.debug(' [SomedayScreen] Nostr未初期化のため、同期をスキップ');
      return;
    }

    try {
      final todoNotifier = ref.read(todosProvider.notifier);
      final customListsNotifier = ref.read(customListsProvider.notifier);
      
      // Nostrから全Todoリストとカスタムリストを同期
      await todoNotifier.syncFromNostr();
      
      // Phase 6.4: グループ招待を同期
      await customListsNotifier.syncGroupInvitations();
      
      AppLogger.info(' [SomedayScreen] ✅ Pull-to-refresh sync completed');
    } catch (e) {
      AppLogger.warning(' [SomedayScreen] ⚠️ 同期エラー: $e');
      // エラーは表示せずに静かに失敗させる（UX改善のため）
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug(' [SomedayScreen] 🎨 build() called');
    
    final customListsAsync = ref.watch(customListsProvider);
    AppLogger.debug(' [SomedayScreen] customListsAsync type: ${customListsAsync.runtimeType}');
    
    final todosAsync = ref.watch(todosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // 楽観的UI更新: 前回のデータがあればそれを使用
    final customLists = customListsAsync.valueOrNull;
    final todos = todosAsync.valueOrNull;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // リストコンテンツ（ヘッダーなし）
          Expanded(
            child: customLists != null && todos != null
                ? RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _buildListContent(
                      context,
                      ref,
                      customLists,
                      todos,
                      isDark,
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),

          // ボトムナビゲーション
          BottomNavigation(
            onTodayTap: () {
              // BUG FIX: カレンダー展開状態をリセット
              ref.read(calendarVisibleProvider.notifier).state = false;
              
              if (widget.onClose != null) {
                widget.onClose!();
              }
            },
            onAddTap: () => _showAddListScreen(context, ref),
            onSomedayTap: () {
              // 既にSOMEDAYページなので何もしない
            },
            isSomedayActive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomList> customLists,
    Map<DateTime?, List<Todo>> todos,
    bool isDark,
  ) {
    AppLogger.info(' [SomedayScreen] 📋 _buildListContent called with ${customLists.length} custom lists');
    for (final list in customLists) {
      AppLogger.debug(' [SomedayScreen]   - "${list.name}" (ID: ${list.id}, isGroup: ${list.isGroup})');
    }
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 同期ステータスインジケーター
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: SyncStatusIndicator(),
          ),
        ),
        
        // MY LISTSセクション
        _buildSectionHeader('MY LISTS', isDark),
        const SizedBox(height: 16),
        
        // カスタムリスト（並び替え可能）
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: customLists.length,
          onReorder: (oldIndex, newIndex) {
            ref.read(customListsProvider.notifier).reorderLists(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final list = customLists[index];
            return _buildCustomListItem(
              context,
              ref,
              list,
              _getListTodoCount(list.id, todos),
              isDark,
              key: ValueKey(list.id),
              showDragHandle: true, // ドラッグハンドルを表示
              onTap: () {
                // インビテーション待ちの場合は招待受諾ダイアログを表示（Phase 6.5で実装）
                if (list.isPendingInvitation) {
                  _showAcceptInvitationDialog(context, ref, list);
                  return;
                }
                
                // リスト詳細画面に遷移
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => ListDetailScreen(
                      customList: list,
                    ),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 32),

        // PLANNINGセクション
        _buildSectionHeader('PLANNING', isDark),
        const SizedBox(height: 16),
        ...PlanningCategory.values.map((category) {
          final count = _getPlanningCategoryCount(category, todos);
          return _buildListItem(
            context,
            ref,
            category.label,
            count,
            isDark,
            key: ValueKey(category.name),
            onTap: () {
              // プランニングカテゴリー詳細画面に遷移
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                  builder: (context) => PlanningDetailScreen(
                    category: category,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  /// セクションヘッダー
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppTheme.darkTextSecondary.withOpacity(0.5)
              : AppTheme.lightTextSecondary.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// リストアイテム
  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref,
    String title,
    int count,
    bool isDark, {
    Key? key,
    required VoidCallback onTap,
    bool showDragHandle = false,
    bool isGroup = false,
    bool isPendingInvitation = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
          ),
        ),
        child: Row(
          children: [
            // ドラッグハンドル（カスタムリストのみ表示）
            if (showDragHandle) ...[
              Icon(
                Icons.drag_handle,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : AppTheme.lightTextSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
            ],
            // グループアイコン（グループリストの場合）
            if (isGroup) ...[
              const Icon(
                Icons.group,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
            ],
            // リスト名
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // インビテーションバッジ（Phase 6.4: MLS招待システム）
            if (isPendingInvitation) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail,
                      size: 14,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '招待',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // カウント
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// カスタムリスト専用のリストアイテム（削除ボタン付き）
  /// 
  /// Phase E.5: リスト削除機能
  Widget _buildCustomListItem(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
    int count,
    bool isDark, {
    Key? key,
    required VoidCallback onTap,
    bool showDragHandle = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
          ),
        ),
        child: Row(
          children: [
            // ドラッグハンドル
            if (showDragHandle) ...[
              Icon(
                Icons.drag_handle,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : AppTheme.lightTextSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
            ],
            // グループアイコン（グループリストの場合）
            if (list.isGroup) ...[
              const Icon(
                Icons.group,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
            ],
            // リスト名
            Expanded(
              child: Text(
                list.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // インビテーションバッジ
            if (list.isPendingInvitation) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail,
                      size: 14,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '招待',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // カウント
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            // 削除ボタン（Personal Listのみ、グループリストと招待は非表示）
            if (!list.isGroup && !list.isPendingInvitation) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: isDark
                      ? AppTheme.darkTextSecondary.withOpacity(0.5)
                      : AppTheme.lightTextSecondary.withOpacity(0.5),
                ),
                onPressed: () => _confirmDeleteList(context, ref, list),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Delete list',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// カスタムリストのTodo数を取得
  int _getListTodoCount(String listId, Map<DateTime?, List<Todo>> todos) {
    var count = 0;
    var totalTodosInMap = 0;
    var todosWithCustomListId = 0;
    
    // デバッグ: 日付nullのTodoを確認
    if (todos.containsKey(null)) {
      AppLogger.debug('🔍 [SomedayScreen] date=null group has ${todos[null]!.length} todos');
      for (final todo in todos[null]!) {
        AppLogger.debug('   - "${todo.title}" (customListId: ${todo.customListId}, completed: ${todo.completed})');
      }
    } else {
      AppLogger.debug('⚠️ [SomedayScreen] No date=null group found in todos map!');
    }
    
    for (final entry in todos.entries) {
      AppLogger.debug('🔍 [SomedayScreen] Date key: ${entry.key}, ${entry.value.length} todos');
      for (final todo in entry.value) {
        totalTodosInMap++;
        if (todo.customListId != null) {
          todosWithCustomListId++;
          AppLogger.debug('   - "${todo.title}" → customListId: ${todo.customListId}');
        }
        if (todo.customListId == listId && !todo.completed) {
          count++;
          AppLogger.debug('   ✅ Matched for list $listId: "${todo.title}"');
        }
      }
    }
    
    AppLogger.debug('📊 [SomedayScreen] _getListTodoCount for list $listId:');
    AppLogger.debug('   - Total todos in map: $totalTodosInMap');
    AppLogger.debug('   - Todos with customListId: $todosWithCustomListId');
    AppLogger.debug('   - Matched todos: $count');
    
    return count;
  }

  /// プランニングカテゴリーのTodo数を取得
  int _getPlanningCategoryCount(
    PlanningCategory category,
    Map<DateTime?, List<Todo>> todos,
  ) {
    final dateRange = category.getDateRange();
    var count = 0;

    for (final entry in todos.entries) {
      final date = entry.key;
      if (date != null && dateRange.contains(date)) {
        // 未完了のTodoのみカウント
        count += entry.value.where((todo) => !todo.completed).length;
      }
    }

    return count;
  }

  /// リスト削除の確認ダイアログ
  /// 
  /// Phase E.5: リスト削除機能
  Future<void> _confirmDeleteList(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: Text(
          'DELETE LIST',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Delete "${list.name}"?\n\nThis will remove the list and all its tasks from all devices.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Issue #101: 削除処理の順序を修正
      AppLogger.info('🗑️ [Someday UI] Starting list deletion: "${list.name}" (ID: ${list.id})');
      
      // 1. まずタスクを削除（失敗してもリストは残るのでやり直せる）
      AppLogger.info('🗑️ [Someday UI] Step 1: Deleting tasks in list...');
      final todosNotifier = ref.read(todosProvider.notifier);
      await todosNotifier.deleteAllTodosInList(list.id);
      AppLogger.info('✅ [Someday UI] Step 1: Tasks deleted');
      
      // 2. 次にリストを削除（タスク削除が成功してから）
      AppLogger.info('🗑️ [Someday UI] Step 2: Deleting list itself...');
      await ref.read(customListsProvider.notifier).deleteList(list.id);
      AppLogger.info('✅ [Someday UI] Step 2: List deletion request completed');
      
      // 3. 現在の状態を確認
      final currentLists = ref.read(customListsProvider).valueOrNull ?? [];
      AppLogger.info('📋 [Someday UI] Current lists after deletion: ${currentLists.length} lists');
      AppLogger.info('📋 [Someday UI] List IDs: ${currentLists.map((l) => l.id).join(", ")}');
      final stillExists = currentLists.any((l) => l.id == list.id);
      if (stillExists) {
        AppLogger.error('❌ [Someday UI] BUG: List "${list.name}" still exists in state after deletion!');
      } else {
        AppLogger.info('✅ [Someday UI] List "${list.name}" successfully removed from state');
      }
    }
  }

  /// リスト追加画面を表示（通常リストorグループリスト）
  void _showAddListScreen(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: Text(
            'ADD LIST',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              letterSpacing: 1.2,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 通常のカスタムリスト
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Personal List'),
                subtitle: const Text('個人用のタスクリスト'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const AddListScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              const Divider(),
              // グループリスト（有効化）
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Group List'),
                subtitle: const Text('共有可能なグループタスクリスト'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog<void>(
                    context: context,
                    builder: (context) => const AddGroupListDialog(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// グループ招待受諾ダイアログを表示（Phase 6.5: MLS招待システム）
  void _showAcceptInvitationDialog(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: Row(
            children: [
              const Icon(
                Icons.mail,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'グループ招待',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              if (list.inviterName != null) ...[
                Text(
                  '招待者: ${list.inviterName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (list.inviterNpub != null) ...[
                Text(
                  '公開鍵: ${list.inviterNpub!.substring(0, 16)}...',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark 
                      ? AppTheme.darkTextSecondary.withOpacity(0.7) 
                      : AppTheme.lightTextSecondary.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'このグループリストに参加しますか？',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Issue #102: 辞退ボタン - 招待を辞退してリストを削除
                Navigator.pop(context);
                
                // リストを削除
                try {
                  await ref.read(customListsProvider.notifier).deleteList(list.id);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('「${list.name}」への招待を辞退しました'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  
                  AppLogger.info('✅ [GroupInvitation] Declined invitation for: ${list.name}');
                } catch (e) {
                  AppLogger.error('❌ [GroupInvitation] Failed to decline invitation: $e');
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('辞退処理に失敗しました: $e'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              },
              child: Text(
                '辞退',
                style: TextStyle(
                  color: Colors.red.shade400,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // ダイアログのcontextはpop直後にunmountされるため、
                // 以降の処理（ローディング表示/クローズ、Snackbar表示）は親contextで行う。
                Navigator.pop(dialogContext);
                await _acceptGroupInvitation(context, ref, list);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('参加する'),
            ),
          ],
        );
      },
    );
  }

  /// グループ招待を受諾（Phase 6.5 + Phase D.5: MLS招待システム + UseCase統合）
  Future<void> _acceptGroupInvitation(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
  ) async {
    var isLoadingDialogShown = false;
    
    try {
      AppLogger.info('🎉 [GroupInvitation] Accepting invitation for: ${list.name}');
      
      // ローディングインジケータを表示（rootNavigator使用で安定性向上）
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      isLoadingDialogShown = true;
      AppLogger.debug('📱 [GroupInvitation] Loading dialog shown');
      
      // Welcome Messageをデコード
      if (list.welcomeMsg == null) {
        throw Exception('Welcome message not found');
      }
      
      // 公開鍵を取得
      final nostrService = ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();
      
      if (userPubkey == null) {
        throw Exception('User public key not available');
      }
      
      // 🔥 Phase D.9: タイムアウト追加（無限待機バグ修正）
      // AcceptGroupInvitationUseCaseを使用（Amber署名含むため長めのタイムアウト）
      AppLogger.info('🔐 [GroupInvitation] Accepting invitation with timeout (3 min)...');
      final acceptInvitationUseCase = ref.read(acceptGroupInvitationUseCaseProvider);
      final result = await ErrorHandler.withTimeout(
        operation: () => acceptInvitationUseCase(AcceptGroupInvitationParams(
          publicKey: userPubkey,
          groupId: list.id,
          welcomeMessage: list.welcomeMsg!,
        )),
        operationName: 'acceptGroupInvitation',
        timeout: const Duration(minutes: 3), // Amber署名を含むため長めに設定
      );
      
      await result.fold(
        (failure) async {
          AppLogger.error('❌ [GroupInvitation] Failed: ${failure.message}');
          throw Exception(failure.message);
        },
        (mlsGroup) async {
          AppLogger.info('✅ [GroupInvitation] Successfully joined MLS group');
          AppLogger.info('🔑 [GroupInvitation] Key Package auto-published (forceUpload=true)');
          
          // リストの招待フラグをクリア
          final updatedList = list.copyWith(
            // 🔥 Important: 受諾後は必ずグループリスト扱いにする
            // これがfalseだと MLS group のローカル参照が失敗し、同期で「未承諾」に戻りやすくなる
            isGroup: true,
            isPendingInvitation: false,
            inviterNpub: null,
            inviterName: null,
            welcomeMsg: null,
            // 🔥 Phase 8.7: Bug #1修正 - 承諾日時を記録して再表示を防ぐ
            acceptedAt: DateTime.now(),
            // Rust側から取得した実メンバー情報を保存（後続のUI/同期で参照可能に）
            groupMembers: mlsGroup.memberPubkeys,
          );
          
          // ローカルストレージに保存
          AppLogger.debug('💾 [GroupInvitation] Updating custom list...');
          final customListsNotifier = ref.read(customListsProvider.notifier);
          await customListsNotifier.updateList(updatedList);
          AppLogger.debug('✅ [GroupInvitation] Custom list updated');
          
          AppLogger.info('🎉 [GroupInvitation] Group invitation accepted successfully');
          
          // Phase D.5: グループタスクを同期（リスト内容が見えるように）
          AppLogger.info('🔄 [GroupInvitation] Syncing group todos...');
          try {
            await ref.read(todosProvider.notifier).syncGroupTodos(list.id);
            AppLogger.info('✅ [GroupInvitation] Group todos synced');
          } catch (e) {
            AppLogger.warning('⚠️ [GroupInvitation] Failed to sync group todos: $e');
            // エラーは無視（後で手動同期可能）
          }
          
          // ローディングを閉じる（rootNavigatorを使用）
          AppLogger.debug('🔓 [GroupInvitation] Closing loading dialog... context.mounted=${context.mounted}');
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            isLoadingDialogShown = false;
            AppLogger.debug('✅ [GroupInvitation] Loading dialog closed');
          } else {
            AppLogger.warning('⚠️ [GroupInvitation] Context not mounted, cannot close loading dialog');
          }
          
          // 成功メッセージ（自動遷移は行わず、ユーザーが自分でタップできるように）
          if (context.mounted) {
            AppLogger.debug('📢 [GroupInvitation] Showing success snackbar');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${list.name}に参加しました。リストをタップして開いてください。'),
              ),
            );
            AppLogger.info('✅ [GroupInvitation] Invitation accepted successfully - user can now tap the list');
          } else {
            AppLogger.warning('⚠️ [GroupInvitation] Context not mounted, cannot show snackbar');
          }
        },
      );
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [GroupInvitation] Failed to accept invitation', error: e, stackTrace: stackTrace);
      
      // ローディングを閉じる（エラー時も確実に閉じる、rootNavigatorを使用）
      AppLogger.debug('🔓 [GroupInvitation] Closing loading dialog (error case)... isLoadingDialogShown=$isLoadingDialogShown, context.mounted=${context.mounted}');
      if (isLoadingDialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppLogger.debug('✅ [GroupInvitation] Loading dialog closed (error case)');
      }
      
      // Phase 2.5B: NoMatchingKeyPackageエラーの特別処理
      final errorMessage = e.toString();
      final isKeyPackageError = errorMessage.contains('NoMatchingKeyPackage');
      
      // エラーメッセージ
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isKeyPackageError ? Icons.key_off : Icons.error,
                    color: isKeyPackageError ? Colors.orange : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  const Text('エラー'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isKeyPackageError) ...[
                    // Phase 2.5B: Key Packageエラーの詳細説明
                    const Text(
                      'Key Packageが変更されたため、グループに参加できません。',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.backup_outlined, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              l10n.ifYouHaveBackup,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.mlsBackupImportInstruction,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              l10n.ifYouDontHaveBackup,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.requestReinviteFromAdmin,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Text(l10n.inviteAcceptanceFailed(e.toString())),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
          },
        );
      }
    }
  }
}

