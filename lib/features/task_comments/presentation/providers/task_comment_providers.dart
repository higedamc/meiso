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
/// Personal comments are fail-closed until the session-key FFI lands
/// (secret-key mode) and stay fail-closed in Amber mode (no nsec exists).
/// This only probes the resolver for null; the resolved key material is
/// discarded here and never held in UI state.
final AutoDisposeFutureProvider<bool> personalCommentAvailabilityProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final resolver = ref.watch(personalNsecHexResolverProvider);
      final nsecHex = await resolver();
      return nsecHex != null;
    });
