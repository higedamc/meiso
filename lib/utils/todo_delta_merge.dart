/// Merge helpers for the delta sync (`_syncFromNostrDelta`).
///
/// The delta sync replaces every affected list with the relay snapshot. A task
/// that was added or edited locally while the fetch was in flight is still
/// `needsSync` and has not reached the relays yet, so the snapshot does not
/// contain it (or contains an older version). It must win over the snapshot or
/// the local change is silently lost.
///
/// Pure function so the policy can be unit-tested without a provider.
library;

import '../models/todo.dart';

/// [merged] with every `needsSync` todo from [current] put back in place of
/// whatever the snapshot had for that id. Order of the surviving snapshot
/// entries is preserved; preserved todos are appended.
List<Todo> preserveInFlightTodos({
  required List<Todo> merged,
  required Iterable<Todo> current,
}) {
  final pending = current.where((t) => t.needsSync).toList();
  if (pending.isEmpty) return merged;

  final pendingIds = pending.map((t) => t.id).toSet();
  final result = merged.where((t) => !pendingIds.contains(t.id)).toList();
  result.addAll(pending);
  return result;
}
