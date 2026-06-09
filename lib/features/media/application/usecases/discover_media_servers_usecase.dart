import 'package:dartz/dartz.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/errors/media_failure.dart';
import '../../domain/repositories/media_upload_repository.dart';

/// Discover available media servers (Kind 10063 + manual config).
class DiscoverMediaServersUseCase {
  const DiscoverMediaServersUseCase(this._repository);
  final MediaUploadRepository _repository;

  Future<Either<MediaFailure, List<MediaServer>>> call() {
    return _repository.discoverServers();
  }
}
