import 'package:hive_flutter/hive_flutter.dart';

import 'task_comment_local_datasource.dart';

/// `task_comments` Hive box を直接走査し、指定した pubkey が著者として
/// 登場するコメントが1件でもあるかを確認する。
///
/// コメント機能の初回案内カード(issue #219 §6)の表示要否判定専用。
/// 既存の [TaskCommentLocalDataSource] はタスク単位でしかコメントを
/// 読めないため(全タスク横断の著者検索 API が無い)、この用途に限って
/// Box を直接開いて走査する。Box 名は
/// [TaskCommentLocalDataSourceHive.boxName] を参照するだけで、
/// データソース実装そのものには手を入れない。
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
