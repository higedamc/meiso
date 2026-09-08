import '../domain/notification_payload.dart';

/// Maps a decrypted `TaskCommentPayload` JSON (`rust/src/task_comments.rs`)
/// plus its Nostr envelope into a validated [NotificationPayload].
///
/// The decrypted JSON's fields originate from a group relay that third
/// parties can write to (any group member's client, or a spoofed event if
/// the group key ever leaks), so — even though `rust/src/task_comments.rs`
/// already runs its own `validate_comment_payload` — this always goes through
/// [NotificationPayload.tryFromJson] rather than constructing
/// [NotificationPayload] directly. That function's checks (hex64 shape,
/// length caps, body sanitization, `created_at` forward-skew bound) are the
/// single gate every leaf must pass through; re-deriving a subset of them
/// here would be the "first leaf to forget it opens the hole" the contract
/// warns about.
///
/// Returns null for a tombstone (`deleted: true`) — a deletion has an empty
/// body and nothing useful to show in a notification — or for a payload that
/// fails validation.
NotificationPayload? mapDecryptedCommentToNotificationPayload({
  required String envelopeEventId,
  required int envelopeCreatedAt,
  required String groupId,
  required Map<String, dynamic> decryptedCommentJson,
  DateTime? now,
}) {
  if (decryptedCommentJson['deleted'] == true) {
    return null;
  }
  return NotificationPayload.tryFromJson({
    'event_id': envelopeEventId,
    'comment_id': decryptedCommentJson['comment_id'],
    'task_id': decryptedCommentJson['task_id'],
    'group_id': groupId,
    'author_pubkey': decryptedCommentJson['author_pubkey'],
    'body': decryptedCommentJson['body'],
    // The envelope's created_at (what the relay orders by, and what `since`
    // resumes from), not the decrypted payload's own created_at field.
    // Editing a comment (see `TaskCommentPayload.edited_at`) republishes the
    // same `d` tag with a new envelope created_at but does not necessarily
    // change the payload's original created_at.
    'created_at': envelopeCreatedAt,
  }, now: now);
}
