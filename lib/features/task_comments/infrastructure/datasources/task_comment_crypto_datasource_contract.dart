/// タスクコメント(kind:35002)の暗号処理データソース契約
///
/// 実装は `task_comment_crypto_datasource.dart` の
/// `TaskCommentCryptoDataSourceRust`（Rust FFI 委譲）。
/// Phase 1a(Rust/FRB)ブランチと並行開発するため、rust_api を参照する
/// 実装ファイルとこの契約ファイルを分離している。リポジトリやテストは
/// この抽象のみに依存することで、FRB バインディング未生成の状態でも
/// コンパイル・テスト可能になる。
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

  /// 個人タスク用: セッションクライアントの鍵(Rust 側常駐)で署名した
  /// kind:35002 イベント JSON を返す。
  ///
  /// 秘密鍵モードでは nsec が Rust セッション内にのみ存在し Dart へ
  /// 露出しないため、鍵を引数に取らずセッション側で完結させる。
  /// Amber モード(セッションに鍵なし)では例外を投げる(呼び出し側で
  /// fail-closed に扱う)。
  Future<String> buildSignedCommentEventWithSessionKey({
    required String commentJson,
  });

  /// 個人タスク用: セッションクライアントの鍵でイベントを検証・復号する。
  /// 検証内容は [decryptCommentEvent] と同一。
  Future<String> decryptCommentEventWithSessionKey({
    required String eventJson,
  });
}
