import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/nostr_provider.dart';
import '../../../../services/logger_service.dart';
import '../../../shared_list/infrastructure/providers/repository_providers.dart';
import '../../domain/repositories/task_comment_repository.dart';
import '../datasources/task_comment_crypto_datasource.dart';
import '../datasources/task_comment_crypto_datasource_contract.dart';
import '../datasources/task_comment_local_datasource.dart';
import '../repositories/task_comment_repository_impl.dart';

final taskCommentCryptoDataSourceProvider =
    Provider<TaskCommentCryptoDataSource>((ref) {
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
  );
});

/// 個人タスクコメント(kind:35002, author=self)のリアルタイム購読
///
/// watch している間だけ購読が張られる(dispose で解除)。Phase 2 の
/// UI(タスク詳細画面など)がこの provider を watch して有効化する。
/// 共有リスト側の kind:35002 は todos_provider の既存 shared-v1
/// 購読ハンドラ経由でルーティングされる。
final personalTaskCommentSubscriptionProvider = FutureProvider<String?>((
  ref,
) async {
  final initialized = ref.watch(nostrInitializedProvider);
  if (!initialized) {
    return null;
  }

  final nostrService = ref.read(nostrServiceProvider);
  final publicKeyHex = await nostrService.getPublicKey();
  if (publicKeyHex == null) {
    return null;
  }

  final repository = ref.read(taskCommentRepositoryProvider);
  final seenEventIds = <String>{};

  final subscriptionId = await nostrService.subscribePersonalTaskComments(
    publicKeyHex: publicKeyHex,
    onEventsReceived: (events) {
      unawaited(() async {
        // LWW 決定論化: created_at 昇順(同秒は event id 辞書順)で適用
        // (shared-v1 todos の issue #138 R1/R2 と同じ規則)
        final ordered = events.toList()
          ..sort((a, b) {
            if (a.createdAt != b.createdAt) {
              return a.createdAt.compareTo(b.createdAt);
            }
            return a.eventId.compareTo(b.eventId);
          });
        for (final event in ordered) {
          if (seenEventIds.contains(event.eventId)) {
            continue;
          }
          seenEventIds.add(event.eventId);
          final result = await repository.applyRemoteCommentEvent(
            eventJson: event.eventJson,
          );
          result.fold(
            (failure) => AppLogger.warning(
              '[task-chat] personal comment apply failed: '
              '${failure.message}',
            ),
            (_) {},
          );
        }
      }());
    },
  );

  ref.onDispose(() {
    unawaited(nostrService.stopSubscription(subscriptionId));
  });

  return subscriptionId;
});
