import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_payload.dart';

/// Fires the on-device notification for a validated [NotificationPayload].
///
/// Content-carrying (title + decrypted body), unlike Pokey's `4`/`1059`
/// kinds which never decrypt and only ever show "New private message"
/// (`PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`). That is safe here specifically
/// because shared-task comments decrypt locally with the group nsec — no
/// Amber round trip needed in the background.
class NotificationDispatcher {
  NotificationDispatcher(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'meiso.notifications.sharedTaskComments';
  static const String channelName = 'Shared task comments';
  static const String channelDescription =
      'Notifications for comments on tasks shared with you.';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
  }

  /// Shows one notification for [payload].
  ///
  /// The notification id is derived deterministically from
  /// [NotificationPayload.eventId] (the dedup key), so re-showing the same
  /// event (should dedup ever be bypassed) updates the existing notification
  /// instead of stacking a duplicate.
  Future<void> showCommentNotification(NotificationPayload payload) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(payload.body),
    );
    await _plugin.show(
      id: _notificationId(payload.eventId),
      title: 'New comment',
      body: payload.body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload.taskId,
    );
  }

  /// Masks the sign bit — `flutter_local_notifications` notification ids are
  /// signed 32-bit ints on Android, and `String.hashCode` is not.
  static int _notificationId(String eventId) => eventId.hashCode & 0x7fffffff;
}
