import 'dart:async';

import '../../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../../providers/nostr_provider.dart';
import '../../../../services/logger_service.dart';
import '../../domain/repositories/task_comment_repository.dart';

/// Owns the session-scoped realtime subscription for personal task comments
/// (`kind:35002`, author = self). Issue #218 L2.
///
/// Driven imperatively ([start] on login, [stop] on logout) rather than by a
/// provider rebuild: the app root arms it with a single `ref.read` while the
/// session is still uninitialised, and a `ref.watch`-based provider with no
/// listener is not recomputed when its dependency later changes, so the
/// subscription would never have been opened on a cold start.
///
/// Same hazard as the #188 reconnect code: the relay round-trips in [start]
/// can outlive the session that began them. A generation counter stands in
/// for the `onDispose`-before-`await` guard of the old autoDispose provider —
/// a result that arrives for a stale generation is stopped, not stored.
class PersonalTaskCommentSession {
  PersonalTaskCommentSession({
    required NostrService nostrService,
    required TaskCommentRepository repository,
  }) : _nostrService = nostrService,
       _repository = repository;

  final NostrService _nostrService;
  final TaskCommentRepository _repository;

  int _generation = 0;
  String? _subscriptionId;

  /// Relay subscription id of the live subscription, or null while none is
  /// open (before login, after logout, while the round-trip is in flight).
  String? get subscriptionId => _subscriptionId;

  /// Opens the subscription for the current session. A no-op while one is
  /// already open.
  Future<void> start() async {
    if (_subscriptionId != null) {
      return;
    }
    final generation = ++_generation;

    final publicKeyHex = await _nostrService.getPublicKey();
    if (generation != _generation) {
      return;
    }
    if (publicKeyHex == null) {
      return;
    }

    final seenEventIds = <String>{};
    final String subscriptionId;
    try {
      subscriptionId = await _nostrService.subscribePersonalTaskComments(
        publicKeyHex: publicKeyHex,
        onEventsReceived: (events) {
          unawaited(_applyEvents(events, seenEventIds));
        },
      );
    } on Object catch (e) {
      AppLogger.warning('[task-chat] personal comment subscribe failed: $e');
      return;
    }

    if (generation != _generation) {
      // Stopped (or restarted) while the round-trip was in flight: nobody
      // else knows this id, so stop the orphan here.
      _stopQuietly(subscriptionId);
      return;
    }
    _subscriptionId = subscriptionId;
  }

  /// Closes the subscription if one is open and invalidates any [start] still
  /// in flight. Fire-and-forget: the caller (logout) does not wait on relays.
  void stop() {
    _generation++;
    final id = _subscriptionId;
    _subscriptionId = null;
    if (id != null) {
      _stopQuietly(id);
    }
  }

  void _stopQuietly(String subscriptionId) {
    unawaited(
      _nostrService.stopSubscription(subscriptionId).catchError((Object e) {
        AppLogger.warning(
          '[task-chat] personal comment unsubscribe failed: $e',
        );
      }),
    );
  }

  Future<void> _applyEvents(
    List<rust_api.ReceivedEvent> events,
    Set<String> seenEventIds,
  ) async {
    // LWW 決定論化: created_at 昇順(同秒は event id 辞書順)で適用
    // (shared-v1 todos の issue #138 R1/R2 と同じ規則)
    final ordered = events.toList()
      ..sort((a, b) {
        if (a.createdAt != b.createdAt) {
          return a.createdAt.compareTo(b.createdAt);
        }
        return a.eventId.compareTo(b.eventId);
      });
    for (final event in ordered) {
      if (!seenEventIds.add(event.eventId)) {
        continue;
      }
      final result = await _repository.applyRemoteCommentEvent(
        eventJson: event.eventJson,
      );
      result.fold(
        (failure) => AppLogger.warning(
          '[task-chat] personal comment apply failed: ${failure.message}',
        ),
        (_) {},
      );
    }
  }
}
