/// タスクコメント(kind:35002)の暗号処理データソース契約
///
/// 実装は `task_comment_crypto_datasource.dart` の
/// `TaskCommentCryptoDataSourceRust`（Rust FFI 委譲、秘密鍵モード）と
/// `task_comment_crypto_datasource_amber.dart` の
/// `TaskCommentCryptoDataSourceAmber`（個人経路を Amber / NIP-55 に委譲）。
/// providers 側がモードに応じて実装を選ぶため、リポジトリはモード非依存の
/// ままこの抽象のみに依存する。rust_api を参照する実装ファイルと
/// この契約ファイルを分離しているのは、FRB バインディング未生成の状態でも
/// コンパイル・テスト可能にするため。
abstract class TaskCommentCryptoDataSource {
  /// コメント payload JSON を NIP-44 self-encrypt し、nsec で署名した
  /// kind:35002 イベント JSON を返す。
  ///
  /// [nsecHex] は共有リストならグループ鍵 G、個人タスクなら自分の鍵。
  Future<String> buildSignedCommentEvent({
    required String nsecHex,
    required String commentJson,
  });

  /// kind:35002 イベント JSON を復号し、平文の payload JSON を返す。
  Future<String> decryptCommentEvent({
    required String nsecHex,
    required String eventJson,
  });

  /// 個人タスク用: 利用者自身の鍵で署名した kind:35002 イベント JSON を返す。
  ///
  /// 秘密鍵モードは Rust セッション内の鍵で完結し(nsec を Dart へ出さない)、
  /// Amber モードは外部署名者(NIP-55)に暗号化と署名を委譲する。
  /// 署名できない場合(Amber 拒否など)は例外を投げる(呼び出し側で
  /// AuthFailure に写像し、握り潰さず UI に出す)。
  Future<String> buildSignedPersonalCommentEvent({
    required String commentJson,
  });

  /// 個人タスク用: 利用者自身の鍵でイベントを検証・復号する。
  /// 検証内容は [decryptCommentEvent] と同一
  /// (kind / author / 署名 / d タグ照合 / payload スキーマ)。
  Future<String> decryptPersonalCommentEvent({
    required String eventJson,
  });
}

/// Amber 経路の Rust 側ヘルパー契約(暗号・署名は含まない検証専用 FFI)
///
/// Amber モードでは NIP-44 暗号化・復号と署名だけが Rust の外(NIP-55)へ
/// 出る。イベント外形の検証と payload 検証は引き続き Rust 側で行うことで、
/// `decrypt_comment_event` と同じ 5 点検証(kind / author / 署名 / d タグ /
/// payload スキーマ)を Amber モードでも落とさない。
abstract class TaskCommentEnvelopeDataSource {
  /// 暗号化済み content を載せた kind:35002 の未署名イベント JSON を返す。
  Future<String> buildUnsignedCommentEvent({
    required String authorPubkeyHex,
    required String commentId,
    required String encryptedContent,
    required int createdAt,
  });

  /// 署名済みイベントの外形(kind / author / 署名 / d タグ存在)を検証し、
  /// content(暗号文)を返す。
  Future<String> verifySignedCommentEnvelope({
    required String eventJson,
    required String expectedAuthorPubkeyHex,
  });

  /// 復号済み平文 payload を検証し、正規化済み payload JSON を返す
  /// (スキーマ + body クランプ + d タグ照合 + author 照合)。
  Future<String> validateDecryptedCommentPayload({
    required String plaintextJson,
    required String expectedCommentId,
    required String expectedAuthorPubkeyHex,
  });
}
