import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_link.freezed.dart';
part 'task_link.g.dart';

/// タスク間のリンク関係
///
/// NIP-XXA 互換タグ形式:
///   ["a", "35001:<pubkey>:<target-d>", "<relay>", "<linkType>"]
@Freezed(makeCollectionsUnmodifiable: false)
class TaskLink with _$TaskLink {
  const factory TaskLink({
    required String targetTaskId,
    required TaskLinkType linkType,
  }) = _TaskLink;

  factory TaskLink.fromJson(Map<String, dynamic> json) =>
      _$TaskLinkFromJson(json);
}

/// リンク種別（Asana 互換 + Nostr 標準化候補）
@JsonEnum()
enum TaskLinkType {
  /// このタスクが target をブロックしている
  blocks,

  /// このタスクが target にブロックされている
  blockedBy,

  /// 関連タスク（双方向）
  relatedTo,

  /// 重複タスク
  duplicateOf,
}

extension TaskLinkTypeExtension on TaskLinkType {
  String get displayLabel {
    switch (this) {
      case TaskLinkType.blocks:
        return 'Blocks';
      case TaskLinkType.blockedBy:
        return 'Blocked by';
      case TaskLinkType.relatedTo:
        return 'Related to';
      case TaskLinkType.duplicateOf:
        return 'Duplicate of';
    }
  }

  /// 逆方向のリンクタイプ（双方向リンク生成用）
  TaskLinkType get inverse {
    switch (this) {
      case TaskLinkType.blocks:
        return TaskLinkType.blockedBy;
      case TaskLinkType.blockedBy:
        return TaskLinkType.blocks;
      case TaskLinkType.relatedTo:
        return TaskLinkType.relatedTo;
      case TaskLinkType.duplicateOf:
        return TaskLinkType.duplicateOf;
    }
  }
}
