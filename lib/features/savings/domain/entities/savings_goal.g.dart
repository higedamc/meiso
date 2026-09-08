// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_goal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SavingsGoalImpl _$$SavingsGoalImplFromJson(Map<String, dynamic> json) =>
    _$SavingsGoalImpl(
      goalId: json['goalId'] as String,
      name: json['name'] as String,
      targetSats: (json['targetSats'] as num).toInt(),
      mintUrl: json['mintUrl'] as String,
      p2pkPubkey: json['p2pkPubkey'] as String?,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      isCollaborative: json['isCollaborative'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      currency: json['currency'] as String? ?? 'sat',
    );

Map<String, dynamic> _$$SavingsGoalImplToJson(_$SavingsGoalImpl instance) =>
    <String, dynamic>{
      'goalId': instance.goalId,
      'name': instance.name,
      'targetSats': instance.targetSats,
      'mintUrl': instance.mintUrl,
      'p2pkPubkey': instance.p2pkPubkey,
      'deadline': instance.deadline?.toIso8601String(),
      'isCollaborative': instance.isCollaborative,
      'createdAt': instance.createdAt.toIso8601String(),
      'currency': instance.currency,
    };
