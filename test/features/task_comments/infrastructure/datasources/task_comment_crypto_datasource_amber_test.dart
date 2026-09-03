import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_crypto_datasource_amber.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_crypto_datasource_contract.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/services/amber_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAmberService extends Mock implements AmberService {}

class MockNostrService extends Mock implements NostrService {}

class MockEnvelopeDataSource extends Mock
    implements TaskCommentEnvelopeDataSource {}

class MockGroupKeyDataSource extends Mock
    implements TaskCommentCryptoDataSource {}

const String kOwnPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String kOwnNpub = 'npub1self';

String _commentJson({String commentId = 'c-1'}) {
  return jsonEncode({
    'v': 1,
    'comment_id': commentId,
    'task_id': 'task-1',
    'author_pubkey': kOwnPubkey,
    'body': 'hello from amber',
    'created_at': 1787900000,
    'deleted': false,
  });
}

String _eventJson({List<List<String>> tags = const [
  ['d', 'c-1'],
]}) {
  return jsonEncode({
    'id': 'ev-1',
    'kind': 35002,
    'pubkey': kOwnPubkey,
    'created_at': 1787900100,
    'content': 'ciphertext-on-relay',
    'tags': tags,
    'sig': 'f' * 128,
  });
}

void main() {
  late MockAmberService amber;
  late MockNostrService nostr;
  late MockEnvelopeDataSource envelope;
  late MockGroupKeyDataSource groupKey;
  late TaskCommentCryptoDataSourceAmber dataSource;

  setUp(() {
    amber = MockAmberService();
    nostr = MockNostrService();
    envelope = MockEnvelopeDataSource();
    groupKey = MockGroupKeyDataSource();
    dataSource = TaskCommentCryptoDataSourceAmber(
      envelopeDataSource: envelope,
      amberService: amber,
      nostrService: nostr,
      groupKeyDataSource: groupKey,
    );

    when(() => nostr.getPublicKey()).thenAnswer((_) async => kOwnPubkey);
    when(() => nostr.hexToNpub(kOwnPubkey)).thenAnswer((_) async => kOwnNpub);
  });

  group('buildSignedPersonalCommentEvent', () {
    setUp(() {
      when(
        () => envelope.validateDecryptedCommentPayload(
          plaintextJson: any(named: 'plaintextJson'),
          expectedCommentId: any(named: 'expectedCommentId'),
          expectedAuthorPubkeyHex: any(named: 'expectedAuthorPubkeyHex'),
        ),
      ).thenAnswer((_) async => 'normalized-payload');
      when(
        () => amber.encryptNip44WithContentProvider(
          plaintext: any(named: 'plaintext'),
          pubkey: any(named: 'pubkey'),
          npub: any(named: 'npub'),
        ),
      ).thenAnswer((_) async => 'amber-ciphertext');
      when(
        () => envelope.buildUnsignedCommentEvent(
          authorPubkeyHex: any(named: 'authorPubkeyHex'),
          commentId: any(named: 'commentId'),
          encryptedContent: any(named: 'encryptedContent'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => 'unsigned-event');
    });

    test('検証→自己暗号化→未署名構築→ContentProvider 署名の順で通る', () async {
      when(
        () => amber.signEventWithContentProvider(
          event: any(named: 'event'),
          npub: any(named: 'npub'),
        ),
      ).thenAnswer((_) async => 'signed-event');

      final signed = await dataSource.buildSignedPersonalCommentEvent(
        commentJson: _commentJson(),
      );

      expect(signed, 'signed-event');
      // 書き込み側検証は Rust(envelope)へ: payload の comment_id と自鍵で照合
      verify(
        () => envelope.validateDecryptedCommentPayload(
          plaintextJson: _commentJson(),
          expectedCommentId: 'c-1',
          expectedAuthorPubkeyHex: kOwnPubkey,
        ),
      ).called(1);
      // 自己暗号化: NIP-44 の相手先は自分自身の pubkey
      verify(
        () => amber.encryptNip44WithContentProvider(
          plaintext: 'normalized-payload',
          pubkey: kOwnPubkey,
          npub: kOwnNpub,
        ),
      ).called(1);
      verify(
        () => envelope.buildUnsignedCommentEvent(
          authorPubkeyHex: kOwnPubkey,
          commentId: 'c-1',
          encryptedContent: 'amber-ciphertext',
          createdAt: any(named: 'createdAt', that: greaterThan(0)),
        ),
      ).called(1);
      verify(
        () => amber.signEventWithContentProvider(
          event: 'unsigned-event',
          npub: kOwnNpub,
        ),
      ).called(1);
      verifyNever(() => amber.signEventWithTimeout(any()));
    });

    test('ContentProvider 署名失敗時は intent 経路にフォールバックする', () async {
      when(
        () => amber.signEventWithContentProvider(
          event: any(named: 'event'),
          npub: any(named: 'npub'),
        ),
      ).thenThrow(PlatformException(code: 'AMBER_REJECTED'));
      when(
        () => amber.signEventWithTimeout(any()),
      ).thenAnswer((_) async => 'signed-via-intent');

      final signed = await dataSource.buildSignedPersonalCommentEvent(
        commentJson: _commentJson(),
      );

      expect(signed, 'signed-via-intent');
      verify(() => amber.signEventWithTimeout('unsigned-event')).called(1);
    });

    test('暗号化の AMBER_REJECTED は握り潰さず伝播する', () async {
      when(
        () => amber.encryptNip44WithContentProvider(
          plaintext: any(named: 'plaintext'),
          pubkey: any(named: 'pubkey'),
          npub: any(named: 'npub'),
        ),
      ).thenThrow(PlatformException(code: 'AMBER_REJECTED'));

      await expectLater(
        dataSource.buildSignedPersonalCommentEvent(
          commentJson: _commentJson(),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'AMBER_REJECTED',
          ),
        ),
      );
      verifyNever(
        () => amber.signEventWithContentProvider(
          event: any(named: 'event'),
          npub: any(named: 'npub'),
        ),
      );
    });

    test('公開鍵が取れなければ何も呼ばずに失敗する', () async {
      when(() => nostr.getPublicKey()).thenAnswer((_) async => null);

      await expectLater(
        dataSource.buildSignedPersonalCommentEvent(
          commentJson: _commentJson(),
        ),
        throwsA(isA<StateError>()),
      );
      verifyZeroInteractions(envelope);
      verifyZeroInteractions(amber);
    });
  });

  group('decryptPersonalCommentEvent', () {
    setUp(() {
      when(
        () => envelope.verifySignedCommentEnvelope(
          eventJson: any(named: 'eventJson'),
          expectedAuthorPubkeyHex: any(named: 'expectedAuthorPubkeyHex'),
        ),
      ).thenAnswer((_) async => 'verified-ciphertext');
      when(
        () => amber.decryptNip44WithContentProvider(
          ciphertext: any(named: 'ciphertext'),
          pubkey: any(named: 'pubkey'),
          npub: any(named: 'npub'),
        ),
      ).thenAnswer((_) async => 'amber-plaintext');
      when(
        () => envelope.validateDecryptedCommentPayload(
          plaintextJson: any(named: 'plaintextJson'),
          expectedCommentId: any(named: 'expectedCommentId'),
          expectedAuthorPubkeyHex: any(named: 'expectedAuthorPubkeyHex'),
        ),
      ).thenAnswer((_) async => 'normalized-payload');
    });

    test('envelope 検証→Amber 復号→payload 検証の順で通る', () async {
      final result = await dataSource.decryptPersonalCommentEvent(
        eventJson: _eventJson(),
      );

      expect(result, 'normalized-payload');
      verify(
        () => envelope.verifySignedCommentEnvelope(
          eventJson: _eventJson(),
          expectedAuthorPubkeyHex: kOwnPubkey,
        ),
      ).called(1);
      // Amber へ渡るのは envelope 検証済みの暗号文だけ
      verify(
        () => amber.decryptNip44WithContentProvider(
          ciphertext: 'verified-ciphertext',
          pubkey: kOwnPubkey,
          npub: kOwnNpub,
        ),
      ).called(1);
      // 復号平文は d タグ(c-1)と自鍵で必ず再検証される
      verify(
        () => envelope.validateDecryptedCommentPayload(
          plaintextJson: 'amber-plaintext',
          expectedCommentId: 'c-1',
          expectedAuthorPubkeyHex: kOwnPubkey,
        ),
      ).called(1);
    });

    test('envelope 検証に失敗したら Amber へは何も渡らない', () async {
      when(
        () => envelope.verifySignedCommentEnvelope(
          eventJson: any(named: 'eventJson'),
          expectedAuthorPubkeyHex: any(named: 'expectedAuthorPubkeyHex'),
        ),
      ).thenThrow(Exception('signature verification failed'));

      await expectLater(
        dataSource.decryptPersonalCommentEvent(eventJson: _eventJson()),
        throwsA(isA<Exception>()),
      );
      verifyZeroInteractions(amber);
    });

    test('復号の AMBER_REJECTED は握り潰さず伝播する', () async {
      when(
        () => amber.decryptNip44WithContentProvider(
          ciphertext: any(named: 'ciphertext'),
          pubkey: any(named: 'pubkey'),
          npub: any(named: 'npub'),
        ),
      ).thenThrow(PlatformException(code: 'AMBER_REJECTED'));

      await expectLater(
        dataSource.decryptPersonalCommentEvent(eventJson: _eventJson()),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'AMBER_REJECTED',
          ),
        ),
      );
      // 平文検証まで到達しない(検証をスキップした entity 化はしない)
      verifyNever(
        () => envelope.validateDecryptedCommentPayload(
          plaintextJson: any(named: 'plaintextJson'),
          expectedCommentId: any(named: 'expectedCommentId'),
          expectedAuthorPubkeyHex: any(named: 'expectedAuthorPubkeyHex'),
        ),
      );
    });
  });

  group('共有リスト経路', () {
    test('グループ鍵メソッドは Rust 実装へ委譲し Amber を使わない', () async {
      when(
        () => groupKey.buildSignedCommentEvent(
          nsecHex: any(named: 'nsecHex'),
          commentJson: any(named: 'commentJson'),
        ),
      ).thenAnswer((_) async => 'group-signed');
      when(
        () => groupKey.decryptCommentEvent(
          nsecHex: any(named: 'nsecHex'),
          eventJson: any(named: 'eventJson'),
        ),
      ).thenAnswer((_) async => 'group-plaintext');

      final signed = await dataSource.buildSignedCommentEvent(
        nsecHex: 'f' * 64,
        commentJson: _commentJson(),
      );
      final plaintext = await dataSource.decryptCommentEvent(
        nsecHex: 'f' * 64,
        eventJson: _eventJson(),
      );

      expect(signed, 'group-signed');
      expect(plaintext, 'group-plaintext');
      verifyZeroInteractions(amber);
      verifyZeroInteractions(envelope);
    });
  });
}
