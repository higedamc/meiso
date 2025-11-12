import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/errors/todo_errors.dart';
import '../datasources/todo_local_datasource.dart';
import '../datasources/todo_remote_datasource.dart';
import '../../../../services/logger_service.dart';

/// TodoリポジトリのInfrastructure層実装
///
/// ローカル（Hive）とリモート（Nostr）のDataSourceを統合
class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  final TodoLocalDataSource localDataSource;
  final TodoRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Todo>>> getAllTodos() async {
    try {
      final todos = await localDataSource.loadAllTodos();
      return Right(todos);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] getAllTodos failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> getTodoById(String id) async {
    try {
      final todo = await localDataSource.loadTodoById(id);
      if (todo == null) {
        return Left(TodoFailure(TodoError.notFound));
      }
      return Right(todo);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] getTodoById failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> createTodo(Todo todo) async {
    try {
      // ローカルに保存
      await localDataSource.saveTodo(todo);
      AppLogger.info('✅ [TodoRepository] Created todo: ${todo.id}');

      // Nostr同期は非同期（エラーは無視）
      // Phase 4で実装予定
      // _syncToNostrBackground(todo);

      return Right(todo);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] createTodo failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> updateTodo(Todo todo) async {
    try {
      // ローカルに保存
      await localDataSource.saveTodo(todo);
      AppLogger.info('✅ [TodoRepository] Updated todo: ${todo.id}');

      // Nostr同期は非同期（エラーは無視）
      // Phase 4で実装予定
      // _syncToNostrBackground(todo);

      return Right(todo);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] updateTodo failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTodo(String id) async {
    try {
      await localDataSource.deleteTodo(id);
      AppLogger.info('✅ [TodoRepository] Deleted todo: $id');

      // Nostr削除は非同期（エラーは無視）
      // Phase 4で実装予定
      // _deleteFromNostrBackground(id);

      return const Right(null);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] deleteTodo failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> syncFromNostr() async {
    // Phase 4で実装予定
    // 現在はローカルデータのみを返す
    return getAllTodos();
  }

  @override
  Future<Either<Failure, void>> syncToNostr(Todo todo) async {
    // Phase 4で実装予定
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> saveLocal(List<Todo> todos) async {
    try {
      await localDataSource.saveTodos(todos);
      AppLogger.info('✅ [TodoRepository] Saved ${todos.length} todos locally');
      return const Right(null);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] saveLocal failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> loadLocal() async {
    return getAllTodos();
  }

  @override
  Future<Either<Failure, List<Todo>>> getTodosByDate(DateTime? date) async {
    try {
      final allTodos = await localDataSource.loadAllTodos();

      // 日付でフィルタリング
      final filtered = allTodos.where((todo) {
        if (date == null) {
          // null = Somedayタスク
          return todo.date == null;
        } else {
          // 日付が一致するタスク
          return todo.date != null &&
              todo.date!.value.year == date.year &&
              todo.date!.value.month == date.month &&
              todo.date!.value.day == date.day;
        }
      }).toList();

      // order順にソート
      filtered.sort((a, b) => a.order.compareTo(b.order));

      return Right(filtered);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] getTodosByDate failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> getTodosByCustomList(String listId) async {
    try {
      final allTodos = await localDataSource.loadAllTodos();

      // カスタムリストIDでフィルタリング
      final filtered =
          allTodos.where((todo) => todo.customListId == listId).toList();

      // order順にソート
      filtered.sort((a, b) => a.order.compareTo(b.order));

      return Right(filtered);
    } catch (e) {
      AppLogger.error('❌ [TodoRepository] getTodosByCustomList failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> getTodosByCompletionStatus(
      bool completed) async {
    try {
      final allTodos = await localDataSource.loadAllTodos();

      // 完了状態でフィルタリング
      final filtered =
          allTodos.where((todo) => todo.completed == completed).toList();

      // order順にソート
      filtered.sort((a, b) => a.order.compareTo(b.order));

      return Right(filtered);
    } catch (e) {
      AppLogger.error(
          '❌ [TodoRepository] getTodosByCompletionStatus failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> createRecurringInstance(Todo recurringTodo) async {
    // Phase 4で実装予定（リカーリングタスク機能）
    return Left(TodoFailure(TodoError.invalidRecurrence));
  }
}

