// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutzap_contribution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NutzapContributionImpl _$$NutzapContributionImplFromJson(
  Map<String, dynamic> json,
) => _$NutzapContributionImpl(
  eventId: json['eventId'] as String,
  goalId: json['goalId'] as String,
  amountSats: (json['amountSats'] as num).toInt(),
  senderPubkey: json['senderPubkey'] as String,
  comment: json['comment'] as String?,
  redeemedAt: DateTime.parse(json['redeemedAt'] as String),
);

Map<String, dynamic> _$$NutzapContributionImplToJson(
  _$NutzapContributionImpl instance,
) => <String, dynamic>{
  'eventId': instance.eventId,
  'goalId': instance.goalId,
  'amountSats': instance.amountSats,
  'senderPubkey': instance.senderPubkey,
  'comment': instance.comment,
  'redeemedAt': instance.redeemedAt.toIso8601String(),
};
