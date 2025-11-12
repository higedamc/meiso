import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../entities/todo.dart';

/// TodoリポジトリのDomain層インターフェース
/// 
/// Infrastructure層で実装される。
/// データの永続化・同期の詳細を抽象化。
abstract class TodoRepository {
  /// すべてのTodoを取得（ローカルキャッシュから）
  Future<Either<Failure, List<Todo>>> getAllTodos();

  /// 特定の日付のTodoを取得
  /// 
  /// [date] がnullの場合はSomedayタスクを取得
  Future<Either<Failure, List<Todo>>> getTodosByDate(DateTime? date);

  /// 特定のカスタムリストのTodoを取得
  Future<Either<Failure, List<Todo>>> getTodosByListId(String listId);

  /// 特定のTodoを取得
  Future<Either<Failure, Todo>> getTodoById(String id);

  /// Todoを作成
  /// 
  /// ローカルに保存し、バックグラウンドでNostrに同期。
  Future<Either<Failure, Todo>> createTodo(Todo todo);

  /// Todoを更新
  /// 
  /// ローカルに保存し、バックグラウンドでNostrに同期。
  Future<Either<Failure, Todo>> updateTodo(Todo todo);

  /// Todoを削除
  /// 
  /// ローカルから削除し、バックグラウンドでNostrからも削除。
  Future<Either<Failure, void>> deleteTodo(String id);

  /// NostrリレーからTodoを同期（取得）
  /// 
  /// リモートからデータを取得し、ローカルに反映。
  Future<Either<Failure, List<Todo>>> syncFromNostr();

  /// TodoをNostrリレーに送信（同期）
  /// 
  /// 指定したTodoをリモートに送信。
  Future<Either<Failure, void>> syncToNostr(Todo todo);

  /// ローカルストレージに保存
  Future<Either<Failure, void>> saveLocal(List<Todo> todos);

  /// ローカルストレージから読み込み
  Future<Either<Failure, List<Todo>>> loadLocal();

  /// 複数のTodoの並び順を更新
  Future<Either<Failure, List<Todo>>> reorderTodos(List<Todo> todos);

  /// Todoを別の日付に移動
  Future<Either<Failure, Todo>> moveTodo(String id, DateTime? newDate);
}

