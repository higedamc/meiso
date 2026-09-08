/// The group keys the background notification isolate needs, and the mirror it
/// reads them from.
///
/// Design: see `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md` (Lead). This is Phase 0.1 of
/// the Phase 3 contract, landed on main before Leaf 2 depends on it.
///
/// ## Why a mirror exists at all
///
/// Shared-task comments are encrypted to the group key, so the background
/// isolate needs `groupNsecHex` to decrypt them, and `groupNpubHex` to build
/// the relay subscription. Today those live in the Hive `settings` box
/// (`LocalStorageService.loadSharedGroupCredentials`).
///
/// **The background isolate must never open that box.** Opening, from a second
/// isolate, a box the UI isolate already holds corrupts it — that is not an
/// avoidable accident, it is what Hive does. So the UI side mirrors what the
/// isolate needs into a store both sides can reach.
///
/// ## Why flutter_secure_storage and not SharedPreferences
///
/// The mirror carries secret key material. SharedPreferences would put group
/// nsecs in the clear; `flutter_secure_storage` encrypts them with a key held
/// in the Android Keystore.
///
/// **Use the package defaults on Android.** On 10.x those are
/// `AES/GCM/NoPadding` for the data and RSA-OAEP-SHA256 to wrap the key — an
/// AEAD, so the stored blob is authenticated as well as confidential. Do not
/// pass `AndroidOptions(encryptedSharedPreferences: true)`: it is deprecated
/// upstream (Jetpack Security is deprecated by Google) and ignored from v11.
/// The 9.x defaults were `AES/CBC/PKCS7` wrapped with RSA/ECB/PKCS1v1.5 —
/// unauthenticated, padding-oracle-prone — which is why this project requires
/// 10.x rather than pinning the version the spike happened to use.
///
/// **Do not turn on `enforceBiometrics`.** A background isolate has no UI to
/// prompt with, so a biometric-gated read fails there and notifications stop
/// with no visible cause.
///
/// The open question was whether the platform channel resolves in a headless
/// engine with no Activity. **Measured, not assumed**: on a physical API 36
/// device, after `am force-stop`, a cold headless engine read back a value the
/// UI process had written, in 21 ms (Renge, 2026-09-08; procedure and logcat in
/// `RESEARCH/MEISO_PHASE3_SPIKE.md`, CHECK-4). That run used 9.2.4, so Leaf 2
/// must repeat CHECK-4 against 10.x before its PR — the plugin's Android
/// implementation changed underneath the same API.
///
/// ## Deleting the mirror is part of the contract
///
/// This is a second copy of key material. Whoever writes it owns erasing it:
/// on sign-out, on leaving or deleting a shared list, and on group-key
/// rotation. A mirror that outlives the credential it copied is a secret
/// nobody remembers is there.
///
/// ## What still holds from the Phase 0 contract
///
/// Non-secret notification settings stay in SharedPreferences
/// (`NotificationPrefsKeys`). This file is only for key material. Do not move
/// settings in here and do not put secrets in there.
library;

import 'dart:convert';

/// Where the mirror lives inside `flutter_secure_storage`.
abstract final class NotificationSecureKeys {
  /// The single entry holding [NotificationGroupKeys] as JSON.
  ///
  /// Versioned in the key itself: a future shape change gets a new key rather
  /// than silently reinterpreting the old bytes. Readers ignore keys they do
  /// not know.
  static const String groupKeys = 'meiso.notifications.groupKeys.v1';
}

/// One shared group's key material, as the background isolate needs it.
class NotificationGroupKey {
  const NotificationGroupKey({
    required this.groupId,
    required this.groupNpubHex,
    required this.groupNsecHex,
  });

  /// Same identifier as `SharedGroupCredentials.groupId`.
  final String groupId;

  /// Public key of the group, used as the subscription's `authors` filter.
  final String groupNpubHex;

