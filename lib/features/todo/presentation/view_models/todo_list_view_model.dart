import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/todo.dart';
import '../../../../providers/nostr_provider.dart';
import '../../../../providers/todos_provider.dart' as old;
import '../../../../services/local_storage_service.dart';
import '../../../../services/logger_service.dart';
import 'todo_list_state.dart';

/// TodoリストのViewModel（旧TodosNotifierと同等の機能）
class TodoListViewModel extends StateNotifier<TodoListState> {
  TodoListViewModel(
    this._ref, {
    bool autoLoad = true,
  }) : super(const TodoListState.initial()) {
    if (autoLoad) {
      _initialize();
    }
  }

  final Ref _ref;
  
  // バッチ同期用のタイマー
  Timer? _batchSyncTimer;

  /// 初期化処理
  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localTodos = await localStorageService.loadTodos();
      
      final hasLocalData = localTodos.isNotEmpty;
      
      if (hasLocalData) {
        // ローカルデータがある場合：即座に表示
        final Map<DateTime?, List<Todo>> grouped = {};
        for (final todo in localTodos) {
          grouped[todo.date] ??= [];
          grouped[todo.date]!.add(todo);
        }
        
        // 各日付のリストをorder順にソート
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
        }
        
        AppLogger.info('[TodoListViewModel] ローカルから${localTodos.length}件のタスクを読み込み');
        state = TodoListState.loaded(groupedTodos: grouped);
        
        // ログイン済みの場合のみバックグラウンド同期
        if (_ref.read(nostrInitializedProvider)) {
          AppLogger.debug('[TodoListViewModel] Nostr初期化済み。バックグラウンド同期を開始');
          _backgroundSync();
        }
      } else {
        // ローカルデータがない場合：空の状態
        AppLogger.info('[TodoListViewModel] ローカルデータなし');
        state = const TodoListState.loaded(groupedTodos: {});
        
        // ログイン済みの場合のみ優先同期
        if (_ref.read(nostrInitializedProvider)) {
          AppLogger.debug('[TodoListViewModel] Nostr初期化済み。優先同期を開始');
          _prioritySync();
        }
      }
      
      // 自動バッチ同期タイマーを開始（30秒ごと）
      _startBatchSyncTimer();
    } catch (e, stackTrace) {
      AppLogger.error('[TodoListViewModel] 初期化エラー', error: e, stackTrace: stackTrace);
      state = TodoListState.error(message: e.toString());
    }
  }

  /// 自動バッチ同期タイマーを開始（30秒ごと）
  void _startBatchSyncTimer() {
    AppLogger.debug('[TodoListViewModel] バッチ同期タイマー起動（30秒ごと）');
    _batchSyncTimer?.cancel();
    _batchSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _executeBatchSync();
    });
  }

  /// バッチ同期を実行
  Future<void> _executeBatchSync() async {
    AppLogger.info('[TodoListViewModel] バッチ同期実行中...');
    await syncFromNostr();
  }

  /// バックグラウンド同期
  Future<void> _backgroundSync() async {
    try {
      await syncFromNostr();
    } catch (e) {
      AppLogger.error('[TodoListViewModel] バックグラウンド同期エラー', error: e);
    }
  }

  /// 優先同期
  Future<void> _prioritySync() async {
    try {
      await syncFromNostr();
    } catch (e) {
      AppLogger.error('[TodoListViewModel] 優先同期エラー', error: e);
    }
  }

  /// Nostrから同期（旧実装を踏襲）
  Future<void> syncFromNostr() async {
    try {
      if (!_ref.read(nostrInitializedProvider)) {
        AppLogger.warning('[TodoListViewModel] Nostr未初期化のため同期をスキップ');
        return;
      }

      AppLogger.info('[TodoListViewModel] Nostr同期開始');
      
      // 旧実装の syncFromNostr ロジックを呼び出し
      // TODO: この部分は旧Providerに委譲
      final oldProvider = _ref.read(old.todosProvider.notifier);
      await oldProvider.syncFromNostr();
      
      // 同期後にローカルから再読み込み
      await loadTodos();
      
      AppLogger.info('[TodoListViewModel] Nostr同期完了');
    } catch (e, stackTrace) {
      AppLogger.error('[TodoListViewModel] Nostr同期エラー', error: e, stackTrace: stackTrace);
    }
  }

  /// Todoリストを読み込み
  Future<void> loadTodos() async {
    try {
      final localTodos = await localStorageService.loadTodos();
      
      final Map<DateTime?, List<Todo>> grouped = {};
      for (final todo in localTodos) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }
      
      // 各日付のリストをorder順にソート
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }
      
      state = TodoListState.loaded(groupedTodos: grouped);
    } catch (e, stackTrace) {
      AppLogger.error('[TodoListViewModel] Todoリスト読み込みエラー', error: e, stackTrace: stackTrace);
      state = TodoListState.error(message: e.toString());
    }
  }

  @override
  void dispose() {
    AppLogger.debug('[TodoListViewModel] dispose: バッチ同期タイマーをキャンセル');
    _batchSyncTimer?.cancel();
    super.dispose();
  }
}

