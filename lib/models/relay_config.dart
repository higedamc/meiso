enum RelayRole {
  local,
  global,
}

class RelayConfig {
  const RelayConfig({
    required this.url,
    required this.role,
  });

  final String url;
  final RelayRole role;
}

bool isLikelyLocalRelayUrl(String url) {
  final normalized = url.trim().toLowerCase();
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;

  // Android local relay is supported only via explicit local endpoint:
  // ws://localhost:4869 or ws://127.0.0.1:4869
  if (uri.scheme != 'ws') return false;
  if (uri.port != 4869) return false;
  return uri.host == 'localhost' || uri.host == '127.0.0.1';
}
