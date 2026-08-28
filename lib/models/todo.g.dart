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
  localOpId: json['localOpId'] as String?,
  localRelaySyncedAt: json['localRelaySyncedAt'] == null
      ? null
      : DateTime.parse(json['localRelaySyncedAt'] as String),
  globalRelaySyncedAt: json['globalRelaySyncedAt'] == null
      ? null
      : DateTime.parse(json['globalRelaySyncedAt'] as String),
  globalSyncPending: json['globalSyncPending'] as bool? ?? false,
  globalSyncFailed: json['globalSyncFailed'] as bool? ?? false,
  linkPreview: json['linkPreview'] == null
      ? null
      : LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>),
  recurrence: json['recurrence'] == null
      ? null
      : RecurrencePattern.fromJson(json['recurrence'] as Map<String, dynamic>),
  parentRecurringId: json['parentRecurringId'] as String?,
  customListId: json['customListId'] as String?,
  needsSync: json['needsSync'] as bool? ?? true,
  parentTaskId: json['parentTaskId'] as String?,
  depth: (json['depth'] as num?)?.toInt() ?? 0,
  taskLinks:
      (json['taskLinks'] as List<dynamic>?)
          ?.map((e) => TaskLink.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  imageUrl: json['imageUrl'] as String?,
  editorPubkey: json['editorPubkey'] as String?,
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
      'localOpId': instance.localOpId,
      'localRelaySyncedAt': instance.localRelaySyncedAt?.toIso8601String(),
      'globalRelaySyncedAt': instance.globalRelaySyncedAt?.toIso8601String(),
      'globalSyncPending': instance.globalSyncPending,
      'globalSyncFailed': instance.globalSyncFailed,
      'linkPreview': instance.linkPreview?.toJson(),
      'recurrence': instance.recurrence?.toJson(),
      'parentRecurringId': instance.parentRecurringId,
      'customListId': instance.customListId,
      'needsSync': instance.needsSync,
      'parentTaskId': instance.parentTaskId,
      'depth': instance.depth,
      'taskLinks': instance.taskLinks.map((e) => e.toJson()).toList(),
      'imageUrl': instance.imageUrl,
      'editorPubkey': instance.editorPubkey,
    };
