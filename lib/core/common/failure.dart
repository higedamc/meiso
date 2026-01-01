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
  const NetworkFailure([super.message = 'ネットワークエラーが発生しました']);
}

/// 認証エラー
class AuthFailure extends Failure {
  const AuthFailure([super.message = '認証に失敗しました']);
}

/// サーバーエラー
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'サーバーエラーが発生しました']);
}

/// キャッシュエラー
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'キャッシュエラーが発生しました']);
}

/// 検証エラー
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// 予期せぬエラー
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = '予期しないエラーが発生しました']);
}

/// Nostr関連エラー
class NostrFailure extends Failure {
  const NostrFailure([super.message = 'Nostrエラーが発生しました']);
}

/// Amber関連エラー
class AmberFailure extends Failure {
  const AmberFailure([super.message = 'Amberエラーが発生しました']);
}

/// 暗号化エラー
class EncryptionFailure extends Failure {
  const EncryptionFailure([super.message = '暗号化に失敗しました']);
}

/// 復号化エラー
class DecryptionFailure extends Failure {
  const DecryptionFailure([super.message = '復号化に失敗しました']);
}

