import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/todos_provider.dart';
import 'unread_comment_providers.dart';

/// Where the tasks with unread comments sit in the navigation tree (issue
/// #219 §1, L4): which day pages, which SOMEDAY lists, and whether anything
/// lives outside both.
///
/// Every answer here is a join of [unreadCommentCountsProvider] (L1) with the
/// local todo store. No surface counts unread on its own — the ambient dot in
/// the bottom bar, the dot on a day tab, the dot on a list row and the badge
/// on the tile are all views of the same map, so they can never disagree.
class UnreadCommentSurfaces {
  const UnreadCommentSurfaces({
    required this.dates,
    required this.listIds,
    required this.undated,
  });

  static const UnreadCommentSurfaces none = UnreadCommentSurfaces(
    dates: {},
    listIds: {},
    undated: false,
  );

  /// Day keys (local midnight, the same keys the todo store groups by) of
  /// dated tasks that have unread comments.
  final Set<DateTime> dates;

  /// `customListId` values (custom and shared lists alike) of tasks that have
  /// unread comments.
  final Set<String> listIds;

  /// A task with neither a date nor a list has unread comments.
  final bool undated;

  /// Ambient dot on the TODAY segment: some day page has an unread thread.
  bool get today => dates.isNotEmpty;

  /// Ambient dot on the SOMEDAY segment: some list row (or an undated task
  /// outside any list) has an unread thread.
  bool get someday => listIds.isNotEmpty || undated;

  bool get any => today || someday;

  /// Locating dot on a day tab.
  bool hasUnreadOn(DateTime day) {
    return dates.contains(DateTime(day.year, day.month, day.day));
  }

  /// Locating dot on a custom or shared list row.
  bool hasUnreadInList(String listId) => listIds.contains(listId);

  /// Locating dot on a planning row (THIS WEEK, NEXT MONTH, ...): any unread
  /// day inside the inclusive range.
  bool hasUnreadBetween(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    return dates.any((day) => !day.isBefore(first) && !day.isAfter(last));
  }
}

/// Derived from [unreadCommentCountsProvider] and the todo store only. While
/// the own pubkey is unknown L1 reports no unread, so this is empty too — a
/// cold start never lights a dot for the user's own threads. A task whose
/// comments are stored but which no longer exists locally contributes
/// nothing: there is no surface it could be located on.
final unreadCommentSurfacesProvider = Provider<UnreadCommentSurfaces>((ref) {
  final counts = ref.watch(unreadCommentCountsProvider);
  if (counts.isEmpty) {
    return UnreadCommentSurfaces.none;
  }
  final todos = ref.watch(todosProvider).valueOrNull;
  if (todos == null) {
    return UnreadCommentSurfaces.none;
  }

  final dates = <DateTime>{};
  final listIds = <String>{};
  var undated = false;
  todos.forEach((dateKey, group) {
    for (final todo in group) {
      if (!counts.containsKey(todo.id)) {
        continue;
      }
      final listId = todo.customListId;
      if (listId != null) {
        listIds.add(listId);
      }
      if (dateKey != null) {
        dates.add(dateKey);
      } else if (listId == null) {
        undated = true;
      }
    }
  });
  if (dates.isEmpty && listIds.isEmpty && !undated) {
    return UnreadCommentSurfaces.none;
  }
  return UnreadCommentSurfaces(
    dates: dates,
    listIds: listIds,
    undated: undated,
  );
});
