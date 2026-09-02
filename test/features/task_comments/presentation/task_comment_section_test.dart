import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/domain/repositories/task_comment_repository.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/features/task_comments/presentation/widgets/task_comment_section.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/providers/nostr_provider.dart';

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
}) {
  return ProviderScope(
    overrides: [
      taskCommentRepositoryProvider.overrideWithValue(repository),
      publicKeyProvider.overrideWith((ref) => _myPubkey),
      isAmberModeProvider.overrideWithValue(amberMode),
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
    'personal task in Amber mode: shows unavailable notice, no input',
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

      expect(
        find.text("Comments aren't available for this task yet"),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      // Existing synced comments stay visible even while input is disabled.
      expect(find.text('hello'), findsOneWidget);
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
}
