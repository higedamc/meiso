import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../core/common/failure.dart';
import '../../../providers/nostr_provider.dart';
import '../../../services/logger_service.dart';
import '../domain/outbox_entry.dart';
import '../domain/send_outbox_repository.dart';

/// 送信アウトボックスの再送エンジン。
///
/// トリガは 1 経路だけに頼らない(`PLANS/MEISO_SEND_OUTBOX_LEAF.md` §6):
/// アプリ復帰・リレー接続確立(`presentation/providers/outbox_providers.dart`
/// から [flush] を呼ぶ)に加えて、ここ自身が指数バックオフの定期タイマーを
/// 持つ。再送は直列(同時に投げない)。1 件成功するたびにキューから削除し、
/// 失敗したら試行回数・最終エラーを更新して次へ進む。
class SendOutboxService {
  SendOutboxService({
    required SendOutboxRepository repository,
    required NostrService nostrService,
  }) : _repository = repository,
       _nostrService = nostrService;

  final SendOutboxRepository _repository;
  final NostrService _nostrService;

  bool _flushing = false;
  Timer? _timer;
  bool _disposed = false;

  static const Duration minBackoff = Duration(seconds: 30);
  static const Duration maxBackoff = Duration(minutes: 15);

  /// [eventJson](署名済み)をキューへ追加し、再送タイマーを起動する。
  Future<Either<Failure, Unit>> enqueue({
    required String eventId,
    required String eventJson,
    required int kind,
    String? addressableId,
  }) async {
    final result = await _repository.enqueue(
      eventId: eventId,
      eventJson: eventJson,
      kind: kind,
      addressableId: addressableId,
    );
    if (result.isRight()) {
      unawaited(_rearm());
    }
    return result;
  }

  /// 1 件だけ即時に再試行する(未送信バブルの「タップで再試行」用)。
  Future<void> retryNow(String eventId) async {
    final entries = await _repository.loadAll();
    OutboxEntry? target;
    for (final entry in entries) {
      if (entry.eventId == eventId) {
        target = entry;
        break;
      }
    }
    if (target == null) {
      return;
    }
    await _sendOne(target);
    unawaited(_rearm());
  }

  /// キュー全件を直列で 1 回ずつ試行する。
  ///
  /// 同時に複数の [flush] が走らないよう、進行中なら即 return する
  /// (アプリ復帰・リレー接続・定期タイマーが短時間に重なっても安全)。
  Future<void> flush() async {
    if (_flushing || _disposed) {
      return;
    }
    _flushing = true;
    try {
      for (final entry in await _repository.loadAll()) {
        await _sendOne(entry);
      }
    } finally {
      _flushing = false;
    }
    unawaited(_rearm());
  }

  Future<void> _sendOne(OutboxEntry entry) async {
    try {
      final result = await _nostrService.sendSignedEvent(entry.eventJson);
      if (result.success) {
        await _repository.markSent(entry.eventId);
        return;
      }
      await _repository.markFailed(
        eventId: entry.eventId,
        errorMessage: result.errorMessage ?? 'send failed (no error message)',
      );
    } on Object catch (e) {
      AppLogger.warning('[send-outbox] 送信試行エラー: $e');
      await _repository.markFailed(
        eventId: entry.eventId,
        errorMessage: e.toString(),
      );
    }
  }

  /// タイマーを再評価する。キューが空なら止めて待機(次のトリガで再開)、
  /// 空でなければ現在の最大 `attempts` から次のバックオフを計算して張る。
  Future<void> _rearm() async {
    _timer?.cancel();
    _timer = null;
    if (_disposed) {
      return;
    }
    final remaining = await _repository.loadAll();
    if (remaining.isEmpty) {
      return;
    }
    _timer = Timer(nextBackoff(remaining), () => unawaited(flush()));
  }

  /// `min(30s * 2^(attempts-1), 15分)`。`attempts` はキュー内の最大値を使う。
  /// タイマーに依存せず単体でテストできるよう static にしている。
  static Duration nextBackoff(List<OutboxEntry> entries) {
    var maxAttempts = 0;
    for (final entry in entries) {
      if (entry.attempts > maxAttempts) {
        maxAttempts = entry.attempts;
      }
    }
    final exponent = maxAttempts <= 1 ? 0 : (maxAttempts - 1).clamp(0, 10);
    final seconds = minBackoff.inSeconds * (1 << exponent);
    return Duration(
      seconds: seconds.clamp(minBackoff.inSeconds, maxBackoff.inSeconds),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
