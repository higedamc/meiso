import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../providers/todos_provider.dart';
import '../providers/nostr_provider.dart';
import 'todo_edit_screen.dart';
import 'circular_checkbox.dart';

/// リカーリングタスク削除オプション
enum RecurringDeleteOption {
  thisInstance,   // このインスタンスのみ削除
  allInstances,   // すべてのインスタンスを削除
  cancel,         // キャンセル
}

/// 個別のTodoアイテムウィジェット
class TodoItem extends StatelessWidget {
  const TodoItem({
    required this.todo,
    super.key,
  });

  final Todo todo;

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TodoEditScreen(todo: todo),
        fullscreenDialog: true,
      ),
    );
  }

  void _showJsonDialog(BuildContext context, WidgetRef ref) {
    final jsonData = {
      'id': todo.id,
      'title': todo.title,
      'completed': todo.completed,
      'date': todo.date?.toIso8601String(),
      'order': todo.order,
      'createdAt': todo.createdAt.toIso8601String(),
      'updatedAt': todo.updatedAt.toIso8601String(),
      'eventId': todo.eventId,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code, size: 20),
            const SizedBox(width: 8),
            const Text('Todo JSON'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSONをコピーしました')),
                );
              },
              tooltip: 'コピー',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonString,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          // Kind 30001実装: needsSyncフラグで同期状態を判定
          if (!todo.needsSync)
            // 同期済み
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(todo.eventId != null 
                      ? '同期済み (Event ID: ${todo.eventId!.substring(0, 8)}...)'
                      : '同期済み'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_done, size: 16),
              label: const Text('同期済み'),
            )
          else
            // 未同期 - 手動送信ボタン（全Todoリストを再送信）
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                
                // Nostr接続チェック
                final isInitialized = ref.read(nostrInitializedProvider);
                
                if (!isInitialized) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nostrが初期化されていません。設定画面で接続してください。'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
                
                // 全Todoリストをリレーに送信（Kind 30001）
                try {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('リレーに送信中...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  
                  // 内部で_syncAllTodosToNostr()を呼び出す
                  await ref.read(todosProvider.notifier).manualSyncToNostr();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ リレーに送信しました'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ 送信エラー: $e'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_upload, size: 16),
              label: const Text('リレーに送信する'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// リンクカードウィジェット
  Widget _buildLinkCard(BuildContext context, LinkPreview linkPreview) {
    return Padding(
      padding: const EdgeInsets.only(left: 50, right: 16, bottom: 12),
      child: InkWell(
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

  /// リカーリングタスク削除確認ダイアログ
  Future<RecurringDeleteOption?> _showRecurringDeleteDialog(BuildContext context) async {
    return showDialog<RecurringDeleteOption>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Delete recurring to-do',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
          contentPadding: EdgeInsets.zero,
          actionsPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // このインスタンスを削除
              InkWell(
                onTap: () => Navigator.of(context).pop(RecurringDeleteOption.thisInstance),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Text(
                    'Remove this instance',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.red.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              // すべてのインスタンスを削除
              InkWell(
                onTap: () => Navigator.of(context).pop(RecurringDeleteOption.allInstances),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Text(
                    'Remove all instances',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(RecurringDeleteOption.cancel),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Dismissible(
          key: Key(todo.id),
          direction: DismissDirection.horizontal,
          // 右スワイプ時の背景（明日に移動）
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            color: Colors.blue.shade100,
            child: Icon(
              Icons.arrow_forward,
              color: Colors.blue.shade700,
            ),
          ),
          // 左スワイプ時の背景（削除）
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red.shade100,
            child: Icon(
              Icons.delete_outline,
              color: Colors.red.shade700,
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // 右スワイプ → 明日に移動
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = today.add(const Duration(days: 1));
              
              // 現在の日付から明日の日付を計算
              final targetDate = todo.date == null 
                  ? tomorrow 
                  : todo.date!.add(const Duration(days: 1));
              
              await ref.read(todosProvider.notifier).moveTodo(
                todo.id,
                todo.date,
                targetDate,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「${todo.title}」を翌日に移動しました'),
                  duration: const Duration(seconds: 2),
                ),
              );
              
              return true;
            } else {
              // 左スワイプ → 削除
              // リカーリングタスクの場合は確認ダイアログを表示
              if (todo.isRecurring) {
                final result = await _showRecurringDeleteDialog(context);
                if (result == RecurringDeleteOption.thisInstance) {
                  // このインスタンスのみ削除
                  await ref.read(todosProvider.notifier).deleteRecurringInstance(
                    todo.id,
                    todo.date,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('「${todo.title}」を削除しました'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  return false; // Dismissibleをキャンセル（手動で削除済み）
                } else if (result == RecurringDeleteOption.allInstances) {
                  // すべてのインスタンスを削除
                  await ref.read(todosProvider.notifier).deleteAllRecurringInstances(
                    todo.id,
                    todo.date,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('「${todo.title}」のすべてのインスタンスを削除しました'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  return false; // Dismissibleをキャンセル（手動で削除済み）
                } else {
                  // キャンセル
                  return false;
                }
              } else {
                // 通常のタスクはそのまま削除
                return true;
              }
            }
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              // 左スワイプの場合のみ削除
              // 削除前にTodoを保持（元に戻す用）
              final deletedTodo = todo;
              
              ref.read(todosProvider.notifier).deleteTodo(todo.id, todo.date);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「${todo.title}」を削除しました'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: '元に戻す',
                    textColor: Colors.blue.shade300,
                    onPressed: () {
                      // 削除をキャンセルしてTodoを復元
                      ref.read(todosProvider.notifier).addTodoWithData(deletedTodo);
                    },
                  ),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: InkWell(
              onTap: () => _showEditDialog(context, ref),
              onLongPress: () => _showJsonDialog(context, ref),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Todo タイトル行
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 14.0,
                    ),
                    child: Row(
                      children: [
                        // 円形チェックボックス
                        CircularCheckbox(
                          value: todo.completed,
                          onChanged: (_) {
                            ref
                                .read(todosProvider.notifier)
                                .toggleTodo(todo.id, todo.date);
                          },
                          size: 22.0,
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // タイトル
                        Expanded(
                          child: Text(
                            todo.title,
                            style: todo.completed
                                ? AppTheme.todoTitleCompleted
                                : AppTheme.todoTitle(context),
                          ),
                        ),
                        
                        // リカーリングタスクのマーカー
                        if (todo.isRecurring)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.repeat,
                              size: 18,
                              color: AppTheme.primaryPurple.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // リンクカード（URLが検出された場合）
                  if (todo.linkPreview != null)
                    _buildLinkCard(context, todo.linkPreview!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

