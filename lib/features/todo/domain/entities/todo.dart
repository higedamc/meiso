import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/todo_title.dart';
import '../value_objects/todo_date.dart';

part 'todo.freezed.dart';

/// Todoエンティティ（Domain層）
/// 
/// Nostr NIP-44暗号化でリレーに保存される。
/// ビジネスロジック層のコアエンティティ。
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
    
    /// URLリンクプレビュー（JSON化して保存）
    String? linkPreviewJson,
    
    /// リカーリングタスクの繰り返しパターン（JSON化して保存）
    String? recurrenceJson,
    
    /// 親リカーリングタスクのID（このタスクが自動生成されたインスタンスの場合）
    String? parentRecurringId,
    
    /// カスタムリストID（SOMEDAYページのリストに属する場合）
    String? customListId,
    
    /// Nostrへの同期が必要かどうか（楽観的UI更新用）
    required bool needsSync,
  }) = _Todo;

  const Todo._();

  /// JSON変換用のシンプルなマップに変換
  /// 
  /// Infrastructure層でDTO変換時に使用。
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
  };
}

/// Todoの便利な拡張メソッド
extension TodoExtension on Todo {
  /// このタスクがリカーリングタスクかどうか
  bool get isRecurring => recurrenceJson != null;

  /// このタスクがリカーリングタスクから生成されたインスタンスかどうか
  bool get isRecurringInstance => parentRecurringId != null;

  /// このタスクが今日のタスクかどうか
  bool get isToday => date?.isToday ?? false;

  /// このタスクが明日のタスクかどうか
  bool get isTomorrow => date?.isTomorrow ?? false;

  /// このタスクがSomedayかどうか
  bool get isSomeday => date == null;
}

