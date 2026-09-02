import '../../../../bridge_generated.dart/api.dart' as rust_api;
import 'task_comment_crypto_datasource_contract.dart';

/// [TaskCommentCryptoDataSource] の Rust FFI 実装
///
/// Phase 1a(`leaf/task-chat-rust`)で生成される 2 関数
/// `sharedBuildSignedCommentEvent` / `sharedDecryptCommentEvent` への
/// 薄いラッパー。task_comments 配下で rust_api を参照するのは
/// このファイルのみとし、FRB バインディングがマージされるまでの
/// アナライザエラーをここに閉じ込める。
class TaskCommentCryptoDataSourceRust implements TaskCommentCryptoDataSource {
  const TaskCommentCryptoDataSourceRust();

  @override
  Future<String> buildSignedCommentEvent({
    required String nsecHex,
    required String commentJson,
  }) {
    return rust_api.sharedBuildSignedCommentEvent(
      groupNsecHex: nsecHex,
      commentJson: commentJson,
    );
  }

  @override
  Future<String> decryptCommentEvent({
    required String nsecHex,
    required String eventJson,
  }) {
    return rust_api.sharedDecryptCommentEvent(
      groupNsecHex: nsecHex,
      eventJson: eventJson,
    );
  }

  @override
  Future<String> buildSignedCommentEventWithSessionKey({
    required String commentJson,
  }) {
    return rust_api.clientBuildSignedCommentEvent(commentJson: commentJson);
  }

  @override
  Future<String> decryptCommentEventWithSessionKey({
    required String eventJson,
  }) {
    return rust_api.clientDecryptCommentEvent(eventJson: eventJson);
  }
}
