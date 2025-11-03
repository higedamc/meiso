import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/recurrence_pattern.dart';
import '../providers/todos_provider.dart';

/// Todo追加/編集用の全画面モーダル
class TodoEditScreen extends ConsumerStatefulWidget {
  const TodoEditScreen({
    this.todo,
    this.date,
    super.key,
  });

  final Todo? todo;
  final DateTime? date;

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

          // テキストフィールド
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TextField(
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
            // SOMEDAY
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('SOMEDAY'),
              onTap: () => Navigator.pop(context, 'someday'),
            ),
            const Divider(),
            // Pick a date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Pick a date...'),
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

  /// 保存処理
  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (isEditing) {
      // 編集モード: タイトルと繰り返しパターンを更新
      ref.read(todosProvider.notifier).updateTodoWithRecurrence(
        widget.todo!.id,
        widget.todo!.date,
        text,
        _recurrence,
      );
    } else {
      // 追加モード: 新しいTodoを作成
      ref.read(todosProvider.notifier).addTodo(text, widget.date);
    }

    Navigator.pop(context);
  }
}

