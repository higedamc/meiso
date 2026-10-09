import 'task_comment.dart';

/// A [TaskComment] as it sits in the local store, together with the
/// device-local receipt stamp the store attached when it applied the event.
///
/// [receivedAtMillis] is **this device's** clock at the moment the comment
/// was upserted (issue #218). It is what the unread computation compares
/// against, never the author-reported `created_at` inside the payload: a
/// skewed or hostile author clock would otherwise either pin a badge on
/// forever or, once read, push the read watermark into the future so later
/// genuine comments count as read.
///
/// `null` means the entry was written before the stamp existed (pre-#218
/// store). Such entries are treated as already read so that upgrading does
/// not light up every old thread.
class TaskCommentRecord {
  const TaskCommentRecord({required this.comment, this.receivedAtMillis});

  final TaskComment comment;

  /// Local receipt time (unix ms), or null for pre-upgrade entries.
  final int? receivedAtMillis;
}
