import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/infrastructure/comment_notification_mapper.dart';

const String _eventId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _authorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final DateTime _fixedNow = DateTime.utc(2026, 9, 8);

Map<String, dynamic> _decryptedComment({
  String commentId = 'c1',
  String taskId = 't1',
  String authorPubkey = _authorPubkey,
  String body = 'hello',
  int createdAt = 1788514631,
  bool deleted = false,
}) => {
  'v': 1,
  'comment_id': commentId,
  'task_id': taskId,
  'author_pubkey': authorPubkey,
  'body': body,
  'created_at': createdAt,
  'deleted': deleted,
};

void main() {
  group('mapDecryptedCommentToNotificationPayload', () {
    test('maps a well-formed decrypted comment', () {
      final payload = mapDecryptedCommentToNotificationPayload(
        envelopeEventId: _eventId,
        envelopeCreatedAt: 1788514700,
        groupId: 'g1',
        decryptedCommentJson: _decryptedComment(),
        now: _fixedNow,
      );
      expect(payload, isNotNull);
      expect(payload!.eventId, _eventId);
      expect(payload.commentId, 'c1');
      expect(payload.taskId, 't1');
      expect(payload.groupId, 'g1');
      expect(payload.authorPubkey, _authorPubkey);
      expect(payload.body, 'hello');
    });

    test(
      'uses the envelope created_at, not the decrypted payload one — '
      'the envelope is what the relay orders by and what since resumes '
      'from; an edited comment can keep its original payload created_at',
      () {
        final payload = mapDecryptedCommentToNotificationPayload(
          envelopeEventId: _eventId,
          envelopeCreatedAt: 1788514700,
          groupId: 'g1',
          decryptedCommentJson: _decryptedComment(createdAt: 1),
          now: _fixedNow,
        );
        expect(payload!.createdAt, 1788514700);
      },
    );

    test('returns null for a tombstone (deleted:true)', () {
      final payload = mapDecryptedCommentToNotificationPayload(
        envelopeEventId: _eventId,
        envelopeCreatedAt: 1788514700,
        groupId: 'g1',
        decryptedCommentJson: _decryptedComment(deleted: true, body: ''),
        now: _fixedNow,
      );
      expect(payload, isNull);
    });

    test(
      'returns null instead of throwing on a malformed decrypted payload '
      '(third parties can write to the group relay; one bad event must '
      'not take the resident service down)',
      () {
        final payload = mapDecryptedCommentToNotificationPayload(
          envelopeEventId: _eventId,
          envelopeCreatedAt: 1788514700,
          groupId: 'g1',
          decryptedCommentJson: _decryptedComment(authorPubkey: 'not-hex'),
          now: _fixedNow,
        );
        expect(payload, isNull);
      },
    );

    test('rejects a non-hex64 envelope event id', () {
      final payload = mapDecryptedCommentToNotificationPayload(
        envelopeEventId: 'short',
        envelopeCreatedAt: 1788514700,
        groupId: 'g1',
        decryptedCommentJson: _decryptedComment(),
        now: _fixedNow,
      );
      expect(payload, isNull);
    });
  });
}
