import '../models/todo.dart';
import '../models/custom_list.dart';
import '../rust/api/api.dart' as rust_api;
import 'logger_service.dart';

/// グループタスク管理サービス
/// 
/// マルチパーティ暗号化を使用したグループタスクの作成・同期を担当
class GroupTaskService {
  /// グループタスクリストを作成（暗号化してNostrに保存）
  Future<void> createGroupTaskList({
    required List<Todo> tasks,
    required CustomList customList,
  }) async {
    try {
      AppLogger.info('🔐 Creating group task list: ${customList.name} with ${customList.groupMembers.length} members');
      
      // Todoデータを rust_api.GroupTodoData に変換
      final groupTasks = tasks.map((todo) => rust_api.GroupTodoData(
        id: todo.id,
        title: todo.title,
        completed: todo.completed,
        date: todo.date?.toIso8601String(),
        order: todo.order,
        createdAt: todo.createdAt.toIso8601String(),
        updatedAt: todo.updatedAt.toIso8601String(),
      )).toList();
      
      // 1. タスクを暗号化（マルチパーティ暗号化）
      final encryptedGroup = await rust_api.encryptGroupTaskList(
        tasks: groupTasks,
        groupId: customList.id,
        groupName: customList.name,
        memberPubkeys: customList.groupMembers,
      );
      
      AppLogger.info('✅ Encrypted group tasks for ${customList.groupMembers.length} members');
      
      // 2. Nostrに保存（Kind 30001 - NIP-51）
      final result = await rust_api.saveGroupTaskListToNostr(
        groupList: encryptedGroup,
      );
      
      if (result.success) {
        AppLogger.info('✅ Group task list saved to Nostr: ${result.eventId}');
      } else {
        AppLogger.warning('⚠️ Group task list save failed: ${result.errorMessage}');
      }
    } catch (e, st) {
      AppLogger.error('❌ Failed to create group task list: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// 自分がメンバーになっているグループタスクリストを取得
  Future<List<rust_api.GroupTodoList>> fetchMyGroupTaskLists() async {
    try {
      AppLogger.info('📥 Fetching my group task lists...');
      
      final groupLists = await rust_api.fetchMyGroupTaskLists();
      
      AppLogger.info('✅ Fetched ${groupLists.length} group task lists');
      
      return groupLists;
    } catch (e, st) {
      AppLogger.error('❌ Failed to fetch group task lists: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// グループタスクリストを復号化
  Future<List<Todo>> decryptGroupTaskList({
    required rust_api.GroupTodoList groupList,
  }) async {
    try {
      AppLogger.info('🔓 Decrypting group task list: ${groupList.groupName}');
      
      final decryptedTasks = await rust_api.decryptGroupTaskList(
        groupList: groupList,
      );
      
      // rust_api.GroupTodoData を Todo モデルに変換
      final todos = decryptedTasks.map((task) {
        DateTime? date;
        if (task.date != null) {
          try {
            date = DateTime.parse(task.date!);
          } catch (e) {
            AppLogger.warning('Failed to parse date: ${task.date}');
          }
        }
        
        return Todo(
          id: task.id,
          title: task.title,
          completed: task.completed,
          date: date,
          order: task.order,
          createdAt: DateTime.parse(task.createdAt),
          updatedAt: DateTime.parse(task.updatedAt),
          customListId: groupList.groupId,
        );
      }).toList();
      
      AppLogger.info('✅ Decrypted ${todos.length} todos from group');
      
      return todos;
    } catch (e, st) {
      AppLogger.error('❌ Failed to decrypt group task list: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// グループにメンバーを追加
  Future<void> addMemberToGroup({
    required rust_api.GroupTodoList groupList,
    required String newMemberPubkey,
  }) async {
    try {
      AppLogger.info('👥 Adding member to group: ${groupList.groupName}');
      
      final updatedGroup = await rust_api.addMemberToGroupTaskList(
        groupList: groupList,
        newMemberPubkey: newMemberPubkey,
      );
      
      final result = await rust_api.saveGroupTaskListToNostr(
        groupList: updatedGroup,
      );
      
      if (result.success) {
        AppLogger.info('✅ Member added and synced to Nostr');
      } else {
        AppLogger.warning('⚠️ Failed to sync updated group: ${result.errorMessage}');
      }
    } catch (e, st) {
      AppLogger.error('❌ Failed to add member to group: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// グループからメンバーを削除（Forward Secrecy: 新しいAES鍵で再暗号化）
  Future<void> removeMemberFromGroup({
    required rust_api.GroupTodoList groupList,
    required String memberToRemove,
  }) async {
    try {
      AppLogger.info('👥 Removing member from group: ${groupList.groupName}');
      
      final updatedGroup = await rust_api.removeMemberFromGroupTaskList(
        groupList: groupList,
        memberToRemove: memberToRemove,
      );
      
      final result = await rust_api.saveGroupTaskListToNostr(
        groupList: updatedGroup,
      );
      
      if (result.success) {
        AppLogger.info('✅ Member removed and re-encrypted (Forward Secrecy)');
      } else {
        AppLogger.warning('⚠️ Failed to sync updated group: ${result.errorMessage}');
      }
    } catch (e, st) {
      AppLogger.error('❌ Failed to remove member from group: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// グループリストを同期（NostrからCustomListに変換）
  Future<List<CustomList>> syncGroupLists() async {
    try {
      AppLogger.info('🔄 Syncing group lists from Nostr...');
      
      final groupLists = await fetchMyGroupTaskLists();
      
      final customLists = groupLists.map((groupList) {
        return CustomList(
          id: groupList.groupId,
          name: groupList.groupName,
          order: 0, // 順序は後で調整
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: true,
          groupMembers: groupList.members,
        );
      }).toList();
      
      AppLogger.info('✅ Synced ${customLists.length} group lists');
      
      return customLists;
    } catch (e, st) {
      AppLogger.error('❌ Failed to sync group lists: $e', error: e, stackTrace: st);
      return [];
    }
  }
}

/// グローバルなGroupTaskServiceインスタンス
final groupTaskService = GroupTaskService();

