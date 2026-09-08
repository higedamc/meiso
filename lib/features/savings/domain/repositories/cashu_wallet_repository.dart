import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/cashu_proof.dart';
import '../entities/goal_balance.dart';

/// Cashu ウォレットのリポジトリインターフェース
///
/// Cashu の proof（ecash）操作を抽象化する。実装は Infrastructure 層で
/// Rust（cdk）FFI をラップする（`rust/src/cashu.rs`）。
///
/// 責務:
/// - Lightning invoice 経由の発行（mint）/ 払い出し（melt）/ 交換（swap）
/// - proof のローカル保管と NIP-60（kind 7375 暗号化）への同期
/// - ゴール単位の残高算出
///
/// セキュリティ:
/// - proof は bearer 資産。実装は secret / C をログに出さないこと
/// - 乱数は cdk 内蔵 CSPRNG を使用（自前の Math.random / rand 禁止）
abstract class CashuWalletRepository {
  // ============================================================
  // 発行 / 払い出し（Lightning 連携）
  // ============================================================

  /// 指定額の発行用 Lightning invoice を作成する（mint quote）。
  ///
  /// 戻り値: [MintQuote]（支払うべき bolt11 と quote ID）
  Future<Either<Failure, MintQuote>> createDepositInvoice({
    required String mintUrl,
    required int amountSats,
  });

  /// invoice の支払を検知して proof を発行・受領する（mint）。
  ///
  /// 受領した proof は [goalId] のウォレットに保存する。
  /// 戻り値: 発行された proof 群
  Future<Either<Failure, List<CashuProof>>> redeemDepositInvoice({
    required String goalId,
    required String mintUrl,
    required String quoteId,
  });

  /// proof を Lightning へ払い出す（melt）。掃き出し / 出金に使用。
  ///
  /// [destinationInvoice] は払い出し先の bolt11。
  /// 戻り値: 実際に払い出した額（手数料控除後の sat）
  Future<Either<Failure, int>> withdrawToLightning({
    required String goalId,
    required String mintUrl,
    required String destinationInvoice,
  });

  // ============================================================
  // proof 操作 / 残高
  // ============================================================

  /// proof を新しい proof に交換する（swap）。
  /// NutZap 回収後の自ウォレットへの取り込み等で使用。
  Future<Either<Failure, List<CashuProof>>> swap({
    required String mintUrl,
    required List<CashuProof> proofs,
  });

  /// ゴールの現在残高（未使用 proof 合計）を取得する。
  Future<Either<Failure, GoalBalance>> getBalance({
    required String goalId,
    required int targetSats,
  });

  // ============================================================
  // 永続化 / 同期（NIP-60）
  // ============================================================

  /// ゴールの proof をローカル + NIP-60（kind 7375 暗号化）に保存する。
  Future<Either<Failure, void>> persistProofs({
    required String goalId,
    required List<CashuProof> proofs,
  });

  /// ゴールの proof をローカル / NIP-60 から読み込む。
  Future<Either<Failure, List<CashuProof>>> loadProofs({
    required String goalId,
  });
}

/// mint quote（発行用 invoice）
class MintQuote {
  const MintQuote({
    required this.quoteId,
    required this.bolt11,
    required this.amountSats,
  });

  /// mint が払い出す quote の識別子
  final String quoteId;

  /// 支払うべき Lightning invoice（bolt11）
  final String bolt11;

  /// 発行予定額（sat）
  final int amountSats;
}
