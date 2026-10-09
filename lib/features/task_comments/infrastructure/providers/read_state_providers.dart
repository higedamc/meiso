import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/task_comment_read_state_datasource.dart';

/// Device-local read watermarks for comment threads (issue #218).
///
/// Lives in its own file so the fetch-scope leaf can edit
/// `repository_providers.dart` without touching this one.
final taskCommentReadStateDataSourceProvider =
    Provider<TaskCommentReadStateDataSource>((ref) {
      return TaskCommentReadStateDataSourceHive();
    });
