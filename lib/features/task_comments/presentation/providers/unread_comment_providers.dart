import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/nostr_provider.dart';
import '../../domain/entities/task_comment_record.dart';
import '../../infrastructure/datasources/task_comment_read_state_datasource.dart';
import '../../infrastructure/providers/read_state_providers.dart';
import '../../infrastructure/providers/repository_providers.dart';

/// What a task tile needs to know about its comment thread (issue #218).
class CommentThreadSummary {
  const CommentThreadSummary({
    required this.visibleCount,
    required this.unreadCount,
  });

  /// Non-deleted comments in the thread, any author.
  final int visibleCount;

  /// Non-deleted comments by someone else that arrived on this device after
  /// the thread was last opened here.
  final int unreadCount;

  bool get hasThread => visibleCount > 0;
  bool get hasUnread => unreadCount > 0;
}

/// Every stored thread with receipt stamps. App-wide: not autoDispose, so the
/// box stream stays open once the home screen has watched it.
final taskCommentRecordsProvider =
    StreamProvider<Map<String, List<TaskCommentRecord>>>((ref) {
      return ref.watch(taskCommentLocalDataSourceProvider).watchAllRecords();
    });

/// task_id -> read watermark (unix ms, local clock).
final taskCommentWatermarksProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(taskCommentReadStateDataSourceProvider).watchWatermarks();
});

/// task_id -> [CommentThreadSummary] for every task that has at least one
/// stored comment (tombstone-only threads are omitted).
///
/// Unread rules (issue #218, fixed by design — change them in the issue
/// first):
/// - compare the entry's device-local `received_at` with the device-local
///   watermark; the author's `created_at` is never consulted;
/// - entries without a stamp (written before the upgrade) are read;
/// - own comments are never unread; while the own pubkey is still unknown
///   (before the session is restored) nothing is unread, so a cold start
///   cannot flash badges on threads the user wrote themselves;
/// - tombstones count for neither number.
final commentThreadSummariesProvider =
    Provider<Map<String, CommentThreadSummary>>((ref) {
      final records =
          ref.watch(taskCommentRecordsProvider).valueOrNull ??
          const <String, List<TaskCommentRecord>>{};
      final watermarks =
          ref.watch(taskCommentWatermarksProvider).valueOrNull ??
          const <String, int>{};
      final myPubkey = ref.watch(publicKeyProvider);

      final summaries = <String, CommentThreadSummary>{};
      records.forEach((taskId, thread) {
        final watermark = watermarks[taskId];
        var visible = 0;
        var unread = 0;
        for (final record in thread) {
          final comment = record.comment;
          if (comment.deleted) {
            continue;
          }
          visible++;
          if (isUnreadCommentRecord(
            record,
            watermark: watermark,
            myPubkey: myPubkey,
          )) {
            unread++;
          }
        }
        if (visible > 0) {
          summaries[taskId] = CommentThreadSummary(
            visibleCount: visible,
            unreadCount: unread,
          );
        }
      });
      return summaries;
    });

/// task_id -> unread count, only for tasks with something unread.
final unreadCommentCountsProvider = Provider<Map<String, int>>((ref) {
  final summaries = ref.watch(commentThreadSummariesProvider);
  return {
    for (final entry in summaries.entries)
      if (entry.value.hasUnread) entry.key: entry.value.unreadCount,
  };
});

/// The one place the unread predicate is written down.
bool isUnreadCommentRecord(
  TaskCommentRecord record, {
  required int? watermark,
  required String? myPubkey,
}) {
  if (record.comment.deleted) {
    return false;
  }
  final receivedAt = record.receivedAtMillis;
  if (receivedAt == null) {
    // Pre-upgrade entry: no stamp, treated as read.
    return false;
  }
  if (myPubkey == null || record.comment.authorPubkey == myPubkey) {
    return false;
  }
  return watermark == null || receivedAt > watermark;
}

/// Marks a thread read. L3 calls [TaskCommentReadMarker.markRead] when the
/// thread opens and again whenever its comment list changes while open.
final taskCommentReadMarkerProvider = Provider<TaskCommentReadMarker>((ref) {
  return TaskCommentReadMarker(
    loadRecords: ref.watch(taskCommentLocalDataSourceProvider).loadRecords,
    readState: ref.watch(taskCommentReadStateDataSourceProvider),
  );
});

class TaskCommentReadMarker {
  TaskCommentReadMarker({
    required Future<List<TaskCommentRecord>> Function(String taskId)
    loadRecords,
    required TaskCommentReadStateDataSource readState,
  }) : _loadRecords = loadRecords,
       _readState = readState;

  final Future<List<TaskCommentRecord>> Function(String taskId) _loadRecords;
  final TaskCommentReadStateDataSource _readState;

  /// Advances the watermark of [taskId] to the latest `received_at` the
  /// store currently holds for it. Taking the stamp from the store rather
  /// than `DateTime.now()` keeps the two sides of the comparison on exactly
  /// the values that were written, so a wall-clock step between receipt and
  /// read cannot leave a comment stranded on either side. No-op when the
  /// thread has no stamped entries.
  Future<void> markRead(String taskId) async {
    final records = await _loadRecords(taskId);
    int? latest;
    for (final record in records) {
      final stamp = record.receivedAtMillis;
      if (stamp != null && (latest == null || stamp > latest)) {
        latest = stamp;
      }
    }
    if (latest == null) {
      return;
    }
    await _readState.markRead(taskId: taskId, receivedAtMillis: latest);
  }
}
