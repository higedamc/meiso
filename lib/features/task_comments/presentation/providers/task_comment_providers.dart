import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task_comment.dart';
import '../../infrastructure/providers/repository_providers.dart';

/// Watches the local comment store for one task (created_at ascending,
/// tombstones included — the UI filters them out).
final AutoDisposeStreamProviderFamily<List<TaskComment>, String>
taskCommentsStreamProvider = StreamProvider.autoDispose
    .family<List<TaskComment>, String>((ref, taskId) {
      return ref
          .watch(taskCommentRepositoryProvider)
          .watchComments(taskId: taskId);
    });

/// Whether personal-task comments can be signed at all.
///
/// Both signing modes can now sign personal comments: secret-key mode via the
/// Rust session key and Amber mode via the external signer (NIP-55), so this
/// is always true. Kept as the single seam the widget checks so any future
/// unsignable state fails closed with the explicit notice instead of a
/// silently failing input; runtime signing failures (e.g. Amber rejection)
/// still surface through AuthFailure and a SnackBar.
final Provider<bool> personalCommentAvailabilityProvider = Provider<bool>(
  (ref) => true,
);
