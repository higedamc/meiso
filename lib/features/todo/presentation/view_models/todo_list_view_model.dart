import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/common/usecase.dart';
import '../../../../services/logger_service.dart';
import '../../application/usecases/create_todo_usecase.dart';
import '../../application/usecases/delete_todo_usecase.dart';
import '../../application/usecases/get_all_todos_usecase.dart';
import '../../application/usecases/move_todo_usecase.dart';
import '../../application/usecases/reorder_todo_usecase.dart';
import '../../application/usecases/sync_from_nostr_usecase.dart';
import '../../application/usecases/toggle_todo_usecase.dart';
import '../../application/usecases/update_todo_usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/value_objects/todo_date.dart';
import 'todo_list_state.dart';

/// TodoリストのViewModel (StateNotifier)
///
/// UseCaseを使用してTodoリストの状態を管理する
class TodoListViewModel extends StateNotifier<TodoListState> {
  TodoListViewModel({
    required GetAllTodosUseCase getAllTodosUseCase,
    required CreateTodoUseCase createTodoUseCase,
    required UpdateTodoUseCase updateTodoUseCase,
    required DeleteTodoUseCase deleteTodoUseCase,
    required ToggleTodoUseCase toggleTodoUseCase,
    required ReorderTodoUseCase reorderTodoUseCase,
    required MoveTodoUseCase moveTodoUseCase,
    required SyncFromNostrUseCase syncFromNostrUseCase,
    bool autoLoad = true,
  })  : _getAllTodosUseCase = getAllTodosUseCase,
        _createTodoUseCase = createTodoUseCase,
        _updateTodoUseCase = updateTodoUseCase,
        _deleteTodoUseCase = deleteTodoUseCase,
        _toggleTodoUseCase = toggleTodoUseCase,
        _reorderTodoUseCase = reorderTodoUseCase,
        _moveTodoUseCase = moveTodoUseCase,
        _syncFromNostrUseCase = syncFromNostrUseCase,
        super(const TodoListState.initial()) {
    if (autoLoad) {
      _initialize();
    }
  }
  
  /// 初期化処理
  Future<void> _initialize() async {
    // Todoリストを読み込み
    await loadTodos();
    
    // 自動バッチ同期タイマーを開始（30秒ごと）
    _startBatchSyncTimer();
  }
  
