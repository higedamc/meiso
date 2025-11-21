import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../widgets/sync_status_indicator.dart';
import '../list_detail/list_detail_screen.dart';
import '../planning_detail/planning_detail_screen.dart';
// Phase D.5: MLS UseCase統合
import '../../features/mls/application/providers/usecase_providers.dart';
import '../../features/mls/application/usecases/accept_group_invitation_usecase.dart';

/// SOMEDAYページ（リスト管理画面）- モーダル版
class SomedayScreen extends ConsumerWidget {
  const SomedayScreen({
    this.onClose,
    super.key,
  });

  final VoidCallback? onClose;

  /// Pull-to-refreshで同期を実行
  Future<void> _onRefresh(WidgetRef ref) async {
    AppLogger.info(' [SomedayScreen] 🔄 Pull-to-refresh triggered');
    
    // Nostr未初期化の場合はスキップ
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onRefresh: () => _onRefresh(ref),
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
              
              if (onClose != null) {
                onClose!();
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
                  MaterialPageRoute(
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
                MaterialPageRoute(
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
              width: 1,
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
              Icon(
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
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
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
                  style: TextStyle(
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
              width: 1,
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
              Icon(
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
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
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
                  style: TextStyle(
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
    int count = 0;
    int totalTodosInMap = 0;
    int todosWithCustomListId = 0;
    
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
    int count = 0;

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
      // リストを削除
      await ref.read(customListsProvider.notifier).deleteList(list.id);
      
      // そのリストに属する全てのTODOも削除
      final todosNotifier = ref.read(todosProvider.notifier);
      await todosNotifier.deleteAllTodosInList(list.id);
    }
  }

  /// リスト追加画面を表示（通常リストorグループリスト）
  void _showAddListScreen(BuildContext context, WidgetRef ref) {
    showDialog(
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
                    MaterialPageRoute(
                      builder: (context) => const AddListScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              const Divider(),
              // グループリスト（ステージング版では無効化）
              ListTile(
                // leading: const Icon(Icons.group),
                // title: const Text('Group List'),
                // subtitle: const Text('共有可能なグループタスクリスト'),
                // onTap: () {
                //   Navigator.pop(context);
                //   showDialog(
                //     context: context,
                //     builder: (context) => const AddGroupListDialog(),
                //   );
                // },

                leading: Icon(Icons.group, color: Colors.grey.shade400),
                title: Text('Group List', style: TextStyle(color: Colors.grey.shade400)),
                subtitle: Text('共有可能なグループタスクリスト（開発中）', style: TextStyle(color: Colors.grey.shade400)),
                enabled: false,
                onTap: null,
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
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: Row(
            children: [
              Icon(
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
                '${list.name}',
                style: TextStyle(
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
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
    bool isLoadingDialogShown = false;
    
    try {
      AppLogger.info('🎉 [GroupInvitation] Accepting invitation for: ${list.name}');
      
      // ローディングインジケータを表示（rootNavigator使用で安定性向上）
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true, // アプリのライフサイクルに影響されない
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
            isPendingInvitation: false,
            inviterNpub: null,
            inviterName: null,
            welcomeMsg: null,
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
                duration: const Duration(seconds: 4),
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
      
      // エラーメッセージ
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('エラー'),
            content: Text('招待の受諾に失敗しました\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

