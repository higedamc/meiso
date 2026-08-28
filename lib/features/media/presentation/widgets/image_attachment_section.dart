import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../../../app_theme.dart';
import '../../../../services/logger_service.dart';
import '../../application/providers/media_providers.dart';
import '../../application/usecases/upload_image_usecase.dart';
import '../../domain/entities/media_server.dart';
import '../../../../widgets/remote_image_gate.dart';
import 'image_thumbnail.dart';

class ImageAttachmentSection extends ConsumerStatefulWidget {
  const ImageAttachmentSection({
    required this.imageUrl,
    required this.onImageChanged,
    super.key,
  });

  final String? imageUrl;
  final ValueChanged<String?> onImageChanged;

  @override
  ConsumerState<ImageAttachmentSection> createState() =>
      _ImageAttachmentSectionState();
}

class _ImageAttachmentSectionState
    extends ConsumerState<ImageAttachmentSection> {
  bool _uploading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    _showServerPicker(File(picked.path));
  }

  Future<void> _showServerPicker(File imageFile) async {
    List<MediaServer> servers;
    final cached = ref.read(mediaServersProvider);
    if (cached.hasValue) {
      servers = cached.value!;
    } else {
      final useCase = ref.read(discoverMediaServersUseCaseProvider);
      final result = await useCase();
      servers = result.fold((_) => <MediaServer>[], (list) => list);
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<MediaServer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ServerPickerSheet(servers: servers),
    );

    if (selected == null || !mounted) return;

    await _uploadToServer(imageFile, selected);
  }

  Future<void> _uploadToServer(File file, MediaServer server) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _uploading = true);

    try {
      final useCase = ref.read(uploadImageUseCaseProvider);
      final result = await useCase(
        UploadImageParams(file: file, preferredServer: server),
      );

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.imageUploadFailed(failure.message)),
                backgroundColor: Colors.red,
              ),
            );
          }
          AppLogger.error('[ImageAttachment] Upload failed: ${failure.message}');
        },
        (attachment) {
          widget.onImageChanged(attachment.url);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.imageUploaded)),
            );
          }
          AppLogger.info('[ImageAttachment] Upload success: ${attachment.url}');
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.imageUploadFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('[ImageAttachment] Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSourcePicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.imageSourceCamera),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.imageSourceGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_uploading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.uploadingImage,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.imageUrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => showFullScreenImage(context, widget.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RemoteImageGate(
                  allowed: (context) => CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                  // Tor モード時はリモート取得を抑止し非表示アイコンを表示
                  blocked: (context) => Container(
                    height: 200,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.visibility_off_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.onImageChanged(null),
                icon: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                label: Text(
                  l10n.removeImage,
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: _showSourcePicker,
        icon: Icon(
          Icons.image_outlined,
          color: AppTheme.primaryPurple.withOpacity(0.7),
        ),
        label: Text(
          l10n.attachImage,
          style: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark
                ? AppTheme.darkDivider
                : AppTheme.lightDivider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _ServerPickerSheet extends StatefulWidget {
  const _ServerPickerSheet({required this.servers});
  final List<MediaServer> servers;

  @override
  State<_ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<_ServerPickerSheet> {
  final _customUrlController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  void _selectCustomUrl() {
    final url = _customUrlController.text.trim();
    if (url.isEmpty) return;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) return;

    final isNip96 = url.contains('nostr.build') ||
        url.contains('void.cat') ||
        url.contains('sovbit');
    Navigator.pop(
      context,
      MediaServer(
        url: url,
        type: isNip96 ? MediaServerType.nip96 : MediaServerType.blossom,
        isManual: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectUploadServer,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (widget.servers.isEmpty && !_showCustomInput)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  l10n.noServersFound,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ...widget.servers.map(
              (server) => ListTile(
                leading: Icon(
                  server.type == MediaServerType.blossom
                      ? Icons.cloud_upload
                      : Icons.http,
                  color: AppTheme.primaryPurple,
                ),
                title: Text(
                  _displayUrl(server.url),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  server.type == MediaServerType.blossom ? 'Blossom' : 'NIP-96',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                trailing: server.isManual
                    ? null
                    : Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                onTap: () => Navigator.pop(context, server),
              ),
            ),
            const Divider(height: 1),
            if (!_showCustomInput)
              ListTile(
                leading: Icon(
                  Icons.add_link,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
                title: Text(l10n.addCustomServer),
                onTap: () => setState(() => _showCustomInput = true),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customUrlController,
                        decoration: InputDecoration(
                          hintText: l10n.customServerUrlHint,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        autofocus: true,
                        onSubmitted: (_) => _selectCustomUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selectCustomUrl,
                      child: Text(l10n.upload),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _displayUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.host;
  }
}
