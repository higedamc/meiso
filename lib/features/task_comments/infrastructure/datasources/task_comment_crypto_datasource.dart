import '../../../../bridge_generated.dart/api.dart' as rust_api;
import 'task_comment_crypto_datasource_contract.dart';

/// [TaskCommentCryptoDataSource] の Rust FFI 実装（秘密鍵モード）
///
/// Phase 1a(`leaf/task-chat-rust`)で生成された FFI への薄いラッパー。
/// task_comments 配下で rust_api を参照するのはこのファイルのみとし、
/// FRB バインディング未生成時のアナライザエラーをここに閉じ込める。
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
  Future<String> buildSignedPersonalCommentEvent({
    required String commentJson,
  }) {
    return rust_api.clientBuildSignedCommentEvent(commentJson: commentJson);
  }

  @override
  Future<String> decryptPersonalCommentEvent({
    required String eventJson,
  }) {
    return rust_api.clientDecryptCommentEvent(eventJson: eventJson);
  }
}

/// [TaskCommentEnvelopeDataSource] の Rust FFI 実装
///
/// Amber 経路で Rust 側に残る検証専用 FFI(鍵材は一切渡らない)。
class TaskCommentEnvelopeDataSourceRust
    implements TaskCommentEnvelopeDataSource {
  const TaskCommentEnvelopeDataSourceRust();

  @override
  Future<String> buildUnsignedCommentEvent({
    required String authorPubkeyHex,
    required String commentId,
    required String encryptedContent,
    required int createdAt,
  }) {
    return rust_api.buildUnsignedCommentEvent(
      authorPubkeyHex: authorPubkeyHex,
      commentId: commentId,
      encryptedContent: encryptedContent,
      createdAt: createdAt,
    );
  }

  @override
  Future<String> verifySignedCommentEnvelope({
    required String eventJson,
    required String expectedAuthorPubkeyHex,
  }) {
    return rust_api.verifySignedCommentEnvelope(
      eventJson: eventJson,
      expectedAuthorPubkeyHex: expectedAuthorPubkeyHex,
    );
  }

  @override
  Future<String> validateDecryptedCommentPayload({
    required String plaintextJson,
    required String expectedCommentId,
    required String expectedAuthorPubkeyHex,
  }) {
    return rust_api.validateDecryptedCommentPayload(
      plaintextJson: plaintextJson,
      expectedCommentId: expectedCommentId,
      expectedAuthorPubkeyHex: expectedAuthorPubkeyHex,
    );
  }
}
