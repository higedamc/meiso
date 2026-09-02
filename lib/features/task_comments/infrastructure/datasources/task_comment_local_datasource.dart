import 'package:hive_flutter/hive_flutter.dart';

import '../../../../services/logger_service.dart';
import '../../domain/entities/task_comment.dart';

/// タスクコメントのローカル永続化データソース契約
///
/// 復号済みコメントを task_id をキーに保持する。tombstone
/// (`deleted: true`, body 空)もそのまま保存し、UI 側で非表示にする。
abstract class TaskCommentLocalDataSource {
  /// タスクのコメント一覧を監視する(payload の created_at 昇順)。
  Stream<List<TaskComment>> watchComments(String taskId);

  /// タスクのコメント一覧を読み込む(payload の created_at 昇順)。
  Future<List<TaskComment>> loadComments(String taskId);

  /// LWW upsert。イベントの created_at 昇順(同秒は event_id 辞書順)で
  /// 「後勝ち」となるよう、保存済みエントリより新しい場合のみ適用する
  /// (shared-v1 todos の issue #138 R1/R2 と同じ規則)。
  ///
  /// 適用した場合 true、古い/重複イベントとしてスキップした場合 false。
  Future<bool> upsert({
    required TaskComment comment,
    required int eventCreatedAt,
    required String eventId,
  });

  /// Box を閉じて物理ファイルごと削除する(ログアウト用)。
  ///
  /// `Box.clear()` は append-only な Hive フレームを論理クリアする
  /// だけで `.hive` ファイルに旧データのバイト列が残るため、
  /// `LocalStorageService.clearAllData()` と同じく物理削除する。
  Future<void> wipe();
}

/// Hive 実装
///
/// Box 構造: `task_comments` Box に task_id をキーとして
/// `{ comment_id: { payload, event_created_at, event_id } }` を保存する。
class TaskCommentLocalDataSourceHive implements TaskCommentLocalDataSource {
  TaskCommentLocalDataSourceHive({Box<Map<dynamic, dynamic>>? box})
    : _box = box;

  /// Hive Box 名
  static const String boxName = 'task_comments';

  Box<Map<dynamic, dynamic>>? _box;

  Future<Box<Map<dynamic, dynamic>>> _openBox() async {
    return _box ??= await Hive.openBox<Map<dynamic, dynamic>>(boxName);
  }

  @override
  Stream<List<TaskComment>> watchComments(String taskId) async* {
    final box = await _openBox();
    yield _readComments(box, taskId);
    await for (final _ in box.watch(key: taskId)) {
      yield _readComments(box, taskId);
    }
  }

  @override
  Future<List<TaskComment>> loadComments(String taskId) async {
    final box = await _openBox();
    return _readComments(box, taskId);
  }

  @override
  Future<bool> upsert({
    required TaskComment comment,
    required int eventCreatedAt,
    required String eventId,
  }) async {
    final box = await _openBox();
    final entries = _readEntries(box, comment.taskId);

    final existing = entries[comment.commentId];
    if (existing is Map) {
      final prevCreatedAt =
          (existing['event_created_at'] as num?)?.toInt() ?? 0;
      final prevEventId = existing['event_id']?.toString() ?? '';
      // LWW: (created_at, event_id) が保存済み以下なら古い/重複として棄却
      if (prevCreatedAt > eventCreatedAt ||
          (prevCreatedAt == eventCreatedAt &&
              prevEventId.compareTo(eventId) >= 0)) {
        return false;
      }
    }

    entries[comment.commentId] = <String, dynamic>{
      'payload': comment.toJson(),
      'event_created_at': eventCreatedAt,
      'event_id': eventId,
    };
    await box.put(comment.taskId, entries);
    return true;
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
      // インスタンス未使用でも同名 Box が開いていれば閉じてから消す
      // (開いたまま deleteBoxFromDisk すると同期に失敗する場合がある)。
      await Hive.box<Map<dynamic, dynamic>>(boxName).close();
    }
    await Hive.deleteBoxFromDisk(name);
  }

  // === Private Helpers ===

  Map<String, dynamic> _readEntries(
    Box<Map<dynamic, dynamic>> box,
    String taskId,
  ) {
    final raw = box.get(taskId);
    if (raw == null) {
      return <String, dynamic>{};
    }
    return _deepCastMap(raw);
  }

  List<TaskComment> _readComments(
    Box<Map<dynamic, dynamic>> box,
    String taskId,
  ) {
    final entries = _readEntries(box, taskId);
    final comments = <TaskComment>[];
    for (final entry in entries.values) {
      if (entry is! Map) {
        continue;
      }
      final payload = entry['payload'];
      if (payload is! Map<String, dynamic>) {
        continue;
      }
      try {
        comments.add(TaskComment.fromJson(payload));
      } on Object catch (e) {
        AppLogger.warning('[TaskCommentLocal] コメント復元エラー: $e');
        continue;
      }
    }
    // 表示順: payload の created_at 昇順、同秒は comment_id 辞書順
    comments.sort((a, b) {
      if (a.createdAt != b.createdAt) {
        return a.createdAt.compareTo(b.createdAt);
      }
      return a.commentId.compareTo(b.commentId);
    });
    return comments;
  }

  /// Map を deep copy で `Map<String, dynamic>` に変換
  /// (LocalStorageService._deepCastMap と同じ方式)
  Map<String, dynamic> _deepCastMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _deepCastMap(value));
        } else if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((e) {
              if (e is Map) {
                return _deepCastMap(e);
              }
              return e;
            }).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }
}
