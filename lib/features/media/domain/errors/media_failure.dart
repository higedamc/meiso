import '../../../../core/common/failure.dart';

enum MediaError {
  noServerAvailable,
  uploadFailed,
  authFailed,
  fileTooLarge,
  unsupportedFileType,
  serverDiscoveryFailed,
  networkError,
  timeout,
  unknown,
}

class MediaFailure extends Failure {
  const MediaFailure(this.error, String message) : super(message);

  factory MediaFailure.noServer() => const MediaFailure(
        MediaError.noServerAvailable,
        'No media server available',
      );

  factory MediaFailure.uploadFailed(String reason) => MediaFailure(
        MediaError.uploadFailed,
        'Upload failed: $reason',
      );

  factory MediaFailure.authFailed(String reason) => MediaFailure(
        MediaError.authFailed,
        'Authentication failed: $reason',
      );

  factory MediaFailure.fileTooLarge(int maxBytes) => MediaFailure(
        MediaError.fileTooLarge,
        'File exceeds maximum size (${maxBytes ~/ 1024 ~/ 1024} MB)',
      );

  factory MediaFailure.unsupportedType(String mimeType) => MediaFailure(
        MediaError.unsupportedFileType,
        'Unsupported file type: $mimeType',
      );

  factory MediaFailure.discoveryFailed(String reason) => MediaFailure(
        MediaError.serverDiscoveryFailed,
        'Server discovery failed: $reason',
      );

  factory MediaFailure.network(String reason) => MediaFailure(
        MediaError.networkError,
        'Network error: $reason',
      );

  factory MediaFailure.timeout() => const MediaFailure(
        MediaError.timeout,
        'Request timed out',
      );

  factory MediaFailure.unknown(String reason) => MediaFailure(
        MediaError.unknown,
        'Unknown error: $reason',
      );

  final MediaError error;
}
