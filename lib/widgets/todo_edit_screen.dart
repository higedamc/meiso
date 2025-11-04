import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../providers/todos_provider.dart';
import '../providers/custom_lists_provider.dart';

/// Todo追加/編集用の全画面モーダル
class TodoEditScreen extends ConsumerStatefulWidget {
  const TodoEditScreen({
    this.todo,
    this.date,
    this.customListId,
    this.customListName,
    super.key,
  });

  final Todo? todo;
  final DateTime? date;
  final String? customListId;
  final String? customListName;

  @override
  ConsumerState<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends ConsumerState<TodoEditScreen> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  RecurrencePattern? _recurrence;

  bool get isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.todo?.title ?? '');
    _focusNode = FocusNode();
    _recurrence = widget.todo?.recurrence;

    // 次のフレームでフォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ヘッダー（日付 + ×ボタン）
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 12,
              top: statusBarHeight + 12,
              bottom: 16,
            ),
            color: theme.cardTheme.color,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 日付表示
                Text(
                  _getDateLabel(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                // ×ボタン
                IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // テキストフィールド + リンクカード
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // テキストフィールド
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : AppTheme.lightTextSecondary.withOpacity(0.5),
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  
                  // リンクカード（編集モード時のみ表示）
                  if (isEditing && widget.todo?.linkPreview != null) ...[
                    const SizedBox(height: 16),
                    _buildLinkCard(widget.todo!.linkPreview!),
                  ],
                ],
              ),
            ),
          ),

          // 底部ボタンエリア
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左側: MOVE TO（編集時のみ）
                if (isEditing)
                  TextButton(
                    onPressed: _showMoveToDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'MOVE TO',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // 右側: SAVE
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'SAVE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 日付ラベルを取得
  String _getDateLabel() {
    // カスタムリストの場合はリスト名を表示
    if (widget.customListName != null) {
      return widget.customListName!;
    }

    final currentDate = widget.todo?.date ?? widget.date;
    
    if (currentDate == null) {
      return 'SOMEDAY';
    }

    return DateFormat('EEEE, MMMM d', 'en_US')
        .format(currentDate)
        .toUpperCase();
  }

  /// MOVE TOダイアログを表示
  Future<void> _showMoveToDialog() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MOVE TO'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TODAY
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('TODAY'),
              onTap: () => Navigator.pop(context, today),
            ),
            // TOMORROW
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('TOMORROW'),
              onTap: () => Navigator.pop(context, tomorrow),
            ),
            // SOMEDAY LIST（サブメニューを表示）
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('SOMEDAY LIST'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                _showSomedayListDialog();
              },
            ),
            const Divider(),
            // Another day（日付選択）
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Another day'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: widget.todo?.date ?? today,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (selectedDate != null && mounted) {
                  _moveToDate(selectedDate);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      if (result == 'someday') {
        _moveToDate(null);
      } else if (result is DateTime) {
        _moveToDate(result);
      }
    }
  }

  /// SOMEDAY LISTのサブメニューを表示
  Future<void> _showSomedayListDialog() async {
    final customListsAsync = ref.read(customListsProvider);

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => customListsAsync.when(
        data: (customLists) => AlertDialog(
          title: const Text('MOVE TO → SOMEDAY LIST'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Someday (no list)
                ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('Someday (no list)'),
                  subtitle: const Text('No specific date or list'),
                  onTap: () => Navigator.pop(context, {'type': 'someday'}),
                ),
                const Divider(),
                // カスタムリスト一覧
                ...customLists.map((customList) {
                  return ListTile(
                    leading: const Icon(Icons.list),
                    title: Text(customList.name),
                    onTap: () => Navigator.pop(context, {
                      'type': 'customList',
                      'listId': customList.id,
                      'listName': customList.name,
                    }),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK'),
            ),
          ],
        ),
        loading: () => const AlertDialog(
          title: Text('MOVE TO → SOMEDAY LIST'),
          content: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to load custom lists'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      if (result is Map) {
        if (result['type'] == 'someday') {
          // Someday (no list) - 日付なし、リストなし
          _moveToDateAndList(null, null);
        } else if (result['type'] == 'customList') {
          // カスタムリストに移動（日付はnull）
          _moveToDateAndList(null, result['listId'] as String?, result['listName'] as String?);
        }
      }
    }
  }

  /// Todoを指定した日付に移動
  void _moveToDate(DateTime? targetDate) {
    if (widget.todo == null) return;

    ref.read(todosProvider.notifier).moveTodo(
      widget.todo!.id,
      widget.todo!.date,
      targetDate,
    );

    // 画面を閉じる
    Navigator.pop(context);

    // フィードバック
    final dateLabel = targetDate == null
        ? 'SOMEDAY'
        : DateFormat('EEEE, MMMM d', 'en_US').format(targetDate).toUpperCase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved to $dateLabel'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Todoを指定した日付とカスタムリストに移動
  void _moveToDateAndList(DateTime? targetDate, String? customListId, [String? customListName]) {
    if (widget.todo == null) return;

    // 日付を移動
    ref.read(todosProvider.notifier).moveTodo(
      widget.todo!.id,
      widget.todo!.date,
      targetDate,
    );

    // カスタムリストIDを更新
    ref.read(todosProvider.notifier).updateTodoCustomListId(
      widget.todo!.id,
      targetDate,  // 移動後の日付
      customListId,
    );

    // 画面を閉じる
    Navigator.pop(context);

    // フィードバック
    final label = customListName ?? (targetDate == null ? 'SOMEDAY' : DateFormat('EEEE, MMMM d', 'en_US').format(targetDate).toUpperCase());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved to $label'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 保存処理
  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (isEditing) {
      // 編集モード: タイトルと繰り返しパターンを更新
      print('📝 Updating todo: "$text" (id: ${widget.todo!.id})');
      await ref.read(todosProvider.notifier).updateTodoWithRecurrence(
        widget.todo!.id,
        widget.todo!.date,
        text,
        _recurrence,
      );
      print('✅ Todo update completed and synced');
    } else {
      // 追加モード: 新しいTodoを作成
      print('📝 Adding todo to list: "$text" (customListId: ${widget.customListId})');
      await ref.read(todosProvider.notifier).addTodo(
        text,
        widget.date,
        customListId: widget.customListId,
      );
      print('✅ Todo added and synced to Nostr');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// リンクカードウィジェット（削除ボタン付き）
  Widget _buildLinkCard(LinkPreview linkPreview) {
    return Stack(
      children: [
        // リンクカード本体
        InkWell(
          onTap: () => _openUrl(linkPreview.url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // サムネイル画像
                if (linkPreview.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: Image.network(
                      linkPreview.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 画像読み込み失敗時は非表示
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                
                // タイトル・説明・URL
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル + ファビコン
                      Row(
                        children: [
                          // ファビコン
                          if (linkPreview.faviconUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Image.network(
                                linkPreview.faviconUrl!,
                                width: 16,
                                height: 16,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.link,
                                    size: 16,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            ),
                          
                          // タイトル
                          Expanded(
                            child: Text(
                              linkPreview.title ?? linkPreview.url,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // 説明文
                      if (linkPreview.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          linkPreview.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // URL
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _extractDomain(linkPreview.url),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 削除ボタン（左上）
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _removeLinkPreview,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// URLからドメイン名を抽出
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  /// URLをブラウザで開く
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL: $url');
      }
    } catch (e) {
      print('❌ Failed to open URL: $e');
    }
  }

  /// リンクプレビューを削除
  Future<void> _removeLinkPreview() async {
    if (widget.todo == null) return;

    await ref.read(todosProvider.notifier).removeLinkPreview(
      widget.todo!.id,
      widget.todo!.date,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('リンクカードを削除しました'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

