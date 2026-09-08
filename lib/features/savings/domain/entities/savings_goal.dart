import 'package:freezed_annotation/freezed_annotation.dart';

part 'savings_goal.freezed.dart';
part 'savings_goal.g.dart';

/// 貯金ゴール（貯金カスタムリストのメタデータ）
///
/// CustomList（Kind 30001）に「お金」を乗せるための種別メタ。
/// 個人積立・共同貯金の両方を表現する。
///
/// 設計方針（壁打ちで確定）:
/// - 単位は sat 固定（[targetSats] / [currency]）
/// - mint は非依存に持つ（[mintUrl]）。MVPは単一 mint だが将来複数化できる形
/// - ロックは UX ロック（P2PK locktime は使わない）。[deadline] と達成判定で
///   引き出しボタンの表示可否を制御する
/// - [isCollaborative] が true のとき、[p2pkPubkey] を NIP-61 kind 10019 で
///   公開し、他者の NutZap（kind 9321）を受け取る
@freezed
class SavingsGoal with _$SavingsGoal {
  const factory SavingsGoal({
    /// ゴールID（CustomList.id と対応。決定的に生成）
    required String goalId,

    /// ゴール名（表示用）
    required String name,

    /// 目標額（sat）
    required int targetSats,

    /// このゴールが ecash を保管する mint の URL
    required String mintUrl,

    /// 受取用 P2PK 公開鍵（hex）。
    /// 協同ゴールで NutZap を受け取る場合のみ必須。個人積立では null 可。
    String? p2pkPubkey,

    /// 引き出し解禁の目安期日（UX ロック用）。null なら期日条件なし。
    DateTime? deadline,

    /// 協同（共同貯金）かどうか。
    /// true のとき kind 10019 を公開し、メンバー/他者の NutZap を受け付ける。
    @Default(false) bool isCollaborative,

    /// 作成日時
    required DateTime createdAt,

    /// 単位通貨（現状 'sat' 固定。将来拡張用）
    @Default('sat') String currency,
  }) = _SavingsGoal;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) =>
      _$SavingsGoalFromJson(json);
}

/// SavingsGoal のヘルパー
extension SavingsGoalHelpers on SavingsGoal {
  /// Nostr の d タグに使うプレフィックス（ゴール定義 Kind 30001）
  static const String dTagPrefix = 'meiso-savings-';

  /// ゴールIDから Nostr d タグを生成する
  String get dTag => '$dTagPrefix$goalId';

  /// 期日を過ぎているか（UX ロック判定に使用）
  bool isPastDeadline(DateTime now) {
    final d = deadline;
    if (d == null) {
      return false;
    }
    return now.isAfter(d);
  }
}
