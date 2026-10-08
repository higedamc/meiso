import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/send_outbox/domain/outbox_entry.dart';
import 'package:meiso/features/send_outbox/infrastructure/outbox_local_datasource.dart';
import 'package:meiso/features/send_outbox/presentation/providers/outbox_providers.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/repositories/task_comment_repository.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/features/task_comments/presentation/providers/author_profile_providers.dart';
import 'package:meiso/features/task_comments/presentation/widgets/task_comment_section.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/providers/nostr_provider.dart';

/// Fake that never touches Rust FFI (`hexToNpub`). Tests that render an
/// other-author bubble need this, or `author_profile_providers.dart` hits
/// the FFI and crashes (no existing test in this widget test file had put a
/// bubble under another author's pubkey before, so this gap went unhit).
class _NoopAuthorLabelsNotifier extends AuthorLabelsNotifier {
  @override
  Map<String, AuthorLabel> build() => const {};

  @override
  void ensureLoaded(List<String> pubkeyHexes) {}
}

/// Fake that never touches Hive. This test controls the outbox's contents
/// via a direct override of [pendingCommentOutboxProvider], so this only
/// needs to satisfy [sendOutboxTriggerProvider]'s dependency resolution.
class _FakeOutboxLocalDataSource implements OutboxLocalDataSource {
  @override
  Future<Map<String, OutboxEntry>> loadAll() async => const {};

  @override
  Future<void> put(OutboxEntry entry) async {}

  @override
  Future<void> remove(String eventId) async {}

  @override
  Stream<Map<String, OutboxEntry>> watchAll() => Stream.value(const {});

  @override
  Future<void> wipe() async {}
}

const _myPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

TaskComment _comment(
  String id, {
  String body = 'hello',
  bool deleted = false,
  int? editedAt,
}) {
  return TaskComment(
    commentId: id,
    taskId: 'task-1',
    authorPubkey: _myPubkey,
    body: body,
    createdAt: 1756800000,
    editedAt: editedAt,
    deleted: deleted,
  );
}

class _FakeTaskCommentRepository implements TaskCommentRepository {
  _FakeTaskCommentRepository(this.seed);

  final List<TaskComment> seed;
  final List<({String taskId, String body, String? groupId})> addCalls = [];
  Either<Failure, TaskComment>? addResult;

  @override
  Stream<List<TaskComment>> watchComments({required String taskId}) {
    return Stream.value(seed);
  }

  @override
  Future<Either<Failure, TaskComment>> addComment({
    required String taskId,
    required String body,
    String? groupId,
    String? parentCommentId,
  }) async {
    addCalls.add((taskId: taskId, body: body, groupId: groupId));
    return addResult ?? Right(_comment('new', body: body));
  }

  @override
  Future<Either<Failure, TaskComment>> editComment({
    required TaskComment comment,
    required String newBody,
    String? groupId,
  }) async {
    return Right(comment.copyWith(body: newBody, editedAt: 1756800100));
  }

  @override
  Future<Either<Failure, Unit>> deleteComment({
    required TaskComment comment,
    String? groupId,
  }) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> applyRemoteCommentEvent({
    required String eventJson,
    String? groupId,
  }) async {
    return const Right(unit);
  }
}

