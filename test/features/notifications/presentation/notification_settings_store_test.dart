import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_settings.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<NotificationSettingsStore> newStore([
  Map<String, Object>? initial,
]) async {
  SharedPreferences.setMockInitialValues(initial ?? {});
  return NotificationSettingsStore(await SharedPreferences.getInstance());
}

void main() {
  group('NotificationSettingsStore', () {
    test('returns the contract defaults when nothing was written', () async {
      final store = await newStore();

      expect(store.read(), NotificationSettings.defaults);
      expect(store.read().enabled, isFalse, reason: 'opt-in by contract');
      expect(store.read().sharedTaskComments, isTrue);
    });

    test('reads values from the contract keys', () async {
      final store = await newStore({
        NotificationPrefsKeys.enabled: true,
        NotificationPrefsKeys.sharedTaskComments: false,
      });

      expect(
        store.read(),
        const NotificationSettings(enabled: true, sharedTaskComments: false),
      );
    });

    test('write persists under the contract keys and reads back', () async {
      final store = await newStore();
      const next = NotificationSettings(
        enabled: true,
        sharedTaskComments: false,
      );

      await store.write(next);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationPrefsKeys.enabled), isTrue);
      expect(prefs.getBool(NotificationPrefsKeys.sharedTaskComments), isFalse);
      expect(store.read(), next);
    });

    test('write leaves the background-isolate keys untouched', () async {
      final store = await newStore({
        NotificationPrefsKeys.deliveredEventIds: <String>['a', 'b'],
        NotificationPrefsKeys.lastSeenCreatedAt: 1234,
      });

      await store.write(const NotificationSettings(enabled: true));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(NotificationPrefsKeys.deliveredEventIds),
        ['a', 'b'],
      );
      expect(prefs.getInt(NotificationPrefsKeys.lastSeenCreatedAt), 1234);
      expect(
        prefs.getKeys(),
        {
          NotificationPrefsKeys.deliveredEventIds,
          NotificationPrefsKeys.lastSeenCreatedAt,
          NotificationPrefsKeys.enabled,
          NotificationPrefsKeys.sharedTaskComments,
        },
        reason: 'no key outside the contract is ever written',
      );
    });
  });
}
