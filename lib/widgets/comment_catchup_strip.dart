import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';

import '../features/task_comments/presentation/providers/comment_catchup_providers.dart';
import '../presentation/comment_catchup/comment_catchup_screen.dart';
import 'slide_up_route.dart';

/// Non-modal strip shown at the top of the date page when unread task
/// comments exist (issue #219 §2). Same layout as CommentIntroCard, but
/// different semantics: tapping the body opens the catch-up list, and the
/// close button only hides the strip for this foreground session — neither
/// action marks anything read, and nothing here is persisted.
class CommentCatchupStrip extends ConsumerWidget {
  const CommentCatchupStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = ref.watch(totalUnreadCommentCountProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            slideUpRoute<void>(const CommentCatchupScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.commentCatchupStripMessage(count),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.closeButton,
                onPressed: () => ref
                    .read(commentCatchupDismissedProvider.notifier)
                    .dismiss(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
