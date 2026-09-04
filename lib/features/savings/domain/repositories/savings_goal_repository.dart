import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/savings_goal.dart';

/// 貯金ゴールのリポジトリインターフェース
///
/// ゴール定義（メタデータ）の CRUD を抽象化する。実体は既存の
/// CustomList（Kind 30001 + LWW 同期）に委譲し、貯金固有のメタ
/// （目標額・mint・P2PK・期日）を上乗せして永続化する。
///
/// 実装は `custom_list_repository_impl.dart` のパターンを踏襲する。
abstract class SavingsGoalRepository {
  /// ローカル + Nostr から全貯金ゴールを読み込む。
  Future<Either<Failure, List<SavingsGoal>>> loadGoals();

  /// 単一ゴールを取得する。
  Future<Either<Failure, SavingsGoal>> getGoal(String goalId);

  /// ゴールを作成し、ローカル + Nostr（Kind 30001）へ保存する。
  Future<Either<Failure, SavingsGoal>> createGoal(SavingsGoal goal);

  /// ゴールのメタデータを更新する（名前・目標額・期日など）。
  Future<Either<Failure, void>> updateGoal(SavingsGoal goal);

  /// ゴールを削除する（Kind 5 tombstone）。
  ///
  /// ⚠️ 実装は削除前に残高が 0 でないことを呼び出し側が確認している前提。
  /// 残高がある状態の削除は資産消失につながるため UseCase 側でガードする。
  Future<Either<Failure, void>> deleteGoal(String goalId);
}
