// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_balance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GoalBalanceImpl _$$GoalBalanceImplFromJson(Map<String, dynamic> json) =>
    _$GoalBalanceImpl(
      goalId: json['goalId'] as String,
      currentSats: (json['currentSats'] as num).toInt(),
      targetSats: (json['targetSats'] as num).toInt(),
    );

Map<String, dynamic> _$$GoalBalanceImplToJson(_$GoalBalanceImpl instance) =>
    <String, dynamic>{
      'goalId': instance.goalId,
      'currentSats': instance.currentSats,
      'targetSats': instance.targetSats,
    };
