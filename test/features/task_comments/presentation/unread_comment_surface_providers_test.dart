import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment_record.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_read_state_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/read_state_providers.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/unread_comment_surface_providers.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/todos_provider.dart';

const _me = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

TaskCommentRecord _record(
  String taskId, {
  String author = _other,
  int receivedAt = 1000,
}) {
  return TaskCommentRecord(
    comment: TaskComment(
      commentId: '$taskId-c',
      taskId: taskId,
      authorPubkey: author,
      body: 'body',
      createdAt: 1700000000,
    ),
    receivedAtMillis: receivedAt,
  );
}

Todo _todo(String id, {DateTime? date, String? listId}) => Todo(
  id: id,
  title: id,
  date: date,
  customListId: listId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// In-memory stand-in for the Hive comment store (same shape as the other
/// task_comments tests, duplicated per the per-file test-double convention).
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

  void emit(Map<String, int> next) {
    watermarks
      ..clear()
      ..addAll(next);
    _controller.add(Map.of(watermarks));
  }

  @override
  Stream<Map<String, int>> watchWatermarks() async* {
    yield Map.of(watermarks);
    yield* _controller.stream;
  }

  @override
  Future<Map<String, int>> loadWatermarks() async => Map.of(watermarks);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTodosNotifier
    extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>>
    implements TodosNotifier {
  /// `null` = the store is still loading.
  _FakeTodosNotifier(Map<DateTime?, List<Todo>>? todos)
    : super(
        todos == null ? const AsyncValue.loading() : AsyncValue.data(todos),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _jan7 = DateTime(2026, 1, 7);
final _jan20 = DateTime(2026, 1, 20);

({
  ProviderContainer container,
  _FakeLocalDataSource local,
  _FakeReadState readState,
})
_setUp({
  String? myPubkey = _me,
  Map<DateTime?, List<Todo>>? todos = const {},
}) {
  final local = _FakeLocalDataSource();
  final readState = _FakeReadState();
  final container = ProviderContainer(
    overrides: [
      taskCommentLocalDataSourceProvider.overrideWithValue(local),
      taskCommentReadStateDataSourceProvider.overrideWithValue(readState),
      publicKeyProvider.overrideWith((ref) => myPubkey),
      todosProvider.overrideWith((ref) => _FakeTodosNotifier(todos)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(unreadCommentSurfacesProvider, (_, _) {});
  return (container: container, local: local, readState: readState);
}

/// The store the scenarios share: one dated task, one list task, one task
/// with neither, and one list task that also has a date.
final Map<DateTime?, List<Todo>> _todos = {
  _jan7: [_todo('dated'), _todo('dated-in-list', listId: 'list-1')],
  null: [_todo('listed', listId: 'list-2'), _todo('loose')],
};

void main() {
  group('unreadCommentSurfacesProvider', () {
    test('is empty while nothing is unread', () async {
      final s = _setUp(todos: _todos);
      s.local.emit({});
      await pumpEventQueue();
      expect(
        s.container.read(unreadCommentSurfacesProvider).any,
        isFalse,
      );
    });

    test(
      'locates each unread thread on its day page and its list row',
      () async {
        final s = _setUp(todos: _todos);
        s.local.emit({
          'dated': [_record('dated')],
          'dated-in-list': [_record('dated-in-list')],
          'listed': [_record('listed')],
          'loose': [_record('loose')],
        });
        await pumpEventQueue();

        final surfaces = s.container.read(unreadCommentSurfacesProvider);
        expect(surfaces.dates, {_jan7});
        expect(surfaces.listIds, {'list-1', 'list-2'});
        expect(surfaces.undated, isTrue);
        expect(surfaces.today, isTrue);
        expect(surfaces.someday, isTrue);
        expect(surfaces.hasUnreadOn(DateTime(2026, 1, 7, 15, 30)), isTrue);
        expect(surfaces.hasUnreadOn(DateTime(2026, 1, 8)), isFalse);
        expect(surfaces.hasUnreadInList('list-1'), isTrue);
        expect(surfaces.hasUnreadInList('list-9'), isFalse);
        expect(surfaces.hasUnreadBetween(DateTime(2026, 1, 5), _jan7), isTrue);
        expect(
          surfaces.hasUnreadBetween(DateTime(2026, 1, 8), _jan20),
          isFalse,
        );
      },
    );

    test('a dated task in a list lights both TODAY and SOMEDAY', () async {
      final s = _setUp(todos: _todos);
      s.local.emit({
        'dated-in-list': [_record('dated-in-list')],
      });
      await pumpEventQueue();

      final surfaces = s.container.read(unreadCommentSurfacesProvider);
      expect(surfaces.dates, {_jan7});
      expect(surfaces.listIds, {'list-1'});
      expect(surfaces.undated, isFalse);
      expect(surfaces.today, isTrue);
      expect(surfaces.someday, isTrue);
    });

    test('a loose undated task lights SOMEDAY only', () async {
      final s = _setUp(todos: _todos);
      s.local.emit({
        'loose': [_record('loose')],
      });
      await pumpEventQueue();

      final surfaces = s.container.read(unreadCommentSurfacesProvider);
      expect(surfaces.today, isFalse);
      expect(surfaces.someday, isTrue);
      expect(surfaces.listIds, isEmpty);
    });

    test('own comments and read threads light nothing', () async {
      final s = _setUp(todos: _todos);
      s.readState.emit({'listed': 5000});
      await pumpEventQueue();
      s.local.emit({
        'dated': [_record('dated', author: _me)],
        'listed': [_record('listed', receivedAt: 5000)],
      });

      expect(s.container.read(unreadCommentSurfacesProvider).any, isFalse);
    });

    test('stays dark until the own pubkey is known (cold start), then '
        'lights without a re-read of the store', () async {
      final s = _setUp(myPubkey: null, todos: _todos);
      s.local.emit({
        'dated': [_record('dated')],
      });
      await pumpEventQueue();
      expect(s.container.read(unreadCommentSurfacesProvider).any, isFalse);

      s.container.read(publicKeyProvider.notifier).state = _me;
      await pumpEventQueue();

      expect(s.container.read(unreadCommentSurfacesProvider).today, isTrue);
    });

    test('a thread whose task is gone locally has no surface', () async {
      final s = _setUp(todos: _todos);
      s.local.emit({
        'deleted-task': [_record('deleted-task')],
      });
      await pumpEventQueue();

      expect(s.container.read(unreadCommentSurfacesProvider).any, isFalse);
    });

    test('is empty while the todo store is still loading', () async {
      final s = _setUp(todos: null);
      s.local.emit({
        'dated': [_record('dated')],
      });
      await pumpEventQueue();

      expect(s.container.read(unreadCommentSurfacesProvider).any, isFalse);
    });

    test('clears when the thread is marked read', () async {
      final s = _setUp(todos: _todos);
      s.local.emit({
        'dated': [_record('dated', receivedAt: 5000)],
      });
      await pumpEventQueue();
      expect(s.container.read(unreadCommentSurfacesProvider).today, isTrue);

      s.readState.emit({'dated': 5000});

      await pumpEventQueue();

      expect(s.container.read(unreadCommentSurfacesProvider).any, isFalse);
    });
  });
}
