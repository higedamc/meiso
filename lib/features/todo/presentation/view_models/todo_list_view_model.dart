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

  /// 初期化処理
  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localTodos = await localStorageService.loadTodos();
      
      final hasLocalData = localTodos.isNotEmpty;
      
      if (hasLocalData) {
        // ローカルデータがある場合：即座に表示
        final grouped = <DateTime?, List<Todo>>{};
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
        
        // 🔥 FIX: 初期化時の自動同期を無効化
        // 理由: タイトル更新直後に再初期化されると、古いデータで上書きされてしまう。
        // 同期はTodosProviderのバッチ同期タイマーで行われる。
        // if (_ref.read(nostrInitializedProvider)) {
        //   AppLogger.debug('[TodoListViewModel] Nostr初期化済み。バックグラウンド同期を開始');
        //   _backgroundSync();
        // }
      } else {
        // ローカルデータがない場合：空の状態
        AppLogger.info('[TodoListViewModel] ローカルデータなし');
        state = const TodoListState.loaded(groupedTodos: {});
        
        // 🔥 FIX: 初期化時の自動同期を無効化
        // 理由: タイトル更新直後に再初期化されると、古いデータで上書きされてしまう。
        // 同期はTodosProviderのバッチ同期タイマーで行われる。
        // if (_ref.read(nostrInitializedProvider)) {
        //   AppLogger.debug('[TodoListViewModel] Nostr初期化済み。優先同期を開始');
        //   _prioritySync();
        // }
      }
      
      // 🔥 FIX: 自動バッチ同期タイマーを無効化
      // 理由: TodosProviderの5秒タイマーで送信処理は行われている。
      // 30秒ごとの受信処理は、送信完了前に古いデータで上書きしてしまう競合を引き起こす。
      // 受信は手動同期（Pull-to-refresh）のみで十分。
    } catch (e, stackTrace) {
      AppLogger.error('[TodoListViewModel] 初期化エラー', error: e, stackTrace: stackTrace);
      state = TodoListState.error(message: e.toString());
    }
  }

  // 🔥 FIX: 自動同期関連のメソッドを削除
  // 理由: TodosProviderの5秒バッチ同期タイマーと競合し、
  // タイトル更新後に古いデータで上書きしてしまう問題が発生していました。
  // 受信は手動同期（Pull-to-refresh: syncFromNostr()を直接呼び出し）で行います。
  // 
  // 削除したメソッド:
  // - _startBatchSyncTimer() - 30秒ごとの自動同期タイマー
  // - _executeBatchSync() - バッチ同期実行
  // - _backgroundSync() - 初期化時のバックグラウンド同期
  // - _prioritySync() - 初期化時の優先同期

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
      
      final grouped = <DateTime?, List<Todo>>{};
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
    AppLogger.debug('[TodoListViewModel] dispose');
    super.dispose();
  }
}

