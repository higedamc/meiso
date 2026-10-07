import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show RelayListSyncStatus;
import 'package:meiso/models/app_settings.dart';
import 'package:meiso/utils/relay_list_sync_guard.dart';

/// Issue #193: a user's own relay must not be replaced by the public
/// defaults. Each test names its negative control: what the old code did
/// with the same input.
void main() {
  const saved = ['ws://10.0.2.2:10547'];

  group('startupRelaysFromSaved (cold start)', () {
    test('a saved single relay is used, not the defaults', () {
      // Negative control: the old code read the in-memory relay status map,
      // which is empty on a cold start, and initialised the client with the
      // public defaults.
      final settings = AppSettings.defaultSettings().copyWith(relays: saved);
      expect(startupRelaysFromSaved(settings), saved);
    });

    test('no saved settings at all means defaults (first start)', () {
      expect(startupRelaysFromSaved(null), isNull);
    });

    test('a saved empty list means never configured, so defaults apply', () {
      // The first start persists AppSettings.defaultSettings() with
      // relays: [] before any login, so an empty saved list cannot mean
      // "deliberately none". Negative control: treating it as a configured
      // list initialised the client with no relay at all after a fresh
      // install ("no relays specified" on the Amber login path).
      final settings = AppSettings.defaultSettings().copyWith(relays: const []);
      expect(startupRelaysFromSaved(settings), isNull);
    });
  });

  group('resolveSyncedRelays (kind 10002 applied to the saved list)', () {
    test('an unreachable relay keeps the saved list', () {
      // Negative control: the old code took the empty result as the new
      // list, and the app then fell back to the public defaults.
      expect(
        resolveSyncedRelays(
          status: RelayListSyncStatus.unreachable,
          remoteRelays: const [],
          savedRelays: saved,
        ),
        saved,
      );
    });

    test('a missing relay list keeps the saved list', () {
      expect(
        resolveSyncedRelays(
          status: RelayListSyncStatus.notFound,
          remoteRelays: const [],
          savedRelays: saved,
        ),
        saved,
      );
    });

    test('a read relay list with no entries keeps the saved list', () {
      // Negative control: applying the event as published leaves the app
      // with no relay and every sync silently stopped.
      expect(
        resolveSyncedRelays(
          status: RelayListSyncStatus.found,
          remoteRelays: const [],
          savedRelays: saved,
        ),
        saved,
      );
    });

    test('the account\'s own non-empty relay list is applied when read', () {
      expect(
        resolveSyncedRelays(
          status: RelayListSyncStatus.found,
          remoteRelays: const ['wss://relay.example', 'ws://10.0.2.2:10547'],
          savedRelays: saved,
        ),
        ['wss://relay.example', 'ws://10.0.2.2:10547'],
      );
    });

    test('the result is a copy, not the caller\'s list', () {
      final mine = ['ws://a'];
      resolveSyncedRelays(
        status: RelayListSyncStatus.unreachable,
        remoteRelays: const [],
        savedRelays: mine,
      ).add('ws://b');
      expect(mine, ['ws://a']);
    });
  });
}
