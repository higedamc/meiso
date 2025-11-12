import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/todo_title.dart';
import '../value_objects/todo_date.dart';
import '../../../../models/link_preview.dart';
import '../../../../models/recurrence_pattern.dart';

part 'todo.freezed.dart';

/// Todoエンティティ（ビジネスロジック層）
///
/// Nostr NIP-44暗号化でリレーに保存される
/// Infrastructure層でJSON変換を行う
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    /// UUID (Nostrイベントの'd' tagとしても使用)
    required String id,

    /// タスクのタイトル（Value Object）
    required TodoTitle title,

    /// 完了状態
    required bool completed,

    /// 日付（Value Object、null = Someday）
    TodoDate? date,

    /// 同じ日付内での並び順
    required int order,

    /// 作成日時
    required DateTime createdAt,

    /// 更新日時
    required DateTime updatedAt,

    /// Nostrイベントの event ID (同期後に設定)
    String? eventId,

    /// URLリンクプレビュー（テキストにURLが含まれる場合）
    LinkPreview? linkPreview,

    /// リカーリングタスクの繰り返しパターン
    RecurrencePattern? recurrence,

    /// 親リカーリングタスクのID（このタスクが自動生成されたインスタンスの場合）
    String? parentRecurringId,

    /// カスタムリストID（SOMEDAYページのリストに属する場合）
    String? customListId,

    /// Nostrへの同期が必要かどうか（楽観的UI更新用）
    required bool needsSync,
  }) = _Todo;

  const Todo._();

  /// JSON から Todo を作成
  ///
  /// Infrastructure層で使用
  factory Todo.fromSimpleJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: TodoTitle.unsafe(json['title'] as String),
      completed: json['completed'] as bool? ?? false,
      date: json['date'] != null
          ? TodoDate.dateOnly(DateTime.parse(json['date'] as String))
          : null,
      order: json['order'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      eventId: json['eventId'] as String?,
      linkPreview: json['linkPreview'] != null
          ? LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>)
          : null,
      recurrence: json['recurrence'] != null
          ? RecurrencePattern.fromJson(
              json['recurrence'] as Map<String, dynamic>)
          : null,
      parentRecurringId: json['parentRecurringId'] as String?,
      customListId: json['customListId'] as String?,
      needsSync: json['needsSync'] as bool? ?? true,
    );
  }
}

/// Todoの便利な拡張メソッド
extension TodoExtension on Todo {
  /// このタスクがリカーリングタスクかどうか
  bool get isRecurring => recurrence != null;

  /// このタスクがリカーリングタスクから生成されたインスタンスかどうか
  bool get isRecurringInstance => parentRecurringId != null;

  /// 日付が今日かどうか
  bool get isToday => date?.isToday ?? false;

  /// 日付が明日かどうか
  bool get isTomorrow => date?.isTomorrow ?? false;

  /// 日付が過去かどうか
  bool get isPast => date?.isPast ?? false;

  /// 日付が未来かどうか
  bool get isFuture => date?.isFuture ?? false;

  /// Somedayタスクかどうか（日付なし）
  bool get isSomeday => date == null;

  /// JSON変換用のシンプルなマップに変換
  ///
  /// Infrastructure層で使用
  Map<String, dynamic> toSimpleJson() => {
        'id': id,
        'title': title.value,
        'completed': completed,
        'date': date?.value.toIso8601String(),
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'eventId': eventId,
        'linkPreview': linkPreview?.toJson(),
        'recurrence': recurrence?.toJson(),
        'parentRecurringId': parentRecurringId,
        'customListId': customListId,
        'needsSync': needsSync,
      };
}

