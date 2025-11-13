import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/custom_list.dart';

/// CustomListRepository抽象クラス
/// 
/// Phase C.3.1: ローカルストレージCRUD操作のみ
/// Phase C.3.2: Nostr同期操作を追加予定
/// Phase D: MLS操作を追加予定
abstract class CustomListRepository {
  // ============================================================
  // ローカルストレージ操作
  // ============================================================
  
  /// ローカルストレージから全てのカスタムリストを読み込む
  Future<Either<Failure, List<CustomList>>> loadCustomListsFromLocal();
  
  /// ローカルストレージに複数のカスタムリストを保存
  Future<Either<Failure, void>> saveCustomListsToLocal(List<CustomList> lists);
  
  /// ローカルストレージに単一のカスタムリストを保存
  Future<Either<Failure, void>> saveCustomListToLocal(CustomList list);
  
  /// ローカルストレージから単一のカスタムリストを削除
  Future<Either<Failure, void>> deleteCustomListFromLocal(String id);
  
  // ============================================================
  // Nostr同期操作（Phase C.3.2で実装予定）
  // ============================================================
  
  /// Nostrから個人カスタムリストを同期
  /// 
  /// 実装予定: Phase C.3.2
  Future<Either<Failure, List<CustomList>>> syncPersonalListsFromNostr();
  
  /// Nostrへ個人カスタムリストを送信
  /// 
  /// 実装予定: Phase C.3.2
  Future<Either<Failure, void>> syncPersonalListsToNostr({
    required List<CustomList> lists,
    required bool isAmberMode,
  });
  
  // ============================================================
  // 削除イベント同期（Phase C.3.2で実装予定）
  // ============================================================
  
  /// Kind 5削除イベントを同期
  /// 
  /// 実装予定: Phase C.3.2
  Future<Either<Failure, Set<String>>> syncDeletionEvents({
    required String publicKey,
  });
  
  /// 削除済みイベントIDをローカルに保存
  /// 
  /// 実装予定: Phase C.3.2
  Future<Either<Failure, void>> saveDeletedEventIds(Set<String> eventIds);
  
  /// 削除済みイベントIDをローカルから読み込み
  /// 
  /// 実装予定: Phase C.3.2
  Future<Either<Failure, Set<String>>> loadDeletedEventIds();
  
  // ============================================================
  // MLS操作（Phase Dで実装予定）
  // ============================================================
  
  /// MLSグループを作成
  /// 
  /// 実装予定: Phase D
  Future<Either<Failure, CustomList>> createMlsGroup({
    required String groupId,
    required String groupName,
    required List<String> keyPackages,
  });
  
  /// MLSグループ招待を同期
  /// 
  /// 実装予定: Phase D
  Future<Either<Failure, List<CustomList>>> syncGroupInvitations({
    required String recipientPublicKey,
  });
  
  /// グループメンバーを追加
  /// 
  /// 実装予定: Phase D
  Future<Either<Failure, void>> addMemberToGroup({
    required String groupId,
    required String memberPubkey,
  });
  
  /// グループメンバーを削除
  /// 
  /// 実装予定: Phase D
  Future<Either<Failure, void>> removeMemberFromGroup({
    required String groupId,
    required String memberPubkey,
  });
}