  /// 自動バッチ同期タイマーを開始（30秒ごと）
  void _startBatchSyncTimer() {
    AppLogger.debug('[TodoListViewModel] バッチ同期タイマー起動（30秒ごと）');
    
    // 既存のタイマーをキャンセル
    _batchSyncTimer?.cancel();
    
    // 30秒ごとに実行
    _batchSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _executeBatchSync();
    });
  }
  
  /// バッチ同期を実行
  Future<void> _executeBatchSync() async {
    AppLogger.info('[TodoListViewModel] バッチ同期実行中...');
    
    // バックグラウンドで同期（UIをブロックしない）
    syncFromNostr();
  }
  
  @override
  void dispose() {
    AppLogger.debug('[TodoListViewModel] dispose: バッチ同期タイマーをキャンセル');
    _batchSyncTimer?.cancel();
    super.dispose();
  }

  final GetAllTodosUseCase _getAllTodosUseCase;
  final CreateTodoUseCase _createTodoUseCase;
  final UpdateTodoUseCase _updateTodoUseCase;
  final DeleteTodoUseCase _deleteTodoUseCase;
  final ToggleTodoUseCase _toggleTodoUseCase;
  final ReorderTodoUseCase _reorderTodoUseCase;
  final MoveTodoUseCase _moveTodoUseCase;
  final SyncFromNostrUseCase _syncFromNostrUseCase;
  
  // バッチ同期用のタイマー
  Timer? _batchSyncTimer;

  /// Todoリストを読み込む
  Future<void> loadTodos() async {
    state = const TodoListState.loading();

    final result = await _getAllTodosUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todoリスト読み込みエラー: ${failure.message}');
        state = TodoListState.error(failure);
      },
      (todos) {
        AppLogger.info('[TodoListNotifier] ${todos.length}件のTodoを読み込み');
        final grouped = _groupTodosByDate(todos);
        state = TodoListState.loaded(groupedTodos: grouped);
      },
    );
  }

  /// Todoを作成
  Future<void> createTodo({
    required String title,
    TodoDate? date,
    String? customListId,
    int? order,
  }) async {
    final params = CreateTodoParams(
      title: title,
      date: date,
      customListId: customListId,
      order: order,
    );

    final result = await _createTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todo作成エラー: ${failure.message}');
        // エラーをStateに反映（必要に応じて）
      },
      (todo) {
        AppLogger.info('[TodoListNotifier] Todo作成成功: ${todo.id}');
        // リストを再読み込み
        loadTodos();
      },
    );
  }

  /// Todoを更新
  Future<void> updateTodo({
    required String todoId,
    String? title,
    bool? completed,
    TodoDate? date,
    String? customListId,
    int? order,
  }) async {
    final params = UpdateTodoParams(
      todoId: todoId,
      title: title,
      completed: completed,
      date: date,
      customListId: customListId,
      order: order,
    );

    final result = await _updateTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todo更新エラー: ${failure.message}');
      },
      (todo) {
        AppLogger.info('[TodoListNotifier] Todo更新成功: ${todo.id}');
        loadTodos();
      },
    );
  }

  /// Todoを削除
  Future<void> deleteTodo(String todoId) async {
    final params = DeleteTodoParams(todoId: todoId);

    final result = await _deleteTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todo削除エラー: ${failure.message}');
      },
      (_) {
        AppLogger.info('[TodoListNotifier] Todo削除成功: $todoId');
        loadTodos();
      },
    );
  }

  /// Todoの完了状態をトグル
  Future<void> toggleTodo(String todoId) async {
    final params = ToggleTodoParams(todoId: todoId);

    final result = await _toggleTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todoトグルエラー: ${failure.message}');
      },
      (todo) {
        AppLogger.info('[TodoListNotifier] Todoトグル成功: ${todo.id} -> ${todo.completed}');
        loadTodos();
      },
    );
  }

  /// Todoを並び替え
  Future<void> reorderTodo({
    required String todoId,
    required int newOrder,
  }) async {
    final params = ReorderTodoParams(
      todoId: todoId,
      newOrder: newOrder,
    );

    final result = await _reorderTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todo並び替えエラー: ${failure.message}');
      },
      (todo) {
        AppLogger.info('[TodoListNotifier] Todo並び替え成功: ${todo.id} -> order ${todo.order}');
        loadTodos();
      },
    );
  }

  /// Todoを移動
  Future<void> moveTodo({
    required String todoId,
    TodoDate? newDate,
    String? newCustomListId,
    int? newOrder,
  }) async {
    final params = MoveTodoParams(
      todoId: todoId,
      newDate: newDate,
      newCustomListId: newCustomListId,
      newOrder: newOrder,
    );

    final result = await _moveTodoUseCase(params);

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Todo移動エラー: ${failure.message}');
      },
      (todo) {
        AppLogger.info('[TodoListNotifier] Todo移動成功: ${todo.id}');
        loadTodos();
      },
    );
  }

  /// Nostrから同期
  Future<void> syncFromNostr() async {
    final result = await _syncFromNostrUseCase(const NoParams());

    result.fold(
      (failure) {
        AppLogger.error('[TodoListNotifier] Nostr同期エラー: ${failure.message}');
      },
      (todos) {
        AppLogger.info('[TodoListNotifier] Nostr同期成功: ${todos.length}件');
        loadTodos();
      },
    );
  }

  /// Todoリストを日付ごとにグループ化
  Map<DateTime?, List<Todo>> _groupTodosByDate(List<Todo> todos) {
    final Map<DateTime?, List<Todo>> grouped = {};

    for (final todo in todos) {
      final date = todo.date?.value;
      grouped[date] ??= [];
      grouped[date]!.add(todo);
    }

    // 各日付のリストをorder順にソート
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
    }

    return grouped;
  }
}

