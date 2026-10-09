import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_author_scan.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';

void main() {
  group('hasAuthoredAnyComment', () {
    late Box<Map<dynamic, dynamic>> box;

    setUp(() async {
      Hive.init('./test_cache');
      box = await Hive.openBox<Map<dynamic, dynamic>>(
        TaskCommentLocalDataSourceHive.boxName,
      );
    });

    tearDown(() async {
      await box.clear();
      await box.close();
      await Hive.deleteFromDisk();
    });

    test('box が空なら false', () async {
      final result = await hasAuthoredAnyComment('mine');
      expect(result, isFalse);
    });

    test('自分以外のコメントしか無ければ false', () async {
      await box.put('task-1', {
        'comment-1': {
          'payload': {'author_pubkey': 'someone-else', 'body': 'hi'},
          'event_created_at': 1,
          'event_id': 'ev1',
        },
      });

      final result = await hasAuthoredAnyComment('mine');
      expect(result, isFalse);
    });

    test('自分のコメントが別タスクにあれば true', () async {
      await box.put('task-1', {
        'comment-1': {
          'payload': {'author_pubkey': 'someone-else', 'body': 'hi'},
          'event_created_at': 1,
          'event_id': 'ev1',
        },
      });
      await box.put('task-2', {
        'comment-2': {
          'payload': {'author_pubkey': 'mine', 'body': 'yo'},
          'event_created_at': 2,
          'event_id': 'ev2',
        },
      });

      final result = await hasAuthoredAnyComment('mine');
      expect(result, isTrue);
    });

    test('payload が壊れたエントリは無視して継続する', () async {
      await box.put('task-1', {
        'comment-1': {'payload': 'not-a-map'},
        'comment-2': {
          'payload': {'author_pubkey': 'mine', 'body': 'yo'},
          'event_created_at': 2,
          'event_id': 'ev2',
        },
      });

      final result = await hasAuthoredAnyComment('mine');
      expect(result, isTrue);
    });
  });
}
