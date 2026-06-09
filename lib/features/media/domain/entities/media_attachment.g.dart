// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MediaAttachmentImpl _$$MediaAttachmentImplFromJson(
  Map<String, dynamic> json,
) => _$MediaAttachmentImpl(
  url: json['url'] as String,
  sha256: json['sha256'] as String,
  mimeType: json['mimeType'] as String?,
  size: (json['size'] as num?)?.toInt(),
  blurHash: json['blurHash'] as String?,
);

Map<String, dynamic> _$$MediaAttachmentImplToJson(
  _$MediaAttachmentImpl instance,
) => <String, dynamic>{
  'url': instance.url,
  'sha256': instance.sha256,
  'mimeType': instance.mimeType,
  'size': instance.size,
  'blurHash': instance.blurHash,
};
