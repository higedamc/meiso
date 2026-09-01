import 'package:dartz/dartz.dart';

import '../../../../core/common/failure.dart';
import '../entities/task_comment.dart';

/// タスクコメント(タスクチャット)のリポジトリ契約
///
/// 実装は Phase 1b。共有リストはグループ鍵 G 経路(kind:35002 / author = G)、
/// 個人タスクは self NIP-44 経路(kind:35002 / author = 自分)を内部で使い分ける。
/// 設計は `docs/TASK_CHAT_DESIGN.md` を参照。
abstract class TaskCommentRepository {
  /// タスクのコメント一覧をローカルストアから監視する(created_at 昇順、
  /// tombstone は含むが UI 側で非表示にする)。
  Stream<List<TaskComment>> watchComments({required String taskId});

  /// コメントを投稿する。共有タスクなら groupId を渡し G 鍵経路で発行する。
  Future<Either<Failure, TaskComment>> addComment({
    required String taskId,
    required String body,
    String? groupId,
    String? parentCommentId,
  });

  /// 既存コメントを編集する(同一 `d` の再発行、editedAt 更新)。
  Future<Either<Failure, TaskComment>> editComment({
    required TaskComment comment,
    required String newBody,
    String? groupId,
  });

  /// コメントを削除する(tombstone の再発行。リレー上の本文も置換で消える)。
  Future<Either<Failure, Unit>> deleteComment({
    required TaskComment comment,
    String? groupId,
  });

  /// リレーから受信した kind:35002 イベントを復号・検証してローカルへ
  /// LWW 適用する(購読側から呼ばれる)。
  Future<Either<Failure, Unit>> applyRemoteCommentEvent({
    required String eventJson,
    String? groupId,
  });
}
