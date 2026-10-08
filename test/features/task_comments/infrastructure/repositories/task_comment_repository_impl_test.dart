import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show EventSendResult;
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/send_outbox/application/send_outbox_service.dart';
import 'package:meiso/features/shared_list/domain/entities/shared_group_credentials.dart';
import 'package:meiso/features/shared_list/infrastructure/datasources/shared_group_key_local_datasource.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_crypto_datasource_contract.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/repositories/task_comment_repository_impl.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:mocktail/mocktail.dart';

/// Fake that never touches Rust FFI: "encryption" is the identity map,
/// putting plaintext straight into content. Event id / created_at increase
/// monotonically per call.
class FakeTaskCommentCryptoDataSource implements TaskCommentCryptoDataSource {
  FakeTaskCommentCryptoDataSource({this.baseCreatedAt = 1787900000});

  final int baseCreatedAt;
  int _counter = 0;

  /// Set to false to simulate the personal path being unable to sign (no
  /// session key / Amber rejected); the personal-path methods then throw,
  /// same as the real implementation.
  bool personalSigningAvailable = true;

  @override
  Future<String> buildSignedCommentEvent({
    required String nsecHex,
    required String commentJson,
  }) async {
    _counter++;
    return jsonEncode({
      'id': 'event_${_counter.toString().padLeft(4, '0')}',
      'kind': 35002,
      'created_at': baseCreatedAt + _counter,
      'content': commentJson,
      'tags': [
        ['d', 'dummy'],
      ],
    });
  }

  @override
  Future<String> decryptCommentEvent({
    required String nsecHex,
    required String eventJson,
  }) async {
    final map = jsonDecode(eventJson) as Map<String, dynamic>;
    return map['content'] as String;
  }

  @override
  Future<String> buildSignedPersonalCommentEvent({
    required String commentJson,
  }) async {
    if (!personalSigningAvailable) {
      throw Exception('Cannot sign personal comment (no key / Amber rejected)');
    }
    return buildSignedCommentEvent(
      nsecHex: 'personal',
      commentJson: commentJson,
    );
  }

  @override
  Future<String> decryptPersonalCommentEvent({
    required String eventJson,
  }) async {
    if (!personalSigningAvailable) {
      throw Exception('Cannot decrypt personal comment (no key / Amber rejected)');
    }
    return decryptCommentEvent(nsecHex: 'personal', eventJson: eventJson);
  }
}

class MockNostrService extends Mock implements NostrService {}

class MockSharedGroupKeyLocalDataSource extends Mock
    implements SharedGroupKeyLocalDataSource {}

class MockSendOutboxService extends Mock implements SendOutboxService {}

const String kAuthorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const String kGroupId = 'group-1';

EventSendResult _sendOk() => EventSendResult(
  eventId: 'relay-accepted',
  success: true,
  successfulRelays: BigInt.one,
  failedRelays: BigInt.zero,
  timedOut: false,
);

EventSendResult _sendFail() => EventSendResult(
  eventId: '',
  success: false,
  successfulRelays: BigInt.zero,
  failedRelays: BigInt.zero,
  timedOut: true,
  errorMessage: 'Timeout after 3 seconds',
);

/// Builds a relay-received event JSON.
String _remoteEventJson({
  required String eventId,
  required int eventCreatedAt,
  required TaskComment payload,
}) {
  return jsonEncode({
    'id': eventId,
    'kind': 35002,
    'created_at': eventCreatedAt,
    'content': jsonEncode(payload.toJson()),
    'tags': [
      ['d', payload.commentId],
    ],
  });
}

