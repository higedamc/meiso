import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../domain/entities/media_attachment.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/errors/media_failure.dart';
import '../../../../services/logger_service.dart';

/// NIP-96 HTTP file storage integration (legacy fallback).
///
/// Protocol flow:
/// 1. GET /.well-known/nostr/nip96.json for server configuration
/// 2. Create Kind 27235 (NIP-98) auth event
/// 3. POST <api_url> with multipart form data
/// 4. Parse NIP-94 file metadata from response
class Nip96UploadService {
  Nip96UploadService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Fetch the NIP-96 server configuration.
  Future<_Nip96ServerInfo> _fetchServerInfo(String serverUrl) async {
    final wellKnownUrl = _normalizeUrl(serverUrl, '/.well-known/nostr/nip96.json');
    AppLogger.debug('[NIP-96] Fetching server info from $wellKnownUrl');

    final response = await _httpClient
        .get(Uri.parse(wellKnownUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw MediaFailure.discoveryFailed(
        'NIP-96 server info fetch failed: HTTP ${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final apiUrl = body['api_url'] as String?;
    if (apiUrl == null) {
      throw MediaFailure.discoveryFailed('NIP-96 api_url not found in server info');
    }

    return _Nip96ServerInfo(
      apiUrl: apiUrl.startsWith('http') ? apiUrl : _normalizeUrl(serverUrl, apiUrl),
    );
  }

  /// Upload a file using NIP-96.
  ///
  /// [signNip98Event] creates and signs a Kind 27235 event for the given URL/method.
  Future<MediaAttachment> upload({
    required File file,
    required MediaServer server,
    required Future<String> Function({
      required String url,
      required String method,
    }) signNip98Event,
  }) async {
    final serverInfo = await _fetchServerInfo(server.url);

    AppLogger.info('[NIP-96] Uploading to ${serverInfo.apiUrl}');

    final authEventJson = await signNip98Event(
      url: serverInfo.apiUrl,
      method: 'POST',
    );

    final authBase64 = base64.encode(utf8.encode(authEventJson));

    final request = http.MultipartRequest('POST', Uri.parse(serverInfo.apiUrl));
    request.headers['Authorization'] = 'Nostr $authBase64';
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final streamedResponse = await request.send().timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw MediaFailure.timeout(),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      AppLogger.error('[NIP-96] Upload failed: ${response.statusCode} ${response.body}');
      throw MediaFailure.uploadFailed(
        'NIP-96 HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // NIP-94 compatible response
    final nip94Event = body['nip94_event'] as Map<String, dynamic>?;
    String? url;
    String? sha256hex;
    String? mimeType;
    int? size;

    if (nip94Event != null) {
      final tags = (nip94Event['tags'] as List<dynamic>?)?.cast<List<dynamic>>();
      if (tags != null) {
        for (final tag in tags) {
          if (tag.isEmpty) continue;
          final tagName = tag[0] as String;
          if (tagName == 'url' && tag.length > 1) url = tag[1] as String;
          if (tagName == 'x' && tag.length > 1) sha256hex = tag[1] as String;
          if (tagName == 'm' && tag.length > 1) mimeType = tag[1] as String;
          if (tagName == 'size' && tag.length > 1) {
            size = int.tryParse(tag[1].toString());
          }
        }
      }
    }

    url ??= body['url'] as String?;
    if (url == null) {
      throw MediaFailure.uploadFailed('No URL in NIP-96 upload response');
    }

    AppLogger.info('[NIP-96] Upload succeeded: $url');

    return MediaAttachment(
      url: url,
      sha256: sha256hex ?? '',
      mimeType: mimeType,
      size: size,
    );
  }

  String _normalizeUrl(String baseUrl, String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base$path';
  }
}

class _Nip96ServerInfo {
  const _Nip96ServerInfo({required this.apiUrl});
  final String apiUrl;
}
