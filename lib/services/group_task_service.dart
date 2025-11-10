import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/todo.dart';
import '../models/custom_list.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../bridge_generated.dart/group_tasks.dart';
import 'logger_service.dart';
import 'amber_service.dart';

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
      
      // Todoデータを GroupTodoData に変換
      final groupTasks = tasks.map((todo) => GroupTodoData(
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
  /// 
  /// [publicKey] - hex形式の公開鍵
  /// [npub] - npub形式の公開鍵
  Future<List<GroupTodoList>> fetchMyGroupTaskLists({
    required String publicKey,
    required String npub,
  }) async {
    try {
      AppLogger.info('📥 Fetching my group task lists...');
      
      // 1. 暗号化されたグループタスクイベントを取得
      final encryptedEvents = await rust_api.fetchEncryptedGroupTaskListsForPubkey(
        publicKeyHex: publicKey,
      );
      
      AppLogger.info('📦 Fetched ${encryptedEvents.length} encrypted group task events');
      
      // 2. 各イベントを復号化してGroupTodoListに変換
      final groupLists = <GroupTodoList>[];
      
      for (final encryptedEvent in encryptedEvents) {
        try {
          // Amber経由でNIP-44復号化
          final decrypted = await _decryptContentViaAmber(
            encryptedContent: encryptedEvent.encryptedContent,
            publicKey: publicKey,
            npub: npub,
          );
          
          // JSONをパース
          final Map<String, dynamic> json = jsonDecode(decrypted);
          
          // GroupTodoListを再構築
          final groupList = GroupTodoList(
            groupId: json['group_id'] as String,
            groupName: json['group_name'] as String,
            encryptedData: json['encrypted_data'] as String,
            members: (json['members'] as List).map((e) => e as String).toList(),
            encryptedKeys: (json['encrypted_keys'] as List)
                .map((e) => EncryptedKey(
                      memberPubkey: e['member_pubkey'] as String,
                      encryptedAesKey: e['encrypted_aes_key'] as String,
                    ))
                .toList(),
          );
          
          // 自分がメンバーに含まれているか確認
          if (groupList.members.contains(publicKey)) {
            AppLogger.info('✅ Decrypted group: ${groupList.groupName} (member check: ✓)');
            groupLists.add(groupList);
          } else {
            AppLogger.warning('⚠️ Skipping group ${groupList.groupName} (not a member)');
          }
        } catch (e, st) {
          AppLogger.error(
            '❌ Failed to decrypt group event ${encryptedEvent.listId}: $e',
            error: e,
            stackTrace: st,
          );
          // エラーは無視して次のイベントを処理
        }
      }
      
      AppLogger.info('✅ Fetched ${groupLists.length} group task lists');
      
      return groupLists;
    } catch (e, st) {
      AppLogger.error('❌ Failed to fetch group task lists: $e', error: e, stackTrace: st);
      rethrow;
    }
  }
  
  /// Amber経由でコンテンツを復号化
  Future<String> _decryptContentViaAmber({
    required String encryptedContent,
    required String publicKey,
    required String npub,
  }) async {
    final amberService = AmberService();
    
    try {
      // まずContentProvider経由で試す（バックグラウンド処理）
      final decrypted = await amberService.decryptNip44WithContentProvider(
        ciphertext: encryptedContent,
        pubkey: publicKey,
        npub: npub,
      );
      AppLogger.info(' 復号化完了（バックグラウンド）');
      return decrypted;
    } on PlatformException catch (e) {
      // ContentProviderが失敗した場合（未承認 or 応答なし）→ Intent経由にフォールバック
      AppLogger.warning(' ContentProvider復号化失敗 (${e.code}), UI経由で再試行します...');
      final decrypted = await amberService.decryptNip44(
        encryptedContent,
        publicKey,
      );
      AppLogger.info(' 復号化完了（UI経由）');
      return decrypted;
    }
  }
  
  /// グループタスクリストを復号化
  Future<List<Todo>> decryptGroupTaskList({
    required GroupTodoList groupList,
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
    required GroupTodoList groupList,
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
    required GroupTodoList groupList,
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
  /// 
  /// [publicKey] - hex形式の公開鍵
  /// [npub] - npub形式の公開鍵
  Future<List<CustomList>> syncGroupLists({
    required String publicKey,
    required String npub,
  }) async {
    try {
      AppLogger.info('🔄 Syncing group lists from Nostr...');
      
      final groupLists = await fetchMyGroupTaskLists(
        publicKey: publicKey,
        npub: npub,
      );
      
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

