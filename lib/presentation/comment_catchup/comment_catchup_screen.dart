import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';

import '../../features/task_comments/presentation/providers/author_profile_providers.dart';
import '../../features/task_comments/presentation/providers/comment_catchup_providers.dart';
import '../../features/task_comments/presentation/providers/unread_comment_providers.dart';
import '../../widgets/slide_up_route.dart';
import '../../widgets/todo_edit_screen.dart';

/// The catch-up list opened by tapping CommentCatchupStrip (issue #219
/// §2): every task with an unread comment, newest arrival first. Opening a
/// row's task is what marks it read — viewing this list never does.
class CommentCatchupScreen extends ConsumerWidget {
  const CommentCatchupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(commentCatchupEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.commentCatchupScreenTitle),
        elevation: 0,
        actions: [
          if (entries.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(taskCommentReadMarkerProvider).markAllRead(),
              child: Text(l10n.commentCatchupMarkAllReadButton),
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                l10n.commentCatchupAllCaughtUp,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _CommentCatchupRow(entry: entries[index]),
            ),
    );
  }
}

class _CommentCatchupRow extends ConsumerWidget {
  const _CommentCatchupRow({required this.entry});

  final CommentCatchupEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authorHex = entry.latestComment.authorPubkey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      ref.read(authorLabelsProvider.notifier).ensureLoaded([authorHex]);
    });
    final authorLabel = ref.watch(authorLabelsProvider)[authorHex];
    final author = authorLabel?.displayName ?? authorLabel?.shortNpub ?? '…';

    final todo = entry.todo;
    return ListTile(
      enabled: todo != null,
      title: Text(
        todo?.title ?? l10n.commentCatchupUntitledTask,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$author: ${entry.latestComment.body}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _relativeTime(l10n, entry.latestReceivedAtMillis),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: todo == null
          ? null
          : () {
              Navigator.of(context).push(
                slideUpRoute<void>(
                  TodoEditScreen(todo: todo),
                  fullscreenDialog: true,
                ),
              );
            },
    );
  }
}

/// Relative time for a row's newest unread comment, from the device-local
/// `received_at` (never the author-reported `created_at`, same rule as the
/// unread predicate itself).
String _relativeTime(AppLocalizations l10n, int receivedAtMillis) {
  final then = DateTime.fromMillisecondsSinceEpoch(receivedAtMillis);
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) {
    return l10n.commentCatchupJustNow;
  }
  if (diff.inHours < 1) {
    return l10n.commentCatchupMinutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.commentCatchupHoursAgo(diff.inHours);
  }
  return l10n.commentCatchupDaysAgo(diff.inDays);
}
