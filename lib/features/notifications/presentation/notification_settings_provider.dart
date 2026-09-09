import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_settings.dart';
import 'notification_settings_store.dart';

/// Store backed by the process-wide [SharedPreferences] instance.
final notificationSettingsStoreProvider =
    FutureProvider<NotificationSettingsStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return NotificationSettingsStore(prefs);
});

/// Notification settings as shown and edited by the settings screen.
///
/// Phase 4 (integration) is the place that reacts to these values by arming
/// or stopping the resident service. This controller only persists them.
class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final store = await ref.watch(notificationSettingsStoreProvider.future);
    return store.read();
  }

  /// Master switch. `false` means no resident service at all.
  Future<void> setEnabled({required bool enabled}) =>
      _update((current) => current.copyWith(enabled: enabled));

  /// Comments on shared tasks.
  Future<void> setSharedTaskComments({required bool enabled}) =>
      _update((current) => current.copyWith(sharedTaskComments: enabled));

  Future<void> _update(
    NotificationSettings Function(NotificationSettings current) change,
  ) async {
    final current = state.valueOrNull ?? await future;
    final next = change(current);
    final store = await ref.read(notificationSettingsStoreProvider.future);
    // Keep the last good value on screen if the write fails; the error is
    // surfaced through [AsyncValue.error] with the previous data attached.
    state = await AsyncValue.guard(() async {
      await store.write(next);
      return next;
    });
  }
}

final notificationSettingsProvider = AsyncNotifierProvider<
    NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);

/// Battery-optimization exemption, behind an interface so the screen can be
/// tested without the platform channel.
///
/// A resident foreground service that Android's battery optimizer kills stops
/// notifying without any visible error, so the settings screen shows the
/// current state and offers the system dialog.
abstract class BatteryOptimizationGate {
  /// Whether the app is already excluded from battery optimization.
  Future<bool> isIgnoring();

  /// Opens the system dialog asking to exclude the app. Resolves to the new
  /// state once the dialog is dismissed.
  Future<bool> request();
}

/// Production gate, delegating to `flutter_foreground_task` which already
/// ships the `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` plumbing (the permission
/// itself is declared by Leaf 1 in the Android manifest).
class ForegroundTaskBatteryOptimizationGate
    implements BatteryOptimizationGate {
  const ForegroundTaskBatteryOptimizationGate();

  @override
  Future<bool> isIgnoring() =>
      FlutterForegroundTask.isIgnoringBatteryOptimizations;

  @override
  Future<bool> request() =>
      FlutterForegroundTask.requestIgnoreBatteryOptimization();
}

final batteryOptimizationGateProvider = Provider<BatteryOptimizationGate>(
  (ref) => const ForegroundTaskBatteryOptimizationGate(),
);

/// Current exemption state. Invalidate after [BatteryOptimizationGate.request]
/// or when the app comes back to the foreground to re-read it.
final batteryOptimizationExemptProvider = FutureProvider<bool>(
  (ref) => ref.watch(batteryOptimizationGateProvider).isIgnoring(),
);
