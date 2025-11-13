import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../services/local_storage_service.dart';
import '../../../../services/amber_service.dart';
import '../../../../services/logger_service.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../../../providers/nostr_provider.dart';

/// TodoRepository実装
/// 
/// Phase C: 個人Todo同期のみ実装
/// Phase D: グループTodo同期（MLS）を追加予定
/// 
/// 依存関係:
/// - LocalStorageService: ローカル永続化
/// - NostrService: Nostr通信
/// - AmberService: Amber署名/復号化
class TodoRepositoryImpl implements TodoRepository {
  final LocalStorageService _localStorageService;
  // Phase C.2で使用予定
  // ignore: unused_field
  final NostrService _nostrService;
  // Phase C.2で使用予定
  // ignore: unused_field
  final AmberService _amberService;
  
  const TodoRepositoryImpl({
    required LocalStorageService localStorageService,
    required NostrService nostrService,
    required AmberService amberService,
  })  : _localStorageService = localStorageService,
        _nostrService = nostrService,
        _amberService = amberService;
  
  // ============================================================
  // ローカルストレージ操作
  // ============================================================
  
  @override
  Future<Either<Failure, List<Todo>>> loadTodosFromLocal() async {
    try {
      AppLogger.debug('📂 [Repo] Loading todos from local storage...');
      
      final todos = await _localStorageService.loadTodos();
      
      AppLogger.info('✅ [Repo] Loaded ${todos.length} todos from local');
      return Right(todos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to load todos from local', error: e, stackTrace: stackTrace);
      return Left(LocalStorageFailure('ローカルからTodoの読み込みに失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveTodosToLocal(List<Todo> todos) async {
    try {
      AppLogger.debug('💾 [Repo] Saving ${todos.length} todos to local storage...');
      
      await _localStorageService.saveTodos(todos);
      
      AppLogger.info('✅ [Repo] Saved ${todos.length} todos to local');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to save todos to local', error: e, stackTrace: stackTrace);
      return Left(LocalStorageFailure('ローカルへTodoの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> saveTodoToLocal(Todo todo) async {
    try {
      AppLogger.debug('💾 [Repo] Saving single todo to local storage: ${todo.id}');
      
      await _localStorageService.saveTodo(todo);
      
      AppLogger.debug('✅ [Repo] Saved todo ${todo.id} to local');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to save todo to local', error: e, stackTrace: stackTrace);
      return Left(LocalStorageFailure('ローカルへTodoの保存に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> deleteTodoFromLocal(String id) async {
    try {
      AppLogger.debug('🗑️ [Repo] Deleting todo from local storage: $id');
      
      await _localStorageService.deleteTodo(id);
      
      AppLogger.debug('✅ [Repo] Deleted todo $id from local');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to delete todo from local', error: e, stackTrace: stackTrace);
      return Left(LocalStorageFailure('ローカルからTodoの削除に失敗しました: $e'));
    }
  }
  
  // ============================================================
  // Nostr同期操作（個人Todo）
  // ============================================================
  
  @override
  Future<Either<Failure, PersonalTodoSyncResult>> syncPersonalTodosFromNostr() async {
    try {
      AppLogger.info('🔄 [Repo] Syncing personal todos from Nostr...');
      
      // TODO: Phase C - ステップ2で実装
      // TodosProvider.syncFromNostr()からロジックを移植
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C Step 2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to sync from Nostr', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('Nostr同期に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> syncPersonalTodosToNostr({
    required List<Todo> todos,
    required bool isAmberMode,
  }) async {
    try {
      AppLogger.info('📤 [Repo] Syncing ${todos.length} personal todos to Nostr (Amber: $isAmberMode)...');
      
      // TODO: Phase C - ステップ2で実装
      // TodosProvider._syncAllTodosToNostr()からロジックを移植
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C Step 2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to sync to Nostr', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('Nostr送信に失敗しました: $e'));
    }
  }
  
  // ============================================================
  // マイグレーション関連
  // ============================================================
  
  @override
  Future<Either<Failure, bool>> checkKind30001Exists() async {
    try {
      AppLogger.debug('🔍 [Repo] Checking Kind 30001 existence...');
      
      // TODO: Phase C - ステップ2で実装
      // TodosProvider.checkKind30001Exists()からロジックを移植
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C Step 2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to check Kind 30001', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('Kind 30001チェックに失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> checkMigrationNeeded() async {
    try {
      AppLogger.debug('🔍 [Repo] Checking migration needed...');
      
      // TODO: Phase C - ステップ2で実装
      // TodosProvider.checkMigrationNeeded()からロジックを移植
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C Step 2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to check migration', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('マイグレーションチェックに失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> migrateFromKind30078ToKind30001() async {
    try {
      AppLogger.info('🔄 [Repo] Migrating from Kind 30078 to Kind 30001...');
      
      // TODO: Phase C - ステップ2で実装
      // TodosProvider.migrateFromKind30078ToKind30001()からロジックを移植
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C Step 2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to migrate', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('マイグレーションに失敗しました: $e'));
    }
  }
}

/// ローカルストレージのエラー
class LocalStorageFailure extends Failure {
  const LocalStorageFailure(String message) : super(message);
}

/// ネットワークエラー
class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}
