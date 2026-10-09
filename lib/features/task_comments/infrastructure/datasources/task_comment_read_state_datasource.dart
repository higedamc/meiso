import 'package:hive_flutter/hive_flutter.dart';

import 'hive_box_snapshot_stream.dart';

/// Device-local "last read" watermark per task thread (issue #218).
///
/// The watermark is a `received_at` value (unix ms, this device's clock):
/// every stored comment whose own `received_at` is later than the watermark
/// is unread. Both sides of the comparison come from the same local clock,
/// so the author-reported `created_at` never enters the computation.
///
/// **This state is never published.** A read receipt on relays would hand
/// them exactly the per-task metadata the task-chat design withholds (which
/// task a comment belongs to, how active it is, who is reading it). The
/// documented consequence is that clearing the mark on one device does not
/// clear it on another.
abstract class TaskCommentReadStateDataSource {
  /// task_id -> watermark (unix ms). Emits the full map once on subscribe
  /// and again after any change.
  Stream<Map<String, int>> watchWatermarks();

  /// task_id -> watermark (unix ms).
  Future<Map<String, int>> loadWatermarks();

  /// Records that everything received up to and including [receivedAtMillis]
  /// has been seen for [taskId]. Only ever moves the watermark forward; a
  /// stale call cannot un-read a thread.
  Future<void> markRead({
    required String taskId,
    required int receivedAtMillis,
  });

  /// [markRead] for many threads in one write: `task_id -> received_at`.
  /// Entries that would move a watermark backwards are dropped, so this has
  /// the same forward-only guarantee as the single-thread call.
  Future<void> markReadAll(Map<String, int> watermarks);

  /// Closes the box and deletes its file (logout). Mirrors
  /// `TaskCommentLocalDataSourceHive.wipe`.
  Future<void> wipe();
}

/// Hive implementation. Box `task_comment_read_state`: task_id -> int (ms).
class TaskCommentReadStateDataSourceHive
    implements TaskCommentReadStateDataSource {
  TaskCommentReadStateDataSourceHive({Box<int>? box}) : _box = box;

  /// Hive Box 名
  static const String boxName = 'task_comment_read_state';

  Box<int>? _box;

  Future<Box<int>> _openBox() async {
    return _box ??= await Hive.openBox<int>(boxName);
  }

  @override
  Stream<Map<String, int>> watchWatermarks() {
    return watchBoxSnapshot(openBox: _openBox, read: _readAll);
  }

  @override
  Future<Map<String, int>> loadWatermarks() async {
    final box = await _openBox();
    return _readAll(box);
  }

  @override
  Future<void> markRead({
    required String taskId,
    required int receivedAtMillis,
  }) async {
    final box = await _openBox();
    final current = box.get(taskId);
    if (current != null && current >= receivedAtMillis) {
      return;
    }
    await box.put(taskId, receivedAtMillis);
  }

  @override
  Future<void> markReadAll(Map<String, int> watermarks) async {
    final box = await _openBox();
    final forward = <String, int>{};
    watermarks.forEach((taskId, receivedAtMillis) {
      final current = box.get(taskId);
      if (current == null || current < receivedAtMillis) {
        forward[taskId] = receivedAtMillis;
      }
    });
    if (forward.isEmpty) {
      return;
    }
    await box.putAll(forward);
  }

  /// Box を閉じる(テスト用)
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  @override
  Future<void> wipe() async {
    final box = _box;
    _box = null;
    var name = boxName;
    if (box != null && box.isOpen) {
      name = box.name;
      await box.close();
    } else if (Hive.isBoxOpen(boxName)) {
      // Same guard as the comment box: a box left open by another instance
      // must be closed before deleteBoxFromDisk, or the delete can fail.
      await Hive.box<int>(boxName).close();
    }
    await Hive.deleteBoxFromDisk(name);
  }

  Map<String, int> _readAll(Box<int> box) {
    final result = <String, int>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        result[key.toString()] = value;
      }
    }
    return result;
  }
}
