/// 送信アウトボックスの 1 エントリ(署名済みイベント)
///
/// キューには署名済みイベントの JSON そのものを持つ。再送に鍵が要らない
/// (Amber / 秘密鍵どちらの経路で署名したかがここに漏れない)ための設計。
/// 仕様: `PLANS/MEISO_SEND_OUTBOX_LEAF.md`。
class OutboxEntry {
  const OutboxEntry({
    required this.eventId,
    required this.eventJson,
    required this.kind,
    required this.queuedAt,
    this.addressableId,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      eventId: json['event_id'] as String,
      eventJson: json['event_json'] as String,
      kind: (json['kind'] as num).toInt(),
      queuedAt: (json['queued_at'] as num).toInt(),
      addressableId: json['addressable_id'] as String?,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: (json['last_attempt_at'] as num?)?.toInt(),
      lastError: json['last_error'] as String?,
    );
  }

  /// 署名済みイベントの id(64 桁小文字 hex)。box のキーでもある主キー。
  final String eventId;

  /// `sendSignedEvent` にそのまま渡せる署名済み JSON。
  final String eventJson;

  /// 監視・デバッグ用のイベント種別。
  final int kind;

  /// 最初にキューへ入れた unix 秒。
  final int queuedAt;

  /// addressable event の `d` タグ値(タスクコメントでは commentId)。
  /// UI が `TaskComment` にスキーマ変更を加えずに「未送信」を結合するための
  /// キー。event id ではなくこちらで結合する。
  final String? addressableId;

  /// 送信試行回数。
  final int attempts;

  /// 最後に試行した unix 秒。
  final int? lastAttemptAt;

  /// 最後の `errorMessage`。本文(イベント content)は含めない。
  final String? lastError;

  OutboxEntry copyWith({
    int? attempts,
    int? lastAttemptAt,
    String? lastError,
  }) {
    return OutboxEntry(
      eventId: eventId,
      eventJson: eventJson,
      kind: kind,
      queuedAt: queuedAt,
      addressableId: addressableId,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'event_json': eventJson,
    'kind': kind,
    'queued_at': queuedAt,
    'addressable_id': addressableId,
    'attempts': attempts,
    'last_attempt_at': lastAttemptAt,
    'last_error': lastError,
  };

  /// キューの最大件数。件数だけ縛っても 1 件あたりが無制限なら結局無制限
  /// なので [maxEventJsonBytes] と両方で縛る。上限到達時は新規投入をエラー
  /// にする(古いエントリを黙って捨てない)。
  static const int maxEntries = 200;

  /// 1 件あたりの `eventJson` の最大バイト数。超過分はキューに入れずに
  /// 即エラーを返す(入れてから捨てると「入れたのに消えた」になる)。
  static const int maxEventJsonBytes = 64 * 1024;

  /// この試行回数に達したエントリは UI 上「未送信」を明示する。
  static const int maxAttemptsBeforeVisible = 5;
}
