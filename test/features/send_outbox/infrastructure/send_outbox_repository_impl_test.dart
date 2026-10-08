import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/send_outbox/domain/outbox_entry.dart';
import 'package:meiso/features/send_outbox/infrastructure/outbox_local_datasource.dart';
import 'package:meiso/features/send_outbox/infrastructure/send_outbox_repository_impl.dart';

void main() {
  late Directory tempDir;
  late Box<Map<dynamic, dynamic>> box;
  late OutboxLocalDataSourceHive localDataSource;
  late SendOutboxRepositoryImpl repository;
  var boxSeq = 0;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('send_outbox_test');
    Hive.init(tempDir.path);
    boxSeq++;
    box = await Hive.openBox<Map<dynamic, dynamic>>('send_outbox_$boxSeq');
    localDataSource = OutboxLocalDataSourceHive(box: box);
    repository = SendOutboxRepositoryImpl(localDataSource: localDataSource);
  });

  tearDown(() async {
    if (box.isOpen) {
      await box.deleteFromDisk();
    }
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('enqueue でキューに1件入る', () async {
    final result = await repository.enqueue(
      eventId: 'ev-1',
      eventJson: '{"id":"ev-1"}',
      kind: 35002,
      addressableId: 'comment-1',
    );

    expect(result.isRight(), true);
    final all = await repository.loadAll();
    expect(all, hasLength(1));
    expect(all.single.eventId, 'ev-1');
    expect(all.single.addressableId, 'comment-1');
    expect(all.single.attempts, 0);
  });

  test('同じ eventId を2回 enqueue しても1件のまま(主キーによる二重投入防止)', (
  ) async {
    await repository.enqueue(
      eventId: 'ev-1',
      eventJson: '{"id":"ev-1","v":1}',
      kind: 35002,
    );
    final second = await repository.enqueue(
      eventId: 'ev-1',
      eventJson: '{"id":"ev-1","v":2}',
      kind: 35002,
    );

    expect(second.isRight(), true);
    final all = await repository.loadAll();
    expect(all, hasLength(1));
    // 2回目の投入内容で上書きされていない(最初の投入がそのまま残る)
    expect(all.single.eventJson, '{"id":"ev-1","v":1}');
  });

  test('maxEventJsonBytes を超えるイベントはキューに入らずエラーになる', (
  ) async {
    final hostile = 'x' * (OutboxEntry.maxEventJsonBytes + 1);

    final result = await repository.enqueue(
      eventId: 'ev-huge',
      eventJson: hostile,
      kind: 35002,
    );

    expect(result.isLeft(), true);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('should be Left'),
    );
    final all = await repository.loadAll();
    expect(all, isEmpty);
  });

  test(
    'maxEntries に達すると新規投入はエラーになり、既存の古いエントリは消えない',
    () async {
      for (var i = 0; i < OutboxEntry.maxEntries; i++) {
        final result = await repository.enqueue(
          eventId: 'ev-$i',
          eventJson: '{"id":"ev-$i"}',
          kind: 35002,
        );
        expect(result.isRight(), true);
      }

      final overflow = await repository.enqueue(
        eventId: 'ev-overflow',
        eventJson: '{"id":"ev-overflow"}',
        kind: 35002,
      );

      expect(overflow.isLeft(), true);
      overflow.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('should be Left'),
      );

      final all = await repository.loadAll();
      expect(all, hasLength(OutboxEntry.maxEntries));
      expect(all.any((e) => e.eventId == 'ev-0'), true);
      expect(all.any((e) => e.eventId == 'ev-overflow'), false);
    },
  );

  test('markSent で box から消える', () async {
    await repository.enqueue(
      eventId: 'ev-1',
      eventJson: '{"id":"ev-1"}',
      kind: 35002,
    );

    await repository.markSent('ev-1');

    final all = await repository.loadAll();
    expect(all, isEmpty);
  });

  test(
    'markFailed で attempts が増え lastError が入る。lastError に本文は混ざらない',
    () async {
      await repository.enqueue(
        eventId: 'ev-1',
        eventJson: '{"id":"ev-1","content":"super secret comment body"}',
        kind: 35002,
      );

      await repository.markFailed(
        eventId: 'ev-1',
        errorMessage: 'Timeout after 3 seconds',
      );

      final all = await repository.loadAll();
      expect(all.single.attempts, 1);
      expect(all.single.lastError, 'Timeout after 3 seconds');
      expect(
        all.single.lastError!.contains('super secret comment body'),
        false,
      );
      expect(all.single.lastAttemptAt, isNotNull);

      await repository.markFailed(
        eventId: 'ev-1',
        errorMessage: 'Timeout after 3 seconds',
      );
      final second = await repository.loadAll();
      expect(second.single.attempts, 2);
    },
  );

  test('アプリ再起動(box を開き直す)をまたいで残る', () async {
    await repository.enqueue(
      eventId: 'ev-1',
      eventJson: '{"id":"ev-1"}',
      kind: 35002,
      addressableId: 'comment-1',
    );
    await localDataSource.close();

    final reopened = OutboxLocalDataSourceHive(
      box: await Hive.openBox<Map<dynamic, dynamic>>(box.name),
    );
    final reopenedRepository = SendOutboxRepositoryImpl(
      localDataSource: reopened,
    );

    final all = await reopenedRepository.loadAll();
    expect(all, hasLength(1));
    expect(all.single.eventId, 'ev-1');
    expect(all.single.addressableId, 'comment-1');
  });
}
