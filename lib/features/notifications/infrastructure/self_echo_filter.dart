/// Self-echo suppression for shared-task comment notifications.
///
/// Every member of a shared task signs with the same group key
/// (`PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`), so **the event envelope's `pubkey`
/// never reveals who actually wrote a comment** — it is always the group
/// npub. The only place authorship survives is the decrypted payload's
/// `author_pubkey` field. Comparing against the envelope here would suppress
/// nothing (every author looks like the group) or suppress everything
/// (depending on which side of the comparison "wins"); both are wrong.
library;

/// Returns true if [payloadAuthorPubkey] (the decrypted comment's own author
/// field, `NotificationPayload.authorPubkey`) is the local user
/// ([localPubkeyHex]) — i.e. this comment should **not** be notified because
/// it is an echo of the user's own write.
bool isSelfEcho({
  required String payloadAuthorPubkey,
  required String localPubkeyHex,
}) {
  return payloadAuthorPubkey == localPubkeyHex;
}
