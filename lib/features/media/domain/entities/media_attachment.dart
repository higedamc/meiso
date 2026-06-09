import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_attachment.freezed.dart';
part 'media_attachment.g.dart';

@freezed
class MediaAttachment with _$MediaAttachment {
  const factory MediaAttachment({
    required String url,
    required String sha256,
    String? mimeType,
    int? size,
    String? blurHash,
  }) = _MediaAttachment;

  factory MediaAttachment.fromJson(Map<String, dynamic> json) =>
      _$MediaAttachmentFromJson(json);
}
