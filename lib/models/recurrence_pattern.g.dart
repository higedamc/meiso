// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_pattern.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecurrencePatternImpl _$$RecurrencePatternImplFromJson(
  Map<String, dynamic> json,
) => _$RecurrencePatternImpl(
  type: $enumDecode(_$RecurrenceTypeEnumMap, json['type']),
  interval: (json['interval'] as num?)?.toInt() ?? 1,
  weekdays: (json['weekdays'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  dayOfMonth: (json['dayOfMonth'] as num?)?.toInt(),
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
);

Map<String, dynamic> _$$RecurrencePatternImplToJson(
  _$RecurrencePatternImpl instance,
) => <String, dynamic>{
  'type': _$RecurrenceTypeEnumMap[instance.type]!,
  'interval': instance.interval,
  'weekdays': instance.weekdays,
  'dayOfMonth': instance.dayOfMonth,
  'endDate': instance.endDate?.toIso8601String(),
};

const _$RecurrenceTypeEnumMap = {
  RecurrenceType.daily: 'daily',
  RecurrenceType.weekly: 'weekly',
  RecurrenceType.monthly: 'monthly',
  RecurrenceType.custom: 'custom',
};
