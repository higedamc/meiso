import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_balance.freezed.dart';
part 'goal_balance.g.dart';

/// 貯金ゴールの残高・進捗
///
/// ゴールウォレットの未使用 proof 合計（[currentSats]）と目標額
/// （[targetSats]）から進捗を算出する。表示用の派生値を提供する。
@freezed
class GoalBalance with _$GoalBalance {
  const factory GoalBalance({
    /// 対象ゴールID
    required String goalId,

    /// 現在の貯金額（未使用 proof 合計, sat）
    required int currentSats,

    /// 目標額（sat）
    required int targetSats,
  }) = _GoalBalance;

  const GoalBalance._();

  factory GoalBalance.fromJson(Map<String, dynamic> json) =>
      _$GoalBalanceFromJson(json);

  /// 進捗率（0.0〜1.0）。targetSats が 0 以下なら 0。
  double get progress {
    if (targetSats <= 0) {
      return 0;
    }
    final p = currentSats / targetSats;
    if (p < 0) {
      return 0;
    }
    if (p > 1) {
      return 1;
    }
    return p;
  }

  /// 目標達成済みか
  bool get isReached => targetSats > 0 && currentSats >= targetSats;

  /// 目標までの残額（sat, 0 未満にはならない）
  int get remainingSats {
    final r = targetSats - currentSats;
    return r < 0 ? 0 : r;
  }
}
