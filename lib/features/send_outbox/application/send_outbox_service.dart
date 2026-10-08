import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../core/common/failure.dart';
import '../../../providers/nostr_provider.dart';
import '../../../services/logger_service.dart';
import '../domain/outbox_entry.dart';
import '../domain/send_outbox_repository.dart';

/// Retry engine for the send outbox.
///
/// Does not rely on a single trigger path (`PLANS/MEISO_SEND_OUTBOX_LEAF.md`
/// §6): app resume and relay-connect (`presentation/providers/
/// outbox_providers.dart` calls [flush]) both feed in, and this class also
/// keeps its own exponential-backoff timer. Retries are serial (never more
/// than one send in flight). Each success removes the entry from the queue;
/// each failure updates its attempt count and last error, then moves on.
class SendOutboxService {
  SendOutboxService({
    required SendOutboxRepository repository,
    required NostrService nostrService,
  }) : _repository = repository,
       _nostrService = nostrService {
    // Arm immediately so a queue populated before this instance existed (an
    // app restart with entries already on disk) is not left waiting for the
    // next app-resume or relay-reconnect edge — which may never fire if the
    // relay was already connected at launch.
    unawaited(_rearm());
  }

  final SendOutboxRepository _repository;
  final NostrService _nostrService;

  bool _flushing = false;
  Timer? _timer;
  bool _disposed = false;

  static const Duration minBackoff = Duration(seconds: 30);
  static const Duration maxBackoff = Duration(minutes: 15);

  /// Adds the (signed) [eventJson] to the queue and arms the retry timer.
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  }) async {
    final result = await _repository.enqueue(
      eventId: eventId,
      eventJson: eventJson,
      kind: kind,
      addressableId: addressableId,
    );
    if (result.isRight()) {
      unawaited(_rearm());
    }
    return result;
  }

  /// Retries a single entry immediately (for the unsent bubble's "tap to
  /// retry"). No-ops while a [flush] is already in flight — that pass will
  /// reach this entry on its own, and sending it twice concurrently is a
  /// wasted duplicate wire send rather than a new attempt.
  Future<void> retryNow(String eventId) async {
    if (_flushing) {
      return;
    }
    final entries = await _repository.loadAll();
    OutboxEntry? target;
    for (final entry in entries) {
      if (entry.eventId == eventId) {
        target = entry;
        break;
      }
    }
    if (target == null) {
      return;
    }
    await _sendOne(target);
    unawaited(_rearm());
  }

  /// Tries every queued entry once, serially.
  ///
  /// Returns immediately if one is already running, so overlapping triggers
  /// (app resume, relay connect, the backoff timer) never run concurrently.
  Future<void> flush() async {
    if (_flushing || _disposed) {
      return;
    }
    _flushing = true;
    try {
      for (final entry in await _repository.loadAll()) {
        await _sendOne(entry);
      }
    } finally {
      _flushing = false;
    }
    unawaited(_rearm());
  }

  Future<void> _sendOne(OutboxEntry entry) async {
    try {
      final result = await _nostrService.sendSignedEvent(entry.eventJson);
      if (result.success) {
        await _repository.markSent(entry.eventId);
        return;
      }
      await _repository.markFailed(
        eventId: entry.eventId,
        errorMessage: result.errorMessage ?? 'send failed (no error message)',
      );
    } on Object catch (e) {
      AppLogger.warning('[send-outbox] Send attempt error: $e');
      await _repository.markFailed(
        eventId: entry.eventId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Re-evaluates the timer. Stops and waits for the next trigger if the
  /// queue is empty; otherwise arms it for the earliest entry's own backoff
  /// deadline (see [nextBackoff] — never the slowest entry's).
  Future<void> _rearm() async {
    _timer?.cancel();
    _timer = null;
    if (_disposed) {
      return;
    }
    final remaining = await _repository.loadAll();
    if (remaining.isEmpty) {
      return;
    }
    _timer = Timer(nextBackoff(remaining), () => unawaited(flush()));
  }

  /// Delay until the *earliest* queued entry is due for retry — each entry's
  /// own `lastAttemptAt ?? queuedAt` plus `min(30s * 2^(attempts-1), 15min)`.
  /// Per-entry, not queue-wide: a single poisoned entry stuck at the
  /// 15-minute ceiling must never hold back a comment typed moments ago by
  /// forcing it onto the same shared deadline.
  ///
  /// `nowEpochSeconds` defaults to the wall clock; tests inject a fixed value
  /// so the math stays deterministic. Static so it is testable standalone,
  /// independent of the timer.
  static Duration nextBackoff(
    List<OutboxEntry> entries, {
    int? nowEpochSeconds,
  }) {
    if (entries.isEmpty) {
      return minBackoff;
    }
    final now = nowEpochSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var earliestDelay = maxBackoff.inSeconds;
    for (final entry in entries) {
      final delay = (_dueAtSeconds(entry) - now).clamp(0, maxBackoff.inSeconds);
      if (delay < earliestDelay) {
        earliestDelay = delay;
      }
    }
    return Duration(seconds: earliestDelay);
  }

  /// Unix-second deadline for a single entry: `min(30s * 2^(attempts-1),
  /// 15min)` after its last attempt (or after it was queued, for an entry
  /// that has never been retried from this queue — `attempts` starts at 0
  /// here even though the live send that preceded enqueueing already failed
  /// once, so the 30s floor still applies).
  static int _dueAtSeconds(OutboxEntry entry) {
    final base = entry.lastAttemptAt ?? entry.queuedAt;
    final effectiveAttempts = entry.attempts <= 1 ? 1 : entry.attempts;
    final exponent = (effectiveAttempts - 1).clamp(0, 10);
    final backoffSeconds = (minBackoff.inSeconds * (1 << exponent)).clamp(
      minBackoff.inSeconds,
      maxBackoff.inSeconds,
    );
    return base + backoffSeconds;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
