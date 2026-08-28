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
}
