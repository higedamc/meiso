import 'package:dartz/dartz.dart';
import '../../../core/common/failure.dart';
import '../entities/mls_group.dart';
import '../entities/group_invitation.dart';

/// MLS Group Repository Interface
/// 
/// MLSグループの管理を抽象化する。
/// Infrastructure層で実装される。
abstract class MlsGroupRepository {
  // ========================================
  // ローカル操作（グループ）
  // ========================================
  
  /// MLSグループをローカルストレージから読み込み
  /// 
  /// [groupId]: グループID
  /// 
  /// Returns: MLSグループ（存在しない場合はnull）
  Future<Either<Failure, MlsGroup?>> loadMlsGroupFromLocal({
    required String groupId,
  });
  
  /// 全てのMLSグループをローカルストレージから読み込み
  Future<Either<Failure, List<MlsGroup>>> loadAllMlsGroupsFromLocal();
  
  /// MLSグループをローカルストレージに保存
  /// 
  /// [group]: 保存するMLSグループ
  Future<Either<Failure, void>> saveMlsGroupToLocal(MlsGroup group);
  
  /// MLSグループをローカルストレージから削除
  /// 
  /// [groupId]: グループID
  Future<Either<Failure, void>> deleteMlsGroupFromLocal({
    required String groupId,
  });
  
  // ========================================
  // ローカル操作（招待）
  // ========================================
  
  /// グループ招待をローカルストレージから読み込み
  /// 
  /// [groupId]: グループID
  Future<Either<Failure, GroupInvitation?>> loadInvitationFromLocal({
    required String groupId,
  });
  
  /// 全てのグループ招待をローカルストレージから読み込み
  Future<Either<Failure, List<GroupInvitation>>> loadAllInvitationsFromLocal();
  
  /// グループ招待をローカルストレージに保存
  /// 
  /// [invitation]: 保存する招待
  Future<Either<Failure, void>> saveInvitationToLocal(GroupInvitation invitation);
  
  /// グループ招待をローカルストレージから削除
  /// 
  /// [groupId]: グループID
  Future<Either<Failure, void>> deleteInvitationFromLocal({
    required String groupId,
  });
  
  // ========================================
  // MLS操作（グループ作成）
  // ========================================
  
  /// MLSグループを作成
  /// 
  /// Rust APIを呼び出してMLSグループを作成し、Welcome Messageを生成する。
  /// 
  /// [publicKey]: 作成者の公開鍵（hex形式）
  /// [groupId]: グループID
  /// [groupName]: グループ名
  /// [keyPackages]: メンバーのKey Packageリスト
  /// 
  /// Returns: Welcome Message（Base64エンコード）
  Future<Either<Failure, String>> createMlsGroup({
    required String publicKey,
    required String groupId,
    required String groupName,
    required List<String> keyPackages,
  });
  
  // ========================================
  // MLS操作（招待送信）
  // ========================================
  
  /// グループ招待を送信
  /// 
  /// Welcome MessageをNIP-17 Gift Wrapで暗号化して送信する。
  /// 
  /// [recipientNpub]: 受信者のnpub
  /// [groupId]: グループID
  /// [groupName]: グループ名
  /// [welcomeMessage]: Welcome Message（Base64エンコード）
  /// 
  /// Returns: イベントID
  Future<Either<Failure, String>> sendGroupInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    required String welcomeMessage,
  });
  
  // ========================================
  // MLS操作（招待受信）
  // ========================================
  
  /// グループ招待を同期
  /// 
  /// Nostrリレーから未読の招待を取得する。
  /// 
  /// [recipientPublicKey]: 受信者の公開鍵（hex形式）
  /// 
  /// Returns: 招待リスト
  Future<Either<Failure, List<GroupInvitation>>> syncGroupInvitations({
    required String recipientPublicKey,
  });
  
  // ========================================
  // MLS操作（招待受諾）
  // ========================================
  
  /// グループ招待を受諾
  /// 
  /// Welcome Messageを処理してグループに参加する。
  /// 
  /// [publicKey]: ユーザーの公開鍵（hex形式）
  /// [groupId]: グループID
  /// [welcomeMessage]: Welcome Message（Base64エンコード）
  /// 
  /// Returns: 参加後のMLSグループ
  Future<Either<Failure, MlsGroup>> acceptGroupInvitation({
    required String publicKey,
    required String groupId,
    required String welcomeMessage,
  });
}

