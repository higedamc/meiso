import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../../../app_theme.dart';
import '../../application/providers/media_providers.dart';
import '../../domain/entities/media_server.dart';

class MediaServerSettingsScreen extends ConsumerStatefulWidget {
  const MediaServerSettingsScreen({super.key});

  @override
  ConsumerState<MediaServerSettingsScreen> createState() =>
      _MediaServerSettingsScreenState();
}

class _MediaServerSettingsScreenState
    extends ConsumerState<MediaServerSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serversAsync = ref.watch(mediaServersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mediaServers),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refreshServers,
            onPressed: () => ref.invalidate(mediaServersProvider),
          ),
        ],
      ),
      body: serversAsync.when(
        data: (servers) {
          if (servers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 64,
                      color: isDark
                          ? AppTheme.darkTextSecondary.withOpacity(0.5)
                          : AppTheme.lightTextSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noMediaServers,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: servers.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final server = servers[index];
              return _ServerListTile(server: server);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddServerDialog(context),
        backgroundColor: AppTheme.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final urlController = TextEditingController();
    var selectedType = MediaServerType.blossom;

    final result = await showDialog<MediaServer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addMediaServer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: l10n.mediaServerUrl,
                  hintText: 'https://blossom.example.com',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MediaServerType>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: l10n.mediaServerType,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: MediaServerType.blossom,
                    child: const Text('Blossom'),
                  ),
                  DropdownMenuItem(
                    value: MediaServerType.nip96,
                    child: const Text('NIP-96'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancelButton),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                final parsed = Uri.tryParse(url);
                // 署名済みアップロードトークンを平文で送らないため、httpsのみ許可。
                if (url.isEmpty ||
                    parsed == null ||
                    parsed.scheme.toLowerCase() != 'https') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.invalidUrl)),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  MediaServer(
                    url: url,
                    type: selectedType,
                    isManual: true,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.addMediaServer),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final discovery = ref.read(mediaServerDiscoveryServiceProvider);
      await discovery.addManualServer(result);
      ref.invalidate(mediaServersProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mediaServerAdded)),
        );
      }
    }
  }
}

class _ServerListTile extends ConsumerWidget {
  const _ServerListTile({required this.server});
  final MediaServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        server.type == MediaServerType.blossom
            ? Icons.cloud_upload
            : Icons.http,
        color: server.type == MediaServerType.blossom
            ? Colors.purple.shade700
            : Colors.blue.shade700,
      ),
      title: Text(
        server.url,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        server.isManual ? l10n.mediaServerManual : l10n.mediaServerAutoDiscovered,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
      trailing: server.isManual
          ? IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _confirmDelete(context, ref),
            )
          : Chip(
              label: Text(
                server.type == MediaServerType.blossom ? 'Blossom' : 'NIP-96',
                style: const TextStyle(fontSize: 11),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMediaServer),
        content: Text(server.url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteMediaServer),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final discovery = ref.read(mediaServerDiscoveryServiceProvider);
      await discovery.removeManualServer(server.url);
      ref.invalidate(mediaServersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mediaServerDeleted)),
        );
      }
    }
  }
}
