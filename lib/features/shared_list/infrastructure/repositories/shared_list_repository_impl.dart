import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../../../bridge_generated.dart/api.dart' as rust_api;
import '../../../../core/common/failure.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../services/amber_service.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/shared_group_credentials.dart';
import '../../domain/entities/shared_invitation.dart';
import '../../domain/repositories/shared_list_repository.dart';
import '../datasources/shared_group_key_local_datasource.dart';

class SharedListRepositoryImpl implements SharedListRepository {
  SharedListRepositoryImpl({
    required SharedGroupKeyLocalDataSource keyDataSource,
    required NostrService nostrService,
    required bool isAmberMode,
  })  : _keyDataSource = keyDataSource,
        _nostrService = nostrService,
        _isAmberMode = isAmberMode;

  final SharedGroupKeyLocalDataSource _keyDataSource;
  final NostrService _nostrService;
  final bool _isAmberMode;

  @override
  Future<Either<Failure, SharedGroupCredentials>> createSharedGroup({
    required String groupId,
    required String groupName,
  }) async {
    try {
      final groupKey = await rust_api.sharedGenerateGroupKey();
      final credentials = SharedGroupCredentials(
        groupId: groupId,
        groupNsecHex: groupKey.nsecHex,
        groupNpubHex: groupKey.npubHex,
      );
      await _keyDataSource.save(credentials);

      final metaJson = jsonEncode({
        'name': groupName,
        'key_epoch': credentials.keyEpoch,
        'members': <String>[],
        'updated_at': DateTime.now().toIso8601String(),
      });
      final signedMeta = await rust_api.sharedBuildSignedMetaEvent(
        groupNsecHex: credentials.groupNsecHex,
        metaJson: metaJson,
      );
      await _nostrService.sendSignedEvent(signedMeta);

      AppLogger.info('[SharedList] Created group $groupId (${groupKey.npubHex.substring(0, 16)}...)');
      return Right(credentials);
    } catch (e, st) {
      AppLogger.error('[SharedList] createSharedGroup failed', error: e, stackTrace: st);
      return Left(ServerFailure('共有リストの作成に失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> sendInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    required String groupNsecHex,
    required int keyEpoch,
  }) async {
    try {
      if (!_isAmberMode) {
        return Left(ServerFailure('shared-v1 招待は Amber モードが必要です'));
      }

      final senderHex = await _nostrService.getPublicKey();
      if (senderHex == null) {
        return Left(ServerFailure('公開鍵を取得できません'));
      }

      final creds = await _keyDataSource.load(groupId);
      final groupNpub = creds?.groupNpubHex ??
          (await rust_api.sharedGenerateGroupKey()).npubHex;

      final payload = await rust_api.sharedBuildInvitationPayload(
        groupId: groupId,
        groupNsec: groupNsecHex,
        groupNpub: groupNpub,
        groupName: groupName,
        keyEpoch: BigInt.from(keyEpoch),
      );

      final recipientHex = await _nostrService.npubToHex(recipientNpub);
      final amber = AmberService();
      final senderNpub = await _nostrService.hexToNpub(senderHex);

      final encrypted = await amber.encryptNip44WithContentProvider(
        plaintext: payload,
        pubkey: recipientHex,
        npub: senderNpub,
      );

      final unsigned = await rust_api.createUnsignedSharedInvitationEvent(
        senderPublicKeyHex: senderHex,
        recipientNpub: recipientNpub,
        groupId: groupId,
        groupName: groupName,
        encryptedContent: encrypted,
      );

      String signed;
      try {
        signed = await amber.signEventWithContentProvider(
          event: unsigned,
          npub: senderNpub,
        );
      } on Exception {
        signed = await amber.signEventWithTimeout(unsigned);
      }

      final result = await _nostrService.sendSignedEvent(signed);
      return Right(result.eventId);
    } catch (e, st) {
      AppLogger.error('[SharedList] sendInvitation failed', error: e, stackTrace: st);
      return Left(ServerFailure('招待の送信に失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SharedInvitation>>> syncInvitations({
    required String recipientPublicKeyHex,
  }) async {
    try {
      final jsonStr = await rust_api.syncSharedInvitations(
        recipientPublicKeyHex: recipientPublicKeyHex,
      );
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final invitations = list.map((raw) {
        final m = raw as Map<String, dynamic>;
        return SharedInvitation(
          groupId: m['group_id'] as String,
          groupName: (m['group_name'] as String?) ?? 'Shared List',
          encryptedContent: m['encrypted_content'] as String,
          inviterPubkey: m['inviter_pubkey'] as String,
          inviterName: m['inviter_name'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            ((m['created_at'] as num?) ?? 0).toInt() * 1000,
          ),
          eventId: m['event_id'] as String?,
        );
      }).toList();
      return Right(invitations);
    } catch (e, st) {
      AppLogger.error('[SharedList] syncInvitations failed', error: e, stackTrace: st);
      return Left(ServerFailure('招待の同期に失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, SharedGroupCredentials>> acceptInvitation({
    required SharedInvitation invitation,
    required String recipientPublicKeyHex,
    String? recipientNsecHex,
  }) async {
    try {
      String payloadJson;
      if (_isAmberMode) {
        final amber = AmberService();
        final recipientNpub = await _nostrService.hexToNpub(recipientPublicKeyHex);
        final decrypted = await amber.decryptNip44WithContentProvider(
          ciphertext: invitation.encryptedContent,
          pubkey: invitation.inviterPubkey,
          npub: recipientNpub,
        );
        payloadJson = decrypted;
      } else if (recipientNsecHex != null) {
        final parsed = await rust_api.sharedDecryptInvitationFromSender(
          recipientNsecHex: recipientNsecHex,
          senderPubkeyHex: invitation.inviterPubkey,
          ciphertext: invitation.encryptedContent,
        );
        payloadJson = jsonEncode({
          'group_id': parsed.groupId,
          'group_nsec': parsed.groupNsec,
          'group_name': parsed.groupName,
          'key_epoch': parsed.keyEpoch,
        });
      } else {
        return Left(ServerFailure('招待の復号に必要な鍵がありません'));
      }

      final parsed = await rust_api.sharedParseInvitationPayload(
        payloadJson: payloadJson,
      );
      final groupNpub = await rust_api.sharedNpubFromNsec(
        groupNsecHex: parsed.groupNsec,
      );
      final credentials = SharedGroupCredentials(
        groupId: parsed.groupId,
        groupNsecHex: parsed.groupNsec,
        groupNpubHex: groupNpub,
        keyEpoch: parsed.keyEpoch.toInt(),
      );
      await _keyDataSource.save(credentials);
      return Right(credentials);
    } catch (e, st) {
      AppLogger.error('[SharedList] acceptInvitation failed', error: e, stackTrace: st);
      return Left(ServerFailure('招待の受諾に失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, SharedGroupCredentials?>> loadCredentials({
    required String groupId,
  }) async {
    try {
      final creds = await _keyDataSource.load(groupId);
      return Right(creds);
    } catch (e) {
      return Left(ServerFailure('共有鍵の読み込みに失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> publishSignedTaskEvent({
    required String groupNsecHex,
    required String taskJson,
  }) async {
    try {
      final signed = await rust_api.sharedBuildSignedTaskEvent(
        groupNsecHex: groupNsecHex,
        taskJson: taskJson,
      );
      final result = await _nostrService.sendSignedEvent(signed);
      return Right(result.eventId);
    } catch (e, st) {
      AppLogger.error('[SharedList] publishSignedTaskEvent failed', error: e, stackTrace: st);
      return Left(ServerFailure('タスクの送信に失敗しました: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchTaskEvents({
    required String groupNpubHex,
    required DateTime since,
  }) async {
    try {
      final sinceSec = since.millisecondsSinceEpoch ~/ 1000;
      final events = await rust_api.fetchSharedEventsByAuthor(
        groupNpubHex: groupNpubHex,
        since: sinceSec,
        timeoutSecs: BigInt.from(10),
      );
      return Right(
        events
            .map((e) => jsonDecode(e.eventJson) as Map<String, dynamic>)
            .toList(),
      );
    } catch (e, st) {
      AppLogger.error('[SharedList] fetchTaskEvents failed', error: e, stackTrace: st);
      return Left(ServerFailure('タスクの取得に失敗しました: $e'));
    }
  }
}
