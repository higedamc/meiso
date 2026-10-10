import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../features/task_comments/presentation/providers/unread_comment_providers.dart';
import '../l10n/app_localizations.dart';

/// Comment-thread badge on a task tile (issue #219 §1, L3).
///
/// Present whenever the task has a thread, quiet when nothing is unread,
/// emphasised (filled bubble, accent colour, unread count) when something is.
/// Reads [commentThreadSummariesProvider] live — the pubkey is unknown on a
/// cold start, so a value read once in `initState` would be "no unread"
/// forever (spec §10, standing hazard).
class CommentThreadBadge extends ConsumerWidget {
  const CommentThreadBadge({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      commentThreadSummariesProvider.select((summaries) => summaries[taskId]),
    );
    if (summary == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: CommentThreadIndicator(
        visibleCount: summary.visibleCount,
        unreadCount: summary.unreadCount,
      ),
    );
  }
}

/// The badge itself, with no provider dependency so it can be rendered and
/// golden-tested on its own.
///
/// Arrival while the list is on screen (§4): when [unreadCount] grows, the
/// badge fades and scales in once over ~200 ms — no sound, no bounce, no
/// repeat. With reduce-motion on it simply appears. The first build never
/// animates: at app open the badge is state, not an event.
class CommentThreadIndicator extends StatefulWidget {
  const CommentThreadIndicator({
    required this.visibleCount,
    required this.unreadCount,
    super.key,
  });

  /// Non-deleted comments in the thread, any author.
  final int visibleCount;

  /// Non-deleted comments by someone else that arrived after the thread was
  /// last opened on this device.
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  static const Duration arrivalDuration = Duration(milliseconds: 200);

  @override
  State<CommentThreadIndicator> createState() => _CommentThreadIndicatorState();
}

class _CommentThreadIndicatorState extends State<CommentThreadIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: CommentThreadIndicator.arrivalDuration,
    value: 1,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _arrival,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.8,
    end: 1,
  ).animate(_opacity);

  @override
  void didUpdateWidget(CommentThreadIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > oldWidget.unreadCount &&
        !MediaQuery.disableAnimationsOf(context)) {
      _arrival.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUnread = widget.hasUnread;
    final quietColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.6);
    final count = hasUnread ? widget.unreadCount : widget.visibleCount;
    final label = hasUnread
        ? l10n.commentThreadBadgeUnreadLabel(widget.unreadCount)
        : l10n.commentThreadBadgeLabel(widget.visibleCount);

    final badge = Container(
      padding: hasUnread
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : EdgeInsets.zero,
      decoration: hasUnread
          ? BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasUnread ? Icons.chat_bubble : Icons.chat_bubble_outline,
            size: 15,
            color: hasUnread ? AppTheme.primaryColor : quietColor,
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
              color: hasUnread ? AppTheme.primaryColor : quietColor,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(scale: _scale, child: badge),
      ),
    );
  }
}
