/// エラーを表現する基底クラス
///
/// すべての失敗はこのクラスを継承する
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is Failure &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

/// ネットワークエラー
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'ネットワークエラーが発生しました'])
      : super(message);
}

/// 認証エラー
class AuthFailure extends Failure {
  const AuthFailure([String message = '認証に失敗しました']) : super(message);
}

/// サーバーエラー
class ServerFailure extends Failure {
  const ServerFailure([String message = 'サーバーエラーが発生しました'])
      : super(message);
}

/// キャッシュエラー
class CacheFailure extends Failure {
  const CacheFailure([String message = 'キャッシュエラーが発生しました'])
      : super(message);
}

/// 検証エラー
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}

/// 予期せぬエラー
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String message = '予期しないエラーが発生しました'])
      : super(message);
}

/// Nostr関連エラー
class NostrFailure extends Failure {
  const NostrFailure([String message = 'Nostrエラーが発生しました'])
      : super(message);
}

/// Amber関連エラー
class AmberFailure extends Failure {
  const AmberFailure([String message = 'Amberエラーが発生しました'])
      : super(message);
}

/// 暗号化エラー
class EncryptionFailure extends Failure {
  const EncryptionFailure([String message = '暗号化に失敗しました'])
      : super(message);
}

/// 復号化エラー
class DecryptionFailure extends Failure {
  const DecryptionFailure([String message = '復号化に失敗しました'])
      : super(message);
}

