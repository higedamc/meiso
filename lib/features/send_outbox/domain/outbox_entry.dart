/// One entry in the send outbox (a signed event).
///
/// The queue holds the signed event JSON itself, by design: retrying needs
/// no key material (which signing path produced it — Amber or secret-key —
/// never leaks in here). Spec: `PLANS/MEISO_SEND_OUTBOX_LEAF.md`.
class OutboxEntry {
  const OutboxEntry({
    required this.eventId,
    required this.eventJson,
    required this.kind,
    required this.queuedAt,
    this.addressableId,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      eventId: json['event_id'] as String,
      eventJson: json['event_json'] as String,
      kind: (json['kind'] as num).toInt(),
      queuedAt: (json['queued_at'] as num).toInt(),
      addressableId: json['addressable_id'] as String?,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: (json['last_attempt_at'] as num?)?.toInt(),
      lastError: json['last_error'] as String?,
    );
  }

  /// The signed event's id (64-char lowercase hex). Also the box's primary key.
  final String eventId;

  /// Signed JSON, passable as-is to `sendSignedEvent`.
  final String eventJson;

  /// Event kind, for monitoring/debugging only.
  final int kind;

  /// Unix seconds when this entry first entered the queue.
  final int queuedAt;

  /// The addressable event's `d` tag value (for task comments, the
  /// commentId). Lets the UI join "unsent" status onto `TaskComment` without
  /// a schema change — join on this, not on the event id.
  final String? addressableId;

  /// Number of send attempts so far.
  final int attempts;

  /// Unix seconds of the last attempt.
  final int? lastAttemptAt;

  /// The last `errorMessage`. Never the event content (comment body).
  final String? lastError;

  OutboxEntry copyWith({
    int? attempts,
    int? lastAttemptAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return OutboxEntry(
      eventId: eventId,
      eventJson: eventJson,
      kind: kind,
      queuedAt: queuedAt,
      addressableId: addressableId,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      // `lastError: null` alone is indistinguishable from "leave unchanged"
      // under `??`, so clearing it needs its own flag.
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'event_json': eventJson,
    'kind': kind,
    'queued_at': queuedAt,
    'addressable_id': addressableId,
    'attempts': attempts,
    'last_attempt_at': lastAttemptAt,
    'last_error': lastError,
  };

  /// Max queue size. Capping only the count still allows unbounded growth if
  /// a single entry can be arbitrarily large, so this is paired with
  /// [maxEventJsonBytes]. New entries are rejected once this is hit (old
  /// entries are never silently evicted).
  static const int maxEntries = 200;

  /// Max `eventJson` bytes per entry. Oversized payloads are rejected before
  /// entering the queue — rejecting after admission would mean "it was
  /// queued, then vanished", which is the exact silent loss this exists to
  /// prevent.
  static const int maxEventJsonBytes = 64 * 1024;

  /// Wall-clock age after which a still-queued entry shows "Unsent" instead
  /// of "Sending…" in the UI. Based on how long the user has been waiting,
  /// not on [attempts] — that counter is a function of the retry service's
  /// backoff tuning, not of elapsed wait time.
  static const Duration visibleAfter = Duration(seconds: 30);
}
