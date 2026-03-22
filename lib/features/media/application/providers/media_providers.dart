import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bridge_generated.dart/api.dart' as bridge;
import '../../../../providers/nostr_provider.dart';
import '../../../../services/amber_service.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/repositories/media_upload_repository.dart';
import '../../infrastructure/datasources/media_server_discovery_service.dart';
import '../../infrastructure/repositories/media_upload_repository_impl.dart';
import '../../infrastructure/services/blossom_upload_service.dart';
import '../../infrastructure/services/nip96_upload_service.dart';
import '../usecases/discover_media_servers_usecase.dart';
import '../usecases/upload_image_usecase.dart';

/// Blossom upload service provider.
final blossomUploadServiceProvider = Provider<BlossomUploadService>((ref) {
  return BlossomUploadService();
});

/// NIP-96 upload service provider.
final nip96UploadServiceProvider = Provider<Nip96UploadService>((ref) {
  return Nip96UploadService();
});

/// Media server discovery service provider.
final mediaServerDiscoveryServiceProvider =
    Provider<MediaServerDiscoveryService>((ref) {
  return MediaServerDiscoveryService(
    fetchKind10063ServerUrls: () async {
      try {
        return await bridge.fetchBlossomServerList();
      } on Exception catch (e) {
        AppLogger.warning('[MediaProviders] Kind 10063 fetch failed: $e');
        return [];
      }
    },
  );
});

Future<String> _signWithAmber(
  Ref ref,
  String unsignedEventJson,
) async {
  final amberService = AmberService();
  final npub = ref.read(nostrPublicKeyProvider);

  if (npub != null) {
    try {
      return await amberService.signEventWithContentProvider(
        event: unsignedEventJson,
        npub: npub,
      );
    } on PlatformException {
      AppLogger.warning(
        '[MediaProviders] ContentProvider sign failed, falling back to UI',
      );
    }
  }
  return amberService.signEventWithTimeout(unsignedEventJson);
}

/// Media upload repository provider.
final mediaUploadRepositoryProvider = Provider<MediaUploadRepository>((ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  final nip96Service = ref.watch(nip96UploadServiceProvider);
  final discoveryService = ref.watch(mediaServerDiscoveryServiceProvider);
  final isAmber = ref.watch(isAmberModeProvider);
  final publicKeyHex = ref.watch(publicKeyProvider);

  return MediaUploadRepositoryImpl(
    blossomService: blossomService,
    nip96Service: nip96Service,
    discoveryService: discoveryService,
    signBlossomAuthEvent: ({
      required String sha256hex,
      required int fileSize,
    }) async {
      if (isAmber && publicKeyHex != null) {
        final unsigned = await bridge.createUnsignedBlossomAuthEvent(
          sha256Hex: sha256hex,
          fileSize: fileSize,
          publicKeyHex: publicKeyHex,
        );
        return _signWithAmber(ref, unsigned);
      }
      return bridge.signBlossomAuthEvent(
        sha256Hex: sha256hex,
        fileSize: fileSize,
      );
    },
    signNip98AuthEvent: ({
      required String url,
      required String method,
    }) async {
      if (isAmber && publicKeyHex != null) {
        final unsigned = await bridge.createUnsignedNip98AuthEvent(
          url: url,
          method: method,
          publicKeyHex: publicKeyHex,
        );
        return _signWithAmber(ref, unsigned);
      }
      return bridge.signNip98AuthEvent(url: url, method: method);
    },
  );
});

/// Upload image use case provider.
final uploadImageUseCaseProvider = Provider<UploadImageUseCase>((ref) {
  return UploadImageUseCase(ref.watch(mediaUploadRepositoryProvider));
});

/// Discover media servers use case provider.
final discoverMediaServersUseCaseProvider =
    Provider<DiscoverMediaServersUseCase>((ref) {
  return DiscoverMediaServersUseCase(ref.watch(mediaUploadRepositoryProvider));
});

/// Discovered media servers (auto-refreshing).
final mediaServersProvider =
    FutureProvider<List<MediaServer>>((ref) async {
  final useCase = ref.watch(discoverMediaServersUseCaseProvider);
  final result = await useCase();
  return result.fold(
    (failure) {
      AppLogger.warning('[MediaProviders] Server discovery failed: $failure');
      return [];
    },
    (servers) => servers,
  );
});
