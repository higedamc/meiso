import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show EventSendResult;
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/send_outbox/application/send_outbox_service.dart';
import 'package:meiso/features/send_outbox/domain/outbox_entry.dart';
import 'package:meiso/features/send_outbox/domain/send_outbox_repository.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:mocktail/mocktail.dart';

/// In-memory fake, no Hive — observes only the queue's state transitions.
class FakeSendOutboxRepository implements SendOutboxRepository {
  final Map<String, OutboxEntry> _entries = {};

  @override
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  }) async {
    if (_entries.containsKey(eventId)) {
      return const Right(unit);
    }
    _entries[eventId] = OutboxEntry(
      eventId: eventId,
      eventJson: eventJson,
      kind: kind,
      queuedAt: _entries.length,
      addressableId: addressableId,
    );
    return const Right(unit);
  }

  @override
  Future<List<OutboxEntry>> loadAll() async {
    final list = _entries.values.toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return list;
  }

  @override
  Stream<List<OutboxEntry>> watchAll() async* {
    yield await loadAll();
  }

  @override
  Future<void> markSent(String eventId) async {
    _entries.remove(eventId);
  }

  @override
  Future<void> markFailed({
    required String eventId,
    required String errorMessage,
  }) async {
    final existing = _entries[eventId];
    if (existing == null) return;
    _entries[eventId] = existing.copyWith(
      attempts: existing.attempts + 1,
      lastAttemptAt: 0,
      lastError: errorMessage,
    );
  }
}

class MockNostrService extends Mock implements NostrService {}

EventSendResult _sendOk() => EventSendResult(
  eventId: 'relay-accepted',
  success: true,
  successfulRelays: BigInt.one,
  failedRelays: BigInt.zero,
  timedOut: false,
);

EventSendResult _sendFail({String errorMessage = 'Timeout after 3 seconds'}) =>
    EventSendResult(
      eventId: '',
      success: false,
      successfulRelays: BigInt.zero,
      failedRelays: BigInt.one,
      timedOut: true,
      errorMessage: errorMessage,
    );

