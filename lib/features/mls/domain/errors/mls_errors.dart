import '../../../core/common/failure.dart';

/// MLSエラーコード
/// 
/// MLS (Messaging Layer Security) 関連のエラーを分類する。
enum MlsError {
  /// グループが見つからない
  groupNotFound,
  
  /// 招待が見つからない
  invitationNotFound,
  
  /// Key Packageが見つからない
  keyPackageNotFound,
  
  /// Welcome Messageが無効
  invalidWelcomeMessage,
  
  /// Key Packageが無効
  invalidKeyPackage,
  
  /// Key Packageが期限切れ
  keyPackageExpired,
  
  /// 招待が期限切れ
  invitationExpired,
  
  /// メンバーが既に存在
  memberAlreadyExists,
  
  /// メンバーが見つからない
  memberNotFound,
  
  /// グループが既に存在
  groupAlreadyExists,
  
  /// MLS DB初期化エラー
  mlsDbInitFailed,
  
  /// MLS暗号化エラー
  encryptionFailed,
  
  /// MLS復号化エラー
  decryptionFailed,
  
  /// ネットワークエラー
  networkError,
  
  /// タイムアウト
  timeout,
  
  /// 不明なエラー
  unknown,
}

/// MLS Failure基底クラス
abstract class MlsFailure extends Failure {
  final MlsError error;
  
  const MlsFailure(this.error, String message) : super(message);
}

/// グループ関連エラー
class GroupFailure extends MlsFailure {
  const GroupFailure(super.error, super.message);
  
  factory GroupFailure.notFound(String groupId) {
    return GroupFailure(
      MlsError.groupNotFound,
      'グループが見つかりません: $groupId',
    );
  }
  
  factory GroupFailure.alreadyExists(String groupId) {
    return GroupFailure(
      MlsError.groupAlreadyExists,
      'グループは既に存在します: $groupId',
    );
  }
}

/// 招待関連エラー
class InvitationFailure extends MlsFailure {
  const InvitationFailure(super.error, super.message);
  
  factory InvitationFailure.notFound(String groupId) {
    return InvitationFailure(
      MlsError.invitationNotFound,
      '招待が見つかりません: $groupId',
    );
  }
  
  factory InvitationFailure.expired(String groupId) {
    return InvitationFailure(
      MlsError.invitationExpired,
      '招待の有効期限が切れています（7日間）: $groupId',
    );
  }
  
  factory InvitationFailure.invalidWelcomeMessage() {
    return const InvitationFailure(
      MlsError.invalidWelcomeMessage,
      'Welcome Messageが無効です',
    );
  }
}

/// Key Package関連エラー
class KeyPackageFailure extends MlsFailure {
  const KeyPackageFailure(super.error, super.message);
  
  factory KeyPackageFailure.notFound(String pubkey) {
    return KeyPackageFailure(
      MlsError.keyPackageNotFound,
      'Key Packageが見つかりません: ${pubkey.substring(0, 16)}...',
    );
  }
  
  factory KeyPackageFailure.expired(String pubkey) {
    return KeyPackageFailure(
      MlsError.keyPackageExpired,
      'Key Packageの有効期限が切れています（7日間）: ${pubkey.substring(0, 16)}...',
    );
  }
  
  factory KeyPackageFailure.invalid() {
    return const KeyPackageFailure(
      MlsError.invalidKeyPackage,
      'Key Packageが無効です',
    );
  }
  
  factory KeyPackageFailure.publishFailed(String reason) {
    return KeyPackageFailure(
      MlsError.networkError,
      'Key Packageの公開に失敗しました: $reason',
    );
  }
}

/// メンバー関連エラー
class MemberFailure extends MlsFailure {
  const MemberFailure(super.error, super.message);
  
  factory MemberFailure.alreadyExists(String pubkey) {
    return MemberFailure(
      MlsError.memberAlreadyExists,
      'メンバーは既に存在します: ${pubkey.substring(0, 16)}...',
    );
  }
  
  factory MemberFailure.notFound(String pubkey) {
    return MemberFailure(
      MlsError.memberNotFound,
      'メンバーが見つかりません: ${pubkey.substring(0, 16)}...',
    );
  }
}

/// MLS暗号化・復号化エラー
class MlsCryptoFailure extends MlsFailure {
  const MlsCryptoFailure(super.error, super.message);
  
  factory MlsCryptoFailure.encryptionFailed(String reason) {
    return MlsCryptoFailure(
      MlsError.encryptionFailed,
      'MLS暗号化に失敗しました: $reason',
    );
  }
  
  factory MlsCryptoFailure.decryptionFailed(String reason) {
    return MlsCryptoFailure(
      MlsError.decryptionFailed,
      'MLS復号化に失敗しました: $reason',
    );
  }
  
  factory MlsCryptoFailure.mlsDbInitFailed(String reason) {
    return MlsCryptoFailure(
      MlsError.mlsDbInitFailed,
      'MLS DB初期化に失敗しました: $reason',
    );
  }
}

/// ネットワーク関連エラー
class MlsNetworkFailure extends MlsFailure {
  const MlsNetworkFailure(super.error, super.message);
  
  factory MlsNetworkFailure.timeout() {
    return const MlsNetworkFailure(
      MlsError.timeout,
      'タイムアウトしました',
    );
  }
  
  factory MlsNetworkFailure.networkError(String reason) {
    return MlsNetworkFailure(
      MlsError.networkError,
      'ネットワークエラー: $reason',
    );
  }
}