void main() {
  late Directory tempDir;
  late Box<Map<dynamic, dynamic>> box;
  late TaskCommentLocalDataSourceHive localDataSource;
  late FakeTaskCommentCryptoDataSource cryptoDataSource;
  late MockNostrService nostrService;
  late MockSharedGroupKeyLocalDataSource keyDataSource;
  late MockSendOutboxService outboxService;
  late TaskCommentRepositoryImpl repository;
  var boxSeq = 0;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('task_comments_test');
    Hive.init(tempDir.path);
    boxSeq++;
    box = await Hive.openBox<Map<dynamic, dynamic>>('task_comments_$boxSeq');
    localDataSource = TaskCommentLocalDataSourceHive(box: box);
    cryptoDataSource = FakeTaskCommentCryptoDataSource();
    nostrService = MockNostrService();
    keyDataSource = MockSharedGroupKeyLocalDataSource();
    outboxService = MockSendOutboxService();

    when(
      () => nostrService.getPublicKey(),
    ).thenAnswer((_) async => kAuthorPubkey);
    when(
      () => nostrService.sendSignedEvent(any()),
    ).thenAnswer((_) async => _sendOk());
    when(() => keyDataSource.load(kGroupId)).thenAnswer(
      (_) async => SharedGroupCredentials(
        groupId: kGroupId,
        groupNsecHex: 'f' * 64,
        groupNpubHex: 'e' * 64,
      ),
    );
    when(
      () => outboxService.enqueue(
        eventId: any(named: 'eventId'),
        eventJson: any(named: 'eventJson'),
        kind: any(named: 'kind'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const Right(unit));

    repository = TaskCommentRepositoryImpl(
      cryptoDataSource: cryptoDataSource,
      localDataSource: localDataSource,
      keyDataSource: keyDataSource,
      nostrService: nostrService,
      outboxService: outboxService,
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('addComment', () {
    test('shared-list path: signs, stores locally, then publishes', () async {
      final result = await repository.addComment(
        taskId: 'task-1',
        body: 'hello bees',
        groupId: kGroupId,
      );

      expect(result.isRight(), true);
      verify(() => nostrService.sendSignedEvent(any())).called(1);

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1));
      expect(stored.first.body, 'hello bees');
      expect(stored.first.authorPubkey, kAuthorPubkey);
      expect(stored.first.deleted, false);
    });

    test('empty body yields ValidationFailure', () async {
      final result = await repository.addComment(
        taskId: 'task-1',
        body: '   ',
        groupId: kGroupId,
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('should be Left'),
      );
      verifyNever(() => nostrService.sendSignedEvent(any()));
    });

    test('personal task: signs via the personal path, stores, publishes', () async {
      final result = await repository.addComment(
        taskId: 'task-1',
        body: 'personal comment',
      );

      expect(result.isRight(), true);
      verify(() => nostrService.sendSignedEvent(any())).called(1);
      // The group-key path is never touched (personal path is self-contained).
      verifyNever(() => keyDataSource.load(any()));

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1));
      expect(stored.first.body, 'personal comment');
      expect(stored.first.authorPubkey, kAuthorPubkey);
    });

    test(
      'personal task: unable to sign (no key / Amber rejected) yields '
      'AuthFailure',
      () async {
        cryptoDataSource.personalSigningAvailable = false;

        final result = await repository.addComment(
          taskId: 'task-1',
          body: 'personal comment',
        );

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('should be Left'),
        );
        verifyNever(() => nostrService.sendSignedEvent(any()));
        // Fail-closed: nothing is stored locally either.
        final stored = await localDataSource.loadComments('task-1');
        expect(stored, isEmpty);
      },
    );
  });

  group('send-outbox handoff', () {
    test(
      'publish failure enqueues to the outbox with the comment id as '
      'addressableId',
      () async {
        when(
          () => nostrService.sendSignedEvent(any()),
        ).thenAnswer((_) async => _sendFail());

        final result = await repository.addComment(
          taskId: 'task-1',
          body: 'will be queued',
          groupId: kGroupId,
        );

        // Already stored locally, so still Right ("sent but not delivered"
        // is a state, not a failure).
        expect(result.isRight(), true);
        final comment = result.getOrElse(() => fail('should be Right'));

        final captured = verify(
          () => outboxService.enqueue(
            eventId: any(named: 'eventId'),
            eventJson: any(named: 'eventJson'),
            kind: captureAny(named: 'kind'),
            addressableId: captureAny(named: 'addressableId'),
          ),
        ).captured;
        expect(captured, [35002, comment.commentId]);

        final stored = await localDataSource.loadComments('task-1');
        expect(stored, hasLength(1));
        expect(stored.first.body, 'will be queued');
      },
    );

    test('publish success never enqueues to the outbox (negative control)', () async {
      // The default setUp answers _sendOk(), so enqueue must never be
      // called. The preceding failure test flips send to failing and shows
      // enqueue getting called — proof this assertion has teeth.
      final result = await repository.addComment(
        taskId: 'task-1',
        body: 'delivered on first try',
        groupId: kGroupId,
      );

      expect(result.isRight(), true);
      verifyNever(
        () => outboxService.enqueue(
          eventId: any(named: 'eventId'),
          eventJson: any(named: 'eventJson'),
          kind: any(named: 'kind'),
          addressableId: any(named: 'addressableId'),
        ),
      );
    });

    test(
      'publish failure AND a full outbox propagates the outbox failure as '
      'Left, instead of silently losing the comment a second way',
      () async {
        when(
          () => nostrService.sendSignedEvent(any()),
        ).thenAnswer((_) async => _sendFail());
        when(
          () => outboxService.enqueue(
            eventId: any(named: 'eventId'),
            eventJson: any(named: 'eventJson'),
            kind: any(named: 'kind'),
            addressableId: any(named: 'addressableId'),
          ),
        ).thenAnswer(
          (_) async =>
              const Left(ValidationFailure('Send outbox: queue is full')),
        );

        final result = await repository.addComment(
          taskId: 'task-1',
          body: 'cannot even be queued',
          groupId: kGroupId,
        );

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('should be Left'),
        );
        // Negative control: still stored locally — the Left reports the
        // retry-tracking failure, not a rollback of the local write.
        final stored = await localDataSource.loadComments('task-1');
        expect(stored, hasLength(1));
        expect(stored.first.body, 'cannot even be queued');
      },
    );
  });

  group('applyRemoteCommentEvent (LWW)', () {
    const comment = TaskComment(
      commentId: 'c-1',
      taskId: 'task-1',
      authorPubkey: kAuthorPubkey,
      body: 'original',
      createdAt: 1787900000,
    );

    test('a newer event overwrites older stored content (created_at ascending)', () async {
      final first = await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-a',
          eventCreatedAt: 1787900100,
          payload: comment,
        ),
        groupId: kGroupId,
      );
      expect(first.isRight(), true);

      final second = await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-b',
          eventCreatedAt: 1787900200,
          payload: comment.copyWith(body: 'edited', editedAt: 1787900200),
        ),
        groupId: kGroupId,
      );
      expect(second.isRight(), true);

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1));
      expect(stored.first.body, 'edited');
      expect(stored.first.editedAt, 1787900200);
    });

    test('an older event does not overwrite newer stored content', () async {
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-b',
          eventCreatedAt: 1787900200,
          payload: comment.copyWith(body: 'newest', editedAt: 1787900200),
        ),
        groupId: kGroupId,
      );

      final stale = await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-a',
          eventCreatedAt: 1787900100,
          payload: comment,
        ),
        groupId: kGroupId,
      );
      expect(stale.isRight(), true); // Skipping the apply still counts as success

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1));
      expect(stored.first.body, 'newest');
    });

    test('same-second events break ties by event_id lexical order (higher wins)', () async {
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-b',
          eventCreatedAt: 1787900100,
          payload: comment.copyWith(body: 'from ev-b'),
        ),
        groupId: kGroupId,
      );

      // Same second, but lexically smaller event id -> not applied
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-a',
          eventCreatedAt: 1787900100,
          payload: comment.copyWith(body: 'from ev-a'),
        ),
        groupId: kGroupId,
      );

      final stored = await localDataSource.loadComments('task-1');
      expect(stored.first.body, 'from ev-b');
    });

    test('anything other than kind:35002 yields ValidationFailure', () async {
      final result = await repository.applyRemoteCommentEvent(
        eventJson: jsonEncode({
          'id': 'ev-x',
          'kind': 35000,
          'created_at': 1787900100,
          'content': 'whatever',
        }),
        groupId: kGroupId,
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('should be Left'),
      );
    });

    test('an oversized body is clamped to 2000 chars on the read side', () async {
      final hostile = comment.copyWith(body: 'x' * 5000);
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-a',
          eventCreatedAt: 1787900100,
          payload: hostile,
        ),
        groupId: kGroupId,
      );

      final stored = await localDataSource.loadComments('task-1');
      expect(stored.first.body.length, maxCommentBodyChars);
    });

    test('clamping does not split a surrogate pair (emoji)', () async {
      // A body whose 2000th code point is an emoji (2 UTF-16 code units).
      // A UTF-16 substring would leave a lone surrogate and break JSON encoding.
      final hostile = comment.copyWith(body: '🐝' * 3000);
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-emoji',
          eventCreatedAt: 1787900200,
          payload: hostile,
        ),
        groupId: kGroupId,
      );

      final stored = await localDataSource.loadComments('task-1');
      final body = stored.first.body;
      expect(body.runes.length, maxCommentBodyChars);
      // No lone surrogate -> round-trips through JSON unchanged.
      expect(jsonDecode(jsonEncode(body)), body);
      expect(body.runes.every((r) => r == 0x1F41D), true);
    });
  });

  group('deleteComment (tombstone)', () {
    test('tombstone stays stored, with deleted=true and an empty body', () async {
      final added = await repository.addComment(
        taskId: 'task-1',
        body: 'to be deleted',
        groupId: kGroupId,
      );
      final comment = added.getOrElse(() => fail('addComment failed'));

      final deleted = await repository.deleteComment(
        comment: comment,
        groupId: kGroupId,
      );
      expect(deleted.isRight(), true);

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1)); // remains as a tombstone
      expect(stored.first.deleted, true);
      expect(stored.first.body, '');
      expect(stored.first.commentId, comment.commentId);
    });
  });

  group('watchComments', () {
    test('streams in created_at ascending order', () async {
      const older = TaskComment(
        commentId: 'c-old',
        taskId: 'task-1',
        authorPubkey: kAuthorPubkey,
        body: 'older',
        createdAt: 1787900000,
      );
      const newer = TaskComment(
        commentId: 'c-new',
        taskId: 'task-1',
        authorPubkey: kAuthorPubkey,
        body: 'newer',
        createdAt: 1787900500,
      );

      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-n',
          eventCreatedAt: 1787900500,
          payload: newer,
        ),
        groupId: kGroupId,
      );
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-o',
          eventCreatedAt: 1787900000,
          payload: older,
        ),
        groupId: kGroupId,
      );

      final first = await repository.watchComments(taskId: 'task-1').first;
      expect(first.map((c) => c.commentId).toList(), ['c-old', 'c-new']);
    });
  });

  group('TaskCommentLocalDataSourceHive.wipe', () {
    test('closes the box and deletes its backing file (for logout)', () async {
      final wipeBox = await Hive.openBox<Map<dynamic, dynamic>>(
        'task_comments_wipe',
      );
      final dataSource = TaskCommentLocalDataSourceHive(box: wipeBox);
      await dataSource.upsert(
        comment: const TaskComment(
          commentId: 'c-wipe',
          taskId: 'task-w',
          authorPubkey: kAuthorPubkey,
          body: 'to be wiped',
          createdAt: 1787900000,
        ),
        eventCreatedAt: 1787900000,
        eventId: 'ev-wipe',
      );
      final file = File('${tempDir.path}/task_comments_wipe.hive');
      expect(file.existsSync(), true);

      await dataSource.wipe();

      expect(wipeBox.isOpen, false);
      expect(file.existsSync(), false);
    });
  });
}
