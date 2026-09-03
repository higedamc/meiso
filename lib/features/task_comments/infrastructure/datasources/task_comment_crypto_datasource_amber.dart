import 'dart:convert';

import '../../../../providers/nostr_provider.dart';
import '../../../../services/amber_service.dart';
import 'task_comment_crypto_datasource.dart';
import 'task_comment_crypto_datasource_contract.dart';

/// [TaskCommentCryptoDataSource] の Amber(NIP-55)実装
///
/// 個人タスク経路のみ Amber に委譲する。共有リスト経路はグループ鍵 G を
/// 引数で受け取る鍵非依存の Rust FFI なので、Amber モードでもそのまま
/// [groupKeyDataSource](既定は [TaskCommentCryptoDataSourceRust])を使う。
///
/// 設計上の必須制約: Amber に出るのは NIP-44 暗号化・復号と署名だけ。
/// イベント外形の検証(kind / author / 署名 / d タグ)と payload 検証は
/// [TaskCommentEnvelopeDataSource] 経由で Rust 側に残し、秘密鍵モードの
/// `decrypt_comment_event` と同じ 5 点検証を維持する。「Amber が復号できた
/// 平文をそのまま信じる」形にはしない。
///
/// ContentProvider 高速パスと intent 経路の使い分けは
/// `shared_list_repository_impl.dart` の招待フローに合わせる:
/// 暗号化・復号は ContentProvider のみ、署名は ContentProvider →
/// 失敗時に intent(`signEventWithTimeout`)フォールバック。
/// `AMBER_REJECTED` を含む失敗は例外のまま伝播させ、リポジトリ側で
/// AuthFailure / DecryptionFailure に写像する(黙って握り潰さない)。
class TaskCommentCryptoDataSourceAmber implements TaskCommentCryptoDataSource {
  TaskCommentCryptoDataSourceAmber({
    required TaskCommentEnvelopeDataSource envelopeDataSource,
    required AmberService amberService,
    required NostrService nostrService,
    TaskCommentCryptoDataSource groupKeyDataSource =
        const TaskCommentCryptoDataSourceRust(),
  }) : _envelopeDataSource = envelopeDataSource,
       _amberService = amberService,
       _nostrService = nostrService,
       _groupKeyDataSource = groupKeyDataSource;

  final TaskCommentEnvelopeDataSource _envelopeDataSource;
  final AmberService _amberService;
  final NostrService _nostrService;
  final TaskCommentCryptoDataSource _groupKeyDataSource;

  @override
  Future<String> buildSignedCommentEvent({
    required String nsecHex,
    required String commentJson,
  }) {
    return _groupKeyDataSource.buildSignedCommentEvent(
      nsecHex: nsecHex,
      commentJson: commentJson,
    );
  }

  @override
  Future<String> decryptCommentEvent({
    required String nsecHex,
    required String eventJson,
  }) {
    return _groupKeyDataSource.decryptCommentEvent(
      nsecHex: nsecHex,
      eventJson: eventJson,
    );
  }

  @override
  Future<String> buildSignedPersonalCommentEvent({
    required String commentJson,
  }) async {
    final authorPubkeyHex = await _requireOwnPubkeyHex();
    final commentId =
        (jsonDecode(commentJson) as Map<String, dynamic>)['comment_id']
            as String?;
    if (commentId == null || commentId.isEmpty) {
      throw const FormatException('comment payload has no comment_id');
    }

    // Write-side validation + body clamp in Rust, mirroring what
    // build_signed_comment_event does before encrypting.
    final normalized = await _envelopeDataSource
        .validateDecryptedCommentPayload(
          plaintextJson: commentJson,
          expectedCommentId: commentId,
          expectedAuthorPubkeyHex: authorPubkeyHex,
        );

    // Self-encryption: the NIP-44 peer is the author's own pubkey, which
    // yields the same conversation key as Rust's encrypt_for_self (covered
    // by the cross-implementation vector test in task_comments.rs).
    final npub = await _nostrService.hexToNpub(authorPubkeyHex);
    final encrypted = await _amberService.encryptNip44WithContentProvider(
      plaintext: normalized,
      pubkey: authorPubkeyHex,
      npub: npub,
    );

    final unsigned = await _envelopeDataSource.buildUnsignedCommentEvent(
      authorPubkeyHex: authorPubkeyHex,
      commentId: commentId,
      encryptedContent: encrypted,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    try {
      return await _amberService.signEventWithContentProvider(
        event: unsigned,
        npub: npub,
      );
    } on Exception {
      return _amberService.signEventWithTimeout(unsigned);
    }
  }

  @override
  Future<String> decryptPersonalCommentEvent({
    required String eventJson,
  }) async {
    final authorPubkeyHex = await _requireOwnPubkeyHex();

    // Envelope verification stays in Rust: kind / author / signature /
    // d-tag presence. Only after it passes does the ciphertext go to Amber.
    final ciphertext = await _envelopeDataSource.verifySignedCommentEnvelope(
      eventJson: eventJson,
      expectedAuthorPubkeyHex: authorPubkeyHex,
    );

    // The d tag read here comes from the exact JSON Rust just
    // signature-verified (the event id covers the tags), so it is safe to
    // extract in Dart and feed back as the expected comment_id.
    final dTag = _firstDTagValue(eventJson);

    final npub = await _nostrService.hexToNpub(authorPubkeyHex);
    final plaintext = await _amberService.decryptNip44WithContentProvider(
      ciphertext: ciphertext,
      pubkey: authorPubkeyHex,
      npub: npub,
    );

    return _envelopeDataSource.validateDecryptedCommentPayload(
      plaintextJson: plaintext,
      expectedCommentId: dTag,
      expectedAuthorPubkeyHex: authorPubkeyHex,
    );
  }

  Future<String> _requireOwnPubkeyHex() async {
    final pubkey = await _nostrService.getPublicKey();
    if (pubkey == null) {
      throw StateError('public key is not available');
    }
    return pubkey;
  }

  /// Nostr addressable events use the FIRST d tag as the identifier
  /// (matching `tags.identifier()` on the Rust side).
  String _firstDTagValue(String eventJson) {
    final tags =
        (jsonDecode(eventJson) as Map<String, dynamic>)['tags'] as List?;
    for (final tag in tags ?? const []) {
      if (tag is List && tag.length >= 2 && tag[0] == 'd') {
        return tag[1] as String;
      }
    }
    throw const FormatException('comment event has no d tag');
  }
}
