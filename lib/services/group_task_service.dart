import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
  ///
  /// 成功した場合、NostrイベントIDを返す
  Future<String?> createGroupTaskList({
    required List<Todo> tasks,
    required CustomList customList,
    required String publicKey,
    required String npub,
  }) async {
    try {
      AppLogger.info(
        '🔐 [Amber] Creating group task list: ${customList.name} with ${customList.groupMembers.length} members',
      );

      // 1. Todoデータを GroupTodoData JSON に変換
      final groupTasks = tasks
          .map(
            (todo) => {
              'id': todo.id,
              'title': todo.title,
              'completed': todo.completed,
              'date': todo.date?.toIso8601String(),
              'order': todo.order,
              'created_at': todo.createdAt.toIso8601String(),
              'updated_at': todo.updatedAt.toIso8601String(),
            },
          )
          .toList();

      final tasksJson = jsonEncode(groupTasks);
      AppLogger.debug('📝 Serialized ${tasks.length} tasks to JSON');

      // 2. ランダムなAES-256鍵を生成（32バイト = 256ビット）
      final random = Random.secure();
      final aesKeyBytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final aesKeyBase64 = base64Encode(aesKeyBytes);
      AppLogger.debug('🔑 Generated AES-256 key');

      // 3. タスクデータをAES-256-GCMで暗号化（Rust経由）
      final encryptedData = await rust_api.encryptGroupDataWithAesKey(
        tasksJson: tasksJson,
        aesKeyBase64: aesKeyBase64,
      );
      AppLogger.debug('🔒 Encrypted task data with AES-256-GCM');

      // 4. 各メンバー用にAES鍵をAmber経由でNIP-44暗号化
      final encryptedKeys = <EncryptedKey>[];
      for (final memberPubkey in customList.groupMembers) {
        try {
          final encryptedAesKey = await _encryptContentViaAmber(
            plaintext: aesKeyBase64,
            recipientPubkey: memberPubkey,
            senderPubkey: publicKey,
            npub: npub,
          );

          encryptedKeys.add(
            EncryptedKey(
              memberPubkey: memberPubkey,
              encryptedAesKey: encryptedAesKey,
            ),
          );

          AppLogger.debug(
            '🔑 Encrypted AES key for member: ${memberPubkey.substring(0, 8)}...',
          );
        } catch (e) {
          AppLogger.error(
            '❌ Failed to encrypt AES key for member $memberPubkey: $e',
          );
          rethrow;
        }
      }

      AppLogger.info(
        '✅ Encrypted AES keys for ${encryptedKeys.length} members',
      );

      // 5. GroupTodoListを構築
      final groupList = GroupTodoList(
        groupId: customList.id,
        groupName: customList.name,
        encryptedData: encryptedData,
        members: customList.groupMembers,
        encryptedKeys: encryptedKeys,
      );

      // 6. GroupTodoListをJSON化（平文で保存）
      // 注意: contentは平文だが、encrypted_dataとencrypted_keysが暗号化されているため安全
      final groupListJson = jsonEncode({
        'group_id': groupList.groupId,
        'group_name': groupList.groupName,
        'encrypted_data': groupList.encryptedData,
        'members': groupList.members,
        'encrypted_keys': groupList.encryptedKeys
            .map(
              (k) => {
                'member_pubkey': k.memberPubkey,
                'encrypted_aes_key': k.encryptedAesKey,
              },
            )
            .toList(),
      });

      AppLogger.debug('📝 Created GroupTodoList JSON (plaintext metadata)');

      // 7. Rust経由で未署名イベントを作成（contentは平文）
      final unsignedEventJson = await rust_api.createUnsignedGroupTaskListEvent(
        groupListJson: groupListJson,
        encryptedContent: groupListJson, // 平文のまま保存
        publicKeyHex: publicKey,
      );

      AppLogger.debug('📝 Created unsigned event');

      // 8. Amberで署名
      final amberService = AmberService();
      final signedEventJson = await amberService.signEventWithTimeout(
        unsignedEventJson,
      );

      AppLogger.debug('✍️ Signed event with Amber');

      // 9. リレーに送信（Rust API経由）
      final result = await rust_api.sendSignedEvent(eventJson: signedEventJson);

      if (result.success) {
        AppLogger.info('✅ Group task list saved to Nostr: ${result.eventId}');
        return result.eventId;
      } else {
        AppLogger.warning(
          '⚠️ Group task list save failed: ${result.errorMessage}',
        );
        return null;
      }
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to create group task list: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Amber経由でコンテンツを暗号化（NIP-44）
  Future<String> _encryptContentViaAmber({
    required String plaintext,
    required String recipientPubkey,
    required String senderPubkey,
    required String npub,
  }) async {
    final amberService = AmberService();

    try {
      // ContentProvider経由で暗号化を試みる
      final encrypted = await amberService.encryptNip44WithContentProvider(
        plaintext: plaintext,
        pubkey: recipientPubkey,
        npub: npub,
      );
      AppLogger.debug(' 暗号化完了（バックグラウンド）');
      return encrypted;
    } on PlatformException catch (e) {
      AppLogger.warning(' ContentProvider暗号化失敗 (${e.code}), UI経由で再試行します...');
      final encrypted = await amberService.encryptNip44(
        plaintext,
        recipientPubkey,
      );
      AppLogger.debug(' 暗号化完了（UI経由）');
      return encrypted;
    }
  }

  /// 自分がメンバーになっているグループタスクリストを取得
  ///
  /// ⚠️ 戻り値は未認証データ。任意の Nostr 鍵が #p タグで自分を指す
  /// 偽イベントを発行できるため、decryptGroupTaskList の
  /// AEAD 復号（NIP-44 + AES-256-GCM）が成功するまで本物とは扱わないこと。
  /// UI 表示やメンバー鍵への暗号化に直接使ってはならない。
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
      final encryptedEvents = await rust_api
          .fetchEncryptedGroupTaskListsForPubkey(
            publicKeyHex: publicKey,
          );

      AppLogger.info(
        '📦 Fetched ${encryptedEvents.length} encrypted group task events',
      );

      // 2. 各イベントを復号化してGroupTodoListに変換
      final groupLists = <GroupTodoList>[];

      for (final encryptedEvent in encryptedEvents) {
        try {
          // 2-1. 自分がメンバーに含まれているか確認（p タグから取得したメンバー）
          if (!encryptedEvent.members.contains(publicKey)) {
            AppLogger.debug(
              '⏭️  Skipping group ${encryptedEvent.listId} (not a member)',
            );
            continue;
          }

          AppLogger.info(
            '📋 Processing group: ${encryptedEvent.listId} (${encryptedEvent.members.length} members)',
          );

          // 2-2. contentをJSONパース（平文なので復号化不要）
          final groupListJson =
              jsonDecode(encryptedEvent.encryptedContent)
                  as Map<String, dynamic>;

          final encryptedData = groupListJson['encrypted_data'] as String;
          final members = (groupListJson['members'] as List<dynamic>)
              .map((e) => e as String)
              .toList();
          final encryptedKeysJson =
              groupListJson['encrypted_keys'] as List<dynamic>;

          AppLogger.debug(
            '📋 Found encrypted_data and ${encryptedKeysJson.length} encrypted_keys',
          );

          // 2-3. encrypted_keysに自分用のAES鍵が存在するか確認
          encryptedKeysJson.firstWhere(
            (k) => k['member_pubkey'] == publicKey,
            orElse: () =>
                throw Exception('No encrypted AES key found for current user'),
          );

          AppLogger.debug(
            '🔑 Found encrypted AES key for ${encryptedEvent.listId}',
          );

          // 2-4. GroupTodoListを構築
          // 復号はここでは行わない。実際の復号は decryptGroupTaskList が行うため、
          // ここで検証目的に復号すると Amber IPC + AES 復号がグループ毎に二重になる。
          final groupList = GroupTodoList(
            groupId: encryptedEvent.listId,
            groupName: encryptedEvent.groupName ?? encryptedEvent.listId,
            encryptedData: encryptedData,
            members: members,
            encryptedKeys: encryptedKeysJson
                .map(
                  (k) => EncryptedKey(
                    memberPubkey: k['member_pubkey'] as String,
                    encryptedAesKey: k['encrypted_aes_key'] as String,
                  ),
                )
                .toList(),
          );

          groupLists.add(groupList);
          AppLogger.info(
            '✅ Successfully processed group: ${groupList.groupName}',
          );
        } catch (e, st) {
          AppLogger.error(
            '❌ Failed to process group event ${encryptedEvent.listId}: $e',
            error: e,
            stackTrace: st,
          );
          // エラーは無視して次のイベントを処理
        }
      }

      AppLogger.info('✅ Fetched ${groupLists.length} group task lists');

      return groupLists;
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to fetch group task lists: $e',
        error: e,
        stackTrace: st,
      );
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
  /// グループタスクリストを復号化してTodoリストに変換（Amberモード対応）
  Future<List<Todo>> decryptGroupTaskList({
    required GroupTodoList groupList,
    required String publicKey,
    required String npub,
  }) async {
    try {
      AppLogger.info('🔓 Decrypting group task list: ${groupList.groupName}');

      // 1. encrypted_keysから自分用のAES鍵を見つける
      final myEncryptedKey = groupList.encryptedKeys.firstWhere(
        (k) => k.memberPubkey == publicKey,
        orElse: () =>
            throw Exception('No encrypted AES key found for current user'),
      );

      AppLogger.debug('🔑 Found encrypted AES key for ${groupList.groupName}');

      // 2. Amber経由でAES鍵をNIP-44復号化
      final aesKeyBase64 = await _decryptContentViaAmber(
        encryptedContent: myEncryptedKey.encryptedAesKey,
        publicKey: publicKey,
        npub: npub,
      );

      AppLogger.debug('🔓 Decrypted AES key for ${groupList.groupName}');

      // 3. 復号化したAES鍵でデータを復号化（Rust経由）
      final decryptedDataJson = await rust_api.decryptGroupDataWithAesKey(
        encryptedDataBase64: groupList.encryptedData,
        aesKeyBase64: aesKeyBase64,
      );

      AppLogger.debug('📦 Decrypted group data for ${groupList.groupName}');

      // 4. JSONをパースしてTodoオブジェクトに変換
      final tasksJson = jsonDecode(decryptedDataJson) as List<dynamic>;

      final todos = tasksJson.map((taskJson) {
        DateTime? date;
        if (taskJson['date'] != null) {
          try {
            date = DateTime.parse(taskJson['date'] as String);
          } catch (e) {
            AppLogger.warning('Failed to parse date: ${taskJson['date']}');
          }
        }

        return Todo(
          id: taskJson['id'] as String,
          title: taskJson['title'] as String,
          completed: taskJson['completed'] as bool,
          date: date,
          order: taskJson['order'] as int,
          createdAt: DateTime.parse(taskJson['created_at'] as String),
          updatedAt: DateTime.parse(taskJson['updated_at'] as String),
          customListId: groupList.groupId,
          eventId: taskJson['event_id'] as String?,
        );
      }).toList();

      AppLogger.info(
        '✅ Decrypted ${todos.length} todos from group ${groupList.groupName}',
      );

      return todos;
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to decrypt group task list: $e',
        error: e,
        stackTrace: st,
      );
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
        AppLogger.warning(
          '⚠️ Failed to sync updated group: ${result.errorMessage}',
        );
      }
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to add member to group: $e',
        error: e,
        stackTrace: st,
      );
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
        AppLogger.warning(
          '⚠️ Failed to sync updated group: ${result.errorMessage}',
        );
      }
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to remove member from group: $e',
        error: e,
        stackTrace: st,
      );
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isGroup: true,
          groupMembers: groupList.members,
        );
      }).toList();

      AppLogger.info('✅ Synced ${customLists.length} group lists');

      return customLists;
    } catch (e, st) {
      AppLogger.error(
        '❌ Failed to sync group lists: $e',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}

/// グローバルなGroupTaskServiceインスタンス
final groupTaskService = GroupTaskService();
