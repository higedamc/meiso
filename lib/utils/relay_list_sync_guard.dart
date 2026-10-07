/// Decides which relay list the settings sync keeps after reading the
/// account's NIP-65 relay list (kind 10002).
///
/// The relay list is a privacy choice: a user who configured only their own
/// relay expects their pubkey's activity to stay there. The automatic sync
/// used to replace the saved list with whatever the fetch returned, and a
/// fetch returns an empty list both when no relay could be reached and when
/// the account has no relay list, so one unreachable relay at start-up was
/// enough to swap the user's relay for the public defaults (issue #193).
///
/// Pure function so the policy can be unit-tested without a provider.
library;

import '../bridge_generated.dart/api.dart' show RelayListSyncStatus;
import '../models/app_settings.dart';

/// The relay list to keep after reading the account's kind 10002.
///
/// Only [RelayListSyncStatus.found] with at least one relay replaces
/// [savedRelays], because only then was the account's own event actually
/// read and it names relays. An unreachable relay or a missing event keeps
/// [savedRelays] unchanged. A read event with no `r` tags is also kept out:
/// "no relays" can be set from the relay screen directly, while a stray
/// empty event would silently stop every sync with no visible cause.
List<String> resolveSyncedRelays({
  required RelayListSyncStatus status,
  required List<String> remoteRelays,
  required List<String> savedRelays,
}) {
  switch (status) {
    case RelayListSyncStatus.found:
      if (remoteRelays.isEmpty) {
        return List<String>.from(savedRelays);
      }
      return List<String>.from(remoteRelays);
    case RelayListSyncStatus.unreachable:
    case RelayListSyncStatus.notFound:
      return List<String>.from(savedRelays);
  }
}

/// Relays to initialise the Nostr client with at start-up.
///
/// The client used to be initialised from the in-memory relay status map,
/// which is empty on a cold start, so it fell back to the public defaults
/// even though the user had saved their own relay. Returns `null` only when
/// no [AppSettings] were ever saved (first start, the caller applies the
/// defaults); a saved list is respected as it is, including an empty one.
/// `AppSettings.relays` defaults to `[]`, so "never configured" and
/// "deliberately none" can only be told apart by whether settings exist.
List<String>? startupRelaysFromSaved(AppSettings? saved) {
  if (saved == null) {
    return null;
  }
  return List<String>.from(saved.relays);
}
