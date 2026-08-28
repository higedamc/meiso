import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/remote_image_gate.dart';

/// Compact image thumbnail for display in TodoItem rows.
class ImageThumbnail extends StatelessWidget {
  const ImageThumbnail({
    required this.imageUrl,
    this.size = 40,
    super.key,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => showFullScreenImage(context, imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: RemoteImageGate(
            allowed: (context) => CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => SizedBox(
                width: size,
                height: size,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.broken_image,
                  size: size * 0.5,
                  color: Colors.grey,
                ),
              ),
            ),
            // Tor モード時はリモート取得を抑止し非表示アイコンを表示
            blocked: (context) => SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.visibility_off_outlined,
                size: size * 0.5,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showFullScreenImage(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (_, __, ___) => _FullScreenImageView(imageUrl: imageUrl),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: RemoteImageGate(
                  allowed: (context) => CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 64, color: Colors.white54),
                    ),
                  ),
                  // Tor モード時はリモート取得を抑止し非表示アイコンを表示
                  blocked: (context) => const Center(
                    child: Icon(Icons.visibility_off_outlined,
                        size: 64, color: Colors.white54),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
