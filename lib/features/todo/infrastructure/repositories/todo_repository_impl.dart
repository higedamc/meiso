import 'dart:convert';

import 'package:dartz/dartz.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../models/link_preview.dart';
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
      
      // Amberモード判定（LocalStorageから取得）
      final isAmberMode = _localStorageService.isUsingAmber();
      AppLogger.debug('[Repo] Mode: ${isAmberMode ? "Amber" : "Normal"}');
      
      if (isAmberMode) {
        // Amberモード: 暗号化されたTodoリストイベントを取得
        // ⚠️ 復号化はしない！イベントの存在だけチェック
        AppLogger.debug('[Repo] Fetching encrypted Kind 30001 event (NO DECRYPTION)...');
        final encryptedEvent = await _nostrService.fetchEncryptedTodoList();
        
        if (encryptedEvent != null) {
          AppLogger.info('✅ [Repo] Found Kind 30001 event (Amber mode) - Event ID: ${encryptedEvent.eventId}');
          AppLogger.info('[Repo] This means migration is already done. NO NEED TO DECRYPT OLD EVENTS!');
          return const Right(true);
        } else {
          AppLogger.debug('[Repo] No Kind 30001 event found (Amber mode)');
        }
      } else {
        // 通常モード: Rust側で復号化済みのTodoリストを取得
        AppLogger.debug('[Repo] Fetching Kind 30001 todos (normal mode)...');
        final todos = await _nostrService.syncTodoListFromNostr();
        
        if (todos.isNotEmpty) {
          AppLogger.info('✅ [Repo] Found Kind 30001 with ${todos.length} todos (normal mode)');
          return const Right(true);
        } else {
          AppLogger.debug('[Repo] No Kind 30001 todos found (normal mode)');
        }
      }
      
      AppLogger.debug('[Repo] No Kind 30001 found - will check Kind 30078');
      return const Right(false);
    } catch (e, stackTrace) {
      AppLogger.warning('⚠️ [Repo] Failed to check Kind 30001: $e');
      AppLogger.error('[Repo] Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      // エラーでもfalseを返す（マイグレーションチェックに進む）
      return const Right(false);
    }
  }
  
  @override
  Future<Either<Failure, bool>> checkMigrationNeeded() async {
    try {
      AppLogger.debug('🔍 [Repo] Checking migration needed...');
      
      // ローカルストレージでマイグレーション完了済みかチェック
      final completed = await _localStorageService.isMigrationCompleted();
      if (completed) {
        AppLogger.info('✅ [Repo] Migration already completed (cached)');
        return const Right(false); // マイグレーション不要
      }
      
      // Amberモード判定
      final isAmberMode = _localStorageService.isUsingAmber();
      
      if (isAmberMode) {
        // Amberモード: 暗号化されたKind 30078イベントを取得
        AppLogger.debug('[Repo] Checking for old Kind 30078 events (Amber mode)...');
        final encryptedTodos = await _nostrService.fetchEncryptedTodos();
        
        // Kind 30078のTODOイベント（d="todo-*"）が存在する場合のみマイグレーション必要
        if (encryptedTodos.isNotEmpty) {
          AppLogger.info('⚠️ [Repo] Found ${encryptedTodos.length} old Kind 30078 TODO events (Amber mode)');
          return const Right(true); // マイグレーション必要
        }
      } else {
        // 通常モード: 旧実装（Kind 30078）は削除済み
        AppLogger.debug('[Repo] Normal mode - old Kind 30078 implementation removed');
        return const Right(false); // マイグレーション不要
      }
      
      AppLogger.info('✅ [Repo] No old Kind 30078 TODO events found');
      return const Right(false);
    } catch (e, stackTrace) {
      AppLogger.warning('⚠️ [Repo] Failed to check migration: $e');
      AppLogger.error('[Repo] Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      // エラーでもfalseを返す（マイグレーション不要として扱う）
      return const Right(false);
    }
  }
  
  @override
  Future<Either<Failure, List<Todo>>> fetchOldTodosFromKind30078({
    required String publicKey,
  }) async {
    try {
      AppLogger.info('🔍 [Repo] Fetching old Kind 30078 todos for migration...');
      
      final isAmberMode = _localStorageService.isUsingAmber();
      
      if (!isAmberMode) {
        // 通常モード: 旧実装は削除済み
        AppLogger.info('ℹ️ [Repo] Normal mode - old Kind 30078 implementation removed');
        return const Right([]);
      }
      
      // Amberモード: 暗号化されたKind 30078イベントを取得
      AppLogger.debug('[Repo] Fetching encrypted Kind 30078 events...');
      final encryptedTodos = await _nostrService.fetchEncryptedTodos();
      
      if (encryptedTodos.isEmpty) {
        AppLogger.info('ℹ️ [Repo] No Kind 30078 events found');
        return const Right([]);
      }
      
      AppLogger.debug('[Repo] Found ${encryptedTodos.length} encrypted Kind 30078 events');
      
      // Amberで復号化
      final List<Todo> oldTodos = [];
      
      for (final encryptedTodo in encryptedTodos) {
        try {
          final decryptedJson = await _amberService.decryptNip44(
            encryptedTodo.encryptedContent,
            publicKey,
          );
          
          final todoMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
          oldTodos.add(Todo(
            id: todoMap['id'] as String,
            title: todoMap['title'] as String,
            completed: todoMap['completed'] as bool,
            date: todoMap['date'] != null 
                ? DateTime.parse(todoMap['date'] as String)
                : null,
            order: todoMap['order'] as int,
            createdAt: DateTime.parse(todoMap['created_at'] as String),
            updatedAt: DateTime.parse(todoMap['updated_at'] as String),
            eventId: encryptedTodo.eventId,
            linkPreview: todoMap['link_preview'] != null
                ? LinkPreview.fromJson(todoMap['link_preview'] as Map<String, dynamic>)
                : null,
          ));
          AppLogger.debug('[Repo] Decrypted todo: ${todoMap['title']}');
        } catch (e) {
          AppLogger.warning('[Repo] Failed to decrypt/parse event ${encryptedTodo.eventId}: $e');
        }
      }
      
      AppLogger.info('✅ [Repo] Successfully fetched ${oldTodos.length} todos from Kind 30078');
      return Right(oldTodos);
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to fetch old todos', error: e, stackTrace: stackTrace);
      return Left(NetworkFailure('旧Todoの取得に失敗しました: $e'));
    }
  }
  
  @override
  Future<Either<Failure, void>> migrateFromKind30078ToKind30001() async {
    try {
      AppLogger.info('🔄 [Repo] Migrating from Kind 30078 to Kind 30001...');
      
      // TODO: Phase C.2.2で実装
      // 完全なマイグレーション処理:
      // 1. fetchOldTodosFromKind30078()で旧データ取得
      // 2. syncPersonalTodosToNostr()で新形式送信
      // 3. NostrService.deleteEvents()で旧イベント削除
      // 4. LocalStorageService.setMigrationCompleted()でフラグ保存
      
      return Left(UnexpectedFailure('Not implemented yet - Phase C.2.2'));
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Repo] Failed to migrate', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('マイグレーションに失敗しました: $e'));
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
