import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../domain/entities/media_attachment.dart';
import '../../domain/entities/media_server.dart';
import '../../domain/errors/media_failure.dart';
import '../../domain/repositories/media_upload_repository.dart';

class UploadImageParams {
  const UploadImageParams({
    required this.file,
    this.preferredServer,
  });

  final File file;
  final MediaServer? preferredServer;
}

/// Upload an image to a media server (Blossom primary, NIP-96 fallback).
class UploadImageUseCase {
  const UploadImageUseCase(this._repository);
  final MediaUploadRepository _repository;

  Future<Either<MediaFailure, MediaAttachment>> call(
    UploadImageParams params,
  ) {
    return _repository.uploadImage(
      file: params.file,
      preferredServer: params.preferredServer,
    );
  }
}
