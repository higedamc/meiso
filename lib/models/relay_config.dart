/// Amethyst-inspired relay roles.
///
/// - [outbox] (global write): NIP-65 write relays for publishing events.
/// - [inbox]  (global read):  NIP-65 read relays for fetching/discovery.
/// - [local]:  On-device relay (Citrine) for fast cache and offline.
///
/// [global] is kept as a backward-compatible alias that maps to both
/// outbox + inbox (read-write).
enum RelayRole {
  local,
  global,
  outbox,
  inbox,
}

class RelayConfig {
  const RelayConfig({
    required this.url,
    required this.role,
  });

  final String url;
  final RelayRole role;

  bool get isLocal => role == RelayRole.local;

  bool get isWritable =>
      role == RelayRole.global ||
      role == RelayRole.outbox ||
      role == RelayRole.local;

  bool get isReadable =>
      role == RelayRole.global ||
      role == RelayRole.inbox ||
      role == RelayRole.local;
}

const String defaultCitrineUrl = 'ws://localhost:4869';

bool isLikelyLocalRelayUrl(String url) {
  final normalized = url.trim().toLowerCase();
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;

  if (uri.scheme != 'ws') return false;
  if (uri.port != 4869) return false;
  return uri.host == 'localhost' || uri.host == '127.0.0.1';
}
