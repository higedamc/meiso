import '../../../../core/common/failure.dart';

/// 貯金（Cashu / NutZap）機能固有のエラー種別
enum SavingsError {
  /// mint に到達できない / 応答しない
  mintUnreachable,

  /// mint が要求を拒否した（額面不一致・無効 proof 等）
  mintRejected,

  /// proof が不足している（残高不足）
  insufficientProofs,

  /// NutZap の回収（swap）に失敗
  redeemFailed,

  /// ウォレット状態（NIP-60）の同期に失敗
  walletSyncFailed,

  /// proof の二重使用を検知（既に spend 済み）
  doubleSpend,

  /// Lightning invoice の生成・支払に失敗
  lightningFailed,

  /// ゴールが見つからない
  goalNotFound,

  /// 暗号化に失敗
  encryptionFailed,

  /// 復号化に失敗
  decryptionFailed,
}

/// 貯金機能固有の Failure
class SavingsFailure extends Failure {
  const SavingsFailure(this.error, {String? customMessage})
    : super(customMessage ?? '');

  final SavingsError error;

  @override
  String get message {
    final base = _errorMessage(error);
    final custom = super.message;
    return custom.isEmpty ? base : '$base: $custom';
  }

  static String _errorMessage(SavingsError error) {
    switch (error) {
      case SavingsError.mintUnreachable:
        return 'mintに接続できませんでした';
      case SavingsError.mintRejected:
        return 'mintが要求を拒否しました';
      case SavingsError.insufficientProofs:
        return '残高が不足しています';
      case SavingsError.redeemFailed:
        return 'NutZapの回収に失敗しました';
      case SavingsError.walletSyncFailed:
        return 'ウォレットの同期に失敗しました';
      case SavingsError.doubleSpend:
        return 'この残高は既に使用済みです（二重使用）';
      case SavingsError.lightningFailed:
        return 'Lightningの処理に失敗しました';
      case SavingsError.goalNotFound:
        return '貯金ゴールが見つかりませんでした';
      case SavingsError.encryptionFailed:
        return '暗号化に失敗しました';
      case SavingsError.decryptionFailed:
        return '復号化に失敗しました';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsFailure &&
          error == other.error &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, error, message);
}
