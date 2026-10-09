import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';

const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

TaskComment _comment({
  String commentId = 'c1',
  String taskId = 'task-1',
  int createdAt = 1700000000,
  String body = 'hello',
  bool deleted = false,
}) {
  return TaskComment(
    commentId: commentId,
    taskId: taskId,
    authorPubkey: _author,
    body: body,
    createdAt: createdAt,
    deleted: deleted,
  );
}

void main() {
  late Directory tempDir;
  late Box<Map<dynamic, dynamic>> box;
  late TaskCommentLocalDataSourceHive dataSource;
  late int clock;
  var seq = 0;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('task_comments_rx_test');
    Hive.init(tempDir.path);
    seq++;
    box = await Hive.openBox<Map<dynamic, dynamic>>('task_comments_rx_$seq');
    clock = 1_000;
    dataSource = TaskCommentLocalDataSourceHive(
      box: box,
      nowMillis: () => clock,
    );
  });

  tearDown(() async {
    await dataSource.close();
    tempDir.deleteSync(recursive: true);
  });

  test(
    'upsert stamps received_at from the local clock, not created_at',
    () async {
      clock = 5_000;
      // Author clock claims a far-future created_at; the stamp must ignore it.
      await dataSource.upsert(
        comment: _comment(createdAt: 4_000_000_000),
        eventCreatedAt: 4_000_000_000,
        eventId: 'e1',
      );

      final records = await dataSource.loadRecords('task-1');
      expect(records, hasLength(1));
      expect(records.single.receivedAtMillis, 5_000);
      expect(records.single.comment.commentId, 'c1');
    },
  );

  test('LWW-rejected event leaves the existing stamp untouched', () async {
    clock = 5_000;
    await dataSource.upsert(
      comment: _comment(createdAt: 200),
      eventCreatedAt: 200,
      eventId: 'e-new',
    );

    clock = 9_000;
    final applied = await dataSource.upsert(
      comment: _comment(createdAt: 100, body: 'stale'),
      eventCreatedAt: 100,
      eventId: 'e-old',
    );

    expect(applied, isFalse);
    final records = await dataSource.loadRecords('task-1');
    expect(records.single.receivedAtMillis, 5_000);
    expect(records.single.comment.body, 'hello');
  });

  test('a newer version of the same comment is re-stamped', () async {
    clock = 5_000;
    await dataSource.upsert(
      comment: _comment(createdAt: 200),
      eventCreatedAt: 200,
      eventId: 'e1',
    );
    clock = 7_000;
    await dataSource.upsert(
      comment: _comment(createdAt: 200, body: 'edited'),
      eventCreatedAt: 300,
      eventId: 'e2',
    );

    final records = await dataSource.loadRecords('task-1');
    expect(records.single.receivedAtMillis, 7_000);
    expect(records.single.comment.body, 'edited');
  });

  test('pre-upgrade entries without received_at read back as null', () async {
    // Written by a 1.4.3 store: no received_at key at all.
    await box.put('task-legacy', {
      'c-legacy': {
        'payload': _comment(
          commentId: 'c-legacy',
          taskId: 'task-legacy',
        ).toJson(),
        'event_created_at': 1700000000,
        'event_id': 'e-legacy',
      },
    });

    final records = await dataSource.loadRecords('task-legacy');
    expect(records.single.receivedAtMillis, isNull);
    // The legacy read path is unaffected.
    final comments = await dataSource.loadComments('task-legacy');
    expect(comments.single.commentId, 'c-legacy');
  });

  test('watchAllRecords emits every thread and again after a write', () async {
    clock = 1_000;
    await dataSource.upsert(
      comment: _comment(taskId: 'task-a', commentId: 'a1'),
      eventCreatedAt: 1,
      eventId: 'ea1',
    );

    final emissions = <Map<String, int>>[];
    final sub = dataSource.watchAllRecords().listen((all) {
      emissions.add({
        for (final e in all.entries) e.key: e.value.length,
      });
    });
    await pumpEventQueue();
    expect(emissions, [
      {'task-a': 1},
    ]);

    clock = 2_000;
    await dataSource.upsert(
      comment: _comment(taskId: 'task-b', commentId: 'b1'),
      eventCreatedAt: 2,
      eventId: 'eb1',
    );
    await pumpEventQueue();
    expect(emissions.last, {'task-a': 1, 'task-b': 1});

    await sub.cancel();
  });
}
