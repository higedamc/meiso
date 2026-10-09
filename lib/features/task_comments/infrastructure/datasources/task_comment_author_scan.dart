import 'package:hive_flutter/hive_flutter.dart';

import 'task_comment_local_datasource.dart';

/// Scans the `task_comments` Hive box directly to check whether any
/// comment anywhere has the given pubkey as its author.
///
/// Only used to decide whether to show the comment intro card (issue #219
/// §6). [TaskCommentLocalDataSource] only reads comments per task (there is
/// no cross-task author-search API), so this opens the box directly for
/// this single purpose. It only references
/// [TaskCommentLocalDataSourceHive.boxName] and does not touch the
/// datasource implementation itself.
Future<bool> hasAuthoredAnyComment(String pubkey) async {
  final box = await Hive.openBox<Map<dynamic, dynamic>>(
    TaskCommentLocalDataSourceHive.boxName,
  );
  for (final commentsByTask in box.values) {
    for (final entry in commentsByTask.values) {
      if (entry is! Map) {
        continue;
      }
      final payload = entry['payload'];
      if (payload is! Map) {
        continue;
      }
      if (payload['author_pubkey'] == pubkey) {
        return true;
      }
    }
  }
  return false;
}
