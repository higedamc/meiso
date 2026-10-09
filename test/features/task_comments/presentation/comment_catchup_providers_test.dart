import 'dart:async';

import 'package:flutter/material.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment_record.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_read_state_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/read_state_providers.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/comment_catchup_providers.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/providers/app_lifecycle_provider.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/todos_provider.dart';

const _me = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

TaskCommentRecord _record({
  required String taskId,
  required String commentId,
  String author = _other,
  String body = 'body',
  int? receivedAt,
  bool deleted = false,
}) {
  return TaskCommentRecord(
    comment: TaskComment(
      commentId: commentId,
      taskId: taskId,
      authorPubkey: author,
      body: deleted ? '' : body,
      createdAt: 1700000000,
      deleted: deleted,
    ),
    receivedAtMillis: receivedAt,
  );
}

Todo _todo(String id, String title) => Todo(
  id: id,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// In-memory stand-in for the Hive comment store — same shape as
/// unread_comment_providers_test.dart's fake, duplicated here per this
/// codebase's convention of per-file private test doubles.
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
  final Map<String, int> watermarks = {};

  @override
  Stream<Map<String, int>> watchWatermarks() async* {
    yield Map.of(watermarks);
  }

  @override
  Future<Map<String, int>> loadWatermarks() async => Map.of(watermarks);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Satisfies `todosProvider`'s type without running the real notifier's
/// Nostr/Hive bootstrap — same shape as the `_FakeLocalDataSource` /
/// `implements` + `noSuchMethod` pattern above.
class _FakeTodosNotifier
    extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>>
    implements TodosNotifier {
  _FakeTodosNotifier(Map<DateTime?, List<Todo>> initial)
    : super(AsyncValue.data(initial));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

({ProviderContainer container, _FakeLocalDataSource local}) _setUp({
  String? myPubkey = _me,
  Map<DateTime?, List<Todo>> todos = const {},
}) {
  final local = _FakeLocalDataSource();
  final container = ProviderContainer(
    overrides: [
      taskCommentLocalDataSourceProvider.overrideWithValue(local),
      taskCommentReadStateDataSourceProvider.overrideWithValue(
        _FakeReadState(),
      ),
      publicKeyProvider.overrideWith((ref) => myPubkey),
      todosProvider.overrideWith((ref) => _FakeTodosNotifier(todos)),
    ],
  );
  addTearDown(container.dispose);
  // Subscribes to the local data source stream now, before any `emit()`,
  // so later emissions actually flow through instead of being delivered to
  // a provider nobody has read yet.
  container.listen(commentCatchupEntriesProvider, (_, _) {});
  return (container: container, local: local);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('commentCatchupEntriesProvider', () {
    test(
      'one row per task with unread, newest arrival first, resolves the Todo',
      () async {
        final s = _setUp(
          todos: {
            null: [
              _todo('task-1', 'Buy milk'),
              _todo('task-2', 'Water plants'),
            ],
          },
        );
        s.local.emit({
          'task-1': [
            _record(
              taskId: 'task-1',
              commentId: 'a',
              receivedAt: 10,
              body: 'first',
            ),
            _record(
              taskId: 'task-1',
              commentId: 'b',
              receivedAt: 20,
              body: 'second',
            ),
          ],
          'task-2': [
            _record(
              taskId: 'task-2',
              commentId: 'c',
              receivedAt: 5,
              body: 'only',
            ),
          ],
        });
        await pumpEventQueue();

        final entries = s.container.read(commentCatchupEntriesProvider);
        expect(entries.map((e) => e.taskId), ['task-1', 'task-2']);
        expect(entries[0].unreadCount, 2);
        expect(entries[0].latestComment.commentId, 'b');
        expect(entries[0].latestComment.body, 'second');
        expect(entries[0].todo?.title, 'Buy milk');
        expect(entries[1].todo?.title, 'Water plants');
      },
    );

    test('a task missing from the local store resolves todo to null', () async {
      final s = _setUp();
      s.local.emit({
        'ghost': [_record(taskId: 'ghost', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();

      final entries = s.container.read(commentCatchupEntriesProvider);
      expect(entries.single.todo, isNull);
    });

    test('read threads, own comments and tombstones are excluded', () async {
      final s = _setUp();
      s.local.emit({
        'read': [
          _record(taskId: 'read', commentId: 'a'), // pre-upgrade, no stamp
        ],
        'mine': [
          _record(taskId: 'mine', commentId: 'b', author: _me, receivedAt: 10),
        ],
        'gone': [
          _record(
            taskId: 'gone',
            commentId: 'c',
            receivedAt: 10,
            deleted: true,
          ),
        ],
        'hot': [_record(taskId: 'hot', commentId: 'd', receivedAt: 10)],
      });
      await pumpEventQueue();

      final entries = s.container.read(commentCatchupEntriesProvider);
      expect(entries.map((e) => e.taskId), ['hot']);
    });

    test('before the own pubkey is known, the list is empty', () async {
      final s = _setUp(myPubkey: null);
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();

      expect(s.container.read(commentCatchupEntriesProvider), isEmpty);
    });

    test('a later-arriving comment updates the row live', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();
      expect(
        s.container.read(commentCatchupEntriesProvider).single.unreadCount,
        1,
      );

      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(
            taskId: 'task-1',
            commentId: 'b',
            receivedAt: 20,
            body: 'newest',
          ),
        ],
      });
      await pumpEventQueue();
      final entry = s.container.read(commentCatchupEntriesProvider).single;
      expect(entry.unreadCount, 2);
      expect(entry.latestComment.body, 'newest');
    });
  });

  group('totalUnreadCommentCountProvider', () {
    test('sums unread across every task', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [
          _record(taskId: 'task-1', commentId: 'a', receivedAt: 10),
          _record(taskId: 'task-1', commentId: 'b', receivedAt: 20),
        ],
        'task-2': [_record(taskId: 'task-2', commentId: 'c', receivedAt: 5)],
      });
      await pumpEventQueue();

      expect(s.container.read(totalUnreadCommentCountProvider), 3);
    });

    test('zero when nothing is unread', () {
      final s = _setUp();
      expect(s.container.read(totalUnreadCommentCountProvider), 0);
    });
  });

  group('CommentCatchupDismissalNotifier', () {
    test('dismiss hides the strip; resuming from background re-arms it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(commentCatchupDismissedProvider), isFalse);

      container.read(commentCatchupDismissedProvider.notifier).dismiss();
      expect(container.read(commentCatchupDismissedProvider), isTrue);

      // Drive the real AppLifecycleNotifier through its public API, the
      // same way `app_lifecycle_reconnect_outcome_test.dart` does. With
      // `nostrInitializedProvider` left at its default `false`, the heavy
      // reconnect/sync side effects inside `_onAppResumed` bail out early —
      // only `state` changes, which is all this listener reacts to.
      container.read(appLifecycleProvider.notifier)
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(container.read(commentCatchupDismissedProvider), isFalse);
    });

    test('a lifecycle change other than resumed does not re-arm it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(commentCatchupDismissedProvider.notifier).dismiss();
      container
          .read(appLifecycleProvider.notifier)
          .didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(container.read(commentCatchupDismissedProvider), isTrue);
    });
  });

  group('shouldShowCommentCatchupStripProvider', () {
    test('false with no unread even if nothing was dismissed', () {
      final s = _setUp();
      expect(s.container.read(shouldShowCommentCatchupStripProvider), isFalse);
    });

    test('true once unread exists', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();

      expect(s.container.read(shouldShowCommentCatchupStripProvider), isTrue);
    });

    test('false after dismiss, even with unread still present', () async {
      final s = _setUp();
      s.local.emit({
        'task-1': [_record(taskId: 'task-1', commentId: 'a', receivedAt: 10)],
      });
      await pumpEventQueue();
      expect(s.container.read(shouldShowCommentCatchupStripProvider), isTrue);

      s.container.read(commentCatchupDismissedProvider.notifier).dismiss();
      expect(s.container.read(shouldShowCommentCatchupStripProvider), isFalse);
    });
  });
}
