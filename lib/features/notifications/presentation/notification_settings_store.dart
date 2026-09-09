import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_settings.dart';

/// Reads and writes the user-facing notification settings.
///
/// Only [NotificationPrefsKeys.enabled] and
/// [NotificationPrefsKeys.sharedTaskComments] are touched here. The dedup list
/// and the `since` cursor belong to the background isolate; the UI side never
/// reads or writes them (see the contract in `notification_settings.dart`).
///
/// Persistence is SharedPreferences on purpose: these settings are per-device
/// and must not be synced through `AppSettings`.
class NotificationSettingsStore {
  const NotificationSettingsStore(SharedPreferences prefs) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Current settings, falling back to [NotificationSettings.defaults] for
  /// any key that has never been written.
  NotificationSettings read() {
    const defaults = NotificationSettings.defaults;
    return NotificationSettings(
      enabled:
          _prefs.getBool(NotificationPrefsKeys.enabled) ?? defaults.enabled,
      sharedTaskComments:
          _prefs.getBool(NotificationPrefsKeys.sharedTaskComments) ??
              defaults.sharedTaskComments,
    );
  }

  /// Persists [settings]. Throws [NotificationSettingsWriteException] when
  /// the platform store rejects the write, so the caller can keep showing the
  /// previous value instead of a toggle that silently did not stick.
  ///
  /// Both keys are always attempted before the result is checked, so a
  /// rejected first write never leaves the second one untried. The pair is
  /// still not atomic (SharedPreferences cannot be), but the only partial
  /// state left behind is one the store itself reported as a failure.
  Future<void> write(NotificationSettings settings) async {
    final results = await Future.wait([
      _prefs.setBool(NotificationPrefsKeys.enabled, settings.enabled),
      _prefs.setBool(
        NotificationPrefsKeys.sharedTaskComments,
        settings.sharedTaskComments,
      ),
    ]);
    if (results.any((ok) => !ok)) {
      throw const NotificationSettingsWriteException();
    }
  }
}

/// SharedPreferences reported a failed write.
class NotificationSettingsWriteException implements Exception {
  const NotificationSettingsWriteException();

  @override
  String toString() => 'NotificationSettingsWriteException: '
      'SharedPreferences rejected the write';
}
