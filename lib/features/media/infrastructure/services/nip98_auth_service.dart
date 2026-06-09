import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../services/logger_service.dart';

/// NIP-98 HTTP Auth event creation service.
///
/// Creates Kind 27235 events for authenticating HTTP requests,
/// used by NIP-96 file uploads.
class Nip98AuthService {
  /// Build an unsigned Kind 27235 event JSON for NIP-98 authentication.
  ///
  /// Tags: [u, <url>], [method, <POST|GET>], optional [payload, <sha256>]
  /// The caller is responsible for signing the event.
  String buildUnsignedAuthEvent({
    required String url,
    required String method,
    required String publicKeyHex,
    List<int>? payloadBytes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final tags = <List<String>>[
      ['u', url],
      ['method', method.toUpperCase()],
    ];

    if (payloadBytes != null && payloadBytes.isNotEmpty) {
      final payloadHash = sha256.convert(payloadBytes).toString();
      tags.add(['payload', payloadHash]);
    }

    final event = {
      'kind': 27235,
      'created_at': now,
      'tags': tags,
      'content': '',
      'pubkey': publicKeyHex,
    };

    AppLogger.debug('[NIP-98] Built unsigned auth event for $method $url');
    return jsonEncode(event);
  }
}
