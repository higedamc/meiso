import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show EventSendResult;
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/shared_list/domain/entities/shared_group_credentials.dart';
import 'package:meiso/features/shared_list/infrastructure/datasources/shared_group_key_local_datasource.dart';
import 'package:meiso/features/task_comments/domain/entities/task_comment.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_crypto_datasource_contract.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_local_datasource.dart';
import 'package:meiso/features/task_comments/infrastructure/repositories/task_comment_repository_impl.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:mocktail/mocktail.dart';

/// Rust FFI を使わない fake: 「暗号化」は content に平文をそのまま
/// 入れる恒等写像。イベント id / created_at は呼び出しごとに単調増加。
class FakeTaskCommentCryptoDataSource implements TaskCommentCryptoDataSource {
  FakeTaskCommentCryptoDataSource({this.baseCreatedAt = 1787900000});

  final int baseCreatedAt;
  int _counter = 0;

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
}

class MockNostrService extends Mock implements NostrService {}

class MockSharedGroupKeyLocalDataSource extends Mock
    implements SharedGroupKeyLocalDataSource {}

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

/// リレー受信イベント JSON を組み立てるヘルパー
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

    repository = TaskCommentRepositoryImpl(
      cryptoDataSource: cryptoDataSource,
      localDataSource: localDataSource,
      keyDataSource: keyDataSource,
      nostrService: nostrService,
      personalNsecHexResolver: () async => null,
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('addComment', () {
    test('共有リスト経路: 署名→ローカル保存→publish される', () async {
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

    test('本文が空なら ValidationFailure', () async {
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

    test('個人タスク: nsec 未解決なら AuthFailure(TODO: Phase 1a)', () async {
      final result = await repository.addComment(
        taskId: 'task-1',
        body: 'personal comment',
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('should be Left'),
      );
    });
  });

  group('applyRemoteCommentEvent (LWW)', () {
    const comment = TaskComment(
      commentId: 'c-1',
      taskId: 'task-1',
      authorPubkey: kAuthorPubkey,
      body: 'original',
      createdAt: 1787900000,
    );

    test('新しいイベントが古い保存内容を上書きする(created_at 昇順)', () async {
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

    test('古いイベントは新しい保存内容を上書きしない', () async {
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
      expect(stale.isRight(), true); // 適用スキップでも成功扱い

      final stored = await localDataSource.loadComments('task-1');
      expect(stored, hasLength(1));
      expect(stored.first.body, 'newest');
    });

    test('同秒イベントは event_id 辞書順で後勝ち', () async {
      await repository.applyRemoteCommentEvent(
        eventJson: _remoteEventJson(
          eventId: 'ev-b',
          eventCreatedAt: 1787900100,
          payload: comment.copyWith(body: 'from ev-b'),
        ),
        groupId: kGroupId,
      );

      // 同秒だが event id が辞書順で小さい → 適用されない
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

    test('kind:35002 以外は ValidationFailure', () async {
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

    test('過大な本文は読み取り側で 2000 文字にクランプされる', () async {
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

    test('クランプはサロゲートペア(絵文字)を分断しない', () async {
      // 2000 コードポイント目が絵文字(UTF-16 では 2 code unit)になる本文。
      // UTF-16 substring だと lone surrogate が残り JSON 化が壊れる。
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
      // lone surrogate が無い = そのまま JSON round-trip できる
      expect(jsonDecode(jsonEncode(body)), body);
      expect(body.runes.every((r) => r == 0x1F41D), true);
    });
  });

  group('deleteComment (tombstone)', () {
    test('tombstone は保存されたまま deleted=true / body 空になる', () async {
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
      expect(stored, hasLength(1)); // tombstone として残る
      expect(stored.first.deleted, true);
      expect(stored.first.body, '');
      expect(stored.first.commentId, comment.commentId);
    });
  });

  group('watchComments', () {
    test('created_at 昇順で流れる', () async {
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
}
