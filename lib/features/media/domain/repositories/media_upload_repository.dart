import 'dart:io';
import 'package:dartz/dartz.dart';
import '../entities/media_attachment.dart';
import '../entities/media_server.dart';
import '../errors/media_failure.dart';

abstract class MediaUploadRepository {
  /// Upload an image file and return the resulting attachment metadata.
  Future<Either<MediaFailure, MediaAttachment>> uploadImage({
    required File file,
    MediaServer? preferredServer,
  });

  /// Discover available media servers for the current user.
  Future<Either<MediaFailure, List<MediaServer>>> discoverServers();
}