Widget _wrap(
  Widget child, {
  required _FakeTaskCommentRepository repository,
  bool amberMode = false,
  Map<String, OutboxEntry> pendingOutbox = const {},
}) {
  return ProviderScope(
    overrides: [
      taskCommentRepositoryProvider.overrideWithValue(repository),
      publicKeyProvider.overrideWith((ref) => _myPubkey),
      isAmberModeProvider.overrideWithValue(amberMode),
      outboxLocalDataSourceProvider.overrideWithValue(
        _FakeOutboxLocalDataSource(),
      ),
      pendingCommentOutboxProvider.overrideWith(
        (ref) => Stream.value(pendingOutbox),
      ),
      authorLabelsProvider.overrideWith(_NoopAuthorLabelsNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('shared task: renders comments, hides tombstones, shows input', (
    tester,
  ) async {
    final repository = _FakeTaskCommentRepository([
      _comment('c1', body: 'first comment'),
      _comment('c2', body: 'second comment', editedAt: 1756800100),
      _comment('c3', body: '', deleted: true),
    ]);

    await tester.pumpWidget(
      _wrap(
        const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
        repository: repository,
      ),
    );
    await tester.pump();

    expect(find.text('first comment'), findsOneWidget);
    expect(find.text('second comment'), findsOneWidget);
    // Tombstone stays hidden and is excluded from the count.
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    // Edited marker appears exactly once (only c2 was edited).
    expect(find.textContaining('edited'), findsOneWidget);
  });

  testWidgets(
    'shared task: sending a comment passes groupId and clears input',
    (
      tester,
    ) async {
      final repository = _FakeTaskCommentRepository([]);

      await tester.pumpWidget(
        _wrap(
          const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
          repository: repository,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'a new comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(repository.addCalls, hasLength(1));
      expect(repository.addCalls.single.taskId, 'task-1');
      expect(repository.addCalls.single.body, 'a new comment');
      expect(repository.addCalls.single.groupId, 'group-1');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    },
  );

  testWidgets('shared task: add failure surfaces a SnackBar and keeps text', (
    tester,
  ) async {
    final repository = _FakeTaskCommentRepository([])
      ..addResult = const Left(AuthFailure('no group key'));

    await tester.pumpWidget(
      _wrap(
        const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
        repository: repository,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'will fail');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('no group key'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'will fail',
    );
  });

  testWidgets(
    'personal task in Amber mode: input is enabled (signs via Amber)',
    (tester) async {
      final repository = _FakeTaskCommentRepository([_comment('c1')]);

      await tester.pumpWidget(
        _wrap(
          const TaskCommentSection(taskId: 'task-1'),
          repository: repository,
          amberMode: true,
        ),
      );
      await tester.pump();

      // No unavailable notice anymore: Amber mode signs personal comments.
      expect(
        find.text("Comments aren't available for this task yet"),
        findsNothing,
      );
      expect(find.text('hello'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'amber comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(repository.addCalls, hasLength(1));
      expect(repository.addCalls.single.groupId, isNull);
    },
  );

  testWidgets('personal task in secret-key mode: input is enabled', (
    tester,
  ) async {
    final repository = _FakeTaskCommentRepository([]);

    await tester.pumpWidget(
      _wrap(
        const TaskCommentSection(taskId: 'task-1'),
        repository: repository,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'personal note');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(repository.addCalls, hasLength(1));
    expect(repository.addCalls.single.groupId, isNull);
  });

  group('send outbox status marker', () {
    int nowEpochSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // The label is driven by wall-clock age since queuedAt (how long the
    // user has waited), not by attempts — attempts is a function of the
    // retry service's backoff tuning, not of elapsed wait time.
    OutboxEntry entry(String addressableId, {required int queuedAt}) =>
        OutboxEntry(
          eventId: 'ev-$addressableId',
          eventJson: '{}',
          kind: 35002,
          queuedAt: queuedAt,
          addressableId: addressableId,
        );

    testWidgets(
      'own comment just queued (below visibleAfter) shows "Sending…", and '
      'is already tappable',
      (tester) async {
        final repository = _FakeTaskCommentRepository([_comment('c1')]);

        await tester.pumpWidget(
          _wrap(
            const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
            repository: repository,
            pendingOutbox: {'c1': entry('c1', queuedAt: nowEpochSeconds())},
          ),
        );
        await tester.pump();

        expect(find.text('Sending…'), findsOneWidget);
        expect(find.textContaining('Unsent'), findsNothing);
        // Tappable from the moment it is queued, not only once stale.
        await tester.tap(find.text('Sending…'));
        await tester.pump();
      },
    );

    testWidgets(
      'own comment already delivered (not in outbox) shows no marker',
      (tester) async {
        final repository = _FakeTaskCommentRepository([_comment('c1')]);

        await tester.pumpWidget(
          _wrap(
            const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
            repository: repository,
            // Negative control: empty outbox map, same comment as above.
          ),
        );
        await tester.pump();

        expect(find.text('Sending…'), findsNothing);
        expect(find.textContaining('Unsent'), findsNothing);
      },
    );

    testWidgets(
      'own comment queued past visibleAfter shows "Unsent · tap to retry"',
      (tester) async {
        final repository = _FakeTaskCommentRepository([_comment('c1')]);
        final staleQueuedAt =
            nowEpochSeconds() - OutboxEntry.visibleAfter.inSeconds - 5;

        await tester.pumpWidget(
          _wrap(
            const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
            repository: repository,
            pendingOutbox: {'c1': entry('c1', queuedAt: staleQueuedAt)},
          ),
        );
        await tester.pump();

        expect(find.text('Unsent · tap to retry'), findsOneWidget);
        // Tapping the marker must not throw, even though this test's fake
        // outbox datasource is decoupled from pendingCommentOutboxProvider.
        await tester.tap(find.text('Unsent · tap to retry'));
        await tester.pump();
      },
    );

    testWidgets("other member's comment never shows a send marker", (
      tester,
    ) async {
      const otherPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final repository = _FakeTaskCommentRepository([
        TaskComment(
          commentId: 'c1',
          taskId: 'task-1',
          authorPubkey: otherPubkey,
          body: 'from someone else',
          createdAt: 1756800000,
        ),
      ]);
      final staleQueuedAt =
          nowEpochSeconds() - OutboxEntry.visibleAfter.inSeconds - 5;

      await tester.pumpWidget(
        _wrap(
          const TaskCommentSection(taskId: 'task-1', groupId: 'group-1'),
          repository: repository,
          // Even if the id coincidentally matched an outbox entry, other
          // members' bubbles must stay unmarked.
          pendingOutbox: {'c1': entry('c1', queuedAt: staleQueuedAt)},
        ),
      );
      await tester.pump();

      expect(find.text('Unsent · tap to retry'), findsNothing);
      expect(find.text('Sending…'), findsNothing);
    });
  });
}
