// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LinkPreviewImpl _$$LinkPreviewImplFromJson(Map<String, dynamic> json) =>
    _$LinkPreviewImpl(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
    );

Map<String, dynamic> _$$LinkPreviewImplToJson(_$LinkPreviewImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'title': instance.title,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'faviconUrl': instance.faviconUrl,
    };
