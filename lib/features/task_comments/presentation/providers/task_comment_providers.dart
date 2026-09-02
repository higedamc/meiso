import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/nostr_provider.dart';
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
/// The only fail-closed path is Amber mode, where no nsec exists on this
/// device. Keying off [isAmberModeProvider] means no key material is ever
/// resolved into Dart just to answer this question.
final Provider<bool> personalCommentAvailabilityProvider = Provider<bool>((
  ref,
) {
  return !ref.watch(isAmberModeProvider);
});
