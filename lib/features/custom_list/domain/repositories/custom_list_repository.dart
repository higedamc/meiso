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
  // Nostr同期操作（Phase C.3.2.2で実装）
  // ============================================================
  
  /// Nostrからカスタムリスト名を取得
  /// 
  /// Kind 30001イベントのd tag（meiso-list-xxx）とtitle tagから
  /// カスタムリスト名のリストを抽出する
  /// 
  /// Phase C.3.2.2: `_fetchEncryptedEventsForListNames()`を移植
  /// Issue #101: 削除済みイベントIDと削除済みリストIDでフィルタリング
  Future<Either<Failure, List<String>>> fetchCustomListNamesFromNostr({
    required String publicKey,
    required Set<String> deletedEventIds,
    required Set<String> deletedListIds,
  });
  
  /// Nostrから個人カスタムリストを同期（Phase Dで実装予定）
  /// 
  /// Note: 現在はカスタムリストはTodoと一緒に暗黙的に送信されるため、
  /// 独立した送信機能は不要。将来の拡張用に定義のみ残す。
  Future<Either<Failure, List<CustomList>>> syncPersonalListsFromNostr();
  
  /// Nostrへ個人カスタムリストを送信（Phase Dで実装予定）
  /// 
  /// Note: 現在はカスタムリストはTodoと一緒に暗黙的に送信されるため、
  /// 独立した送信機能は不要。将来の拡張用に定義のみ残す。
  Future<Either<Failure, void>> syncPersonalListsToNostr({
    required List<CustomList> lists,
    required bool isAmberMode,
  });
  
  // ============================================================
  // 削除イベント同期（Phase C.3.2.1で実装）
  // ============================================================
  
  /// Kind 5削除イベントを同期
  /// 
  /// Nostrから削除イベント（Kind 5）を取得し、削除済みイベントIDのセットを返す
  Future<Either<Failure, Set<String>>> syncDeletionEvents({
    required String publicKey,
  });
  
  /// 削除済みイベントIDをローカルに保存
  Future<Either<Failure, void>> saveDeletedEventIds(Set<String> eventIds);
  
  /// 削除済みイベントIDをローカルから読み込み
  Future<Either<Failure, Set<String>>> loadDeletedEventIds();
  
  // ============================================================
  // 削除済みリストID（永久ブラックリスト）（Issue #101）
  // ============================================================
  
  /// 削除済みリストIDをローカルに保存（list_idベース）
  /// 一度削除されたリストは二度と表示されない
  Future<Either<Failure, void>> saveDeletedListIds(Set<String> listIds);
  
  /// 削除済みリストIDをローカルから読み込み
  Future<Either<Failure, Set<String>>> loadDeletedListIds();
  
  // ============================================================
  // Personal List削除・更新（Phase E）
  // ============================================================
  
  /// Personal ListをNostrから削除（Kind 5イベント送信）
  /// 
  /// Phase E.1: Personal Listのリモート削除
  /// - Kind 5削除イベントを作成・送信
  /// - 削除済みイベントIDをローカルに保存
  /// - 個人カスタムリスト（isGroup=false）のみ削除可能
  /// 
  /// @param listId カスタムリストのID
  /// @param eventId 削除対象のNostrイベントID
  /// @param isAmberMode Amberモードかどうか
  /// @return 削除成功/失敗
  Future<Either<Failure, void>> deletePersonalListFromNostr({
    required String listId,
    required String eventId,
    required bool isAmberMode,
  });
  
  /// Personal ListをNostrに更新（空リストとして送信）
  /// 
  /// Phase E: Personal Listの名前変更・order更新を同期
  /// - 空のKind 30001イベントとして送信
  /// - d tag: meiso-list-{listId}
  /// - title tag: リスト名
  /// - order tag: 並び順（カスタムタグ）
  /// 
  /// @param list 更新するカスタムリスト
  /// @param isAmberMode Amberモードかどうか
  /// @return 送信されたNostrイベントID
  Future<Either<Failure, String>> updatePersonalListToNostr({
    required CustomList list,
    required bool isAmberMode,
  });
  
  /// 空のPersonal ListをNostrに送信
  /// 
  /// Phase E: 空リストの同期
  /// - TODOが0件でも、リスト自体を独立したイベントとして送信
  /// - d tag: meiso-list-{listId}
  /// - title tag: リスト名
  /// - order tag: 並び順（カスタムタグ）
  /// - content: 空の配列（[]）を暗号化
  /// 
  /// @param list 送信するカスタムリスト
  /// @param isAmberMode Amberモードかどうか
  /// @return 送信されたNostrイベントID
  Future<Either<Failure, String>> publishEmptyPersonalList({
    required CustomList list,
    required bool isAmberMode,
  });
  
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

