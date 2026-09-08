/// Builds the Nostr filter for shared-task comment notifications.
///
/// Same shape as the UI's existing shared-task subscription
/// (`lib/providers/nostr_provider.dart` `subscribeSharedGroupTasks`), narrowed
/// to kind:35002 only (comments) and scoped to the group npubs the local user
/// currently belongs to. Personal comments (author = self) are not part of
/// this filter — Phase 3 does not notify on those (see
/// `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`).
library;

/// kind for task-chat comments (`rust/src/task_comments.rs::TASK_COMMENT_KIND`).
const int taskCommentKind = 35002;

/// Builds a single filter covering all of [groupNpubHexes] at once, so one
/// subscription serves every group the user belongs to.
///
/// [sinceUnixSeconds], when given, resumes from `NotificationPrefsKeys
/// .lastSeenCreatedAt` instead of replaying the group's full comment history
/// on every cold start.
///
/// Returns null if [groupNpubHexes] is empty — an `authors: []` filter would
/// match nothing, and some relays audit or reject that shape.
Map<String, dynamic>? buildSharedTaskCommentFilter({
  required List<String> groupNpubHexes,
  int? sinceUnixSeconds,
}) {
  if (groupNpubHexes.isEmpty) {
    return null;
  }
  return {
    'kinds': [taskCommentKind],
    'authors': groupNpubHexes,
    if (sinceUnixSeconds != null) 'since': sinceUnixSeconds,
  };
}
