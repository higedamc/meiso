import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/presentation/providers/author_profile_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/comment_catchup_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/unread_comment_providers.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/presentation/comment_catchup/comment_catchup_screen.dart';

/// Never touches Rust FFI. `_CommentCatchupRow` calls
/// `authorLabelsProvider.notifier.ensureLoaded`, which hits `hexToNpub` on
/// the real notifier and crashes outside a running app — same gap noted in
/// task_comment_section_test.dart's `_NoopAuthorLabelsNotifier`.
class _NoopAuthorLabelsNotifier extends AuthorLabelsNotifier {
  @override
  Map<String, AuthorLabel> build() => const {};

  @override
  void ensureLoaded(List<String> pubkeyHexes) {}
}

class _FakeReadMarker implements TaskCommentReadMarker {
  int markAllReadCalls = 0;

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
  }

  @override
  Future<void> markRead(String taskId) async {}
}

Todo _todo(String id, String title) => Todo(
  id: id,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

CommentCatchupEntry _entry({
  required String taskId,
  required Todo? todo,
  int unreadCount = 1,
  String body = 'hi',
  int receivedAtMillis = 0,
}) {
  return CommentCatchupEntry(
    taskId: taskId,
    unreadCount: unreadCount,
    latestComment: TaskComment(
      commentId: '$taskId-c',
      taskId: taskId,
      authorPubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      body: body,
      createdAt: 1700000000,
    ),
    latestReceivedAtMillis: receivedAtMillis,
    todo: todo,
  );
}

Widget _wrap(
  List<CommentCatchupEntry> entries, {
  TaskCommentReadMarker? readMarker,
}) {
  return ProviderScope(
    overrides: [
      commentCatchupEntriesProvider.overrideWithValue(entries),
      authorLabelsProvider.overrideWith(_NoopAuthorLabelsNotifier.new),
      if (readMarker != null)
        taskCommentReadMarkerProvider.overrideWithValue(readMarker),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CommentCatchupScreen(),
    ),
  );
}

void main() {
  group('CommentCatchupScreen', () {
    testWidgets('empty state when there is nothing to catch up on', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const []));

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('renders one row per entry with title and preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _entry(taskId: 't1', todo: _todo('t1', 'Buy milk'), body: 'got it?'),
          _entry(taskId: 't2', todo: null, body: 'orphaned'),
        ]),
      );

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.textContaining('got it?'), findsOneWidget);
      // A task deleted locally after the comment arrived still gets a row.
      expect(find.text('(deleted task)'), findsOneWidget);
      expect(find.textContaining('orphaned'), findsOneWidget);
    });

    testWidgets('mark all read button calls the read marker exactly once', (
      tester,
    ) async {
      final marker = _FakeReadMarker();
      await tester.pumpWidget(
        _wrap([
          _entry(taskId: 't1', todo: _todo('t1', 'Buy milk')),
        ], readMarker: marker),
      );

      await tester.tap(find.text('Mark all read'));
      await tester.pump();

      expect(marker.markAllReadCalls, 1);
    });

    testWidgets('a row for a locally-deleted task is not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([_entry(taskId: 't1', todo: null)]),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    });
  });
}
