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

/// Rides the existing app-resume (`appLifecycleProvider`) and relay-connect
/// (`relayStatusProvider`, kept honest by the 30s `relayConnectivityMonitorProvider`)
/// events to call [SendOutboxService.flush] — no new relay subscription of
/// its own (`PLANS/MEISO_SEND_OUTBOX_LEAF.md` §6, triggers 1 and 2).
///
/// A plain (non-autoDispose) Provider: once something watches it once, it
/// keeps this subscription alive for the rest of the app's lifetime.
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

/// commentId -> queued entry, joined on [OutboxEntry.addressableId] (not the
/// event id). `TaskCommentSection` uses this, plus how long the entry has
/// been queued, to decide "Sending…" vs "Unsent" — no separate flag, so the
/// label can never drift from what is actually still queued.
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
