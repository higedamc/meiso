import '../../domain/entities/todo.dart';

/// Todoリモートデータソースのインターフェース
/// 
/// Nostrリレーとの通信を抽象化
abstract class TodoRemoteDataSource {
  /// Nostrからすべてのパーソナル（個人）Todoを取得
  Future<List<Todo>> fetchPersonalTodosFromNostr();

  /// NostrからMLSグループタスクを取得
  Future<List<Todo>> fetchGroupTodosFromNostr(String customListId);

  /// パーソナルTodoをNostrに送信
  Future<void> syncPersonalTodoToNostr(Todo todo);

  /// グループタスクをNostrに送信
  Future<void> syncGroupTodoToNostr(Todo todo, String customListId);

  /// パーソナルTodoをNostrから削除
  Future<void> deletePersonalTodoFromNostr(String id);

  /// グループタスクをNostrから削除
  Future<void> deleteGroupTodoFromNostr(String id, String customListId);
}

/// Nostr実装（Rust API + Amber統合）
/// 
/// 実装の詳細:
/// - NIP-44暗号化でTodoを送信/取得
/// - Amberモードと秘密鍵モードをサポート
/// - MLSグループタスクの同期
/// 
/// この実装は旧 `todos_provider.dart` のロジックを移植する予定。
/// Phase 4（Application層）実装時に完全に移行する。
class TodoRemoteDataSourceNostr implements TodoRemoteDataSource {
  // TODO: Phase 4で実装
  // 現時点ではスタブとして定義のみ

  @override
  Future<List<Todo>> fetchPersonalTodosFromNostr() async {
    // 旧Provider: syncFromNostr() のロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }

  @override
  Future<List<Todo>> fetchGroupTodosFromNostr(String customListId) async {
    // 旧Provider: syncGroupTodos() のロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }

  @override
  Future<void> syncPersonalTodoToNostr(Todo todo) async {
    // 旧Provider: _syncTodoWithMode() のロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }

  @override
  Future<void> syncGroupTodoToNostr(Todo todo, String customListId) async {
    // 旧Provider: _syncGroupTodo() のロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }

  @override
  Future<void> deletePersonalTodoFromNostr(String id) async {
    // 旧Provider: deleteTodo() 内のNostr削除ロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }

  @override
  Future<void> deleteGroupTodoFromNostr(String id, String customListId) async {
    // 旧Provider: deleteGroupTodo() のロジックを移植
    throw UnimplementedError('Phase 4で実装予定');
  }
}

