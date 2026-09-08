import 'package:freezed_annotation/freezed_annotation.dart';

part 'nutzap_contribution.freezed.dart';
part 'nutzap_contribution.g.dart';

/// 受け取った NutZap（協同貯金への貢献）
///
/// NIP-61 の kind 9321 NutZap を回収（swap）した結果の記録。
/// コントリビューションフィードや「誰がいくら投げたか」の表示に使う。
@freezed
class NutzapContribution with _$NutzapContribution {
  const factory NutzapContribution({
    /// 元となった kind 9321 イベントID（重複回収防止のキー）
    required String eventId,

    /// 貢献先ゴールID
    required String goalId,

    /// 額面（sat）
    required int amountSats,

    /// 送り主の公開鍵（hex）
    required String senderPubkey,

    /// 任意のメッセージ（NutZap の content）
    String? comment,

    /// 回収（自分のウォレットへ swap）した日時
    required DateTime redeemedAt,
  }) = _NutzapContribution;

  factory NutzapContribution.fromJson(Map<String, dynamic> json) =>
      _$NutzapContributionFromJson(json);
}
