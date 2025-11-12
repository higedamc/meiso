import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/usecases/create_todo_usecase.dart';
import '../../application/usecases/delete_todo_usecase.dart';
import '../../application/usecases/get_all_todos_usecase.dart';
import '../../application/usecases/get_todo_by_id_usecase.dart';
import '../../application/usecases/get_todos_by_date_usecase.dart';
import '../../application/usecases/get_todos_by_list_usecase.dart';
import '../../application/usecases/move_todo_usecase.dart';
import '../../application/usecases/reorder_todo_usecase.dart';
import '../../application/usecases/sync_from_nostr_usecase.dart';
import '../../application/usecases/sync_to_nostr_usecase.dart';
import '../../application/usecases/toggle_todo_usecase.dart';
import '../../application/usecases/update_todo_usecase.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../infrastructure/datasources/todo_local_datasource.dart';
import '../../infrastructure/datasources/todo_remote_datasource.dart';
import '../../infrastructure/repositories/todo_repository_impl.dart';
import '../state/todo_list_notifier.dart';
import '../state/todo_list_state.dart';

// ============================================================================
// Infrastructure Layer: DataSources
// ============================================================================

/// Hive初期化を管理するProvider
///
/// TodoLocalDataSourceを使用する前に、このProviderでHive初期化を待つ
final todoLocalDataSourceInitializerProvider = FutureProvider<void>((ref) async {
  final dataSource = ref.watch(_todoLocalDataSourceInstanceProvider);
  if (dataSource is TodoLocalDataSourceHive) {
    await dataSource.initialize();
  }
});

/// ローカルデータソースのインスタンスProvider（内部用）
final _todoLocalDataSourceInstanceProvider = Provider<TodoLocalDataSource>((ref) {
  return TodoLocalDataSourceHive(boxName: 'todos');
});

/// ローカルデータソースのProvider
///
/// Hive初期化を待ってからDataSourceを返す
final todoLocalDataSourceProvider = Provider<TodoLocalDataSource>((ref) {
  // 初期化を監視（エラー時は例外をスロー）
  ref.watch(todoLocalDataSourceInitializerProvider).when(
        data: (_) {},
        loading: () {},
        error: (error, stack) => throw error,
      );
  
  return ref.watch(_todoLocalDataSourceInstanceProvider);
});

/// リモートデータソースのProvider
final todoRemoteDataSourceProvider = Provider<TodoRemoteDataSource>((ref) {
  return TodoRemoteDataSourceNostr();
});

// ============================================================================
// Infrastructure Layer: Repository
// ============================================================================

/// TodoRepositoryのProvider
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final localDataSource = ref.watch(todoLocalDataSourceProvider);
  final remoteDataSource = ref.watch(todoRemoteDataSourceProvider);
  return TodoRepositoryImpl(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
  );
});

// ============================================================================
// Application Layer: UseCases
// ============================================================================

// --- CRUD UseCases ---

/// CreateTodoUseCaseのProvider
final createTodoUseCaseProvider = Provider<CreateTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return CreateTodoUseCase(repository);
});

/// GetAllTodosUseCaseのProvider
final getAllTodosUseCaseProvider = Provider<GetAllTodosUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return GetAllTodosUseCase(repository);
});

/// GetTodoByIdUseCaseのProvider
final getTodoByIdUseCaseProvider = Provider<GetTodoByIdUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return GetTodoByIdUseCase(repository);
});

/// UpdateTodoUseCaseのProvider
final updateTodoUseCaseProvider = Provider<UpdateTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return UpdateTodoUseCase(repository);
});

/// DeleteTodoUseCaseのProvider
final deleteTodoUseCaseProvider = Provider<DeleteTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return DeleteTodoUseCase(repository);
});

// --- Todo操作 UseCases ---

/// ToggleTodoUseCaseのProvider
final toggleTodoUseCaseProvider = Provider<ToggleTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return ToggleTodoUseCase(repository);
});

/// ReorderTodoUseCaseのProvider
final reorderTodoUseCaseProvider = Provider<ReorderTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return ReorderTodoUseCase(repository);
});

/// MoveTodoUseCaseのProvider
final moveTodoUseCaseProvider = Provider<MoveTodoUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return MoveTodoUseCase(repository);
});

// --- 同期・フィルタリング UseCases ---

/// SyncFromNostrUseCaseのProvider
final syncFromNostrUseCaseProvider = Provider<SyncFromNostrUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return SyncFromNostrUseCase(repository);
});

/// SyncToNostrUseCaseのProvider
final syncToNostrUseCaseProvider = Provider<SyncToNostrUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return SyncToNostrUseCase(repository);
});

/// GetTodosByDateUseCaseのProvider
final getTodosByDateUseCaseProvider = Provider<GetTodosByDateUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return GetTodosByDateUseCase(repository);
});

/// GetTodosByListUseCaseのProvider
final getTodosByListUseCaseProvider = Provider<GetTodosByListUseCase>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return GetTodosByListUseCase(repository);
});

// ============================================================================
// Presentation Layer: StateNotifier
// ============================================================================

/// TodoリストのStateNotifierProvider
///
/// アプリ全体のTodoリストの状態を管理する
/// 
/// ⚠️ 注意: Hive初期化を待ってから使用してください
/// 使用前に `todoLocalDataSourceInitializerProvider` が完了していることを確認
final todoListNotifierProvider =
    StateNotifierProvider<TodoListNotifier, TodoListState>((ref) {
  // Hive初期化が完了するまで待つ
  final initState = ref.watch(todoLocalDataSourceInitializerProvider);
  
  // 初期化中はautoLoad=falseで作成
  final autoLoad = initState.maybeWhen(
    data: (_) => true,
    orElse: () => false,
  );
  
  return TodoListNotifier(
    getAllTodosUseCase: ref.watch(getAllTodosUseCaseProvider),
    createTodoUseCase: ref.watch(createTodoUseCaseProvider),
    updateTodoUseCase: ref.watch(updateTodoUseCaseProvider),
    deleteTodoUseCase: ref.watch(deleteTodoUseCaseProvider),
    toggleTodoUseCase: ref.watch(toggleTodoUseCaseProvider),
    reorderTodoUseCase: ref.watch(reorderTodoUseCaseProvider),
    moveTodoUseCase: ref.watch(moveTodoUseCaseProvider),
    syncFromNostrUseCase: ref.watch(syncFromNostrUseCaseProvider),
    autoLoad: autoLoad,
  );
});