void main() {
  late FakeSendOutboxRepository repository;
  late MockNostrService nostrService;
  late SendOutboxService service;

  setUp(() {
    repository = FakeSendOutboxRepository();
    nostrService = MockNostrService();
    service = SendOutboxService(
      repository: repository,
      nostrService: nostrService,
    );
  });

  tearDown(() {
    service.dispose();
  });

  test('a successful send is removed from the queue by flush', () async {
    when(
      () => nostrService.sendSignedEvent(any()),
    ).thenAnswer((_) async => _sendOk());
    await repository.enqueue(eventId: 'ev-1', eventJson: '{}', kind: 35002);

    await service.flush();

    expect(await repository.loadAll(), isEmpty);
  });

  test(
    'a failed send stays queued after flush, with attempts incremented and '
    'lastError set',
    () async {
      when(
        () => nostrService.sendSignedEvent(any()),
      ).thenAnswer((_) async => _sendFail());
      await repository.enqueue(eventId: 'ev-1', eventJson: '{}', kind: 35002);

      await service.flush();

      final all = await repository.loadAll();
      expect(all, hasLength(1));
      expect(all.single.attempts, 1);
      expect(all.single.lastError, 'Timeout after 3 seconds');
    },
  );

  test(
    'flush is serial: one failing entry does not stop the rest from being '
    'attempted',
    () async {
      final attempted = <String>[];
      when(() => nostrService.sendSignedEvent(any())).thenAnswer((invocation) async {
        final json = invocation.positionalArguments.single as String;
        attempted.add(json);
        return json == 'fail' ? _sendFail() : _sendOk();
      });
      await repository.enqueue(eventId: 'ev-1', eventJson: 'fail', kind: 35002);
      await repository.enqueue(eventId: 'ev-2', eventJson: 'ok', kind: 35002);

      await service.flush();

      expect(attempted, ['fail', 'ok']);
      final all = await repository.loadAll();
      expect(all, hasLength(1));
      expect(all.single.eventId, 'ev-1');
    },
  );

  test('retryNow retries only the given eventId, immediately', () async {
    when(
      () => nostrService.sendSignedEvent(any()),
    ).thenAnswer((_) async => _sendOk());
    await repository.enqueue(eventId: 'ev-1', eventJson: '{}', kind: 35002);
    await repository.enqueue(eventId: 'ev-2', eventJson: '{}', kind: 35002);

    await service.retryNow('ev-1');

    final all = await repository.loadAll();
    expect(all, hasLength(1));
    expect(all.single.eventId, 'ev-2');
  });

  test(
    'retryNow no-ops while a flush is already in flight, instead of sending '
    'the same entry a second time over the wire',
    () async {
      final gate = Completer<void>();
      final attemptedJson = <String>[];
      when(() => nostrService.sendSignedEvent(any())).thenAnswer((
        invocation,
      ) async {
        attemptedJson.add(invocation.positionalArguments.single as String);
        await gate.future;
        return _sendOk();
      });
      await repository.enqueue(eventId: 'ev-1', eventJson: 'slow', kind: 35002);

      final flushFuture = service.flush();
      // Give flush() a turn to start and reach the (now gated) send call.
      await Future<void>.delayed(Duration.zero);

      await service.retryNow('ev-1');
      expect(attemptedJson, ['slow']); // no second concurrent send

      gate.complete();
      await flushFuture;
    },
  );

  group('nextBackoff', () {
    // All entries share queuedAt/lastAttemptAt = 0, and nowEpochSeconds is
    // pinned to 0 too, so the returned Duration is exactly each entry's own
    // backoff-from-last-attempt — deterministic, independent of the real
    // wall clock.
    OutboxEntry entryWithAttempts(int attempts, {int lastAttemptAt = 0}) =>
        OutboxEntry(
          eventId: 'ev',
          eventJson: '{}',
          kind: 35002,
          queuedAt: 0,
          attempts: attempts,
          lastAttemptAt: attempts > 0 ? lastAttemptAt : null,
        );

    test('attempts<=1 is the 30s floor', () {
      expect(
        SendOutboxService.nextBackoff([
          entryWithAttempts(0),
        ], nowEpochSeconds: 0),
        const Duration(seconds: 30),
      );
      expect(
        SendOutboxService.nextBackoff([
          entryWithAttempts(1),
        ], nowEpochSeconds: 0),
        const Duration(seconds: 30),
      );
    });

    test('grows exponentially with attempts', () {
      expect(
        SendOutboxService.nextBackoff([
          entryWithAttempts(2),
        ], nowEpochSeconds: 0),
        const Duration(seconds: 60),
      );
      expect(
        SendOutboxService.nextBackoff([
          entryWithAttempts(5),
        ], nowEpochSeconds: 0),
        const Duration(seconds: 30 * 16),
      );
    });

    test('caps at the 15-minute ceiling (removing the cap is the regression)', () {
      final uncapped = SendOutboxService.nextBackoff([
        entryWithAttempts(10),
      ], nowEpochSeconds: 0);
      expect(uncapped, const Duration(minutes: 15));

      // Negative control: without the cap, 30*2^9 = 15360s, which exceeds
      // 15 minutes — so this assertion only holds because the cap is applied.
      expect(const Duration(minutes: 15) < const Duration(seconds: 15360), true);
    });

    test(
      'a queue with multiple entries uses the earliest deadline, not the '
      'largest attempt count (one poisoned entry must not hold back a '
      'freshly queued one)',
      () {
        final freshlyQueued = entryWithAttempts(0);
        final poisonedAtCeiling = entryWithAttempts(10);

        final combined = SendOutboxService.nextBackoff([
          freshlyQueued,
          poisonedAtCeiling,
        ], nowEpochSeconds: 0);

        expect(
          combined,
          SendOutboxService.nextBackoff([freshlyQueued], nowEpochSeconds: 0),
        );
        expect(
          combined,
          isNot(
            SendOutboxService.nextBackoff([
              poisonedAtCeiling,
            ], nowEpochSeconds: 0),
          ),
        );
      },
    );
  });
}
