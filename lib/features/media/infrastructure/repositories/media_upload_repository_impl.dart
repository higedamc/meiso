import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../domain/entities/media_attachment.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/errors/media_failure.dart';
import '../../domain/repositories/media_upload_repository.dart';
import '../datasources/media_server_discovery_service.dart';
import '../services/blossom_upload_service.dart';
import '../services/nip96_upload_service.dart';
import '../../../../services/logger_service.dart';

/// Concrete implementation that tries Blossom first, falls back to NIP-96.
class MediaUploadRepositoryImpl implements MediaUploadRepository {
  MediaUploadRepositoryImpl({
    required this.blossomService,
    required this.nip96Service,
    required this.discoveryService,
    required this.signBlossomAuthEvent,
    required this.signNip98AuthEvent,
  });

  final BlossomUploadService blossomService;
  final Nip96UploadService nip96Service;
  final MediaServerDiscoveryService discoveryService;

  /// Callback to sign a Blossom Kind 24242 auth event.
  final Future<String> Function({
    required String sha256hex,
    required int fileSize,
  }) signBlossomAuthEvent;

  /// Callback to sign a NIP-98 Kind 27235 auth event.
  final Future<String> Function({
    required String url,
    required String method,
  }) signNip98AuthEvent;

  @override
  Future<Either<MediaFailure, MediaAttachment>> uploadImage({
    required File file,
    MediaServer? preferredServer,
  }) async {
    try {
      if (preferredServer != null) {
        return _uploadToServer(file, preferredServer);
      }

      final serversResult = await discoverServers();
      final servers = serversResult.fold(
        (failure) => <MediaServer>[],
        (list) => list,
      );

      if (servers.isEmpty) {
        return Left(MediaFailure.noServer());
      }

      final blossomServers =
          servers.where((s) => s.type == MediaServerType.blossom).toList();
      for (final server in blossomServers) {
        try {
          final result = await blossomService.upload(
            file: file,
            server: server,
            signAuthEvent: signBlossomAuthEvent,
          );
          return Right(result);
        } catch (e) {
          AppLogger.warning(
            '[MediaUpload] Blossom upload failed for ${server.url}: $e',
          );
        }
      }

      final nip96Servers =
          servers.where((s) => s.type == MediaServerType.nip96).toList();
      for (final server in nip96Servers) {
        try {
          final result = await nip96Service.upload(
            file: file,
            server: server,
            signNip98Event: signNip98AuthEvent,
          );
          return Right(result);
        } catch (e) {
          AppLogger.warning(
            '[MediaUpload] NIP-96 upload failed for ${server.url}: $e',
          );
        }
      }

      return Left(MediaFailure.uploadFailed(
        'All servers failed (tried ${blossomServers.length} Blossom, ${nip96Servers.length} NIP-96)',
      ));
    } catch (e) {
      AppLogger.error('[MediaUpload] Unexpected error: $e');
      return Left(MediaFailure.unknown(e.toString()));
    }
  }

  Future<Either<MediaFailure, MediaAttachment>> _uploadToServer(
    File file,
    MediaServer server,
  ) async {
    try {
      if (server.type == MediaServerType.blossom) {
        final result = await blossomService.upload(
          file: file,
          server: server,
          signAuthEvent: signBlossomAuthEvent,
        );
        return Right(result);
      } else {
        final result = await nip96Service.upload(
          file: file,
          server: server,
          signNip98Event: signNip98AuthEvent,
        );
        return Right(result);
      }
    } catch (e) {
      AppLogger.error('[MediaUpload] Upload to ${server.url} failed: $e');
      return Left(MediaFailure.uploadFailed(e.toString()));
    }
  }

  @override
  Future<Either<MediaFailure, List<MediaServer>>> discoverServers() async {
    try {
      final servers = await discoveryService.discoverServers();
      return Right(servers);
    } catch (e) {
      AppLogger.error('[MediaUpload] Server discovery failed: $e');
      return Left(MediaFailure.discoveryFailed(e.toString()));
    }
  }
}
