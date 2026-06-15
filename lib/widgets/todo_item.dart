import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../providers/todos_provider.dart';
import '../providers/nostr_provider.dart';
import '../services/logger_service.dart';
import 'todo_edit_screen.dart';
import 'circular_checkbox.dart';
import 'remote_image_gate.dart';
import '../features/media/presentation/widgets/image_thumbnail.dart';

/// リカーリングタスクアクションオプション（削除・更新共通）
enum RecurringActionOption {
  thisInstance,   // このインスタンスのみ
  allInstances,   // すべてのインスタンス
  cancel,         // キャンセル
}

/// リカーリングタスクアクション種別
enum RecurringActionType {
  delete,  // 削除
  update,  // 更新
}

/// 個別のTodoアイテムウィジェット
class TodoItem extends StatelessWidget {
  const TodoItem({
    required this.todo,
    this.index,
    super.key,
  });

  final Todo todo;
  final int? index;

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TodoEditScreen(todo: todo),
        fullscreenDialog: true,
      ),
    );
  }

  void _showJsonDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jsonData = {
      'id': todo.id,
      'title': todo.title,
      'completed': todo.completed,
      'date': todo.date?.toIso8601String(),
      'order': todo.order,
      'createdAt': todo.createdAt.toIso8601String(),
      'updatedAt': todo.updatedAt.toIso8601String(),
      'eventId': todo.eventId,
      'localOpId': todo.localOpId,
      'localRelaySyncedAt': todo.localRelaySyncedAt?.toIso8601String(),
      'globalRelaySyncedAt': todo.globalRelaySyncedAt?.toIso8601String(),
      'globalSyncPending': todo.globalSyncPending,
      'globalSyncFailed': todo.globalSyncFailed,
      'needsSync': todo.needsSync,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code, size: 20),
            const SizedBox(width: 8),
            Text(l10n.todoJsonTitle),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.jsonCopied)),
                );
              },
              tooltip: l10n.copyButton,
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
          if (!todo.needsSync && !todo.globalSyncFailed)
            // 同期済み
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final l10n = AppLocalizations.of(context);
                final suffix = todo.globalSyncPending ? ' (global pending)' : '';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l10n.syncedWithEventId(todo.eventId!.substring(0, 8))}$suffix'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                todo.globalSyncPending ? Icons.cloud_queue : Icons.cloud_done,
                size: 16,
              ),
              label: Text(
                todo.globalSyncPending ? 'Local synced / Global pending' : AppLocalizations.of(context).synced,
              ),
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
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.nostrNotInitialized),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
                
                // 全Todoリストをリレーに送信（Kind 30001）
                try {
                  if (context.mounted) {
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.sendingToRelay),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                  
                  // 内部で_syncAllTodosToNostr()を呼び出す
                  await ref.read(todosProvider.notifier).manualSyncToNostr();
                  
                  if (context.mounted) {
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.sentToRelay),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.sendError(e.toString())),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_upload, size: 16),
              label: Text(AppLocalizations.of(context).sendToRelay),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor,
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
                  child: RemoteImageGate(
                    allowed: (context) => Image.network(
                      linkPreview.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 画像読み込み失敗時は非表示
                        return const SizedBox.shrink();
                      },
                    ),
                    // Tor モード時はサムネイル取得を抑止（非表示）
                    blocked: (context) => const SizedBox.shrink(),
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
                            child: RemoteImageGate(
                              allowed: (context) => Image.network(
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
                              // Tor モード時はファビコン取得を抑止し代替アイコン表示
                              blocked: (context) => const Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.grey,
                              ),
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
                            linkPreview.url,
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


  /// URLをブラウザで開く
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppLogger.warning(' Cannot launch URL: $url');
      }
    } catch (e) {
      AppLogger.error(' Failed to open URL: $e');
    }
  }

  /// リカーリングタスクアクション確認ダイアログ（削除・更新共通）
  static Future<RecurringActionOption?> showRecurringActionDialog(
    BuildContext context,
    RecurringActionType actionType,
  ) async {
    return showDialog<RecurringActionOption>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        
        // アクション種別に応じてテキストと色を変更
        final String title;
        final String thisInstanceText;
        final String allInstancesText;
        final Color actionColor;
        
        switch (actionType) {
          case RecurringActionType.delete:
            title = l10n.deleteRecurringTodoTitle;
            thisInstanceText = l10n.removeThisInstance;
            allInstancesText = l10n.removeAllInstances;
            actionColor = Colors.red.shade600;
            break;
          case RecurringActionType.update:
            title = l10n.updateRecurringTodoTitle;
            thisInstanceText = l10n.updateThisInstance;
            allInstancesText = l10n.updateAllInstances;
            actionColor = Colors.blue.shade600;
            break;
        }
        
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
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
              // このインスタンスのみ
              InkWell(
                onTap: () => Navigator.of(context).pop(RecurringActionOption.thisInstance),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Text(
                    thisInstanceText,
                    style: TextStyle(
                      fontSize: 17,
                      color: actionColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              // すべてのインスタンス
              InkWell(
                onTap: () => Navigator.of(context).pop(RecurringActionOption.allInstances),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Text(
                    allInstancesText,
                    style: TextStyle(
                      fontSize: 17,
                      color: actionColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(RecurringActionOption.cancel),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    l10n.cancelButton,
                    style: const TextStyle(
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

  Future<void> _handleTodoToggle(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(todosProvider.notifier);

    // 親タスクを未完了 -> 完了にする場合は、未完了の子タスク確認を出す
    if (!todo.completed && !todo.isSubtask) {
      final subtasks = notifier.getSubtasks(todo.id);
      final hasIncompleteSubtasks = subtasks.any((subtask) => !subtask.completed);

      if (hasIncompleteSubtasks) {
        final shouldCompleteAll = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Complete parent task?'),
            content: Text(
              'This task has ${subtasks.length} subtasks. Completing the parent will also complete all subtasks.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Complete all'),
              ),
            ],
          ),
        );

        if (shouldCompleteAll != true) {
          return;
        }

        await notifier.completeParentAndSubtasks(todo.id);
        return;
      }
    }

    await notifier.toggleTodo(todo.id, todo.date);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Dismissible(
          key: Key(todo.id),
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
            final l10n = AppLocalizations.of(context);
            
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
                  content: Text(l10n.todoMovedToNextDay(todo.title)),
                  duration: const Duration(seconds: 2),
                ),
              );
              
              return true;
            } else {
              // 左スワイプ → 削除
              // リカーリングタスクの場合は確認ダイアログを表示
              if (todo.isRecurring) {
                final result = await TodoItem.showRecurringActionDialog(
                  context,
                  RecurringActionType.delete,
                );
                if (result == RecurringActionOption.thisInstance) {
                  // このインスタンスのみ削除
                  await ref.read(todosProvider.notifier).deleteRecurringInstance(
                    todo.id,
                    todo.date,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.taskDeletedWithTitle(todo.title)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  return false; // Dismissibleをキャンセル（手動で削除済み）
                } else if (result == RecurringActionOption.allInstances) {
                  // すべてのインスタンスを削除
                  await ref.read(todosProvider.notifier).deleteAllRecurringInstances(
                    todo.id,
                    todo.date,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.allInstancesDeleted(todo.title)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  return false; // Dismissibleをキャンセル（手動で削除済み）
                } else {
                  // キャンセル
                  return false;
                }
              } else {
                // Issue #11: 通常のタスク - ソフト削除（UIのみ削除、永続化・同期しない）
                final deletedTodo = todo;
                
                // Issue #11: refとcontextをキャプチャ（SnackBarコールバックで使うため）
                final notifier = ref.read(todosProvider.notifier);
                final messenger = ScaffoldMessenger.of(context);
                
                AppLogger.info('🎯 [UNDO] About to call softDeleteTodo for: ${deletedTodo.title}');
                
                // UIから削除（楽観的UI更新）
                notifier.softDeleteTodo(deletedTodo);
                
                AppLogger.info('🎯 [UNDO] About to call scheduleDeleteConfirmation');
                
                // Issue #11: 3秒後に削除を確定するタイマーを設定
                notifier.scheduleDeleteConfirmation(const Duration(seconds: 3));
                
                AppLogger.info('🎯 [UNDO] scheduleDeleteConfirmation called successfully');
                
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.taskDeletedWithTitle(deletedTodo.title)),
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: l10n.undoButton,
                      textColor: Colors.blue.shade300,
                      onPressed: () {
                        AppLogger.info('🔵 [UNDO] Undo button pressed!');
                        // Issue #11: UNDO（UIのみ復元、永続化・同期しない）
                        notifier.undoDeleteTodo();
                        // SnackBarを即座に閉じる
                        messenger.hideCurrentSnackBar();
                      },
                    ),
                  ),
                );
                
                return false; // Dismissibleによる自動削除を防ぐ（手動で削除済み）
              }
            }
          },
          onDismissed: (direction) async {
            // Issue #11: confirmDismissで手動処理するため、ここは使わない
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showEditDialog(context, ref),
                    onLongPress: () => _showJsonDialog(context, ref),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.0 + (todo.depth * 24.0),
                            right: index != null ? 0 : 16,
                            top: 14,
                            bottom: 14,
                          ),
                          child: Row(
                            children: [
                              CircularCheckbox(
                                value: todo.completed,
                                onChanged: (_) {
                                  _handleTodoToggle(context, ref);
                                },
                                size: 22,
                              ),
                              
                              const SizedBox(width: 12),
                              
                              if (todo.linkPreview == null)
                                Expanded(
                                  child: Text(
                                    todo.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: todo.completed
                                        ? AppTheme.todoTitleCompleted
                                        : AppTheme.todoTitle(context),
                                  ),
                                ),
                              
                              if (todo.imageUrl != null)
                                ImageThumbnail(imageUrl: todo.imageUrl!),

                              // 共有リストで自分以外が追加/編集したタスクを示すアイコン
                              if (todo.editorPubkey != null &&
                                  todo.editorPubkey !=
                                      ref.watch(publicKeyProvider))
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Tooltip(
                                    message: AppLocalizations.of(context)
                                        .addedByCollaborator,
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.75),
                                    ),
                                  ),
                                ),

                              if (!todo.isSubtask)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final notifier = ref.watch(todosProvider.notifier);
                                    final subs = notifier.getSubtasks(todo.id);
                                    if (subs.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final isExpanded =
                                        ref.watch(subtaskExpansionProvider).contains(todo.id);
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () =>
                                            notifier.toggleSubtasksExpanded(todo.id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${subs.length}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color
                                                      ?.withOpacity(0.75),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.keyboard_arrow_right,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withOpacity(0.65),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

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
                        
                        if (todo.linkPreview != null)
                          _buildLinkCard(context, todo.linkPreview!),
                      ],
                    ),
                  ),
                ),
                if (index != null)
                  ReorderableDelayedDragStartListener(
                    index: index!,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

