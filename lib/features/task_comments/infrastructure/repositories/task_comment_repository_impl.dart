import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/common/failure.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../services/logger_service.dart';
import '../../../shared_list/infrastructure/datasources/shared_group_key_local_datasource.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/repositories/task_comment_repository.dart';
import '../datasources/task_comment_crypto_datasource_contract.dart';
import '../datasources/task_comment_local_datasource.dart';

/// タスクコメントの event kind(docs/TASK_CHAT_DESIGN.md)
const int taskCommentKind = 35002;

/// 本文の最大文字数(MAX_COMMENT_BODY_CHARS)。
/// 書き込み/読み取りの両側でクランプする(読み取り側は巨大な
/// 敵対 payload への防御)。
const int maxCommentBodyChars = 2000;

/// 個人タスク用の自分の nsec(hex)を解決する関数
///
/// 取得できない場合は null を返す(Amber モード等)。
typedef PersonalNsecHexResolver = Future<String?> Function();

/// [TaskCommentRepository] の実装
///
/// - 共有リストタスク(groupId != null): グループ鍵 G で署名/復号
///   (kind:35000 タスクと同一経路)
/// - 個人タスク(groupId == null): 自分の鍵で署名/復号
///   (nsec を解決できない場合は AuthFailure)
class TaskCommentRepositoryImpl implements TaskCommentRepository {
  TaskCommentRepositoryImpl({
    required TaskCommentCryptoDataSource cryptoDataSource,
    required TaskCommentLocalDataSource localDataSource,
    required SharedGroupKeyLocalDataSource keyDataSource,
    required NostrService nostrService,
    required PersonalNsecHexResolver personalNsecHexResolver,
    Uuid uuid = const Uuid(),
  }) : _cryptoDataSource = cryptoDataSource,
       _localDataSource = localDataSource,
       _keyDataSource = keyDataSource,
       _nostrService = nostrService,
       _personalNsecHexResolver = personalNsecHexResolver,
       _uuid = uuid;

  final TaskCommentCryptoDataSource _cryptoDataSource;
  final TaskCommentLocalDataSource _localDataSource;
  final SharedGroupKeyLocalDataSource _keyDataSource;
  final NostrService _nostrService;
  final PersonalNsecHexResolver _personalNsecHexResolver;
  final Uuid _uuid;

  @override
  Stream<List<TaskComment>> watchComments({required String taskId}) {
    return _localDataSource.watchComments(taskId);
  }

