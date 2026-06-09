import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/todo_date.dart';
import '../value_objects/todo_title.dart';

part 'todo.freezed.dart';

/// Todoエンティティ（Domain層）
///
/// Nostr NIP-44暗号化でリレーに保存される。
/// ビジネスロジック層のコアエンティティ。
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required TodoTitle title,
    required bool completed,
    TodoDate? date,
    required int order,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? eventId,
    String? linkPreviewJson,
    String? recurrenceJson,
    String? parentRecurringId,
    String? customListId,
    required bool needsSync,

    /// 親タスクID（サブタスクの場合）
    String? parentTaskId,

    /// ネスト深度（0 = ルート）
    @Default(0) int depth,

    /// タスクリンク JSON（シリアライズ用）
    String? taskLinksJson,
  }) = _Todo;

  const Todo._();

  Map<String, dynamic> toSimpleJson() => {
    'id': id,
    'title': title.value,
    'completed': completed,
    'date': date?.value.toIso8601String(),
    'order': order,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'eventId': eventId,
    'linkPreview': linkPreviewJson,
    'recurrence': recurrenceJson,
    'parentRecurringId': parentRecurringId,
    'customListId': customListId,
    'needsSync': needsSync,
    'parentTaskId': parentTaskId,
    'depth': depth,
    'taskLinksJson': taskLinksJson,
  };
}

extension TodoExtension on Todo {
  bool get isRecurring => recurrenceJson != null;
  bool get isRecurringInstance => parentRecurringId != null;
  bool get isToday => date?.isToday ?? false;
  bool get isTomorrow => date?.isTomorrow ?? false;
  bool get isSomeday => date == null;
  bool get isSubtask => parentTaskId != null;
}

