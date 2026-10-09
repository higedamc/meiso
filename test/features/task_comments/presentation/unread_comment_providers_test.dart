import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment_record.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_read_state_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/read_state_providers.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/unread_comment_providers.dart';
import 'package:meiso/providers/nostr_provider.dart';

const _me = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

TaskCommentRecord _record({
  required String taskId,
  required String commentId,
  String author = _other,
  int createdAt = 1700000000,
  int? receivedAt,
  bool deleted = false,
}) {
  return TaskCommentRecord(
    comment: TaskComment(
      commentId: commentId,
      taskId: taskId,
      authorPubkey: author,
      body: deleted ? '' : 'body',
      createdAt: createdAt,
      deleted: deleted,
    ),
    receivedAtMillis: receivedAt,
  );
}

/// In-memory stand-in for the Hive comment store: only the record surface
/// the unread providers use is implemented.
class _FakeLocalDataSource implements TaskCommentLocalDataSource {
  final _controller =
      StreamController<Map<String, List<TaskCommentRecord>>>.broadcast();
  Map<String, List<TaskCommentRecord>> current = {};

  void emit(Map<String, List<TaskCommentRecord>> records) {
    current = records;
    _controller.add(records);
  }

  @override
  Stream<Map<String, List<TaskCommentRecord>>> watchAllRecords() async* {
    yield current;
    yield* _controller.stream;
  }

  @override
  Future<List<TaskCommentRecord>> loadRecords(String taskId) async =>
      current[taskId] ?? const [];

