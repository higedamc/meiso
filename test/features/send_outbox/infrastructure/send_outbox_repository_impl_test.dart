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

  test('enqueue adds one entry to the queue', () async {
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

  test(
    'enqueuing the same eventId twice stays at one entry (primary-key dedup '
    'against double-enqueue)',
    () async {
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
      // Not overwritten by the second enqueue's content — first one stands.
      expect(all.single.eventJson, '{"id":"ev-1","v":1}');
    },
  );

  test(
    'a second enqueue for the same addressableId (a comment edited before '
    'the first copy sent) replaces the stale entry instead of queuing both',
    () async {
      await repository.enqueue(
        eventId: 'ev-1',
        eventJson: '{"id":"ev-1","body":"first draft"}',
        kind: 35002,
        addressableId: 'comment-1',
      );
      final result = await repository.enqueue(
        eventId: 'ev-2',
        eventJson: '{"id":"ev-2","body":"edited"}',
        kind: 35002,
        addressableId: 'comment-1',
      );

      expect(result.isRight(), true);
      final all = await repository.loadAll();
      expect(all, hasLength(1));
      expect(all.single.eventId, 'ev-2');
      expect(all.single.eventJson, '{"id":"ev-2","body":"edited"}');

      // Negative control: a different addressableId must not collide.
      await repository.enqueue(
        eventId: 'ev-3',
        eventJson: '{"id":"ev-3"}',
        kind: 35002,
        addressableId: 'comment-2',
      );
      expect(await repository.loadAll(), hasLength(2));
    },
  );

  test('an event over maxEventJsonBytes is rejected and never queued', () async {
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
    'hitting maxEntries rejects new entries without evicting the existing '
    'ones',
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

  test('markSent removes the entry from the box', () async {
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
    'markFailed increments attempts and sets lastError, without mixing in '
    'the event body',
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

  test('survives an app restart (reopening the box)', () async {
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
