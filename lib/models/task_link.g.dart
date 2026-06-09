// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskLinkImpl _$$TaskLinkImplFromJson(Map<String, dynamic> json) =>
    _$TaskLinkImpl(
      targetTaskId: json['targetTaskId'] as String,
      linkType: $enumDecode(_$TaskLinkTypeEnumMap, json['linkType']),
    );

Map<String, dynamic> _$$TaskLinkImplToJson(_$TaskLinkImpl instance) =>
    <String, dynamic>{
      'targetTaskId': instance.targetTaskId,
      'linkType': _$TaskLinkTypeEnumMap[instance.linkType]!,
    };

const _$TaskLinkTypeEnumMap = {
  TaskLinkType.blocks: 'blocks',
  TaskLinkType.blockedBy: 'blockedBy',
  TaskLinkType.relatedTo: 'relatedTo',
  TaskLinkType.duplicateOf: 'duplicateOf',
};
