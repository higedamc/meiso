import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/nostr_provider.dart';
import '../../../../services/amber_service.dart';
import '../../../send_outbox/presentation/providers/outbox_providers.dart';
import '../../../shared_list/infrastructure/providers/repository_providers.dart';
import '../../domain/repositories/task_comment_repository.dart';
import '../datasources/task_comment_crypto_datasource.dart';
import '../datasources/task_comment_crypto_datasource_amber.dart';
import '../datasources/task_comment_crypto_datasource_contract.dart';
import '../datasources/task_comment_local_datasource.dart';
import '../repositories/task_comment_repository_impl.dart';
import 'personal_task_comment_session.dart';

/// Mode-dependent crypto datasource: the repository stays mode-agnostic and
/// this provider picks the personal-path implementation (Rust session key in
/// secret-key mode, Amber/NIP-55 delegation in Amber mode).
final taskCommentCryptoDataSourceProvider =
    Provider<TaskCommentCryptoDataSource>((ref) {
      if (ref.watch(isAmberModeProvider)) {
        return TaskCommentCryptoDataSourceAmber(
          envelopeDataSource: const TaskCommentEnvelopeDataSourceRust(),
          amberService: AmberService(),
          nostrService: ref.watch(nostrServiceProvider),
        );
      }
      return const TaskCommentCryptoDataSourceRust();
    });

final taskCommentLocalDataSourceProvider = Provider<TaskCommentLocalDataSource>(
  (ref) {
    return TaskCommentLocalDataSourceHive();
  },
);

final taskCommentRepositoryProvider = Provider<TaskCommentRepository>((ref) {
  return TaskCommentRepositoryImpl(
    cryptoDataSource: ref.watch(taskCommentCryptoDataSourceProvider),
    localDataSource: ref.watch(taskCommentLocalDataSourceProvider),
    keyDataSource: ref.watch(sharedGroupKeyLocalDataSourceProvider),
    nostrService: ref.watch(nostrServiceProvider),
    outboxService: ref.watch(sendOutboxServiceProvider),
  );
});

/// Session-scoped realtime subscription for personal task comments
/// (`kind:35002`, author = self). Issue #218 L2.
///
/// Armed once from the app root (`_MeisoAppState.initState`) with a plain
/// `ref.read` and kept for the app's lifetime; it is not autoDispose, so it
/// does not depend on any screen being open. Without this the unread
/// indicator would be dead UI: a comment written on another device never
/// reached this one until that exact task's thread was opened.
///
/// `nostrInitializedProvider` drives it: login (true) starts the
/// subscription, logout (false) stops it, so a subscription never outlives
/// the session that opened it. Shared-list `kind:35002` events still route
/// through the shared-v1 group subscription and full fetch in
/// `todos_provider`.
final personalTaskCommentSessionProvider = Provider<PersonalTaskCommentSession>(
  (ref) {
    final session = PersonalTaskCommentSession(
      nostrService: ref.watch(nostrServiceProvider),
      repository: ref.watch(taskCommentRepositoryProvider),
    );
    // ref.listen (not ref.watch): the root reads this provider while the
    // session is still uninitialised and never listens to it, and a
    // dependency change does not recompute a watched provider that has no
    // listener. An active listener fires regardless.
    ref
      ..onDispose(session.stop)
      ..listen<bool>(nostrInitializedProvider, (_, initialized) {
        if (initialized) {
          unawaited(session.start());
        } else {
          session.stop();
        }
      }, fireImmediately: true);
    return session;
  },
);

/// Kept for `TaskCommentSection`, which watches it while a personal thread is
/// on screen. It delegates to [personalTaskCommentSessionProvider] so the
/// detail screen never opens a second REQ for the same filter, and closing
/// the screen never stops the session-scoped subscription.
final AutoDisposeProvider<PersonalTaskCommentSession>
personalTaskCommentSubscriptionProvider = Provider.autoDispose((ref) {
  return ref.watch(personalTaskCommentSessionProvider);
});
