import 'nostr_relay_user_agent_impl.dart'
    if (dart.library.html) 'nostr_relay_user_agent_web.dart' as impl;

/// Relay WebSocket User-Agent (issue #130).
Future<String> buildNostrRelayUserAgent() => impl.buildNostrRelayUserAgent();
