import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_lifecycle_provider.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../providers/relay_status_provider.dart';
import '../../application/send_outbox_service.dart';
import '../../domain/outbox_entry.dart';
import '../../domain/send_outbox_repository.dart';
import '../../infrastructure/outbox_local_datasource.dart';
import '../../infrastructure/send_outbox_repository_impl.dart';

final outboxLocalDataSourceProvider = Provider<OutboxLocalDataSource>((ref) {
  return OutboxLocalDataSourceHive();
});

final sendOutboxRepositoryProvider = Provider<SendOutboxRepository>((ref) {
  return SendOutboxRepositoryImpl(
    localDataSource: ref.watch(outboxLocalDataSourceProvider),
  );
});

final sendOutboxServiceProvider = Provider<SendOutboxService>((ref) {
  final service = SendOutboxService(
    repository: ref.watch(sendOutboxRepositoryProvider),
    nostrService: ref.watch(nostrServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// 既存のアプリ復帰(`appLifecycleProvider`)・リレー接続
/// (`relayStatusProvider`、30 秒ごとの `relayConnectivityMonitorProvider` が
/// 実接続状態を反映する)イベントに相乗りして [SendOutboxService.flush] を
/// 呼ぶだけの購読者。新規のリレー購読は作らない
/// (`PLANS/MEISO_SEND_OUTBOX_LEAF.md` §6 のトリガ 1・2)。
///
/// `TaskCommentSection` が初回ビルドで一度 watch すれば、以降は通常の
/// (autoDispose でない) Provider としてアプリ終了までこの購読を維持する。
final sendOutboxTriggerProvider = Provider<SendOutboxService>((ref) {
  final service = ref.watch(sendOutboxServiceProvider);
  var wasAnyRelayConnected = ref
      .read(relayStatusProvider)
      .values
      .any((status) => status.state == RelayConnectionState.connected);

  ref
    ..listen<AppLifecycleState>(appLifecycleProvider, (_, next) {
      if (next == AppLifecycleState.resumed) {
        unawaited(service.flush());
      }
    })
    ..listen<Map<String, RelayStatus>>(relayStatusProvider, (_, next) {
      final isAnyConnected = next.values.any(
        (status) => status.state == RelayConnectionState.connected,
      );
      if (isAnyConnected && !wasAnyRelayConnected) {
        unawaited(service.flush());
      }
      wasAnyRelayConnected = isAnyConnected;
    });

  return service;
});

/// commentId -> キュー中のエントリ。[OutboxEntry.addressableId] で結合する
/// (event id ではない)。`TaskCommentSection` がこれで
/// 「送信中」(`attempts < maxAttemptsBeforeVisible`) /
/// 「未送信」(`attempts >= maxAttemptsBeforeVisible`) を判定する
/// (別フラグを増やすと実体とずれる)。
final pendingCommentOutboxProvider =
    StreamProvider<Map<String, OutboxEntry>>((ref) {
      final repository = ref.watch(sendOutboxRepositoryProvider);
      return repository.watchAll().map((entries) {
        final byCommentId = <String, OutboxEntry>{};
        for (final entry in entries) {
          final commentId = entry.addressableId;
          if (commentId != null) {
            byCommentId[commentId] = entry;
          }
        }
        return byCommentId;
      });
    });
