import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/errors/todo_errors.dart';
import '../../domain/value_objects/todo_date.dart';
import '../datasources/todo_local_datasource.dart';
import '../datasources/todo_remote_datasource.dart';

/// TodoリポジトリのInfrastructure層実装
/// 
/// ローカルストレージとNostrリレーの両方を管理し、
/// 楽観的UI更新パターンを実装する。
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
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> getTodosByDate(DateTime? date) async {
    try {
      final allTodos = await localDataSource.loadAllTodos();

      // 日付でフィルタリング
      final filtered = allTodos.where((todo) {
        if (date == null) {
          // Somedayタスク
          return todo.date == null;
        } else {
          // 指定された日付のタスク
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
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> getTodosByListId(String listId) async {
    try {
      final allTodos = await localDataSource.loadAllTodos();

      // カスタムリストIDでフィルタリング
      final filtered = allTodos.where((todo) {
        return todo.customListId == listId;
      }).toList();

      // order順にソート
      filtered.sort((a, b) => a.order.compareTo(b.order));

      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> getTodoById(String id) async {
    try {
      final todo = await localDataSource.loadTodoById(id);
      if (todo == null) {
        return const Left(TodoFailure(TodoError.notFound));
      }
      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> createTodo(Todo todo) async {
    try {
      // 楽観的UI更新: まずローカルに保存
      await localDataSource.saveTodo(todo);

      // バックグラウンドでNostrに送信（非同期、エラーは無視）
      _syncToNostrInBackground(todo);

      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> updateTodo(Todo todo) async {
    try {
      // 楽観的UI更新: まずローカルに保存
      await localDataSource.saveTodo(todo);

      // バックグラウンドでNostrに送信（非同期、エラーは無視）
      _syncToNostrInBackground(todo);

      return Right(todo);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTodo(String id) async {
    try {
      // ローカルから削除
      await localDataSource.deleteTodo(id);

      // バックグラウンドでNostrからも削除（非同期、エラーは無視）
      _deleteFromNostrInBackground(id);

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> syncFromNostr() async {
    try {
      // Nostrから取得
      final remoteTodos = await remoteDataSource.fetchPersonalTodosFromNostr();

      // ローカルに保存
      for (final todo in remoteTodos) {
        await localDataSource.saveTodo(todo);
      }

      return Right(remoteTodos);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncToNostr(Todo todo) async {
    try {
      if (todo.customListId != null) {
        // グループタスク
        await remoteDataSource.syncGroupTodoToNostr(todo, todo.customListId!);
      } else {
        // パーソナルタスク
        await remoteDataSource.syncPersonalTodoToNostr(todo);
      }
      return const Right(null);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveLocal(List<Todo> todos) async {
    try {
      await localDataSource.saveTodos(todos);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> loadLocal() async {
    try {
      final todos = await localDataSource.loadAllTodos();
      return Right(todos);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Todo>>> reorderTodos(List<Todo> todos) async {
    try {
      // 各TodoをローカルとNostrに保存
      for (final todo in todos) {
        await localDataSource.saveTodo(todo);
        _syncToNostrInBackground(todo);
      }

      return Right(todos);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Todo>> moveTodo(String id, DateTime? newDate) async {
    try {
      // 既存のTodoを取得
      final result = await getTodoById(id);
      
      return result.fold(
        (failure) => Left(failure),
        (existingTodo) async {
          // 日付を更新
          final updatedTodo = existingTodo.copyWith(
            date: newDate != null ? TodoDate.dateOnly(newDate) : null,
            updatedAt: DateTime.now(),
            needsSync: true,
          );

          // 更新して返す
          return updateTodo(updatedTodo);
        },
      );
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // === Private Helpers ===

  /// バックグラウンドでNostrに同期
  /// 
  /// エラーは無視（ログのみ）
  void _syncToNostrInBackground(Todo todo) {
    if (todo.customListId != null) {
      remoteDataSource
          .syncGroupTodoToNostr(todo, todo.customListId!)
          .catchError((e) {
        // ログ記録のみ（Phase 4で実装時にロガー追加）
        print('[TodoRepository] Nostr sync failed: $e');
      });
    } else {
      remoteDataSource.syncPersonalTodoToNostr(todo).catchError((e) {
        print('[TodoRepository] Nostr sync failed: $e');
      });
    }
  }

  /// バックグラウンドでNostrから削除
  /// 
  /// エラーは無視（ログのみ）
  void _deleteFromNostrInBackground(String id) {
    // TODO: Phase 4でグループタスク対応
    remoteDataSource.deletePersonalTodoFromNostr(id).catchError((e) {
      print('[TodoRepository] Nostr delete failed: $e');
    });
  }
}

