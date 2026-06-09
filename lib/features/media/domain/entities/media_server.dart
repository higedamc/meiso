import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_server.freezed.dart';
part 'media_server.g.dart';

enum MediaServerType {
  blossom,
  nip96,
}

@freezed
class MediaServer with _$MediaServer {
  const factory MediaServer({
    required String url,
    @Default(MediaServerType.blossom) MediaServerType type,
    @Default(false) bool isManual,
  }) = _MediaServer;

  factory MediaServer.fromJson(Map<String, dynamic> json) =>
      _$MediaServerFromJson(json);
}
