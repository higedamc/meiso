import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show RelayListSyncStatus;
import 'package:meiso/utils/relay_list_sync_guard.dart';

/// Issue #193: a user's own relay must not be replaced by the public
/// defaults. Each test names its negative control: what the old code did
/// with the same input.
void main() {
  const saved = ['ws://10.0.2.2:10547'];

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
