import 'package:dartz/dartz.dart';

import '../../../core/common/failure.dart';
import 'outbox_entry.dart';

/// CRUD contract for the send outbox. Retry triggers/timing (app resume /
/// relay connect / backoff timer) are not this layer's concern — that is
/// `application/send_outbox_service.dart`.
abstract class SendOutboxRepository {
  /// Adds the (signed) [eventJson] to the queue.
  ///
  /// If `eventId` is already queued, this is a no-op success (primary-key
  /// dedup against double-enqueue). Returns [ValidationFailure] without
  /// queuing anything if [eventJson] exceeds [OutboxEntry.maxEventJsonBytes],
  /// or if the queue is already at [OutboxEntry.maxEntries].
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  });

  /// All queued entries, `queuedAt` ascending.
  Future<List<OutboxEntry>> loadAll();

  /// Watches the queue for changes, `queuedAt` ascending.
  Stream<List<OutboxEntry>> watchAll();

  /// Removes an entry that sent successfully.
  Future<void> markSent(String eventId);

  /// Updates the attempt count and last error for an entry that failed to
  /// send. [errorMessage] must never include the event content (comment body).
  Future<void> markFailed({required String eventId, required String errorMessage});
}
