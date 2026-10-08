import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../../core/common/failure.dart';
import '../domain/outbox_entry.dart';
import '../domain/send_outbox_repository.dart';
import 'outbox_local_datasource.dart';

class SendOutboxRepositoryImpl implements SendOutboxRepository {
  SendOutboxRepositoryImpl({required OutboxLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final OutboxLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  }) async {
    final bytes = utf8.encode(eventJson).length;
    if (bytes > OutboxEntry.maxEventJsonBytes) {
      return Left(
        ValidationFailure(
          '送信アウトボックス: イベントが大きすぎます ($bytes bytes)',
        ),
      );
    }

    final existing = await _localDataSource.loadAll();
    if (existing.containsKey(eventId)) {
      // 主キーによる二重投入防止: 既にキュー済みなら何もしない。
      return const Right(unit);
    }
    if (existing.length >= OutboxEntry.maxEntries) {
      return Left(
        ValidationFailure(
          '送信アウトボックス: 上限(${OutboxEntry.maxEntries}件)に達しています',
        ),
      );
    }

    await _localDataSource.put(
      OutboxEntry(
        eventId: eventId,
        eventJson: eventJson,
        kind: kind,
        queuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        addressableId: addressableId,
      ),
    );
    return const Right(unit);
  }

  @override
  Future<List<OutboxEntry>> loadAll() async {
    final map = await _localDataSource.loadAll();
    return _sorted(map.values);
  }

  @override
  Stream<List<OutboxEntry>> watchAll() {
    return _localDataSource.watchAll().map((map) => _sorted(map.values));
  }

  @override
  Future<void> markSent(String eventId) => _localDataSource.remove(eventId);

  @override
  Future<void> markFailed({
    required String eventId,
    required String errorMessage,
  }) async {
    final existing = (await _localDataSource.loadAll())[eventId];
    if (existing == null) {
      // 送信中に別経路(手動再試行など)で既に外れていた。
      return;
    }
    await _localDataSource.put(
      existing.copyWith(
        attempts: existing.attempts + 1,
        lastAttemptAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lastError: errorMessage,
      ),
    );
  }

  List<OutboxEntry> _sorted(Iterable<OutboxEntry> entries) {
    final list = entries.toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return list;
  }
}
