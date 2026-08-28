/// タスクコメント(タスクチャット)1 件分のエンティティ
///
/// Rust 側 `task_comments.rs` の `TaskCommentPayload` と 1:1 対応する。
/// 設計は `docs/TASK_CHAT_DESIGN.md` を参照。
class TaskComment {
  const TaskComment({
    required this.commentId,
    required this.taskId,
    required this.authorPubkey,
    required this.body,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    this.parentCommentId,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      commentId: json['comment_id'] as String,
      taskId: json['task_id'] as String,
      authorPubkey: json['author_pubkey'] as String,
      body: json['body'] as String? ?? '',
      createdAt: (json['created_at'] as num).toInt(),
      editedAt: (json['edited_at'] as num?)?.toInt(),
      deleted: json['deleted'] as bool? ?? false,
      parentCommentId: json['parent_comment_id'] as String?,
    );
  }

  /// コメント ID(UUID)。addressable event の `d` タグ値。
  final String commentId;

  /// 紐付くタスクの ID(暗号化ペイロード内でのみ保持)
  final String taskId;

  /// 表示用の投稿者公開鍵(hex)。shared-v1 の editorPubkey と同じ自己申告モデル。
  final String authorPubkey;

  /// 本文。tombstone では空文字。
  final String body;

  /// 投稿時刻(unix 秒)
  final int createdAt;

  /// 最終編集時刻(未編集なら null)
  final int? editedAt;

  /// 削除 tombstone フラグ
  final bool deleted;

  /// 返信先コメント ID(将来のスレッド用予約。1.5.0 UI では未使用)
  final String? parentCommentId;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'comment_id': commentId,
        'task_id': taskId,
        'author_pubkey': authorPubkey,
        'body': body,
        'created_at': createdAt,
        if (editedAt != null) 'edited_at': editedAt,
        'deleted': deleted,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      };

  TaskComment copyWith({
    String? body,
    int? editedAt,
    bool? deleted,
  }) {
    return TaskComment(
      commentId: commentId,
      taskId: taskId,
      authorPubkey: authorPubkey,
      body: body ?? this.body,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      parentCommentId: parentCommentId,
    );
  }
}
