import 'package:freezed_annotation/freezed_annotation.dart';
import 'link_preview.dart';
import 'recurrence_pattern.dart';
import 'task_link.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// Nostr Kind 30001 (NIP-51 Bookmark List) として保存されるTodoモデル
///
/// 将来的に NIP-XXA Kind 35001 (per-task addressable event) への移行を想定。
/// サブタスク関係は parentTaskId で、タスクリンクは taskLinks で表現する。
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required String title,
    @Default(false) bool completed,
    DateTime? date,
    @Default(0) int order,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? eventId,
    String? localOpId,
    DateTime? localRelaySyncedAt,
    DateTime? globalRelaySyncedAt,
    @Default(false) bool globalSyncPending,
    @Default(false) bool globalSyncFailed,
    LinkPreview? linkPreview,
    RecurrencePattern? recurrence,
    String? parentRecurringId,
    String? customListId,
    @Default(true) bool needsSync,

    /// 親タスクID（サブタスクの場合に設定）
    /// NIP-XXA 互換: ["a", "35001:<pubkey>:<parent-d>", "", "parent"]
    String? parentTaskId,

    /// ネスト深度（0 = ルートタスク、表示用キャッシュ）
    @Default(0) int depth,

    /// タスクリンク（blocks, blocked_by, related_to, duplicate_of）
    @Default([]) List<TaskLink> taskLinks,

    /// 添付画像のURL（Blossom/NIP-96経由でアップロード済み）
    String? imageUrl,

    /// 共有リスト(shared-v1)で、このタスクを最後に追加/編集した実 npub(hex)。
    /// 自分以外が編集したタスクを UI 上で区別するために使用する。
    String? editorPubkey,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}

extension TodoExtension on Todo {
  bool get isRecurring => recurrence != null;
  bool get isRecurringInstance => parentRecurringId != null;

  /// サブタスクを持つ可能性がある（子の探索は provider 側で行う）
  bool get isSubtask => parentTaskId != null;

  /// ブロッキングリンクが存在するか
  bool get hasBlockingLinks =>
      taskLinks.any((l) => l.linkType == TaskLinkType.blockedBy);
}

/// Todoの日付カテゴリー
enum TodoCategory {
  today,
  tomorrow,
  someday,
}

extension TodoCategoryExtension on TodoCategory {
  String get label {
    switch (this) {
      case TodoCategory.today:
        return 'Today';
      case TodoCategory.tomorrow:
        return 'Tomorrow';
      case TodoCategory.someday:
        return 'Someday';
    }
  }
}

