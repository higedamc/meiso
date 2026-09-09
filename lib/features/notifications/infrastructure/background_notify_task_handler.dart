import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../bridge_generated.dart/frb_generated.dart';
import '../../../providers/nostr_provider.dart' show defaultRelays;
import 'background_session_source.dart';
import 'comment_notification_mapper.dart';
import 'delivered_event_store.dart';
import 'notification_dispatcher.dart';
import 'self_echo_filter.dart';
import 'shared_task_comment_filter.dart';

/// `flutter_foreground_task` client id for the background isolate's own Nostr
/// client, kept separate from the UI's default client (`DEFAULT_CLIENT_ID` in
/// `rust/src/api.rs`) so the two never share subscription/connection state —
/// both may run in the same OS process when the app is open in the
/// foreground while this service is also active.
const String backgroundNotifyClientId = 'meiso.notifications.background';

/// How often the background isolate polls the Rust client for new events.
///
/// `NostrSubscriptionService` (the UI's own poller) starts at 100ms and backs
/// off to 1000ms for responsiveness while a screen is visible. Nothing here
/// is user-watched, so a flat, slower interval is enough and cheaper on
/// battery.
const Duration backgroundPollInterval = Duration(seconds: 5);

/// Registered with `FlutterForegroundTask.setTaskHandler` from the
/// `@pragma('vm:entry-point')` callback the native foreground service (Leaf
/// 1) invokes. Must stay a top-level function per the plugin's contract.
@pragma('vm:entry-point')
void backgroundNotifyStartCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundNotifyTaskHandler());
}

/// Subscribes to every shared group's task comments, decrypts them locally,
/// and fires a notification for each one that is not a self-echo and has not
/// already been delivered.
///
/// New-files-only leaf (`PLANS/MEISO_PHASE3_LEAF2_ISOLATE.md`): this wires
/// together [BackgroundSessionSource] (the Phase 0.1 secure-storage mirror),
/// [buildSharedTaskCommentFilter]
/// (subscription), [DeliveredEventStore] (dedup + resume cursor),
/// [isSelfEcho], [mapDecryptedCommentToNotificationPayload] (validation), and
/// [NotificationDispatcher] (delivery). Each of those is independently unit
/// tested; this class is the untested glue, kept as thin as the pieces allow.
class BackgroundNotifyTaskHandler extends TaskHandler {
  BackgroundNotifyTaskHandler({
    BackgroundSessionSource? sessionSource,
    NotificationDispatcher? dispatcher,
  }) : _sessionSource = sessionSource ?? SecureStorageBackgroundSessionSource(),
       _dispatcherOverride = dispatcher;

  final BackgroundSessionSource _sessionSource;
  final NotificationDispatcher? _dispatcherOverride;

  NotificationDispatcher? _dispatcher;
  DeliveredEventStore? _store;
  Timer? _pollTimer;
  bool _pollInProgress = false;
  bool _clientInitialized = false;
  bool _subscriptionStarted = false;
  Map<String, String> _groupIdByNpub = const {};
  Map<String, String> _nsecByNpub = const {};
  String? _localPubkeyHex;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();

    final localPubkeyHex = await _sessionSource.loadLocalPubkeyHex();
    if (localPubkeyHex == null) {
      // No logged-in user to notify on behalf of.
      return;
    }
    _localPubkeyHex = localPubkeyHex;

    final credentials = await _sessionSource.loadGroupCredentials();
    if (credentials.isEmpty) {
      return;
    }

