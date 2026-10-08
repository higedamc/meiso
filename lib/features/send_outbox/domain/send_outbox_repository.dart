import 'package:dartz/dartz.dart';

import '../../../core/common/failure.dart';
import 'outbox_entry.dart';

/// 送信アウトボックスの CRUD 契約。再送のトリガ・タイミング(アプリ復帰/
/// リレー接続/バックオフタイマー)はここでは扱わない
/// (`application/send_outbox_service.dart` の責務)。
abstract class SendOutboxRepository {
  /// [eventJson](署名済み)をキューに追加する。
  ///
  /// `eventId` が既にキューにあれば成功扱いで何もしない(主キーによる
  /// 二重投入防止)。[OutboxEntry.maxEventJsonBytes] を超える、または
  /// キューが既に [OutboxEntry.maxEntries] に達している場合は
  /// [ValidationFailure] を返し、キューには入れない。
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  });

  /// キュー全件(`queuedAt` 昇順)。
  Future<List<OutboxEntry>> loadAll();

  /// キューの変化を監視する(`queuedAt` 昇順)。
  Stream<List<OutboxEntry>> watchAll();

  /// 送信に成功したエントリをキューから外す。
  Future<void> markSent(String eventId);

  /// 送信に失敗したエントリの試行回数・最終エラーを更新する。
  /// [errorMessage] に本文(イベント content)を混ぜないこと。
  Future<void> markFailed({required String eventId, required String errorMessage});
}
