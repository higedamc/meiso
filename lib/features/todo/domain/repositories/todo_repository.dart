import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/todo.dart';

/// TodoリポジトリのDomain層インターフェース
///
/// Infrastructure層で実装される
abstract class TodoRepository {
  /// すべてのTodoを取得（ローカルキャッシュから）
  Future<Either<Failure, List<Todo>>> getAllTodos();

  /// 特定のTodoを取得
  Future<Either<Failure, Todo>> getTodoById(String id);

  /// Todoを作成
  ///
  /// ローカル保存 + Nostr同期（非同期）
  Future<Either<Failure, Todo>> createTodo(Todo todo);

  /// Todoを更新
  ///
  /// ローカル保存 + Nostr同期（非同期）
  Future<Either<Failure, Todo>> updateTodo(Todo todo);

  /// Todoを削除
  ///
  /// ローカル削除 + Nostr削除（非同期）
  Future<Either<Failure, void>> deleteTodo(String id);

  /// NostrリレーからTodoを同期
  ///
  /// リレーから最新データを取得し、ローカルに保存
  Future<Either<Failure, List<Todo>>> syncFromNostr();

  /// TodoをNostrリレーに送信
  ///
  /// needsSync=trueのTodoを同期
  Future<Either<Failure, void>> syncToNostr(Todo todo);

  /// ローカルストレージに保存
  Future<Either<Failure, void>> saveLocal(List<Todo> todos);

  /// ローカルストレージから読み込み
  Future<Either<Failure, List<Todo>>> loadLocal();

  /// 日付でフィルタリングしたTodoリストを取得
  Future<Either<Failure, List<Todo>>> getTodosByDate(DateTime? date);

  /// カスタムリストでフィルタリングしたTodoリストを取得
  Future<Either<Failure, List<Todo>>> getTodosByCustomList(String listId);

  /// 完了状態でフィルタリングしたTodoリストを取得
  Future<Either<Failure, List<Todo>>> getTodosByCompletionStatus(
      bool completed);

  /// リカーリングタスクのインスタンスを作成
  Future<Either<Failure, Todo>> createRecurringInstance(Todo recurringTodo);
}

