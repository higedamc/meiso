import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/media_attachment.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/errors/media_failure.dart';
import '../../../../services/logger_service.dart';

/// BUD-02 Blossom upload service.
///
/// Protocol flow:
/// 1. Compute SHA-256 of file bytes
/// 2. Create Kind 24242 auth event with tags [t, upload], [x, <sha256>], [expiration, ...]
/// 3. PUT /upload with file body and Authorization: Nostr <base64(authEvent)>
/// 4. Parse response for blob URL
class BlossomUploadService {
  BlossomUploadService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Signs a Kind 24242 auth event.
  ///
  /// [signEvent] is an external callback that handles the actual signing,
  /// supporting both normal mode (secret key) and Amber mode.
  Future<MediaAttachment> upload({
    required File file,
    required MediaServer server,
    required Future<String> Function({
      required String sha256hex,
      required int fileSize,
    }) signAuthEvent,
  }) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final sha256hex = digest.toString();

    AppLogger.info('[Blossom] Uploading ${bytes.length} bytes to ${server.url}');
    AppLogger.debug('[Blossom] SHA-256: $sha256hex');

    final authEventJson = await signAuthEvent(
      sha256hex: sha256hex,
      fileSize: bytes.length,
    );

    final authBase64 = base64.encode(utf8.encode(authEventJson));
    final uploadUrl = _normalizeUrl(server.url, '/upload');

    // 署名済みの Kind 24242 認証イベント(ベアラ相当)を平文で送らない。
    // http:// だと MITM でトークンを盗まれ有効期限内にリプレイされうる。
    _requireHttps(uploadUrl);

    // followRedirects=false: サーバが http:// へリダイレクトしても追従せず、
    // 署名済みトークンが平文経路に乗るのを防ぐ（3xxは失敗として扱う）。
    final request = http.Request('PUT', Uri.parse(uploadUrl))
      ..followRedirects = false
      ..headers['Authorization'] = 'Nostr $authBase64'
      ..headers['Content-Type'] = _guessMimeType(file.path)
      ..bodyBytes = bytes;

    final streamed = await _httpClient.send(request).timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw MediaFailure.timeout(),
        );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      AppLogger.error(
        '[Blossom] Upload failed: ${response.statusCode} ${response.body}',
      );
      throw MediaFailure.uploadFailed(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final blobUrl = body['url'] as String? ?? '$uploadUrl/$sha256hex';

    AppLogger.info('[Blossom] Upload succeeded: $blobUrl');

    return MediaAttachment(
      url: blobUrl,
      sha256: sha256hex,
      mimeType: body['type'] as String? ?? _guessMimeType(file.path),
      size: body['size'] as int? ?? bytes.length,
    );
  }

  String _normalizeUrl(String baseUrl, String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base$path';
  }

  void _requireHttps(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'https') {
      throw MediaFailure.uploadFailed(
        'Insecure (non-HTTPS) server URL rejected: $url',
      );
    }
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}
