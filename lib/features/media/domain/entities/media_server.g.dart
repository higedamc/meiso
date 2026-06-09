// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MediaServerImpl _$$MediaServerImplFromJson(Map<String, dynamic> json) =>
    _$MediaServerImpl(
      url: json['url'] as String,
      type:
          $enumDecodeNullable(_$MediaServerTypeEnumMap, json['type']) ??
          MediaServerType.blossom,
      isManual: json['isManual'] as bool? ?? false,
    );

Map<String, dynamic> _$$MediaServerImplToJson(_$MediaServerImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'type': _$MediaServerTypeEnumMap[instance.type]!,
      'isManual': instance.isManual,
    };

const _$MediaServerTypeEnumMap = {
  MediaServerType.blossom: 'blossom',
  MediaServerType.nip96: 'nip96',
};
