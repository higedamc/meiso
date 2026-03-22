import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/media_server.dart';
import '../../../../services/logger_service.dart';

/// Discovers media servers from Kind 10063 events (BUD-03 / NIP-B7)
/// and merges with manually configured servers from local storage.
class MediaServerDiscoveryService {
  MediaServerDiscoveryService({
    required this.fetchKind10063ServerUrls,
  });

  /// External callback to fetch Blossom server URLs from Kind 10063 events.
  /// This decouples Nostr relay access from the media feature.
  final Future<List<String>> Function() fetchKind10063ServerUrls;

  static const _storageKey = 'manual_media_servers';

  /// Discover all available media servers.
  ///
  /// Priority: manual servers > Kind 10063 auto-discovered servers.
  /// Duplicates (by URL) are removed, keeping the manual version.
  Future<List<MediaServer>> discoverServers() async {
    final manualServers = await _loadManualServers();
    final kind10063Servers = await _fetchKind10063Servers();

    final manualUrls = manualServers.map((s) => s.url).toSet();
    final merged = <MediaServer>[
      ...manualServers,
      ...kind10063Servers.where((s) => !manualUrls.contains(s.url)),
    ];

    AppLogger.info(
      '[MediaServerDiscovery] Found ${merged.length} servers '
      '(${manualServers.length} manual, ${kind10063Servers.length} auto)',
    );

    return merged;
  }

  Future<List<MediaServer>> _fetchKind10063Servers() async {
    try {
      final urls = await fetchKind10063ServerUrls();
      return urls
          .map((url) => MediaServer(url: url, type: MediaServerType.blossom))
          .toList();
    } catch (e) {
      AppLogger.warning('[MediaServerDiscovery] Kind 10063 fetch failed: $e');
      return [];
    }
  }

  Future<List<MediaServer>> _loadManualServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_storageKey);
      if (entries == null || entries.isEmpty) return [];

      return entries.map((line) {
        final parts = line.split('|');
        return MediaServer(
          url: parts[0],
          type: parts.length > 1 && parts[1] == 'nip96'
              ? MediaServerType.nip96
              : MediaServerType.blossom,
          isManual: true,
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(
        '[MediaServerDiscovery] Failed to load manual servers: $e',
      );
      return [];
    }
  }

  /// Save a manually configured server.
  Future<void> addManualServer(MediaServer server) async {
    final current = await _loadManualServers();
    if (current.any((s) => s.url == server.url)) return;
    current.add(server.copyWith(isManual: true));
    await _saveManualServers(current);
  }

  /// Remove a manually configured server.
  Future<void> removeManualServer(String url) async {
    final current = await _loadManualServers();
    current.removeWhere((s) => s.url == url);
    await _saveManualServers(current);
  }

  /// Get all manually configured servers.
  Future<List<MediaServer>> getManualServers() => _loadManualServers();

  Future<void> _saveManualServers(List<MediaServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = servers
        .map((s) =>
            '${s.url}|${s.type == MediaServerType.nip96 ? "nip96" : "blossom"}')
        .toList();
    await prefs.setStringList(_storageKey, entries);
  }
}
