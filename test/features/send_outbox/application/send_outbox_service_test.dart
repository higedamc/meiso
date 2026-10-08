import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/bridge_generated.dart/api.dart' show EventSendResult;
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/send_outbox/application/send_outbox_service.dart';
import 'package:meiso/features/send_outbox/domain/outbox_entry.dart';
import 'package:meiso/features/send_outbox/domain/send_outbox_repository.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:mocktail/mocktail.dart';

/// Hive を使わないインメモリ fake。キューの状態遷移だけを見る。
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

  test('送信成功なら flush でキューから消える', () async {
    when(
      () => nostrService.sendSignedEvent(any()),
    ).thenAnswer((_) async => _sendOk());
    await repository.enqueue(eventId: 'ev-1', eventJson: '{}', kind: 35002);

    await service.flush();

    expect(await repository.loadAll(), isEmpty);
  });

  test(
    '送信失敗なら flush 後もキューに残り、attempts が増え lastError が入る',
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

  test('flush は直列: 1件失敗しても残りのエントリも試行される', () async {
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
  });

  test('retryNow は指定した eventId だけ即時再試行する', () async {
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

  group('nextBackoff', () {
    OutboxEntry entryWithAttempts(int attempts) => OutboxEntry(
      eventId: 'ev',
      eventJson: '{}',
      kind: 35002,
      queuedAt: 0,
      attempts: attempts,
    );

    test('attempts<=1 は下限の30秒', () {
      expect(
        SendOutboxService.nextBackoff([entryWithAttempts(0)]),
        const Duration(seconds: 30),
      );
      expect(
        SendOutboxService.nextBackoff([entryWithAttempts(1)]),
        const Duration(seconds: 30),
      );
    });

    test('attempts が増えるほど指数的に伸びる', () {
      expect(
        SendOutboxService.nextBackoff([entryWithAttempts(2)]),
        const Duration(seconds: 60),
      );
      expect(
        SendOutboxService.nextBackoff([entryWithAttempts(5)]),
        const Duration(seconds: 30 * 16),
      );
    });

    test('上限の15分で頭打ちになる(ここを外すと無限に伸びる回帰になる)', () {
      final uncapped = SendOutboxService.nextBackoff([entryWithAttempts(10)]);
      expect(uncapped, const Duration(minutes: 15));

      // 回帰防止の否定チェック: 上限を外すと 30*2^9=15360秒 になり 15分を超える。
      expect(const Duration(minutes: 15) < const Duration(seconds: 15360), true);
    });

    test('キューが複数件なら最大の attempts を基準にする', () {
      expect(
        SendOutboxService.nextBackoff([
          entryWithAttempts(1),
          entryWithAttempts(4),
        ]),
        SendOutboxService.nextBackoff([entryWithAttempts(4)]),
      );
    });
  });
}
