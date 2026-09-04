import 'package:freezed_annotation/freezed_annotation.dart';

part 'cashu_proof.freezed.dart';
part 'cashu_proof.g.dart';

/// Cashu の proof（ecash 本体）
///
/// ⚠️ これは **bearer 資産** である。secret を知る者が使用できる。
/// 取り扱い注意:
/// - secret / C をログに出力してはならない（[toString] でマスクする）
/// - NIP-60 kind 7375 として暗号化保存する（平文でリレーに出さない）
///
/// フィールドは Cashu NUT-00 の Proof 形式に対応する。
@freezed
class CashuProof with _$CashuProof {
  const factory CashuProof({
    /// keyset ID（どの mint / keyset の proof か）
    required String id,

    /// 額面（sat）。Cashu は 2 の冪の額面に分割される。
    required int amount,

    /// 秘密値（この proof の所有を証明する）。**秘密**
    required String secret,

    /// 署名（unblinded signature, 16進）
    required String C,

    /// この proof を保管している mint の URL
    required String mintUrl,
  }) = _CashuProof;

  const CashuProof._();

  factory CashuProof.fromJson(Map<String, dynamic> json) =>
      _$CashuProofFromJson(json);

  /// 秘密値・署名をマスクしてログ事故を防ぐ
  @override
  String toString() =>
      'CashuProof(id: $id, amount: $amount, mintUrl: $mintUrl, '
      'secret: <redacted>, C: <redacted>)';
}
