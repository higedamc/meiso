import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_settings.dart';
import 'package:meiso/features/notifications/infrastructure/delivered_event_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DeliveredEventStore> makeStore([Map<String, Object>? initial]) async {
  SharedPreferences.setMockInitialValues(initial ?? {});
  return DeliveredEventStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dedup', () {
    test('an event id is not delivered until marked', () async {
      final store = await makeStore();
      expect(store.isDelivered('ev1'), isFalse);
      await store.markDelivered('ev1');
      expect(store.isDelivered('ev1'), isTrue);
    });

    test('marking the same id twice does not duplicate it', () async {
      final store = await makeStore();
      await store.markDelivered('ev1');
      await store.markDelivered('ev1');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(NotificationPrefsKeys.deliveredEventIds),
        ['ev1'],
      );
    });

    test(
      'truncates to maxDeliveredEventIds, dropping the oldest first '
      '(an uncapped list is a DoS surface — a relay-writable third party '
      'could otherwise grow it without bound)',
      () async {
        final store = await makeStore();
        final cap = NotificationPrefsKeys.maxDeliveredEventIds;
        for (var i = 0; i < cap + 5; i++) {
          await store.markDelivered('ev$i');
        }
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getStringList(
          NotificationPrefsKeys.deliveredEventIds,
        )!;
        expect(stored.length, cap);
        // The oldest 5 (ev0..ev4) were dropped; the newest survive.
        expect(stored.contains('ev0'), isFalse);
        expect(stored.contains('ev${cap + 4}'), isTrue);
      },
    );
  });

  group('lastSeenCreatedAt', () {
    test('is null before anything has been processed', () async {
      final store = await makeStore();
      expect(store.lastSeenCreatedAt, isNull);
    });

    test('advances forward', () async {
      final store = await makeStore();
      await store.advanceLastSeenCreatedAt(100);
      expect(store.lastSeenCreatedAt, 100);
      await store.advanceLastSeenCreatedAt(200);
      expect(store.lastSeenCreatedAt, 200);
    });

    test(
      'never moves backwards (rewinding it would re-notify already-seen '
      'comments on the next since-based resubscribe)',
      () async {
        final store = await makeStore();
        await store.advanceLastSeenCreatedAt(200);
        await store.advanceLastSeenCreatedAt(100);
        expect(store.lastSeenCreatedAt, 200);
      },
    );

    test('an equal value is also a no-op, not just a lesser one', () async {
      final store = await makeStore();
      await store.advanceLastSeenCreatedAt(200);
      await store.advanceLastSeenCreatedAt(200);
      expect(store.lastSeenCreatedAt, 200);
    });
  });
}
