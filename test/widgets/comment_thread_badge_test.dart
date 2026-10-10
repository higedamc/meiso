import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment_record.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_read_state_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/read_state_providers.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/todos_provider.dart';
import 'package:meiso/widgets/comment_thread_badge.dart';
import 'package:meiso/widgets/todo_item.dart';

const _me = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

TaskCommentRecord _record(
  String commentId, {
  String author = _other,
  int receivedAt = 1000,
}) {
  return TaskCommentRecord(
    comment: TaskComment(
      commentId: commentId,
      taskId: 'task-1',
      authorPubkey: author,
      body: 'body',
      createdAt: 1700000000,
    ),
    receivedAtMillis: receivedAt,
  );
}

final _todo = Todo(
  id: 'task-1',
  title: 'Buy milk',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

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

/// Enough of [TodosNotifier] for a tile to render: no subtasks.
class _FakeTodosNotifier
    extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>>
    implements TodosNotifier {
  _FakeTodosNotifier() : super(const AsyncValue.data({}));

  @override
  List<Todo> getSubtasks(String parentId) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

/// What a screen reader gets for the badge: the tile's InkWell merges its
/// descendants, so the label is read on the merged node (e.g. "Buy milk 1
/// unread comment"), which is the TalkBack reading the spec asks for (§8.9).
String _badgeLabel(WidgetTester tester) =>
    tester.getSemantics(find.byType(CommentThreadIndicator)).label;

final Matcher _readsUnread = contains('unread comment');
final Matcher _readsQuiet = allOf(
  matches(RegExp(r'\b\d+ comments?\b')),
  isNot(contains('unread')),
);

void main() {
  group('TodoItem comment badge (via CommentThreadBadge)', () {
    late _FakeLocalDataSource local;
    late _FakeReadState readState;
    late ProviderContainer container;

    Future<void> pumpTile(
      WidgetTester tester, {
      required String? myPubkey,
    }) async {
      local = _FakeLocalDataSource();
      readState = _FakeReadState();
      container = ProviderContainer(
        overrides: [
          taskCommentLocalDataSourceProvider.overrideWithValue(local),
          taskCommentReadStateDataSourceProvider.overrideWithValue(readState),
          publicKeyProvider.overrideWith((ref) => myPubkey),
          todosProvider.overrideWith((ref) => _FakeTodosNotifier()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _app(TodoItem(todo: _todo)),
        ),
      );
      await tester.pump();
    }

    testWidgets('no thread: no badge at all', (tester) async {
      await pumpTile(tester, myPubkey: _me);
      local.emit({});
      await tester.pumpAndSettle();

      expect(find.byType(CommentThreadIndicator), findsNothing);
    });

    testWidgets('thread with nothing unread: quiet bubble with the count', (
      tester,
    ) async {
      await pumpTile(tester, myPubkey: _me);
      readState.emit({'task-1': 2000});
      local.emit({
        'task-1': [
          _record('c1'),
          _record('c2', receivedAt: 2000),
        ],
      });
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble), findsNothing);
      expect(find.text('2'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(_badgeLabel(tester), _readsQuiet);
      semantics.dispose();
    });

    testWidgets('cold start: badge is quiet while the own pubkey is unknown '
        'and lights up when it becomes known, without rebuilding the tile', (
      tester,
    ) async {
      // Real launch order: the tile is built and the comment store is read
      // before the session restore has set the pubkey.
      await pumpTile(tester, myPubkey: null);
      local.emit({
        'task-1': [_record('c1')],
      });
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      expect(find.byType(CommentThreadIndicator), findsOneWidget);
      expect(_badgeLabel(tester), _readsQuiet);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      container.read(publicKeyProvider.notifier).state = _me;
      await tester.pumpAndSettle();

      expect(_badgeLabel(tester), _readsUnread);
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('unread count, not total, is the number shown while unread', (
      tester,
    ) async {
      await pumpTile(tester, myPubkey: _me);
      readState.emit({'task-1': 1000});
      local.emit({
        'task-1': [
          _record('c1'),
          _record('c2', receivedAt: 2000),
          _record('c3', receivedAt: 3000),
        ],
      });
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(_badgeLabel(tester), contains('2 unread comments'));
      semantics.dispose();
    });

    testWidgets('marking the thread read turns the badge quiet again', (
      tester,
    ) async {
      await pumpTile(tester, myPubkey: _me);
      local.emit({
        'task-1': [_record('c1', receivedAt: 5000)],
      });
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(_badgeLabel(tester), _readsUnread);

      readState.emit({'task-1': 5000});
      await tester.pumpAndSettle();

      expect(_badgeLabel(tester), _readsQuiet);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      semantics.dispose();
    });
  });

  group('CommentThreadIndicator arrival animation', () {
    Widget indicator(int unread) =>
        CommentThreadIndicator(visibleCount: 3, unreadCount: unread);

    double opacityOf(WidgetTester tester) {
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(CommentThreadIndicator),
          matching: find.byType(FadeTransition),
        ),
      );
      return fade.opacity.value;
    }

    testWidgets(
      'first build never animates: the badge is state, not an event',
      (
        tester,
      ) async {
        await tester.pumpWidget(_app(indicator(2)));
        expect(opacityOf(tester), 1.0);
      },
    );

    testWidgets('a new unread comment fades and scales in once (~200 ms)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(indicator(0)));
      await tester.pumpWidget(_app(indicator(1)));
      await tester.pump();

      expect(opacityOf(tester), lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester), lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester), 1.0);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a decrease (thread read) does not animate', (tester) async {
      await tester.pumpWidget(_app(indicator(2)));
      await tester.pumpWidget(_app(indicator(0)));
      await tester.pump();

      expect(opacityOf(tester), 1.0);
    });

    testWidgets('with reduce-motion on the badge simply appears', (
      tester,
    ) async {
      await tester.pumpWidget(_app(indicator(0), disableAnimations: true));
      await tester.pumpWidget(_app(indicator(1), disableAnimations: true));
      await tester.pump();

      expect(opacityOf(tester), 1.0);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
