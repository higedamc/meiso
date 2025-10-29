import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../models/todo.dart';
import 'sync_status_provider.dart';

/// デフォルトのNostrリレーリスト
const List<String> defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
  'wss://nostr.wine',
];

/// Nostrクライアントの初期化状態を管理するProvider
final nostrInitializedProvider = StateProvider<bool>((ref) => false);

/// 公開鍵を管理するProvider（hex形式）
final publicKeyProvider = StateProvider<String?>((ref) => null);

/// 公開鍵（npub形式）を取得するProvider
final publicKeyNpubProvider = FutureProvider<String?>((ref) async {
  final isInitialized = ref.watch(nostrInitializedProvider);
  if (!isInitialized) return null;
  
  try {
    return await rust_api.getPublicKeyNpub();
  } catch (e) {
    return null;
  }
});

/// NostrServiceを提供するProvider
final nostrServiceProvider = Provider((ref) => NostrService(ref));

class NostrService {
  NostrService(this._ref);

  final Ref _ref;

  /// 秘密鍵をローカルに保存（実際にはセキュアストレージ推奨）
  Future<void> saveSecretKey(String secretKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nostr_secret_key', secretKey);
  }

  /// 秘密鍵を取得
  Future<String?> getSecretKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nostr_secret_key');
  }

  /// 秘密鍵を削除
  Future<void> deleteSecretKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nostr_secret_key');
  }

  /// 新しい秘密鍵を生成
  Future<String> generateNewSecretKey() async {
    return await rust_api.generateSecretKey();
  }

  /// Nostrクライアントを初期化
  Future<String> initializeNostr({String? secretKey, List<String>? relays}) async {
    final key = secretKey ?? await getSecretKey();
    if (key == null) {
      throw Exception('Secret key not found. Please generate or provide one.');
    }

    final relayList = relays ?? defaultRelays;
    final publicKey = await rust_api.initNostrClient(
      secretKeyHex: key,
      relays: relayList,
    );

    // Providerの状態を更新
    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    
    // 同期ステータスを初期化済みに設定
    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    return publicKey;
  }

  /// TodoをNostrに作成
  Future<String> createTodoOnNostr(Todo todo) async {
    final todoData = rust_api.TodoData(
      id: todo.id,
      title: todo.title,
      completed: todo.completed,
      date: todo.date?.toIso8601String(),
      order: todo.order,
      createdAt: todo.createdAt.toIso8601String(),
      updatedAt: todo.updatedAt.toIso8601String(),
      eventId: todo.eventId,
    );

    return await rust_api.createTodo(todo: todoData);
  }

  /// TodoをNostrで更新
  Future<String> updateTodoOnNostr(Todo todo) async {
    final todoData = rust_api.TodoData(
      id: todo.id,
      title: todo.title,
      completed: todo.completed,
      date: todo.date?.toIso8601String(),
      order: todo.order,
      createdAt: todo.createdAt.toIso8601String(),
      updatedAt: todo.updatedAt.toIso8601String(),
      eventId: todo.eventId,
    );

    return await rust_api.updateTodo(todo: todoData);
  }

  /// TodoをNostrから削除
  Future<void> deleteTodoOnNostr(String todoId) async {
    return await rust_api.deleteTodo(todoId: todoId);
  }

  /// NostrからTodoを同期
  Future<List<Todo>> syncTodosFromNostr() async {
    final todoDataList = await rust_api.syncTodos();

    return todoDataList.map((todoData) {
      return Todo(
        id: todoData.id,
        title: todoData.title,
        completed: todoData.completed,
        date: todoData.date != null ? DateTime.parse(todoData.date!) : null,
        order: todoData.order,
        createdAt: DateTime.parse(todoData.createdAt),
        updatedAt: DateTime.parse(todoData.updatedAt),
        eventId: todoData.eventId,
      );
    }).toList();
  }
}
