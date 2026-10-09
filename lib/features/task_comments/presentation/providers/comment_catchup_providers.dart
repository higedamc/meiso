import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/todo.dart';
import '../../../../providers/app_lifecycle_provider.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../providers/todos_provider.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/entities/task_comment_record.dart';
import 'unread_comment_providers.dart';

/// One row of the catch-up list (issue #219 §2): a task with at least one
/// unread comment, the comment that most recently arrived on this device,
/// and the resolved [Todo] when the local store still has it (a task can be
/// deleted locally after a comment on it arrives).
class CommentCatchupEntry {
  const CommentCatchupEntry({
    required this.taskId,
    required this.unreadCount,
    required this.latestComment,
    required this.latestReceivedAtMillis,
    this.todo,
  });

  final String taskId;
  final int unreadCount;
  final TaskComment latestComment;

  /// Device-local receipt time of [latestComment] — the same clock the
  /// unread predicate compares, never the author-reported `created_at`
  /// (see [isUnreadCommentRecord]), so the list orders the same way the
  /// unread/read split does.
  final int latestReceivedAtMillis;

  final Todo? todo;
}

/// taskId -> every task with at least one unread comment, newest arrival
/// first. Built from the same records, watermarks and predicate
/// [commentThreadSummariesProvider] uses, so a row's count always matches
/// the badge count for that task, and nothing here contradicts the "before
/// the own pubkey is known nothing is unread" fail-closed rule.
final commentCatchupEntriesProvider = Provider<List<CommentCatchupEntry>>((
  ref,
) {
  final records =
      ref.watch(taskCommentRecordsProvider).valueOrNull ??
      const <String, List<TaskCommentRecord>>{};
  final watermarks =
      ref.watch(taskCommentWatermarksProvider).valueOrNull ??
      const <String, int>{};
  final myPubkey = ref.watch(publicKeyProvider);

  final todosById = <String, Todo>{};
  final todosState = ref.watch(todosProvider).valueOrNull;
  if (todosState != null) {
    for (final group in todosState.values) {
      for (final todo in group) {
        todosById[todo.id] = todo;
      }
    }
  }

  final entries = <CommentCatchupEntry>[];
  records.forEach((taskId, thread) {
    final watermark = watermarks[taskId];
    TaskCommentRecord? latestUnread;
    var unreadCount = 0;
    for (final record in thread) {
      if (!isUnreadCommentRecord(
        record,
        watermark: watermark,
        myPubkey: myPubkey,
      )) {
        continue;
      }
      unreadCount++;
      final receivedAt = record.receivedAtMillis ?? 0;
      if (latestUnread == null ||
          receivedAt > (latestUnread.receivedAtMillis ?? 0)) {
        latestUnread = record;
      }
    }
    final latest = latestUnread;
    if (latest != null) {
      entries.add(
        CommentCatchupEntry(
          taskId: taskId,
          unreadCount: unreadCount,
          latestComment: latest.comment,
          latestReceivedAtMillis: latest.receivedAtMillis ?? 0,
          todo: todosById[taskId],
        ),
      );
    }
  });
  entries.sort(
    (a, b) => b.latestReceivedAtMillis.compareTo(a.latestReceivedAtMillis),
  );
  return entries;
});

/// Total unread comments across every task, for the catch-up strip's "N new
/// comments" message and its show/hide condition.
final totalUnreadCommentCountProvider = Provider<int>((ref) {
  final counts = ref.watch(unreadCommentCountsProvider);
  return counts.values.fold<int>(0, (sum, count) => sum + count);
});

/// Session-only dismiss flag for the catch-up strip (issue #219 §2).
/// Dismissing never marks anything read — it only hides the strip for the
/// rest of this foreground session. A resume counts as a new session and
/// re-arms it, matching "the strip shows at app launch and resume".
class CommentCatchupDismissalNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<AppLifecycleState>(appLifecycleProvider, (previous, next) {
      if (next == AppLifecycleState.resumed) {
        state = false;
      }
    });
    return false;
  }

  void dismiss() => state = true;
}

final commentCatchupDismissedProvider =
    NotifierProvider<CommentCatchupDismissalNotifier, bool>(
      CommentCatchupDismissalNotifier.new,
    );

/// The catch-up strip's count for this session (issue #219 §2: "don't
/// interrupt while the user is working — only show at launch and resume").
///
/// Unlike badges/dots, the strip must not pop up or grow mid-session just
/// because a comment arrived while the app is in use — that shifts the task
/// list under a finger mid-tap. So this is not a live watch of
/// [totalUnreadCommentCountProvider]: it latches the total the first moment
/// unread is actually readable (own pubkey known, comment records loaded)
/// after launch or resume, and ignores everything that arrives after, until
/// the next resume re-arms it.
///
/// "Readable" has the same two preconditions as the cold-start fail-closed
/// rule everywhere else in this feature: capturing before either is true
/// would always latch onto 0 and the strip would never show.
class CommentCatchupArmedCountNotifier extends Notifier<int?> {
  bool _armed = false;

  @override
  int? build() {
    ref.listen<AppLifecycleState>(appLifecycleProvider, (previous, next) {
      if (next == AppLifecycleState.resumed) {
        _armed = false;
        state = null;
        _tryArm();
      }
    });
    ref.listen<String?>(publicKeyProvider, (previous, next) => _tryArm());
    ref.listen(taskCommentRecordsProvider, (previous, next) => _tryArm());

    return _readyTotal();
  }

  void _tryArm() {
    if (_armed) {
      return;
    }
    final total = _readyTotal();
    if (total == null) {
      return;
    }
    state = total;
  }

  /// The current total, or null when unread is not yet readable. Marks
  /// [_armed] as a side effect once readable, so a later call — from [build]
  /// returning this directly, or from [_tryArm] — latches at most once per
  /// arm cycle.
  int? _readyTotal() {
    final myPubkey = ref.read(publicKeyProvider);
    final records = ref.read(taskCommentRecordsProvider).valueOrNull;
    if (myPubkey == null || records == null) {
      return null;
    }
    _armed = true;
    return ref.read(totalUnreadCommentCountProvider);
  }
}

final commentCatchupArmedCountProvider =
    NotifierProvider<CommentCatchupArmedCountNotifier, int?>(
      CommentCatchupArmedCountNotifier.new,
    );

/// Whether the catch-up strip should be visible right now. Watches
/// [commentCatchupArmedCountProvider] rather than the live
/// [totalUnreadCommentCountProvider] — see that provider's doc for why.
final shouldShowCommentCatchupStripProvider = Provider<bool>((ref) {
  final armed = ref.watch(commentCatchupArmedCountProvider) ?? 0;
  final dismissed = ref.watch(commentCatchupDismissedProvider);
  return armed > 0 && !dismissed;
});
