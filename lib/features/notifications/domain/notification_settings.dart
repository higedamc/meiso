/// Settings entity and persistence keys for Phase 3 notifications
/// (Pokey-style: a persistent relay connection plus on-device notifications).
///
/// Design: see `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md` (Lead).
/// This file is **the only contact surface between Leaf 2 (background
/// isolate) and Leaf 3 (settings UI)**, landed on main first as a contract.
/// The leaves must not change key names or defaults afterwards.
///
/// ## Why this does not live in AppSettings (NIP-78 kind 30078)
///
/// Notification settings are **per-device**. Whether a foreground service can
/// run at all, and whether battery optimization has been waived, depends on
/// the individual device; syncing that over a relay produces "turning it off
/// on one device silences the other". On top of that, `AppSettings` is a god
/// file that drags in freezed output (`app_settings.freezed.dart` / `.g.dart`)
/// and would collide with the parallel leaves.
///
/// ## Persistence is SharedPreferences, not Hive
///
/// The background isolate must not open a Hive box. Opening, from a second
/// isolate, a box the UI isolate already holds corrupts it.
/// `flutter_foreground_task` itself restores its Dart callback from
/// SharedPreferences, so this stays on the same ground.
library;

/// Persistence keys for notification settings.
///
/// These land in SharedPreferences in the clear, so **no secret values here**
/// (the group nsec and the user's secret key stay in their existing stores).
abstract final class NotificationPrefsKeys {
  static const String _prefix = 'meiso.notifications';

  /// Master on/off switch for notifications. Defaults to false (opt-in).
  ///
  /// This decides whether a resident foreground service is started at all,
  /// so it must not default to true.
  static const String enabled = '$_prefix.enabled';

  /// On/off for shared-task comment notifications. Defaults to true.
  ///
  /// There is no corresponding key for personal tasks: comments on those have
  /// the local user as author and are not notified in Phase 3.
  static const String sharedTaskComments = '$_prefix.sharedTaskComments';

  /// Key under which the background isolate remembers already-notified event
  /// ids.
  ///
  /// **Background isolate only. The UI side must not write it.**
  /// BOOT_COMPLETED can be delivered more than once, so dedup is mandatory.
  ///
  /// **Always truncate to [maxDeliveredEventIds] entries, dropping the
  /// oldest.** Third parties can publish events to the group relay, so an
  /// uncapped dedup list is storage an attacker can grow. An
  /// unboundedly-growing cache is itself a DoS surface.
  static const String deliveredEventIds = '$_prefix.deliveredEventIds';

  /// Maximum number of event ids retained in [deliveredEventIds].
  ///
  /// Suppressing duplicate notifications only needs the recent past, not the
  /// full history. [lastSeenCreatedAt] advances the subscription's `since` in
  /// step, so truncating the list does not resurrect old events.
  static const int maxDeliveredEventIds = 500;

  /// `created_at` (unix seconds) of the last event the background isolate
  /// processed.
  ///
  /// **Background isolate only.** Used as `since` when resubscribing.
  ///
  /// **Only values that passed `NotificationPayload` validation may be stored
  /// here.** Third parties can write to the relay, so advancing this from a
  /// raw `created_at` lets a single far-future event push `since` forward,
  /// after which every legitimate event is filtered out and notifications
  /// stop silently and permanently. See
  /// `NotificationPayload.maxFutureSkewSeconds` for the bound.
  /// **This value must also never move backwards** — rewinding it re-notifies.
  static const String lastSeenCreatedAt = '$_prefix.lastSeenCreatedAt';
}

/// Notification settings.
class NotificationSettings {
  const NotificationSettings({
    this.enabled = false,
    this.sharedTaskComments = true,
  });

  /// Defaults. **Notifications are opt-in.**
  static const NotificationSettings defaults = NotificationSettings();

  /// Master on/off for notifications.
  final bool enabled;

  /// Whether comments on shared tasks are notified.
  final bool sharedTaskComments;

  /// Whether the resident service needs to be started.
  ///
  /// If no notification category is enabled, the service is not started, so
  /// no battery is wasted.
  bool get requiresForegroundService => enabled && sharedTaskComments;

  NotificationSettings copyWith({bool? enabled, bool? sharedTaskComments}) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      sharedTaskComments: sharedTaskComments ?? this.sharedTaskComments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          other.enabled == enabled &&
          other.sharedTaskComments == sharedTaskComments;

  @override
  int get hashCode => Object.hash(enabled, sharedTaskComments);
}
