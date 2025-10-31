import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../providers/todos_provider.dart';
import '../providers/nostr_provider.dart';

/// 個別のTodoアイテムウィジェット
class TodoItem extends StatelessWidget {
  const TodoItem({
    required this.todo,
    super.key,
  });

  final Todo todo;

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: todo.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付表示
              Text(
                todo.date != null 
                    ? DateFormat('EEEE, MMMM d', 'en_US').format(todo.date!).toUpperCase()
                    : 'SOMEDAY',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark 
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              
              // タイトル編集フィールド
              TextField(
                controller: controller,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark 
                          ? AppTheme.darkDivider
                          : AppTheme.lightDivider,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark 
                          ? AppTheme.darkDivider
                          : AppTheme.lightDivider,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                maxLines: null,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    ref.read(todosProvider.notifier).updateTodoTitle(
                      todo.id,
                      todo.date,
                      value,
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              
              const SizedBox(height: 24),
              
              // ボタン行
              Row(
                children: [
                  // MOVE TO ボタン
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Phase2で日付移動ダイアログを実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('日付移動は後で実装します'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          'MOVE TO',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // X (閉じる) ボタン
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // SAVE ボタン（テーマカラーの紫を使用）
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        ref.read(todosProvider.notifier).updateTodoTitle(
                          todo.id,
                          todo.date,
                          controller.text,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'SAVE',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          if (todo.eventId != null)
            // 同期済み
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Event ID: ${todo.eventId}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_done, size: 16),
              label: const Text('リレー送信済み'),
            )
          else
            // 未同期 - 手動送信ボタン
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                
                // Nostr接続チェック
                final nostrService = ref.read(nostrServiceProvider);
                final isInitialized = ref.read(nostrInitializedProvider);
                
                if (!isInitialized) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nostrが初期化されていません。設定画面で接続してください。'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                
                // リレーに送信
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('リレーに送信中...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  
                  final eventId = await nostrService.createTodoOnNostr(todo);
                  
                  // eventIdを設定して更新
                  final updatedTodo = todo.copyWith(eventId: eventId);
                  await ref.read(todosProvider.notifier).updateTodo(updatedTodo);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ リレーに送信しました'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ 送信エラー: $e'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red,
                    ),
                  );
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
      padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
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
              return true;
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
                  color: Theme.of(context).dividerColor,
                  width: 1,
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
                  Row(
                    children: [
                      // チェックボックス
                      Checkbox(
                        value: todo.completed,
                        onChanged: (_) {
                          ref
                              .read(todosProvider.notifier)
                              .toggleTodo(todo.id, todo.date);
                        },
                      ),
                      
                      // タイトル
                      Expanded(
                        child: Text(
                          todo.title,
                          style: todo.completed
                              ? AppTheme.todoTitleCompleted
                              : AppTheme.todoTitle(context),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                    ],
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

