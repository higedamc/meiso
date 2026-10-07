/// Decides what to do with a local task that the relay snapshot does not
/// contain (`_updateStateWithSyncedTodos`, step 2).
///
/// Kind 30001 is replaceable and carries the whole list together with the
/// `created_at` of the event. A task that is missing from a list whose
/// `created_at` is newer than the task's local `updatedAt` was deleted on
/// another device; that is positive evidence. Absence alone is not: the list
/// may never have arrived, or the copy we got may predate the local edit.
///
/// This replaces the wall-clock rule ("absent and older than 24 h means
/// deleted"), which deleted tasks whenever a fetch was incomplete. See
/// PLANS/MEISO_TASK_LOSS_FIX_PLAN.md, decision 2.
///
/// Pure function so the policy can be unit-tested without a provider.
library;

/// Outcome for a local task that is absent from the relay snapshot.
enum AbsentTodoResolution {
  /// No list snapshot for the task's list arrived: nothing to compare, keep
  /// the task unchanged.
  keepNoEvidence,

  /// The list snapshot predates the local edit: keep the task and mark it
  /// for re-publish, because the relays hold an older version of the list.
  keepAndResync,

  /// The list snapshot is newer than the local edit and omits the task: it
  /// was deleted elsewhere, drop it locally.
  drop,
}

/// Key of the list a task belongs to, as used in the per-list maps
/// (`null` custom list id is the default list).
String listKeyForCausalCompare(String? customListId) =>
    customListId ?? 'default';

/// Resolves a task absent from the snapshot.
///
/// [listCreatedAt] is the `created_at` (unix seconds) of the fetched event
/// for the task's own list, or `null` when that list was not in the fetch.
/// [localUpdatedAt] is the task's local `updatedAt`.
///
/// `created_at` has second resolution, so the local timestamp is compared at
/// the same resolution. An equal second is not "newer": a list published in
/// the same second as the edit is treated as concurrent and the task is kept.
AbsentTodoResolution resolveAbsentTodo({
  required int? listCreatedAt,
  required DateTime localUpdatedAt,
}) {
  if (listCreatedAt == null) {
    return AbsentTodoResolution.keepNoEvidence;
  }

  final localUpdatedSec = localUpdatedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  if (listCreatedAt > localUpdatedSec) {
    return AbsentTodoResolution.drop;
  }
  return AbsentTodoResolution.keepAndResync;
}
