import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';

/// 貯金ゴールの目標額（Value Object, 単位: sat）
///
/// ビジネスルール:
/// - 1 sat 以上（0 や負数は不可）
/// - 上限 100,000,000 sat（= 1 BTC）。貯金用途として現実的な上限を設ける
class TargetAmount {
  const TargetAmount._(this.sats);

  /// 検証なしで作成（既存データ読み込み時）
  factory TargetAmount.unsafe(int sats) => TargetAmount._(sats);

  final int sats;

  /// 上限（1 BTC 相当）
  static const int maxSats = 100000000;

  /// バリデーション付きファクトリー
  ///
  /// ユーザー入力から作成する際に使用。
  /// 不正な場合は Left(ValidationFailure) を返す。
  static Either<Failure, TargetAmount> create(int input) {
    if (input < 1) {
      return const Left(ValidationFailure('目標額は1 sat以上にしてください'));
    }
    if (input > maxSats) {
      return const Left(
        ValidationFailure('目標額は1 BTC（100,000,000 sat）以内にしてください'),
      );
    }
    return Right(TargetAmount._(input));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TargetAmount && sats == other.sats;

  @override
  int get hashCode => sats.hashCode;

  @override
  String toString() => '$sats sat';
}
