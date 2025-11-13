import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
import '../../../../models/custom_list.dart';
import '../../domain/entities/mls_group.dart';
import '../../domain/entities/group_invitation.dart';

/// MLS Group Local DataSource
/// 
/// LocalStorageService（Hive）を使用してMLSグループと招待を管理する。
/// CustomListモデルを使用してHiveに保存される。
class MlsGroupLocalDataSource {
  final LocalStorageService _localStorage;
  
  const MlsGroupLocalDataSource(this._localStorage);
  
  // ========================================
  // MLSグループ操作
  // ========================================
  
  /// MLSグループをローカルストレージから読み込み
  /// 
  /// [groupId]: グループID
  /// Returns: MLSグループ（存在しない場合はnull）
  Future<MlsGroup?> loadMlsGroup({required String groupId}) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // isGroup=true かつ指定IDのCustomListを検索
      final customList = lists.firstWhere(
        (list) => list.id == groupId && list.isGroup,
        orElse: () => throw Exception('Group not found'),
      );
      
      // CustomList → MlsGroupに変換
      final mlsGroup = _customListToMlsGroup(customList);
      
      AppLogger.debug('[MlsGroupDataSource] Loaded MLS group: $groupId');
      return mlsGroup;
    } catch (e) {
      if (e.toString().contains('Group not found')) {
        AppLogger.debug('[MlsGroupDataSource] MLS group not found: $groupId');
        return null;
      }
      AppLogger.error('[MlsGroupDataSource] Failed to load MLS group', error: e);
      rethrow;
    }
  }
  
  /// 全てのMLSグループをローカルストレージから読み込み
  Future<List<MlsGroup>> loadAllMlsGroups() async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // isGroup=true のCustomListのみフィルタ
      final groupLists = lists.where((list) => list.isGroup && !list.isPendingInvitation);
      
      // CustomList → MlsGroupに変換
      final mlsGroups = groupLists.map(_customListToMlsGroup).toList();
      
      AppLogger.debug('[MlsGroupDataSource] Loaded ${mlsGroups.length} MLS groups');
      return mlsGroups;
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to load all MLS groups', error: e);
      rethrow;
    }
  }
  
  /// MLSグループをローカルストレージに保存
  /// 
  /// [group]: 保存するMLSグループ
  Future<void> saveMlsGroup(MlsGroup group) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // MlsGroup → CustomListに変換
      final customList = _mlsGroupToCustomList(group);
      
      // 既存のグループを更新 or 新規追加
      final index = lists.indexWhere((list) => list.id == group.groupId);
      if (index >= 0) {
        lists[index] = customList;
      } else {
        lists.add(customList);
      }
      
      await _localStorage.saveCustomLists(lists);
      AppLogger.debug('[MlsGroupDataSource] Saved MLS group: ${group.groupId}');
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to save MLS group', error: e);
      rethrow;
    }
  }
  
  /// MLSグループをローカルストレージから削除
  /// 
  /// [groupId]: グループID
  Future<void> deleteMlsGroup({required String groupId}) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // 指定IDのグループを削除
      final updatedLists = lists.where((list) => list.id != groupId).toList();
      
      await _localStorage.saveCustomLists(updatedLists);
      AppLogger.debug('[MlsGroupDataSource] Deleted MLS group: $groupId');
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to delete MLS group', error: e);
      rethrow;
    }
  }
  
  // ========================================
  // グループ招待操作
  // ========================================
  
  /// グループ招待をローカルストレージから読み込み
  /// 
  /// [groupId]: グループID
  Future<GroupInvitation?> loadInvitation({required String groupId}) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // isPendingInvitation=true かつ指定IDのCustomListを検索
      final customList = lists.firstWhere(
        (list) => list.id == groupId && list.isPendingInvitation,
        orElse: () => throw Exception('Invitation not found'),
      );
      
      // CustomList → GroupInvitationに変換
      final invitation = _customListToGroupInvitation(customList);
      
      AppLogger.debug('[MlsGroupDataSource] Loaded invitation: $groupId');
      return invitation;
    } catch (e) {
      if (e.toString().contains('Invitation not found')) {
        AppLogger.debug('[MlsGroupDataSource] Invitation not found: $groupId');
        return null;
      }
      AppLogger.error('[MlsGroupDataSource] Failed to load invitation', error: e);
      rethrow;
    }
  }
  
  /// 全てのグループ招待をローカルストレージから読み込み
  Future<List<GroupInvitation>> loadAllInvitations() async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // isPendingInvitation=true のCustomListのみフィルタ
      final invitationLists = lists.where((list) => list.isPendingInvitation);
      
      // CustomList → GroupInvitationに変換
      final invitations = invitationLists.map(_customListToGroupInvitation).toList();
      
      AppLogger.debug('[MlsGroupDataSource] Loaded ${invitations.length} invitations');
      return invitations;
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to load all invitations', error: e);
      rethrow;
    }
  }
  
  /// グループ招待をローカルストレージに保存
  /// 
  /// [invitation]: 保存する招待
  Future<void> saveInvitation(GroupInvitation invitation) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // GroupInvitation → CustomListに変換
      final customList = _groupInvitationToCustomList(invitation);
      
      // 既存の招待を更新 or 新規追加
      final index = lists.indexWhere((list) => list.id == invitation.groupId);
      if (index >= 0) {
        lists[index] = customList;
      } else {
        lists.add(customList);
      }
      
      await _localStorage.saveCustomLists(lists);
      AppLogger.debug('[MlsGroupDataSource] Saved invitation: ${invitation.groupId}');
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to save invitation', error: e);
      rethrow;
    }
  }
  
  /// グループ招待をローカルストレージから削除
  /// 
  /// [groupId]: グループID
  Future<void> deleteInvitation({required String groupId}) async {
    try {
      final lists = await _localStorage.loadCustomLists();
      
      // 指定IDの招待を削除
      final updatedLists = lists.where((list) => list.id != groupId || !list.isPendingInvitation).toList();
      
      await _localStorage.saveCustomLists(updatedLists);
      AppLogger.debug('[MlsGroupDataSource] Deleted invitation: $groupId');
    } catch (e) {
      AppLogger.error('[MlsGroupDataSource] Failed to delete invitation', error: e);
      rethrow;
    }
  }
  
  // ========================================
  // 内部ヘルパーメソッド
  // ========================================
  
  /// CustomList → MlsGroupに変換
  MlsGroup _customListToMlsGroup(CustomList customList) {
    return MlsGroup(
      groupId: customList.id,
      groupName: customList.name,
      memberPubkeys: customList.groupMembers,
      welcomeMessage: customList.welcomeMsg ?? '',
      createdAt: customList.createdAt,
      updatedAt: customList.updatedAt,
    );
  }
  
  /// MlsGroup → CustomListに変換
  CustomList _mlsGroupToCustomList(MlsGroup group) {
    return CustomList(
      id: group.groupId,
      name: group.groupName,
      order: 0, // orderは後で調整される
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      isGroup: true,
      groupMembers: group.memberPubkeys,
      welcomeMsg: (group.welcomeMessage != null && group.welcomeMessage!.isNotEmpty) ? group.welcomeMessage : null,
      isPendingInvitation: false, // グループは受諾済み
    );
  }
  
  /// CustomList → GroupInvitationに変換
  GroupInvitation _customListToGroupInvitation(CustomList customList) {
    return GroupInvitation(
      groupId: customList.id,
      groupName: customList.name,
      inviterPubkey: customList.inviterNpub ?? '',
      inviterName: customList.inviterName,
      welcomeMessage: customList.welcomeMsg ?? '',
      receivedAt: customList.createdAt,
      isPending: customList.isPendingInvitation,
    );
  }
  
  /// GroupInvitation → CustomListに変換
  CustomList _groupInvitationToCustomList(GroupInvitation invitation) {
    return CustomList(
      id: invitation.groupId,
      name: invitation.groupName,
      order: 0, // orderは後で調整される
      createdAt: invitation.receivedAt,
      updatedAt: invitation.receivedAt,
      isPendingInvitation: invitation.isPending,
      inviterNpub: invitation.inviterPubkey,
      inviterName: invitation.inviterName,
      welcomeMsg: invitation.welcomeMessage,
    );
  }
}