  @override
  Future<Either<Failure, TaskComment>> addComment({
    required String taskId,
    required String body,
    String? groupId,
    String? parentCommentId,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('コメント本文が空です'));
    }
    final authorPubkey = await _nostrService.getPublicKey();
    if (authorPubkey == null) {
      return const Left(AuthFailure('公開鍵を取得できません'));
    }
    final comment = TaskComment(
      commentId: _uuid.v4(),
      taskId: taskId,
      authorPubkey: authorPubkey,
      body: _clampBody(trimmed),
      createdAt: _nowEpochSeconds(),
      parentCommentId: parentCommentId,
    );
    return _signPublishAndStore(comment: comment, groupId: groupId);
  }

  @override
  Future<Either<Failure, TaskComment>> editComment({
    required TaskComment comment,
    required String newBody,
    String? groupId,
  }) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('コメント本文が空です'));
    }
    final updated = comment.copyWith(
      body: _clampBody(trimmed),
      editedAt: _nowEpochSeconds(),
    );
    return _signPublishAndStore(comment: updated, groupId: groupId);
  }

  @override
  Future<Either<Failure, Unit>> deleteComment({
    required TaskComment comment,
    String? groupId,
  }) async {
    // tombstone: 同一 d で deleted=true / body 空を再発行し、
    // addressable 置換でリレー上の本文も消す。
    final tombstone = comment.copyWith(
      body: '',
      deleted: true,
      editedAt: _nowEpochSeconds(),
    );
    final result = await _signPublishAndStore(
      comment: tombstone,
      groupId: groupId,
    );
    return result.map((_) => unit);
  }

  @override
  Future<Either<Failure, Unit>> applyRemoteCommentEvent({
    required String eventJson,
    String? groupId,
  }) async {
    try {
      final eventMap = jsonDecode(eventJson) as Map<String, dynamic>;
      final kind = (eventMap['kind'] as num?)?.toInt();
      if (kind != taskCommentKind) {
        return Left(
          ValidationFailure('kind:$kind はタスクコメントではありません'),
        );
      }
      final eventId = eventMap['id'] as String?;
      final eventCreatedAt = (eventMap['created_at'] as num?)?.toInt();
      if (eventId == null || eventCreatedAt == null) {
        return const Left(ValidationFailure('イベントの id/created_at が不正です'));
      }

      final nsecResult = await _resolveNsecHex(groupId);
      return nsecResult.fold(Left.new, (nsecHex) async {
        final plaintext = await _cryptoDataSource.decryptCommentEvent(
          nsecHex: nsecHex,
          eventJson: eventJson,
        );
        var comment = TaskComment.fromJson(
          jsonDecode(plaintext) as Map<String, dynamic>,
        );
        // 読み取り側クランプ(過大な敵対 payload への防御)
        if (comment.body.runes.length > maxCommentBodyChars) {
          comment = comment.copyWith(body: _clampBody(comment.body));
        }
        final applied = await _localDataSource.upsert(
          comment: comment,
          eventCreatedAt: eventCreatedAt,
          eventId: eventId,
        );
        if (applied) {
          AppLogger.debug(
            '[task-chat] Applied comment ${_short(comment.commentId)}',
          );
        }
        return const Right(unit);
      });
    } on Object catch (e, st) {
      AppLogger.error(
        '[task-chat] applyRemoteCommentEvent failed',
        error: e,
        stackTrace: st,
      );
      return Left(DecryptionFailure('コメントの復号に失敗しました: $e'));
    }
  }

  // === Private Helpers ===

  /// 署名 → ローカル LWW upsert → リレー送信の順で処理する。
  ///
  /// ローカル保存を送信より先に行うことで、リレー送信が失敗しても
  /// オフラインファーストに自端末へは反映される(todos と同方針)。
  Future<Either<Failure, TaskComment>> _signPublishAndStore({
    required TaskComment comment,
    required String? groupId,
  }) async {
    try {
      final nsecResult = await _resolveNsecHex(groupId);
      return nsecResult.fold(Left.new, (nsecHex) async {
        final signed = await _cryptoDataSource.buildSignedCommentEvent(
          nsecHex: nsecHex,
          commentJson: jsonEncode(comment.toJson()),
        );
        final signedMap = jsonDecode(signed) as Map<String, dynamic>;
        final eventId = signedMap['id'] as String? ?? '';
        final eventCreatedAt =
            (signedMap['created_at'] as num?)?.toInt() ?? comment.createdAt;

        await _localDataSource.upsert(
          comment: comment,
          eventCreatedAt: eventCreatedAt,
          eventId: eventId,
        );

        final sendResult = await _nostrService.sendSignedEvent(signed);
        final sendError = sendResult.errorMessage;
        AppLogger.info(
          '[task-chat] publish comment -> '
          'eventId=${_short(sendResult.eventId)}, '
          'success=${sendResult.success}, '
          'successfulRelays=${sendResult.successfulRelays}, '
          'failedRelays=${sendResult.failedRelays}'
          '${sendError != null ? ", err=$sendError" : ""}',
        );
        return Right(comment);
      });
    } on Object catch (e, st) {
      AppLogger.error(
        '[task-chat] publish comment failed',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure('コメントの送信に失敗しました: $e'));
    }
  }

  /// 鍵経路の解決: 共有リストはグループ鍵 G、個人タスクは自分の nsec。
  Future<Either<Failure, String>> _resolveNsecHex(String? groupId) async {
    if (groupId != null) {
      final credentials = await _keyDataSource.load(groupId);
      if (credentials == null) {
        return Left(AuthFailure('共有リスト $groupId のグループ鍵がありません'));
      }
      return Right(credentials.groupNsecHex);
    }
    final nsecHex = await _personalNsecHexResolver();
    if (nsecHex == null) {
      // TODO(task-chat): 個人タスク経路の鍵取得は未解決(Phase 1b 時点)。
      // 秘密鍵モードでは nsec が Rust セッション内にのみ存在し Dart へ
      // 露出せず、Amber モードでは nsec 自体が存在しない。Phase 1a 側で
      // セッション鍵を使う FFI(例: clientBuildSignedCommentEvent)を
      // 追加するまで、個人タスクのコメントは AuthFailure を返す。
      return const Left(
        AuthFailure('個人タスクのコメント署名鍵を取得できません(未対応: docs/TASK_CHAT_DESIGN.md)'),
      );
    }
    return Right(nsecHex);
  }

  /// Rust 側の `chars()` クランプと同じくコードポイント境界で切り詰める
  /// (UTF-16 `substring` はサロゲートペアを分断し JSON 化に失敗しうる)。
  String _clampBody(String body) {
    if (body.runes.length <= maxCommentBodyChars) {
      return body;
    }
    return String.fromCharCodes(body.runes.take(maxCommentBodyChars));
  }

  int _nowEpochSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  String _short(String id) => id.length > 16 ? '${id.substring(0, 16)}...' : id;
}
