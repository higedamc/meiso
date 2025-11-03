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
/// 
/// ## デフォルトリストとカスタムリストの排他性
/// - **デフォルトリスト** (Today/Tomorrow/Someday): `date`フィールドを使用
///   - Today: `date = 今日の日付`
///   - Tomorrow: `date = 明日の日付`
///   - Someday: `date = null` かつ `customListId = null`
/// - **カスタムリスト**: `customListId`フィールドを使用（`date = null`）
/// 
/// ⚠️ 重要: `date`と`customListId`は排他的な関係です。
/// - デフォルトリストのTodo: `customListId`は必ず`null`
/// - カスタムリストのTodo: `date`は必ず`null`
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const Todo._(); // カスタムメソッドを追加するため
  
  const factory Todo({
    /// UUID (Nostrイベントの'd' tagとしても使用)
    required String id,
    
    /// タスクのタイトル
    required String title,
    
    /// 完了状態
    @Default(false) bool completed,
    
    /// 日付 (デフォルトリスト用)
    /// - Today/Tomorrow: 具体的な日付
    /// - Someday: null
    /// - カスタムリスト: null（customListIdと排他的）
    DateTime? date,
    
    /// 同じ日付内またはカスタムリスト内での並び順
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
    
    /// カスタムリストID（dateと排他的）
    /// - カスタムリストに属する場合: 具体的なID
    /// - デフォルトリストに属する場合: null
    String? customListId,
    
    /// Nostrへの同期が必要かどうか（楽観的UI更新用）
    @Default(true) bool needsSync,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
  
  /// バリデーション: dateとcustomListIdは排他的
  /// 
  /// 有効なパターン:
  /// 1. date != null && customListId == null (デフォルトリスト: Today/Tomorrow)
  /// 2. date == null && customListId == null (デフォルトリスト: Someday)
  /// 3. date == null && customListId != null (カスタムリスト)
  /// 
  /// 無効なパターン:
  /// 4. date != null && customListId != null (不正！)
  bool get isValid {
    // dateとcustomListIdが同時に設定されている場合は不正
    if (date != null && customListId != null) {
      return false;
    }
    return true;
  }
  
  /// このTodoがカスタムリストに属しているか
  bool get belongsToCustomList => customListId != null;
  
  /// このTodoがデフォルトリストに属しているか
  bool get belongsToDefaultList => customListId == null;
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