  @override
  Future<Map<String, List<TaskCommentRecord>>> loadAllRecords() async =>
      Map.of(current);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReadState implements TaskCommentReadStateDataSource {
  final _controller = StreamController<Map<String, int>>.broadcast();
  final Map<String, int> watermarks = {};

  @override
  Stream<Map<String, int>> watchWatermarks() async* {
    yield Map.of(watermarks);
    yield* _controller.stream;
  }

  @override
  Future<Map<String, int>> loadWatermarks() async => Map.of(watermarks);

  @override
  Future<void> markRead({
    required String taskId,
    required int receivedAtMillis,
  }) async {
    final current = watermarks[taskId];
    if (current != null && current >= receivedAtMillis) {
      return;
    }
    watermarks[taskId] = receivedAtMillis;
    _controller.add(Map.of(watermarks));
  }

  @override
  Future<void> markReadAll(Map<String, int> watermarks) async {
    markReadAllCalls++;
    var changed = false;
    watermarks.forEach((taskId, receivedAtMillis) {
      final current = this.watermarks[taskId];
      if (current == null || current < receivedAtMillis) {
        this.watermarks[taskId] = receivedAtMillis;
        changed = true;
      }
    });
    if (changed) {
      _controller.add(Map.of(this.watermarks));
    }
  }

  int markReadAllCalls = 0;

  @override
  Future<void> wipe() async {}
}

({ProviderContainer container, _FakeLocalDataSource local, _FakeReadState read})
_setUp({String? myPubkey = _me}) {
  final local = _FakeLocalDataSource();
  final read = _FakeReadState();
  final container = ProviderContainer(
    overrides: [
      taskCommentLocalDataSourceProvider.overrideWithValue(local),
      taskCommentReadStateDataSourceProvider.overrideWithValue(read),
      publicKeyProvider.overrideWith((ref) => myPubkey),
    ],
  );
  addTearDown(container.dispose);
  // Keep the stream providers alive for the whole test.
  container.listen(commentThreadSummariesProvider, (_, __) {});
  return (container: container, local: local, read: read);
}

Future<Map<String, CommentThreadSummary>> _summaries(
  ProviderContainer container,
) async {
  await pumpEventQueue();
  return container.read(commentThreadSummariesProvider);
}

void main() {
  group('isUnreadCommentRecord', () {
    test('other author, stamped, no watermark -> unread', () {
      final r = _record(taskId: 't', commentId: 'c', receivedAt: 10);
      expect(
        isUnreadCommentRecord(r, watermark: null, myPubkey: _me),
        isTrue,
      );
    });

    test('compares received_at with the watermark, strictly after', () {
      final r = _record(taskId: 't', commentId: 'c', receivedAt: 10);
      expect(isUnreadCommentRecord(r, watermark: 9, myPubkey: _me), isTrue);
      expect(isUnreadCommentRecord(r, watermark: 10, myPubkey: _me), isFalse);
      expect(isUnreadCommentRecord(r, watermark: 11, myPubkey: _me), isFalse);
    });

    test('own comment is never unread', () {
      final r = _record(
        taskId: 't',
        commentId: 'c',
        author: _me,
        receivedAt: 10,
      );
      expect(
        isUnreadCommentRecord(r, watermark: null, myPubkey: _me),
        isFalse,
      );
    });

    test('unknown own pubkey -> nothing is unread (fail closed)', () {
      final r = _record(taskId: 't', commentId: 'c', receivedAt: 10);
      expect(
        isUnreadCommentRecord(r, watermark: null, myPubkey: null),
        isFalse,
      );
    });

    test('pre-upgrade entry without a stamp is read', () {
      final r = _record(taskId: 't', commentId: 'c');
      expect(
        isUnreadCommentRecord(r, watermark: null, myPubkey: _me),
        isFalse,
      );
    });

    test('tombstone is never unread', () {
      final r = _record(
        taskId: 't',
        commentId: 'c',
        receivedAt: 10,
        deleted: true,
      );
      expect(
        isUnreadCommentRecord(r, watermark: null, myPubkey: _me),
        isFalse,
      );
    });

    test('the author-reported created_at plays no part', () {
      // Hostile/skewed author clock: created_at far in the future, but the
      // device received it before the watermark -> read.
      final future = _record(
        taskId: 't',
        commentId: 'c',
        createdAt: 4_000_000_000,
        receivedAt: 10,
      );
      expect(
        isUnreadCommentRecord(future, watermark: 10, myPubkey: _me),
        isFalse,
      );
      // created_at in the distant past, received after the watermark -> unread.
      final past = _record(
        taskId: 't',
        commentId: 'c',
        createdAt: 1,
        receivedAt: 11,
      );
      expect(
        isUnreadCommentRecord(past, watermark: 10, myPubkey: _me),
        isTrue,
      );
    });
  });

  group('commentThreadSummariesProvider', () {
    test(
      'counts visible and unread per task; tombstone-only threads omitted',
      () async {
        final s = _setUp();
        s.local.emit({
          'task-1': [
            _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
            _record(taskId: 'task-1', commentId: 'b', receivedAt: 20),
            _record(
              taskId: 'task-1',
              commentId: 'mine',
              author: _me,
              receivedAt: 30,
            ),
            _record(
              taskId: 'task-1',
              commentId: 'gone',
              receivedAt: 40,
              deleted: true,
            ),
          ],
          'task-2': [
            _record(
              taskId: 'task-2',
              commentId: 'x',
              receivedAt: 5,
              deleted: true,
            ),
          ],
        });

        final summaries = await _summaries(s.container);
        expect(summaries.keys, ['task-1']);
        expect(summaries['task-1']!.visibleCount, 3);
        expect(summaries['task-1']!.unreadCount, 2);
      },
    );

    test('watermark clears what was received up to it', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(taskId: 'task-1', commentId: 'b', receivedAt: 20),
        ],
      });
      expect((await _summaries(s.container))['task-1']!.unreadCount, 2);

      await s.read.markRead(taskId: 'task-1', receivedAtMillis: 10);
      expect((await _summaries(s.container))['task-1']!.unreadCount, 1);

      await s.read.markRead(taskId: 'task-1', receivedAtMillis: 20);
      expect((await _summaries(s.container))['task-1']!.unreadCount, 0);
      // The thread still exists for the plain indicator.
      expect((await _summaries(s.container))['task-1']!.hasThread, isTrue);
    });

    test('upgrade: unstamped threads are visible but not unread', () async {
      final s = _setUp();
      s.local.emit({
        'old': [
          _record(taskId: 'old', commentId: 'a'),
          _record(taskId: 'old', commentId: 'b'),
        ],
      });
      final summary = (await _summaries(s.container))['old']!;
      expect(summary.visibleCount, 2);
      expect(summary.unreadCount, 0);
    });

    test('before the own pubkey is known nothing is unread', () async {
      final s = _setUp(myPubkey: null);
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      final summary = (await _summaries(s.container))['task-1']!;
      expect(summary.visibleCount, 1);
      expect(summary.unreadCount, 0);
    });

    test('unreadCommentCountsProvider lists only tasks with unread', () async {
      final s = _setUp();
      s.local.emit({
        'hot': [_record(taskId: 'hot', commentId: 'a', receivedAt: 10)],
        'quiet': [
          _record(taskId: 'quiet', commentId: 'b', author: _me, receivedAt: 10),
        ],
      });
      await pumpEventQueue();
      expect(s.container.read(unreadCommentCountsProvider), {'hot': 1});
    });
  });

  group('TaskCommentReadMarker', () {
    test('advances the watermark to the latest stamp in the store', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(taskId: 'task-1', commentId: 'b', receivedAt: 25),
          _record(taskId: 'task-1', commentId: 'legacy'), // no stamp
        ],
      });
      await pumpEventQueue();

      await s.container.read(taskCommentReadMarkerProvider).markRead('task-1');

      expect(s.read.watermarks, {'task-1': 25});
      expect((await _summaries(s.container))['task-1']!.unreadCount, 0);
    });

    test('is a no-op for a thread with no stamped entries', () async {
      final s = _setUp();
      s.local.emit({
        'old': [_record(taskId: 'old', commentId: 'a')],
      });
      await pumpEventQueue();

      await s.container.read(taskCommentReadMarkerProvider).markRead('old');
      await s.container.read(taskCommentReadMarkerProvider).markRead('none');

      expect(s.read.watermarks, isEmpty);
    });

    test('a comment received after marking read is unread again', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();
      await s.container.read(taskCommentReadMarkerProvider).markRead('task-1');
      expect((await _summaries(s.container))['task-1']!.unreadCount, 0);

      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(taskId: 'task-1', commentId: 'b', receivedAt: 11),
        ],
      });
      expect((await _summaries(s.container))['task-1']!.unreadCount, 1);
    });

    test('markAllRead clears every thread in one write', () async {
      final s = _setUp();
      s.read.watermarks['task-1'] = 5;
      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(taskId: 'task-1', commentId: 'b', receivedAt: 25),
        ],
        'task-2': [_record(taskId: 'task-2', commentId: 'c', receivedAt: 40)],
        'old': [_record(taskId: 'old', commentId: 'd')], // no stamp
      });
      await pumpEventQueue();
      expect(s.container.read(unreadCommentCountsProvider), {
        'task-1': 2,
        'task-2': 1,
      });

      await s.container.read(taskCommentReadMarkerProvider).markAllRead();

      expect(s.read.markReadAllCalls, 1);
      expect(s.read.watermarks, {'task-1': 25, 'task-2': 40});
      expect(s.container.read(unreadCommentCountsProvider), isEmpty);
    });

    test('markAllRead never moves a watermark backwards', () async {
      final s = _setUp();
      s.read.watermarks['task-1'] = 100;
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();

      await s.container.read(taskCommentReadMarkerProvider).markAllRead();

      expect(s.read.watermarks, {'task-1': 100});
    });

    test('markAllRead with no stamped entries writes nothing', () async {
      final s = _setUp();
      s.local.emit({
        'old': [_record(taskId: 'old', commentId: 'a')],
      });
      await pumpEventQueue();

      await s.container.read(taskCommentReadMarkerProvider).markAllRead();

      expect(s.read.markReadAllCalls, 0);
      expect(s.read.watermarks, isEmpty);
    });
  });
}
