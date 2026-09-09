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
  const NotificationSettingsStore(this._prefs);

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
  Future<void> write(NotificationSettings settings) async {
    final ok = await _prefs.setBool(
          NotificationPrefsKeys.enabled,
          settings.enabled,
        ) &&
        await _prefs.setBool(
          NotificationPrefsKeys.sharedTaskComments,
          settings.sharedTaskComments,
        );
    if (!ok) {
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
