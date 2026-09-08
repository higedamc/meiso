/// One notification's worth of data, handed from the background isolate to the
/// notification layer.
///
/// Design: see `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md` (Lead).
/// This is the **type shared by Leaf 1 (native), Leaf 2 (background isolate)
/// and Leaf 3 (UI)**, landed on main first as a contract.
///
/// It crosses the isolate boundary and (if needed) a MethodChannel, so it
/// **must stay JSON round-trippable**. Never put a Riverpod provider or a raw
/// Rust handle in here.
///
/// ## Why this type carries its own input validation
///
/// The values reaching it originate from events on a group relay, and
/// **third parties can write to that relay**. Every field can therefore hold
/// an attacker-chosen value. If validation were left to Leaf 2 and Leaf 3
/// separately, the first leaf to forget it opens the hole. Closing it here,
/// in the single gate all three leaves must pass through, avoids that.
library;

import 'package:characters/characters.dart';

/// Payload for a single notification.
class NotificationPayload {
  const NotificationPayload({
    required this.eventId,
    required this.commentId,
    required this.taskId,
    required this.groupId,
    required this.authorPubkey,
    required this.body,
    required this.createdAt,
  });

  /// Throws [FormatException] on malformed input.
  ///
  /// Types are checked explicitly instead of letting a cast throw `TypeError`
  /// so that **a bug in our own code (`Error`) is never conflated with
  /// malformed data arriving from outside (`Exception`)**. Conflating them
  /// pushes callers into swallowing `Error`.
  ///
  /// [now] exists for tests; it defaults to the current time.
  factory NotificationPayload.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    return NotificationPayload(
      eventId: _requireHex64(json, 'event_id'),
      commentId: _requireId(json, 'comment_id'),
      taskId: _requireId(json, 'task_id'),
      groupId: _requireId(json, 'group_id'),
      authorPubkey: _requireHex64(json, 'author_pubkey'),
      body: sanitizeBody(json['body'] is String ? json['body'] as String : ''),
      createdAt: _requireCreatedAt(json, now ?? DateTime.now()),
    );
  }

  /// Upper bound on notification body length, in grapheme clusters.
  ///
  /// A system notification only ever shows a few lines anyway. Without a cap,
  /// pushing a multi-megabyte body onto the relay lets an attacker grow the
  /// resident memory of the background isolate.
  static const int maxBodyCharacters = 500;

  /// Length cap for opaque ids (comment / task / group).
  ///
  /// These are app-assigned `d` tag values, not necessarily hex, so their
  /// shape cannot be constrained — but their length can. A store that caps
  /// only the number of entries, such as
  /// `NotificationPrefsKeys.deliveredEventIds`, is effectively uncapped if a
  /// single entry may be arbitrarily long.
  static const int maxIdLength = 128;

  /// Forward clock skew allowed on `created_at`, in seconds.
  ///
  /// Device and relay clocks do drift, so some slack is required — but it
  /// must not be unbounded. See the `NotificationPrefsKeys.lastSeenCreatedAt`
  /// docs for why.
  static const int maxFutureSkewSeconds = 24 * 60 * 60;

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Nostr event ids and public keys are defined to be 64-char lowercase hex.
  ///
  /// The shape is constrained not for tidiness but because **this value is
  /// stored on the device verbatim as an entry of the dedup list**. Requiring
  /// only "a non-empty string" would mean the entry-count cap bounds no
  /// number of bytes.
  static String _requireHex64(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || !_hex64.hasMatch(value)) {
      throw FormatException('$key is not a 64-char lowercase hex string');
    }
    return value;
  }

  static String _requireId(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty || value.length > maxIdLength) {
      throw FormatException(
        '$key is missing, empty, or longer than $maxIdLength',
      );
    }
    return value;
  }

  /// Validates `created_at`.
  ///
  /// **The forward bound is the point of this check.** Dart's
  /// `double.toInt()` saturates finite out-of-range values to
  /// `9223372036854775807` rather than throwing (measured on 3.11.4), so
  /// letting a value like `1e300` through would push `lastSeenCreatedAt` to
  /// the int64 ceiling and **every later legitimate event would be filtered
  /// out by `since`, permanently silencing notifications**. Nothing crashes,
  /// so nobody notices. A single event must not be able to mute the whole
  /// feature.
  static int _requireCreatedAt(Map<String, dynamic> json, DateTime now) {
    final value = json['created_at'];
    if (value is! num || !value.isFinite) {
      throw const FormatException('created_at is not a finite number');
    }
    final seconds = value.toInt();
    if (seconds <= 0) {
      throw const FormatException('created_at is not a positive unix time');
    }
    final limit =
        now.toUtc().millisecondsSinceEpoch ~/ 1000 + maxFutureSkewSeconds;
    if (seconds > limit) {
      throw const FormatException('created_at is too far in the future');
    }
    return seconds;
  }

  /// Renders a relay-supplied body into a form that is safe to display.
  ///
  /// Only two classes of character are removed: **bidirectional controls,
  /// which can reorder what is displayed**, and **zero-width fillers**.
  /// `U+200C` / `U+200D` (ZWNJ / ZWJ) are **deliberately kept** — they cannot
  /// reorder anything, and they are required for emoji composition and for
  /// Indic and Arabic orthography, so removing them corrupts text.
  /// (Stripping them wholesale was actually tried in PR #165 on 2026-09-03
  /// and split `👨‍👩` apart.)
  ///
  /// Truncation is done by grapheme cluster. Cutting on `runes` can land the
  /// boundary in the middle of a ZWJ sequence and break an emoji apart.
  static String sanitizeBody(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if (_isDisallowedInvisible(rune)) {
        continue;
      }
      buffer.writeCharCode(rune);
    }
    final cleaned = buffer.toString();
    final characters = cleaned.characters;
    if (characters.length <= maxBodyCharacters) {
      return cleaned;
    }
    return characters.take(maxBodyCharacters).toString();
  }

  static bool _isDisallowedInvisible(int rune) {
    // Bidirectional controls: can reorder the rendering so it reads as a
    // different author or a different message.
    // U+061C ALM / U+200E LRM / U+200F RLM / U+202A..202E / U+2066..2069
    final isBidiControl =
        rune == 0x061C ||
        rune == 0x200E ||
        rune == 0x200F ||
        (rune >= 0x202A && rune <= 0x202E) ||
        (rune >= 0x2066 && rune <= 0x2069);
    // Zero-width fillers: invisibly distort length and cluster boundaries.
    // U+180E / U+200B / U+2060..2064 / U+FFF9..FFFB / U+FEFF
    final isInvisibleFiller =
        rune == 0x180E ||
        rune == 0x200B ||
        (rune >= 0x2060 && rune <= 0x2064) ||
        (rune >= 0xFFF9 && rune <= 0xFFFB) ||
        rune == 0xFEFF;
    return isBidiControl || isInvisibleFiller;
  }

  /// Returns null instead of throwing on malformed input.
  ///
  /// **The background isolate must use this one.** The values reaching it
  /// come from relay events whose content an attacker controls. If one
  /// malformed event made `fromJson` throw and took the resident service
  /// down, **every later notification would stop**. This entry point keeps
  /// "drop one event" from turning into "stop everything".
  static NotificationPayload? tryFromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    try {
      return NotificationPayload.fromJson(json, now: now);
    } on FormatException {
      return null;
    }
  }

  /// The originating Nostr event id (64-char lowercase hex).
  /// **This is the dedup key.**
  ///
  /// The same event can arrive more than once via duplicate BOOT_COMPLETED
  /// delivery or a relay reconnect, so dedup is keyed on the event id rather
  /// than on `commentId`.
  final String eventId;

  /// Comment id (the `d` tag value of the addressable event).
  final String commentId;

  /// Id of the task the comment belongs to; used as the tap destination.
  final String taskId;

  /// Shared group id. Required, because personal comments are not notified in
  /// Phase 3.
  final String groupId;

  /// Author public key (64-char lowercase hex) **as carried in the decrypted
  /// payload**.
  ///
  /// Every member of a shared task signs with the same group key, so **the
  /// event envelope does not reveal who wrote it**. Self-echo suppression
  /// (not notifying someone about their own comment) must therefore compare
  /// this decrypted value against the local pubkey, never the envelope's.
  ///
  /// Note that under shared-v1 this value is self-asserted and **cannot be
  /// used for authorization**. Use it only for display and for self-echo
  /// suppression.
  final String authorPubkey;

  /// Decrypted body shown in the notification, after [sanitizeBody].
  final String body;

  /// Post time, unix seconds.
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'comment_id': commentId,
    'task_id': taskId,
    'group_id': groupId,
    'author_pubkey': authorPubkey,
    'body': body,
    'created_at': createdAt,
  };

  @override
  String toString() =>
      'NotificationPayload(eventId: $eventId, taskId: $taskId, '
      'groupId: $groupId, createdAt: $createdAt)';
}
