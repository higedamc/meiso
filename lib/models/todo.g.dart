// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoImpl _$$TodoImplFromJson(Map<String, dynamic> json) => _$TodoImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  completed: json['completed'] as bool? ?? false,
  date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
  order: (json['order'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  eventId: json['eventId'] as String?,
  linkPreview: json['linkPreview'] == null
      ? null
      : LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$TodoImplToJson(_$TodoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'completed': instance.completed,
      'date': instance.date?.toIso8601String(),
      'order': instance.order,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'eventId': instance.eventId,
      'linkPreview': instance.linkPreview,
    };
