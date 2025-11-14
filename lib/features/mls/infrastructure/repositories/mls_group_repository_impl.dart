import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/mls_group.dart';
import '../../domain/entities/group_invitation.dart';
import '../../domain/repositories/mls_group_repository.dart';
import '../../domain/errors/mls_errors.dart';
import '../datasources/mls_group_local_datasource.dart';
import '../../../../services/logger_service.dart';
import '../../../../services/amber_service.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../../utils/error_handler.dart';

/// MLS Group Repository Implementation
/// 
/// MLSグループの作成、招待送信/受信、招待受諾を実装する。
/// 既存のcustom_lists_provider.dartのMLS関連ロジックを移植。
class MlsGroupRepositoryImpl implements MlsGroupRepository {
  final MlsGroupLocalDataSource _localDataSource;
  final NostrService _nostrService;
  final bool _isAmberMode;
  
  const MlsGroupRepositoryImpl({
    required MlsGroupLocalDataSource localDataSource,
    required NostrService nostrService,
    required bool isAmberMode,
  })  : _localDataSource = localDataSource,
        _nostrService = nostrService,
        _isAmberMode = isAmberMode;
  
  // ========================================
  // ローカル操作（グループ）
  // ========================================
  
  @override
  Future<Either<Failure, MlsGroup?>> loadMlsGroupFromLocal({
    required String groupId,
  }) async {
    try {
      final group = await _localDataSource.loadMlsGroup(groupId: groupId);
      return Right(group);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to load MLS group from local',
        error: e,
        stackTrace: st,
      );
      return Left(GroupFailure(
        MlsError.unknown,
        'MLSグループの読み込みに失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, List<MlsGroup>>> loadAllMlsGroupsFromLocal() async {
    try {
      final groups = await _localDataSource.loadAllMlsGroups();
      return Right(groups);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to load all MLS groups from local',
        error: e,
        stackTrace: st,
      );
      return Left(GroupFailure(
        MlsError.unknown,
        'MLSグループ一覧の読み込みに失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveMlsGroupToLocal(MlsGroup group) async {
    try {
      await _localDataSource.saveMlsGroup(group);
      return Right(null);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to save MLS group to local',
        error: e,
        stackTrace: st,
      );
      return Left(GroupFailure(
        MlsError.unknown,
        'MLSグループの保存に失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteMlsGroupFromLocal({
    required String groupId,
  }) async {
    try {
      await _localDataSource.deleteMlsGroup(groupId: groupId);
      return Right(null);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to delete MLS group from local',
        error: e,
        stackTrace: st,
      );
      return Left(GroupFailure(
        MlsError.unknown,
        'MLSグループの削除に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // ローカル操作（招待）
  // ========================================
  
  @override
  Future<Either<Failure, GroupInvitation?>> loadInvitationFromLocal({
    required String groupId,
  }) async {
    try {
      final invitation = await _localDataSource.loadInvitation(groupId: groupId);
      return Right(invitation);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to load invitation from local',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待の読み込みに失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, List<GroupInvitation>>> loadAllInvitationsFromLocal() async {
    try {
      final invitations = await _localDataSource.loadAllInvitations();
      return Right(invitations);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to load all invitations from local',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待一覧の読み込みに失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveInvitationToLocal(GroupInvitation invitation) async {
    try {
      await _localDataSource.saveInvitation(invitation);
      return Right(null);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to save invitation to local',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待の保存に失敗しました: $e',
      ));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteInvitationFromLocal({
    required String groupId,
  }) async {
    try {
      await _localDataSource.deleteInvitation(groupId: groupId);
      return Right(null);
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to delete invitation from local',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待の削除に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // MLS操作（グループ作成）
  // ========================================
  
  @override
  Future<Either<Failure, String>> createMlsGroup({
    required String publicKey,
    required String groupId,
    required String groupName,
    required List<String> keyPackages,
  }) async {
    try {
      AppLogger.info('[MlsGroupRepo] Creating MLS group: "$groupName"');
      AppLogger.info('   Group ID: $groupId');
      AppLogger.info('   Members: ${keyPackages.length}');
      
      // Phase 8.2.1: タイムアウト付きでMLSグループ作成
      final welcomeMsgBytes = await ErrorHandler.withTimeout(
        operation: () => rust_api.mlsCreateTodoGroup(
          nostrId: publicKey,
          groupId: groupId,
          groupName: groupName,
          keyPackages: keyPackages,
        ),
        operationName: 'mlsCreateTodoGroup',
        timeout: const Duration(seconds: 30),
      );
      
      AppLogger.info('[MlsGroupRepo] MLS group created (Welcome: ${welcomeMsgBytes.length} bytes)');
      
      // Welcome MessageをBase64エンコード
      final welcomeMsgBase64 = base64Encode(welcomeMsgBytes);
      
      return Right(welcomeMsgBase64);
      
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to create MLS group',
        error: e,
        stackTrace: st,
      );
      return Left(MlsCryptoFailure.mlsDbInitFailed(
        'MLSグループの作成に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // MLS操作（招待送信）
  // ========================================
  
  @override
  Future<Either<Failure, String>> sendGroupInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    required String welcomeMessage,
  }) async {
    try {
      AppLogger.info('[MlsGroupRepo] Sending invitation to: ${recipientNpub.substring(0, 20)}...');
      
      if (!_isAmberMode) {
        throw Exception('秘密鍵モードでの招待送信は未実装です。Amberモードをご利用ください。');
      }
      
      // 送信者の公開鍵を取得
      final senderPubkeyHex = await _nostrService.getPublicKey();
      if (senderPubkeyHex == null) {
        throw Exception('Sender public key not available');
      }
      
      final senderNpub = await _nostrService.hexToNpub(senderPubkeyHex);
      
      // 未署名イベントを作成
      final unsignedEventJson = await rust_api.createUnsignedGroupInvitationEvent(
        senderPublicKeyHex: senderPubkeyHex,
        recipientNpub: recipientNpub,
        groupId: groupId,
        groupName: groupName,
        welcomeMsgBase64: welcomeMessage,
        inviterName: null, // オプション
      );
      
      AppLogger.debug('  Created unsigned event');
      
      // Amberで署名
      final amberService = AmberService();
      String signedEvent;
      
      try {
        // ContentProvider経由で試行（バックグラウンド）
        signedEvent = await amberService.signEventWithContentProvider(
          event: unsignedEventJson,
          npub: senderNpub,
        );
        AppLogger.debug('  Signed via ContentProvider');
      } on Exception {
        // UI経由にフォールバック
        AppLogger.warning('  ContentProvider failed, using UI method');
        signedEvent = await amberService.signEventWithTimeout(
          unsignedEventJson,
          timeout: const Duration(minutes: 2),
        );
        AppLogger.debug('  Signed via UI');
      }
      
      // リレーに送信
      final sendResult = await _nostrService.sendSignedEvent(signedEvent);
      
      AppLogger.info('[MlsGroupRepo] Invitation sent successfully');
      AppLogger.info('   Event ID: ${sendResult.eventId.substring(0, 16)}...');
      
      return Right(sendResult.eventId);
      
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to send invitation',
        error: e,
        stackTrace: st,
      );
      return Left(MlsNetworkFailure.networkError(
        '招待の送信に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // MLS操作（招待受信）
  // ========================================
  
  @override
  Future<Either<Failure, List<GroupInvitation>>> syncGroupInvitations({
    required String recipientPublicKey,
  }) async {
    try {
      AppLogger.info('[MlsGroupRepo] Syncing group invitations...');
      
      // Rust APIを呼び出してグループ招待を取得
      final resultJson = await rust_api.syncGroupInvitations(
        recipientPublicKeyHex: recipientPublicKey,
        clientId: null,
      );
      
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      final invitationsData = result['invitations'] as List<dynamic>;
      
      AppLogger.info('[MlsGroupRepo] Found ${invitationsData.length} pending invitations');
      
      // JSONをGroupInvitationエンティティに変換
      final invitations = <GroupInvitation>[];
      for (final invitationData in invitationsData) {
        try {
          final invitation = _parseGroupInvitation(invitationData);
          invitations.add(invitation);
        } catch (e) {
          AppLogger.warning('[MlsGroupRepo] Failed to parse invitation: $e');
          // 個別の招待のパースエラーは無視して続行
        }
      }
      
      AppLogger.info('[MlsGroupRepo] Parsed ${invitations.length} invitations successfully');
      
      return Right(invitations);
      
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to sync group invitations',
        error: e,
        stackTrace: st,
      );
      return Left(MlsNetworkFailure.networkError(
        '招待の同期に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // MLS操作（招待受諾）
  // ========================================
  
  @override
  Future<Either<Failure, MlsGroup>> acceptGroupInvitation({
    required String publicKey,
    required String groupId,
    required String welcomeMessage,
  }) async {
    try {
      AppLogger.info('[MlsGroupRepo] Accepting group invitation: $groupId');
      
      // Welcome MessageをBase64デコード
      final welcomeMsgBytes = base64Decode(welcomeMessage);
      
      // MLSグループに参加
      await rust_api.mlsJoinGroup(
        nostrId: publicKey,
        groupId: groupId,
        welcomeMsg: welcomeMsgBytes,
      );
      
      AppLogger.info('[MlsGroupRepo] Group invitation accepted successfully');
      
      // 参加後のMLSグループを取得
      // Note: グループ情報はローカルストレージから読み込む
      // （招待データがCustomListとして保存されているため）
      final groupResult = await loadMlsGroupFromLocal(groupId: groupId);
      
      return groupResult.fold(
        (failure) {
          AppLogger.warning('[MlsGroupRepo] Group not found after acceptance, creating placeholder');
          // グループが見つからない場合はプレースホルダーを作成
          final now = DateTime.now();
          final mlsGroup = MlsGroup(
            groupId: groupId,
            groupName: 'Unknown Group', // 後でNostrから取得
            memberPubkeys: [],
            welcomeMessage: welcomeMessage,
            createdAt: now,
            updatedAt: now,
          );
          return Right(mlsGroup);
        },
        (group) {
          if (group == null) {
            // nullの場合もプレースホルダーを作成
            final now = DateTime.now();
            final mlsGroup = MlsGroup(
              groupId: groupId,
              groupName: 'Unknown Group',
              memberPubkeys: [],
              welcomeMessage: welcomeMessage,
              createdAt: now,
              updatedAt: now,
            );
            return Right(mlsGroup);
          }
          return Right(group);
        },
      );
      
    } catch (e, st) {
      AppLogger.error(
        '[MlsGroupRepo] Failed to accept group invitation',
        error: e,
        stackTrace: st,
      );
      return Left(InvitationFailure(
        MlsError.unknown,
        '招待の受諾に失敗しました: $e',
      ));
    }
  }
  
  // ========================================
  // 内部ヘルパーメソッド
  // ========================================
  
  /// JSONデータからGroupInvitationを作成
  GroupInvitation _parseGroupInvitation(dynamic invitationData) {
    final map = invitationData as Map<String, dynamic>;
    
    return GroupInvitation(
      groupId: map['group_id'] as String,
      groupName: map['group_name'] as String,
      inviterPubkey: map['inviter_pubkey'] as String, // Rust側のフィールド名に合わせる
      inviterName: map['inviter_name'] as String?,
      welcomeMessage: map['welcome_msg'] as String, // Rust側のフィールド名に合わせる
      receivedAt: DateTime.now(), // 現在時刻を使用
      isPending: true, // 新規取得した招待はペンディング状態
    );
  }
}

