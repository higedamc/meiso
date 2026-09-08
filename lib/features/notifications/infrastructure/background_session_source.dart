/// The session state the background isolate needs but cannot obtain through
/// its usual channels: Hive is off-limits here (contract:
/// `notification_settings.dart`), and Riverpod providers are UI-isolate-bound
/// so they cannot cross into a headless engine either.
///
/// Phase 0.1 now mirrors this state as versioned JSON in
/// `flutter_secure_storage` (`notification_group_keys.dart`). The abstract
/// source remains the seam that keeps storage access separate from the
/// subscription/dedup/notification pipeline and makes the latter easy to test.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/notification_group_keys.dart';

/// Reads the Phase 0.1 secure-storage mirror from a headless isolate.
///
/// The mirror is one versioned JSON value so the local identity and group keys
/// are loaded from the same snapshot. Malformed or missing data is treated as
/// an empty session; the notification service can recover when the UI writes a
/// fresh mirror after the next login or group sync.
class SecureStorageBackgroundSessionSource implements BackgroundSessionSource {
  SecureStorageBackgroundSessionSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  Future<NotificationGroupKeys>? _mirrorFuture;

  Future<NotificationGroupKeys> _loadMirror() {
    return _mirrorFuture ??= _readMirror();
  }

  Future<NotificationGroupKeys> _readMirror() async {
    final raw = await _storage.read(key: NotificationSecureKeys.groupKeys);
    return NotificationGroupKeys.decode(raw);
  }

  @override
  Future<String?> loadLocalPubkeyHex() async {
    final mirror = await _loadMirror();
    return mirror.selfPubkeyHex.isEmpty ? null : mirror.selfPubkeyHex;
  }

  @override
  Future<Map<String, GroupCredential>> loadGroupCredentials() async {
    final mirror = await _loadMirror();
    return {
      for (final group in mirror.groups)
        group.groupId: GroupCredential(
          groupId: group.groupId,
          npubHex: group.groupNpubHex,
          nsecHex: group.groupNsecHex,
        ),
    };
  }
}

/// One shared group's credentials, as needed to subscribe to and decrypt its
/// task comments.
class GroupCredential {
  const GroupCredential({
    required this.groupId,
    required this.npubHex,
    required this.nsecHex,
  });

  /// Local group id (matches `NotificationPayload.groupId`).
  final String groupId;

  /// Group public key (hex). Subscription `authors` filter and, since every
  /// member signs with the same key, the event envelope's `pubkey`.
  final String npubHex;

  /// Group secret key (hex). Local-only decrypt key, never sent anywhere.
  final String nsecHex;
}

/// Source of the two pieces of session state the background isolate needs.
abstract class BackgroundSessionSource {
  /// The local user's own public key (hex), for self-echo suppression.
  ///
  /// Not a secret — this only needs to reach a place the background isolate
  /// can read, not a place as hardened as [GroupCredential.nsecHex].
  ///
  /// Returns null if no user is logged in (background isolate should not
  /// start a subscription).
  Future<String?> loadLocalPubkeyHex();

  /// All shared groups the local user currently belongs to, keyed by
  /// [GroupCredential.groupId].
  Future<Map<String, GroupCredential>> loadGroupCredentials();
}
