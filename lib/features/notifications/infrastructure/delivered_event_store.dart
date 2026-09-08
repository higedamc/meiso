import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_settings.dart';

/// Background-isolate-only dedup and subscription-progress state.
///
/// Backed by [SharedPreferences], per the Phase 0 contract
/// (`notification_settings.dart`): the background isolate must not open a
/// Hive box. Both keys used here are documented there as **background
/// isolate only** — the UI side must not write them.
class DeliveredEventStore {
  DeliveredEventStore(this._prefs);

  final SharedPreferences _prefs;

  /// Whether [eventId] has already been processed (BOOT_COMPLETED can
  /// deliver the same event more than once).
  bool isDelivered(String eventId) => _loadDeliveredIds().contains(eventId);

  /// Records [eventId] as delivered, truncating the list to
  /// [NotificationPrefsKeys.maxDeliveredEventIds] entries, oldest first.
  Future<void> markDelivered(String eventId) async {
    final ids = _loadDeliveredIds();
    if (ids.contains(eventId)) {
      return;
    }
    ids.add(eventId);
    final overflow = ids.length - NotificationPrefsKeys.maxDeliveredEventIds;
    if (overflow > 0) {
      ids.removeRange(0, overflow);
    }
    await _prefs.setStringList(NotificationPrefsKeys.deliveredEventIds, ids);
  }

  List<String> _loadDeliveredIds() =>
      _prefs.getStringList(NotificationPrefsKeys.deliveredEventIds) ??
      <String>[];

  /// `created_at` (unix seconds) of the last event processed, or null before
  /// the first successful subscription.
  int? get lastSeenCreatedAt =>
      _prefs.getInt(NotificationPrefsKeys.lastSeenCreatedAt);

  /// Advances [NotificationPrefsKeys.lastSeenCreatedAt] to [createdAt].
  ///
  /// A no-op if [createdAt] is not strictly greater than the current value —
  /// this value must never move backwards (contract: doing so would
  /// re-notify already-delivered comments on the next `since` resubscribe).
  /// Callers must only pass a `createdAt` that has already passed
  /// `NotificationPayload` validation.
  Future<void> advanceLastSeenCreatedAt(int createdAt) async {
    final current = lastSeenCreatedAt;
    if (current != null && createdAt <= current) {
      return;
    }
    await _prefs.setInt(NotificationPrefsKeys.lastSeenCreatedAt, createdAt);
  }
}
