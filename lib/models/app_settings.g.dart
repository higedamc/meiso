// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    _$AppSettingsImpl(
      darkMode: json['darkMode'] as bool? ?? false,
      weekStartDay: (json['weekStartDay'] as num?)?.toInt() ?? 1,
      calendarView: json['calendarView'] as String? ?? 'week',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      relays:
          (json['relays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      torMode:
          $enumDecodeNullable(_$TorModeEnumMap, json['torMode']) ??
          TorMode.disabled,
      proxyUrl: json['proxyUrl'] as String? ?? 'socks5://127.0.0.1:9050',
      customListOrder:
          (json['customListOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastViewedCustomListId: json['lastViewedCustomListId'] as String?,
      taskUiMode:
          $enumDecodeNullable(_$TaskUiModeEnumMap, json['taskUiMode']) ??
          TaskUiMode.reminders,
      featureFlags:
          (json['featureFlags'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const <String, bool>{},
      hideCompletedTasks: json['hideCompletedTasks'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'weekStartDay': instance.weekStartDay,
      'calendarView': instance.calendarView,
      'notificationsEnabled': instance.notificationsEnabled,
      'relays': instance.relays,
      'torMode': _$TorModeEnumMap[instance.torMode]!,
      'proxyUrl': instance.proxyUrl,
      'customListOrder': instance.customListOrder,
      'lastViewedCustomListId': instance.lastViewedCustomListId,
      'taskUiMode': _$TaskUiModeEnumMap[instance.taskUiMode]!,
      'featureFlags': instance.featureFlags,
      'hideCompletedTasks': instance.hideCompletedTasks,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$TorModeEnumMap = {
  TorMode.disabled: 'disabled',
  TorMode.internal: 'internal',
  TorMode.orbot: 'orbot',
};

const _$TaskUiModeEnumMap = {
  TaskUiMode.reminders: 'reminders',
  TaskUiMode.asana: 'asana',
  TaskUiMode.wunderlist: 'wunderlist',
  TaskUiMode.kanban: 'kanban',
};