  /// Secret key of the group, used to decrypt comment payloads.
  ///
  /// **Never log this, and never put it in a notification body.**
  final String groupNsecHex;

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_npub': groupNpubHex,
    'group_nsec': groupNsecHex,
  };

  /// Returns null instead of throwing on a malformed entry.
  ///
  /// A single corrupt entry must not take down the resident service and with
  /// it every later notification. Skipping one group is recoverable; throwing
  /// out of the isolate's startup path is not.
  static NotificationGroupKey? tryFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final groupId = raw['group_id'];
    final npub = raw['group_npub'];
    final nsec = raw['group_nsec'];
    if (groupId is! String || groupId.isEmpty || groupId.length > 128) {
      return null;
    }
    if (!_isHex64(npub)) {
      return null;
    }
    if (!_isHex64(nsec)) {
      return null;
    }
    return NotificationGroupKey(
      groupId: groupId,
      groupNpubHex: (npub! as String).toLowerCase(),
      groupNsecHex: (nsec! as String).toLowerCase(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationGroupKey &&
          other.groupId == groupId &&
          other.groupNpubHex == groupNpubHex &&
          other.groupNsecHex == groupNsecHex;

  @override
  int get hashCode => Object.hash(groupId, groupNpubHex, groupNsecHex);

  /// Deliberately does not include the key material.
  ///
  /// `toString` ends up in exception messages and log lines that nobody
  /// audited; a secret that only leaks in an error path leaks exactly when
  /// people are pasting output around.
  @override
  String toString() => 'NotificationGroupKey($groupId)';
}

/// Everything the background isolate reads out of secure storage in one go.
class NotificationGroupKeys {
  const NotificationGroupKeys({
    required this.selfPubkeyHex,
    required this.groups,
  });

  /// Parses the mirror, tolerating anything that is not what we wrote.
  ///
  /// Returns [empty] rather than throwing. A mirror that cannot be read means
  /// "no notifications", which is visible to the user and recoverable by
  /// reopening the app; an exception on the isolate's startup path is neither.
  ///
  /// A payload whose `version` is not [currentVersion] is treated as unreadable
  /// on purpose: reinterpreting an unknown shape is how a future field silently
  /// becomes the wrong one.
  factory NotificationGroupKeys.decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return empty;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map) {
      return empty;
    }
    if (decoded['version'] != currentVersion) {
      return empty;
    }

    final self = decoded['self_pubkey'];
    final rawGroups = decoded['groups'];
    final groups = <NotificationGroupKey>[];
    if (rawGroups is List) {
      for (final entry in rawGroups.take(maxGroups)) {
        final parsed = NotificationGroupKey.tryFromJson(entry);
        if (parsed != null &&
            !groups.any((group) => group.groupNpubHex == parsed.groupNpubHex)) {
          groups.add(parsed);
        }
      }
    }
    return NotificationGroupKeys(
      selfPubkeyHex: _isHex64(self) ? (self! as String).toLowerCase() : '',
      groups: groups,
    );
  }

  /// Current shape version of the serialized payload.
  static const int currentVersion = 1;

  /// Bound mirror growth before it reaches the background isolate/filter.
  static const int maxGroups = 256;

  /// Empty mirror: nothing to subscribe to, nothing to decrypt.
  static const NotificationGroupKeys empty = NotificationGroupKeys(
    selfPubkeyHex: '',
    groups: <NotificationGroupKey>[],
  );

  /// The local user's public key.
  ///
  /// Needed for self-echo suppression: every member signs shared events with
  /// the same group key, so the envelope does not say who wrote a comment.
  /// The decrypted payload's author does, and it is compared against this.
  ///
  /// Not itself a secret, but kept here so the isolate gets one consistent
  /// snapshot in a single read. Splitting it across two stores creates a state
  /// where the group list and the identity disagree.
  final String selfPubkeyHex;

  final List<NotificationGroupKey> groups;

  bool get isEmpty => groups.isEmpty;

  /// The `authors` filter for the shared-comment subscription.
  List<String> get groupNpubHexes =>
      groups.map((g) => g.groupNpubHex).toList(growable: false);

  NotificationGroupKey? forGroup(String groupId) {
    for (final g in groups) {
      if (g.groupId == groupId) {
        return g;
      }
    }
    return null;
  }

  /// Find the group a shared event belongs to by the key that signed it.
  NotificationGroupKey? forNpub(String groupNpubHex) {
    final wanted = groupNpubHex.toLowerCase();
    for (final g in groups) {
      if (g.groupNpubHex == wanted) {
        return g;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'self_pubkey': selfPubkeyHex,
    'groups': groups.map((g) => g.toJson()).toList(growable: false),
  };

  String encode() => jsonEncode(toJson());
}

bool _isHex64(Object? value) {
  if (value is! String || value.length != 64) {
    return false;
  }
  for (var i = 0; i < 64; i++) {
    final c = value.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    final isLower = c >= 0x61 && c <= 0x66;
    final isUpper = c >= 0x41 && c <= 0x46;
    if (!isDigit && !isLower && !isUpper) {
      return false;
    }
  }
  return true;
}
