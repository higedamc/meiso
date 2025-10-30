import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';
import '../services/local_storage_service.dart';
import '../services/amber_service.dart';
import 'nostr_provider.dart';
import 'sync_status_provider.dart';

// Amberモード判定のためのインポート
export 'nostr_provider.dart' show isAmberModeProvider;

/// AmberServiceのProvider
final amberServiceProvider = Provider((ref) => AmberService());

/// 日付ごとにグループ化されたTodoリストを管理するProvider
/// 
/// Map<DateTime?, List<Todo>>:
/// - null キー: Someday
/// - DateTime: 特定の日付
final todosProvider =
    StateNotifierProvider<TodosNotifier, AsyncValue<Map<DateTime?, List<Todo>>>>(
  (ref) => TodosNotifier(ref),
);

class TodosNotifier extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>> {
  TodosNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref _ref;
  final _uuid = const Uuid();

  Future<void> _initialize() async {
    try {
      // ローカルストレージから読み込み
      final localTodos = await localStorageService.loadTodos();
      
      if (localTodos.isEmpty) {
        // 初回起動時のみダミーデータを作成
        await _createInitialDummyData();
      } else {
        // ローカルデータをグループ化して状態に設定
        final Map<DateTime?, List<Todo>> grouped = {};
        for (final todo in localTodos) {
          grouped[todo.date] ??= [];
          grouped[todo.date]!.add(todo);
        }
        
        // 各日付のリストをorder順にソート
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
        }
        
        state = AsyncValue.data(grouped);
      }
      
      // Nostr同期は非同期で実行（初期化をブロックしない）
      _backgroundSync();
      
    } catch (e) {
      print('⚠️ Todo初期化エラー: $e');
      // エラー時でもダミーデータで初期化（UIを表示）
      try {
        await _createInitialDummyData();
      } catch (e2) {
        print('⚠️ ダミーデータ作成も失敗: $e2');
        // 最終フォールバック: 空のマップで初期化
        state = AsyncValue.data({});
      }
    }
  }
  
  /// バックグラウンド同期（UIブロックしない）
  Future<void> _backgroundSync() async {
    // 画面表示後に実行
    await Future.delayed(const Duration(seconds: 1));
    
    if (_ref.read(nostrInitializedProvider)) {
      try {
        print('🔄 Starting background Nostr sync...');
        await syncFromNostr();
        print('✅ Background sync completed');
      } catch (e) {
        print('⚠️ バックグラウンド同期失敗: $e');
        // エラーは無視（ローカルデータで継続）
      }
    } else {
      print('ℹ️ Nostr not initialized - skipping background sync');
    }
  }

  /// 初回起動時のダミーデータを作成
  Future<void> _createInitialDummyData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    final initialTodos = [
      Todo(
        id: _uuid.v4(),
        title: 'Nostr統合を完了する',
        completed: false,
        date: today,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'UI/UXを改善する',
        completed: false,
        date: today,
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'Amber統合をテストする',
        completed: false,
        date: tomorrow,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: 'リカーリングタスクを実装する',
        completed: false,
        date: null,
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    
    // ローカルストレージに保存
    await localStorageService.saveTodos(initialTodos);
    
    // 状態に反映
    state = AsyncValue.data({
      today: [initialTodos[0], initialTodos[1]],
      tomorrow: [initialTodos[2]],
      null: [initialTodos[3]],
    });
  }

  /// 新しいTodoを追加
  Future<void> addTodo(String title, DateTime? date) async {
    if (title.trim().isEmpty) return;

    state.whenData((todos) async {
      final now = DateTime.now();
      final newTodo = Todo(
        id: _uuid.v4(),
        title: title.trim(),
        completed: false,
        date: date,
        order: _getNextOrder(todos, date),
        createdAt: now,
        updatedAt: now,
      );

      final list = List<Todo>.from(todos[date] ?? []);
      list.add(newTodo);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final isAmberMode = _ref.read(isAmberModeProvider);
        final nostrService = _ref.read(nostrServiceProvider);
        
        if (isAmberMode) {
          // Amberモード: 未署名イベント → Amber署名 → リレー送信
          print('🔐 Creating Todo with Amber signature...');
          
          // 1. 未署名イベントを作成
          final unsignedEvent = await nostrService.createUnsignedTodoEvent(newTodo);
          print('📝 Unsigned event created');
          
          // 2. Amberで署名
          final amberService = _ref.read(amberServiceProvider);
          final signedEvent = await amberService.signEventWithTimeout(unsignedEvent);
          print('✍️ Event signed by Amber');
          
          // 3. 署名済みイベントをリレーに送信
          final eventId = await nostrService.sendSignedEvent(signedEvent);
          print('📤 Signed event sent to relays: $eventId');
          
          // eventIdをTodoに設定して状態を更新
          _updateTodoEventId(newTodo.id, date, eventId);
        } else {
          // 通常モード: 秘密鍵で署名
          final eventId = await nostrService.createTodoOnNostr(newTodo);
          
          // eventIdをTodoに設定して状態を更新
          _updateTodoEventId(newTodo.id, date, eventId);
        }
      });
    });
  }

  /// Nostrから取得したTodoを追加（既存データを保持）
  Future<void> addTodoWithData(Todo todo) async {
    state.whenData((todos) {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      
      // 同じIDが存在しないことを確認
      if (!list.any((t) => t.id == todo.id)) {
        list.add(todo);
        
        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });
      }
    });
  }

  /// ローカルのeventIdがないTodoをNostrに送信
  Future<void> uploadPendingTodos() async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のためアップロードをスキップ');
      return;
    }

    await state.whenData((todos) async {
      final nostrService = _ref.read(nostrServiceProvider);
      int uploadCount = 0;

      for (final dateGroup in todos.entries) {
        final date = dateGroup.key;
        final list = List<Todo>.from(dateGroup.value);

        for (int i = 0; i < list.length; i++) {
          final todo = list[i];
          
          // eventIdがないTodoを送信
          if (todo.eventId == null) {
            try {
              final eventId = await nostrService.createTodoOnNostr(todo);
              list[i] = todo.copyWith(eventId: eventId);
              uploadCount++;
              print('✅ Todoをアップロード: ${todo.title}');
            } catch (e) {
              print('⚠️ Todoアップロード失敗 (${todo.title}): $e');
            }
          }
        }

        // 更新された日付グループを反映
        todos[date] = list;
      }

      if (uploadCount > 0) {
        state = AsyncValue.data(Map.from(todos));
        await _saveAllTodosToLocal();
        print('✅ ${uploadCount}件のTodoをアップロードしました');
      } else {
        print('ℹ️ アップロードが必要なTodoはありません');
      }
    });
  }

  /// NostrからのTodoをローカルとマージ（スマートマージ）
  /// updatedAtが新しい方を優先
  Future<void> mergeTodosFromNostr(List<Todo> nostrTodos) async {
    state.whenData((localTodos) async {
      final Map<String, Todo> mergedMap = {};
      
      // ローカルのTodoをマップに追加
      for (final dateGroup in localTodos.values) {
        for (final todo in dateGroup) {
          mergedMap[todo.id] = todo;
        }
      }
      
      // NostrのTodoをマージ（新しい方を優先）
      for (final nostrTodo in nostrTodos) {
        final localTodo = mergedMap[nostrTodo.id];
        
        if (localTodo == null) {
          // ローカルに存在しない → 追加
          mergedMap[nostrTodo.id] = nostrTodo;
        } else {
          // 両方に存在 → 新しい方を採用
          if (nostrTodo.updatedAt.isAfter(localTodo.updatedAt)) {
            mergedMap[nostrTodo.id] = nostrTodo;
          }
          // localの方が新しい場合はそのまま
        }
      }
      
      // 日付ごとにグループ化
      final Map<DateTime?, List<Todo>> grouped = {};
      for (final todo in mergedMap.values) {
        grouped[todo.date] ??= [];
        grouped[todo.date]!.add(todo);
      }
      
      // 各日付のリストをorder順にソート
      for (final key in grouped.keys) {
        grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
      }
      
      state = AsyncValue.data(grouped);
      
      // ローカルストレージに保存
      await _saveAllTodosToLocal();
    });
  }

  /// Todoを更新
  Future<void> updateTodo(Todo todo) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[todo.date] ?? []);
      final index = list.indexWhere((t) => t.id == todo.id);

      if (index != -1) {
        list[index] = todo.copyWith(updatedAt: DateTime.now());
        state = AsyncValue.data({
          ...todos,
          todo.date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final eventId = await _syncTodoWithMode(list[index]);
          _updateTodoEventId(todo.id, todo.date, eventId);
        });
      }
    });
  }

  /// Todoのタイトルを更新
  Future<void> updateTodoTitle(String id, DateTime? date, String newTitle) async {
    if (newTitle.trim().isEmpty) return;

    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        list[index] = list[index].copyWith(
          title: newTitle.trim(),
          updatedAt: DateTime.now(),
        );
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final eventId = await _syncTodoWithMode(list[index]);
          _updateTodoEventId(id, date, eventId);
        });
      }
    });
  }

  /// Todoの完了状態をトグル
  Future<void> toggleTodo(String id, DateTime? date) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == id);

      if (index != -1) {
        final todo = list[index];
        list[index] = todo.copyWith(
          completed: !todo.completed,
          updatedAt: DateTime.now(),
        );

        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();

        // Nostr側に送信（バックグラウンド実行）
        _syncToNostr(() async {
          final eventId = await _syncTodoWithMode(list[index]);
          _updateTodoEventId(id, date, eventId);
        });
      }
    });
  }

  /// Todoを削除
  Future<void> deleteTodo(String id, DateTime? date) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      list.removeWhere((t) => t.id == id);

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final nostrService = _ref.read(nostrServiceProvider);
        await nostrService.deleteTodoOnNostr(id);
      });
    });
  }

  /// Todoを並び替え
  Future<void> reorderTodo(
    DateTime? date,
    int oldIndex,
    int newIndex,
  ) async {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      // orderを再計算
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
      }

      state = AsyncValue.data({
        ...todos,
        date: list,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        for (final todo in list) {
          final eventId = await _syncTodoWithMode(todo);
          _updateTodoEventId(todo.id, date, eventId);
        }
      });
    });
  }

  /// Todoを別の日付に移動
  Future<void> moveTodo(String id, DateTime? fromDate, DateTime? toDate) async {
    if (fromDate == toDate) return;

    state.whenData((todos) async {
      final fromList = List<Todo>.from(todos[fromDate] ?? []);
      final toList = List<Todo>.from(todos[toDate] ?? []);

      final todoIndex = fromList.indexWhere((t) => t.id == id);
      if (todoIndex == -1) return;

      final todo = fromList.removeAt(todoIndex);
      final movedTodo = todo.copyWith(
        date: toDate,
        order: _getNextOrder({toDate: toList}, toDate),
        updatedAt: DateTime.now(),
      );
      toList.add(movedTodo);

      state = AsyncValue.data({
        ...todos,
        fromDate: fromList,
        toDate: toList,
      });

      // ローカルストレージに保存
      await _saveAllTodosToLocal();

      // Nostr側に送信（バックグラウンド実行）
      _syncToNostr(() async {
        final eventId = await _syncTodoWithMode(movedTodo);
        _updateTodoEventId(movedTodo.id, toDate, eventId);
      });
    });
  }

  /// 次の order 値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) return 0;
    return list.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Todo同期の共通処理（Amberモード対応・暗号化対応）
  Future<String> _syncTodoWithMode(Todo todo) async {
    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);
    
    if (isAmberMode) {
      // Amberモード（NIP-44暗号化対応）:
      // TodoJSON → Amber暗号化 → 未署名暗号化イベント → Amber署名 → リレー送信
      print('🔐 Amber暗号化モードでTodoを同期します');
      
      // 1. TodoをJSONに変換
      final todoJson = jsonEncode({
        'id': todo.id,
        'title': todo.title,
        'completed': todo.completed,
        'date': todo.date?.toIso8601String(),
        'order': todo.order,
        'createdAt': todo.createdAt.toIso8601String(),
        'updatedAt': todo.updatedAt.toIso8601String(),
        'eventId': todo.eventId,
      });
      
      print('📝 Todo JSON (${todoJson.length} bytes): ${todoJson.substring(0, 50.clamp(0, todoJson.length))}...');
      
      // 2. 公開鍵を取得（自分自身の公開鍵で暗号化）
      final publicKey = _ref.read(publicKeyProvider);
      if (publicKey == null) {
        throw Exception('公開鍵が設定されていません');
      }
      
      // 3. AmberでNIP-44暗号化
      final amberService = _ref.read(amberServiceProvider);
      print('🔐 Amberで暗号化中...');
      final encryptedContent = await amberService.encryptNip44(todoJson, publicKey);
      print('✅ 暗号化完了 (${encryptedContent.length} bytes)');
      
      // 4. 暗号化済みcontentで未署名イベントを作成
      final unsignedEvent = await nostrService.createUnsignedEncryptedTodoEvent(
        todoId: todo.id,
        encryptedContent: encryptedContent,
      );
      print('📄 未署名イベント作成完了');
      
      // 5. Amberで署名
      print('✍️ Amberで署名中...');
      final signedEvent = await amberService.signEventWithTimeout(unsignedEvent);
      print('✅ 署名完了');
      
      // 6. リレーに送信
      print('📤 リレーに送信中...');
      final eventId = await nostrService.sendSignedEvent(signedEvent);
      print('✅ 送信完了: $eventId');
      
      return eventId;
    } else {
      // 通常モード: 秘密鍵で署名（Rust側でNIP-44暗号化）
      return await nostrService.updateTodoOnNostr(todo);
    }
  }

  /// Nostrへの同期処理（リトライ機能付き）
  /// Amberモード時はAmber署名フローを使用
  Future<void> _syncToNostr(Future<void> Function() syncFunction) async {
    if (!_ref.read(nostrInitializedProvider)) {
      // Nostr未初期化の場合はスキップ
      return;
    }

    // Amberモードの場合は専用フローを使用
    // （syncFunctionはAmberモード用に最適化されている前提）
    if (_ref.read(isAmberModeProvider)) {
      print('🔐 Amberモードで同期します');
      // Amberモードの場合はリトライなし（ユーザー操作が必要なため）
      _ref.read(syncStatusProvider.notifier).startSync();
      
      try {
        await syncFunction();
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        print('✅ Amber同期成功');
      } catch (e) {
        _ref.read(syncStatusProvider.notifier).syncError(
          e.toString(),
          shouldRetry: false,
        );
        print('❌ Amber同期失敗: $e');
      }
      return;
    }

    // 通常モード: 秘密鍵で署名
    // 同期開始
    _ref.read(syncStatusProvider.notifier).startSync();

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await syncFunction();
        
        // 成功
        _ref.read(syncStatusProvider.notifier).syncSuccess();
        print('✅ Nostr同期成功');
        return;
        
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        
        if (isLastAttempt) {
          // 最終試行でも失敗
          _ref.read(syncStatusProvider.notifier).syncError(
            e.toString(),
            shouldRetry: false,
          );
          print('❌ Nostr同期失敗（最終試行）: $e');
        } else {
          // リトライする
          print('⚠️ Nostr同期エラー（${attempt + 1}/${maxRetries + 1}回目）: $e');
          print('🔄 ${retryDelay.inSeconds}秒後にリトライします...');
          
          await Future.delayed(retryDelay);
        }
      }
    }
  }

  /// すべてのTodoをローカルストレージに保存
  Future<void> _saveAllTodosToLocal() async {
    await state.whenData((todos) async {
      final allTodos = <Todo>[];
      
      // すべてのTodoをフラットなリストに変換
      for (final dateGroup in todos.values) {
        allTodos.addAll(dateGroup);
      }
      
      try {
        await localStorageService.saveTodos(allTodos);
      } catch (e) {
        print('⚠️ ローカル保存エラー: $e');
      }
    });
  }

  /// TodoにeventIdを設定して状態を更新
  void _updateTodoEventId(String todoId, DateTime? date, String eventId) {
    state.whenData((todos) async {
      final list = List<Todo>.from(todos[date] ?? []);
      final index = list.indexWhere((t) => t.id == todoId);

      if (index != -1) {
        list[index] = list[index].copyWith(eventId: eventId);
        
        state = AsyncValue.data({
          ...todos,
          date: list,
        });

        // ローカルストレージに保存
        await _saveAllTodosToLocal();
      }
    });
  }

  /// Nostrからすべてのtodoを同期（Amber暗号化対応）
  Future<void> syncFromNostr() async {
    if (!_ref.read(nostrInitializedProvider)) {
      print('⚠️ Nostr未初期化のため同期をスキップ');
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    final nostrService = _ref.read(nostrServiceProvider);

    _ref.read(syncStatusProvider.notifier).startSync();

    try {
      if (isAmberMode) {
        // Amberモード: 暗号化されたイベントを取得 → Amberで復号化
        print('🔐 Amberモードで同期します（復号化あり）');
        
        final encryptedEvents = await nostrService.fetchEncryptedTodos();
        print('📥 ${encryptedEvents.length}件の暗号化されたイベントを取得');
        
        if (encryptedEvents.isEmpty) {
          print('⚠️ 暗号化されたイベントが0件です。リレーに接続されているか確認してください。');
        }
        
        final List<Todo> syncedTodos = [];
        final amberService = _ref.read(amberServiceProvider);
        final publicKey = _ref.read(publicKeyProvider);
        
        if (publicKey == null) {
          throw Exception('公開鍵が設定されていません');
        }
        
        print('🔑 公開鍵: ${publicKey.substring(0, 16)}...');
        
        // 各イベントを復号化
        int successCount = 0;
        int failureCount = 0;
        
        for (int i = 0; i < encryptedEvents.length; i++) {
          final event = encryptedEvents[i];
          try {
            print('🔓 [${i + 1}/${encryptedEvents.length}] イベント ${event.eventId.substring(0, 8)}... を復号化中...');
            print('   暗号化content (最初50文字): ${event.encryptedContent.substring(0, 50.clamp(0, event.encryptedContent.length))}...');
            
            // Amberで復号化
            final decryptedJson = await amberService.decryptNip44(
              event.encryptedContent,
              publicKey,
            );
            
            print('   復号化結果 (最初100文字): ${decryptedJson.substring(0, 100.clamp(0, decryptedJson.length))}...');
            
            // JSONをパース
            final todoMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
            
            final todo = Todo(
              id: todoMap['id'] as String,
              title: todoMap['title'] as String,
              completed: todoMap['completed'] as bool,
              date: todoMap['date'] != null 
                  ? DateTime.parse(todoMap['date'] as String) 
                  : null,
              order: todoMap['order'] as int,
              // JSONのキーはスネークケース（created_at, updated_at）
              createdAt: DateTime.parse(todoMap['created_at'] as String),
              updatedAt: DateTime.parse(todoMap['updated_at'] as String),
              // event_idはJSONにある場合とない場合がある
              eventId: todoMap['event_id'] as String? ?? event.eventId,
            );
            
            syncedTodos.add(todo);
            successCount++;
            print('   ✅ 復号化成功: ${todo.title}');
          } catch (e, stackTrace) {
            failureCount++;
            print('   ⚠️ イベント ${event.eventId.substring(0, 8)}... の復号化に失敗:');
            print('   エラー: $e');
            print('   スタックトレース: ${stackTrace.toString().split('\n').take(3).join('\n')}');
            // 失敗したイベントはスキップして続行
          }
        }
        
        print('✅ 復号化完了: 成功 $successCount件 / 失敗 $failureCount件 / 合計 ${encryptedEvents.length}件');
        
        // 状態を更新
        _updateStateWithSyncedTodos(syncedTodos);
        
      } else {
        // 通常モード: Rust側で復号化済みのTodoを取得
        print('🔄 通常モードで同期します');
        final syncedTodos = await nostrService.syncTodosFromNostr();
        print('📥 ${syncedTodos.length}件のTodoを取得しました');
        _updateStateWithSyncedTodos(syncedTodos);
      }
      
      _ref.read(syncStatusProvider.notifier).syncSuccess();
      print('✅ Nostr同期成功');
      
    } catch (e, stackTrace) {
      _ref.read(syncStatusProvider.notifier).syncError(
        e.toString(),
        shouldRetry: false,
      );
      print('❌ Nostr同期失敗: $e');
      print('スタックトレース: ${stackTrace.toString().split('\n').take(5).join('\n')}');
    }
  }

  /// 同期したTodoで状態を更新
  void _updateStateWithSyncedTodos(List<Todo> syncedTodos) {
    // 日付ごとにグループ化
    final Map<DateTime?, List<Todo>> grouped = {};
    for (final todo in syncedTodos) {
      grouped[todo.date] ??= [];
      grouped[todo.date]!.add(todo);
    }
    
    // 各日付のリストをorder順にソート
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.order.compareTo(b.order));
    }
    
    state = AsyncValue.data(grouped);
    
    // ローカルストレージに保存
    _saveAllTodosToLocal();
  }
}

/// 特定の日付のTodoリストを取得するProvider
/// 未完了タスクを上、完了済みタスクを下に表示
final todosForDateProvider = Provider.family<List<Todo>, DateTime?>((ref, date) {
  final todosAsync = ref.watch(todosProvider);
  return todosAsync.when(
    data: (todos) {
      final list = todos[date] ?? [];
      
      // 未完了タスクと完了済みタスクに分ける
      final incomplete = list.where((t) => !t.completed).toList();
      final completed = list.where((t) => t.completed).toList();
      
      // 未完了タスクをorder順にソート
      incomplete.sort((a, b) => a.order.compareTo(b.order));
      // 完了済みタスクもorder順にソート（完了した順番を保持）
      completed.sort((a, b) => a.order.compareTo(b.order));
      
      // 未完了 + 完了済みの順で結合
      return [...incomplete, ...completed];
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