    // Delay the native Rust load until there is a usable session. This keeps
    // the no-session startup path testable on host platforms and avoids
    // loading a native library for a disabled/empty notification service.
    try {
      await RustLib.init();

      _groupIdByNpub = {
        for (final credential in credentials.values)
          credential.npubHex: credential.groupId,
      };
      _nsecByNpub = {
        for (final credential in credentials.values)
          credential.npubHex: credential.nsecHex,
      };

      final prefs = await SharedPreferences.getInstance();
      final store = DeliveredEventStore(prefs);
      _store = store;

      final dispatcher =
          _dispatcherOverride ??
          NotificationDispatcher(FlutterLocalNotificationsPlugin());
      await dispatcher.init();
      _dispatcher = dispatcher;

      await rust_api.initNostrClientWithPubkeyAndId(
        clientId: backgroundNotifyClientId,
        publicKeyHex: localPubkeyHex,
        relays: defaultRelays,
      );
      _clientInitialized = true;

      final filter = buildSharedTaskCommentFilter(
        groupNpubHexes: _groupIdByNpub.keys.toList(growable: false),
        sinceUnixSeconds: store.lastSeenCreatedAt,
      );
      if (filter == null) {
        return;
      }
      await rust_api.startSubscriptionWithClientId(
        filtersJson: jsonEncode([filter]),
        clientId: backgroundNotifyClientId,
      );
      _subscriptionStarted = true;

      _pollTimer = Timer.periodic(backgroundPollInterval, (_) => _poll());
    } catch (_) {
      await _cleanupNativeState();
    }
  }

  Future<void> _poll() async {
    if (_pollInProgress) {
      return;
    }
    _pollInProgress = true;
    try {
      await _pollOnce();
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _pollOnce() async {
    final store = _store;
    final dispatcher = _dispatcher;
    if (store == null || dispatcher == null) {
      return;
    }
    List<rust_api.ReceivedEvent> events;
    try {
      events = await rust_api.receiveSubscriptionEventsWithClientId(
        timeoutMs: BigInt.from(2000),
        clientId: backgroundNotifyClientId,
      );
    } catch (_) {
      // Transient relay/poll error. One malformed or unreachable relay must
      // not stop the resident service — try again on the next tick.
      return;
    }
    for (final event in events) {
      await _handleEvent(event, store: store, dispatcher: dispatcher);
    }
  }

  Future<void> _handleEvent(
    rust_api.ReceivedEvent event, {
    required DeliveredEventStore store,
    required NotificationDispatcher dispatcher,
  }) async {
    // Dedup on the raw envelope id first — cheapest possible check, and
    // avoids re-decrypting an event BOOT_COMPLETED redelivered.
    if (store.isDelivered(event.eventId)) {
      return;
    }

    final String envelopePubkey;
    try {
      final envelope = jsonDecode(event.eventJson) as Map<String, dynamic>;
      envelopePubkey = envelope['pubkey'] as String;
    } catch (_) {
      return;
    }

    final groupId = _groupIdByNpub[envelopePubkey];
    final nsecHex = _nsecByNpub[envelopePubkey];
    if (groupId == null || nsecHex == null) {
      // Not one of the groups this isolate subscribed for. Should not
      // happen given the subscription's own `authors` filter, but a relay
      // is not a trusted boundary — drop rather than crash.
      return;
    }

    final String decryptedJson;
    try {
      decryptedJson = await rust_api.sharedDecryptCommentEvent(
        groupNsecHex: nsecHex,
        eventJson: event.eventJson,
      );
    } catch (_) {
      // Undecryptable (wrong key epoch, corrupt content, ...). One bad
      // event must not take the resident service down.
      return;
    }

    final Map<String, dynamic> decrypted;
    try {
      decrypted = jsonDecode(decryptedJson) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final payload = mapDecryptedCommentToNotificationPayload(
      envelopeEventId: event.eventId,
      envelopeCreatedAt: event.createdAt,
      groupId: groupId,
      decryptedCommentJson: decrypted,
    );
    if (payload == null) {
      return;
    }

    final localPubkeyHex = _localPubkeyHex;
    if (localPubkeyHex != null &&
        isSelfEcho(
          payloadAuthorPubkey: payload.authorPubkey,
          localPubkeyHex: localPubkeyHex,
        )) {
      return;
    }

    await dispatcher.showCommentNotification(payload);

    // Persist only after delivery succeeds. A crash or plugin failure may
    // cause a duplicate, but must not permanently lose a notification.
    // Clamp relay-controlled future timestamps so one valid event cannot move
    // the durable resume cursor ahead of the device clock.
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await store.advanceLastSeenCreatedAt(
      payload.createdAt > nowSeconds ? nowSeconds : payload.createdAt,
    );
    await store.markDelivered(payload.eventId);
  }

  Future<void> _cleanupNativeState() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_subscriptionStarted || _clientInitialized) {
      try {
        await rust_api.stopAllSubscriptionsWithClientId(
          clientId: backgroundNotifyClientId,
        );
      } catch (_) {
        // Best-effort cleanup during startup failure or service shutdown.
      }
    }
    _subscriptionStarted = false;
    _clientInitialized = false;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Polling runs on its own Timer started in onStart; nothing to do here.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _cleanupNativeState();
  }
}
