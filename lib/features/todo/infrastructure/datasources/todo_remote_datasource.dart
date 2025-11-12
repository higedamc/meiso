import '../../domain/entities/todo.dart';

/// NostrリレーDataSource
///
/// TodoをNostrリレーとの間で同期（暗号化・復号化含む）
abstract class TodoRemoteDataSource {
  /// NostrリレーからTodoを取得
  ///
  /// NIP-44復号化を行い、Todoリストを返す
  Future<List<Todo>> fetchTodosFromNostr(String publicKey);

  /// NostrリレーへTodoを送信
  ///
  /// NIP-44暗号化を行い、Nostrイベントとして送信
  Future<void> syncTodoToNostr(Todo todo, String publicKey);

  /// NostrリレーからTodoを削除
  ///
  /// Deletion eventを送信
  Future<void> deleteTodoFromNostr(String todoId, String publicKey);
}

/// Nostr実装（Rust API + Amber統合）
///
/// このクラスは簡略版で、実際のNostr同期ロジックは
/// TodoRepositoryImplで既存のサービスを活用する
class TodoRemoteDataSourceNostr implements TodoRemoteDataSource {
  const TodoRemoteDataSourceNostr();

  @override
  Future<List<Todo>> fetchTodosFromNostr(String publicKey) async {
    // Phase 3では実装をスキップ
    // Phase 4でTodoRepositoryImplが既存のNostrServiceを使用する
    throw UnimplementedError(
        'fetchTodosFromNostr is implemented in TodoRepositoryImpl');
  }

  @override
  Future<void> syncTodoToNostr(Todo todo, String publicKey) async {
    // Phase 3では実装をスキップ
    // Phase 4でTodoRepositoryImplが既存のNostrServiceを使用する
    throw UnimplementedError(
        'syncTodoToNostr is implemented in TodoRepositoryImpl');
  }

  @override
  Future<void> deleteTodoFromNostr(String todoId, String publicKey) async {
    // Phase 3では実装をスキップ
    // Phase 4でTodoRepositoryImplが既存のNostrServiceを使用する
    throw UnimplementedError(
        'deleteTodoFromNostr is implemented in TodoRepositoryImpl');
  }
}

