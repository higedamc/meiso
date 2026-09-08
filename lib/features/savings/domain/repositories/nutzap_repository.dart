import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/cashu_proof.dart';
import '../entities/nutzap_contribution.dart';

/// NutZap（NIP-61）のリポジトリインターフェース
///
/// 協同貯金で他者からの NutZap を受け取り、自ウォレットに回収する経路を
/// 抽象化する。実装は Infrastructure 層で Rust（`rust/src/nutzap.rs`）と
/// nostr-sdk をラップする。
///
/// フロー:
/// 1. [publishNutzapInfo] でゴールの mint と P2PK 公開鍵を kind 10019 で宣言
/// 2. 送り手は [sendNutzap] で受取人の P2PK 鍵にロックした kind 9321 を発行
/// 3. 受取側は [fetchIncomingNutzaps] で着信を取得し [redeemNutzap] で回収（swap）
abstract class NutzapRepository {
  /// ゴールの受取情報（mint + P2PK 公開鍵）を kind 10019 で公開する。
  /// 協同ゴール作成時に呼ぶ。
  Future<Either<Failure, void>> publishNutzapInfo({
    required String mintUrl,
    required String p2pkPubkey,
  });

  /// 指定ゴール（受取人の P2PK 鍵）に向けて NutZap（kind 9321）を送る。
  ///
  /// [proofs] は受取人の P2PK 鍵にロック済みの proof。
  Future<Either<Failure, void>> sendNutzap({
    required String recipientPubkey,
    required String mintUrl,
    required List<CashuProof> proofs,
    String? comment,
  });

  /// ゴール宛の未回収 NutZap（kind 9321）を取得する。
  Future<Either<Failure, List<IncomingNutzap>>> fetchIncomingNutzaps({
    required String goalId,
    required String p2pkPubkey,
  });

  /// 着信 NutZap を自ウォレットに回収（swap）し、貢献記録を返す。
  /// 回収済みの eventId は二重回収しないこと。
  Future<Either<Failure, NutzapContribution>> redeemNutzap({
    required String goalId,
    required IncomingNutzap nutzap,
  });
}

/// 着信した NutZap（未回収）
class IncomingNutzap {
  const IncomingNutzap({
    required this.eventId,
    required this.senderPubkey,
    required this.mintUrl,
    required this.proofs,
    this.comment,
  });

  /// kind 9321 イベントID（回収済み判定のキー）
  final String eventId;

  /// 送り主公開鍵（hex）
  final String senderPubkey;

  /// proof を発行した mint
  final String mintUrl;

  /// P2PK ロックされた proof 群
  final List<CashuProof> proofs;

  /// 任意メッセージ
  final String? comment;
}
