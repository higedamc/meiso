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
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'weekStartDay': instance.weekStartDay,
      'calendarView': instance.calendarView,
      'notificationsEnabled': instance.notificationsEnabled,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
