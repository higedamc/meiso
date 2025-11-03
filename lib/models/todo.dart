import 'package:freezed_annotation/freezed_annotation.dart';
import 'link_preview.dart';
import 'recurrence_pattern.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// Nostr Kind 30078 (Application-specific data) として保存されるTodoモデル
/// 
/// Nostrイベント構造:
/// - Kind: 30078
/// - content: NIP-44で暗号化されたこのTodoのJSONデータ
/// - tags: ["d", "todo-{id}"] (Replaceable Event用)
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    /// UUID (Nostrイベントの'd' tagとしても使用)
    required String id,
    
    /// タスクのタイトル
    required String title,
    
    /// 完了状態
    @Default(false) bool completed,
    
    /// 日付 (null = Someday)
    DateTime? date,
    
    /// 同じ日付内での並び順
    @Default(0) int order,
    
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
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}

/// Todoの便利な拡張メソッド
extension TodoExtension on Todo {
  /// このタスクがリカーリングタスクかどうか
  bool get isRecurring => recurrence != null;
  
  /// このタスクがリカーリングタスクから生成されたインスタンスかどうか
  bool get isRecurringInstance => parentRecurringId != null;
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

