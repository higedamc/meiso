import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bridge_generated.dart';
import '../models/todo.dart';

/// デフォルトのNostrリレーリスト
const List<String> defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
  'wss://nostr.wine',
];

/// Nostrクライアントの初期化状態を管理するProvider
final nostrInitializedProvider = StateProvider<bool>((ref) => false);

/// 公開鍵を管理するProvider
final nostrPublicKeyProvider = StateProvider<String?>((ref) => null);

/// NostrクライアントのProviderを作成
class NostrService {
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
  String generateNewSecretKey() {
    return generateSecretKey();
  }

  /// Nostrクライアントを初期化
  Future<String> initializeNostr({String? secretKey, List<String>? relays}) async {
    final key = secretKey ?? await getSecretKey();
    if (key == null) {
      throw Exception('Secret key not found. Please generate or provide one.');
    }

    final relayList = relays ?? defaultRelays;
    final publicKey = initNostrClient(secretKeyHex: key, relays: relayList);

    return publicKey;
  }

  /// TodoをNostrに作成
  Future<String> createTodo(Todo todo) async {
    final todoData = TodoData(
      id: todo.id,
      title: todo.title,
      completed: todo.completed,
      date: todo.date?.toIso8601String(),
      order: todo.order,
      createdAt: todo.createdAt.toIso8601String(),
      updatedAt: todo.updatedAt.toIso8601String(),
      eventId: todo.eventId,
    );

    return createTodo(todo: todoData);
  }

  /// TodoをNostrで更新
  Future<String> updateTodo(Todo todo) async {
    final todoData = TodoData(
      id: todo.id,
      title: todo.title,
      completed: todo.completed,
      date: todo.date?.toIso8601String(),
      order: todo.order,
      createdAt: todo.createdAt.toIso8601String(),
      updatedAt: todo.updatedAt.toIso8601String(),
      eventId: todo.eventId,
    );

    return updateTodo(todo: todoData);
  }

  /// TodoをNostrから削除
  Future<void> deleteTodo(String todoId) async {
    return deleteTodo(todoId: todoId);
  }

  /// NostrからTodoを同期
  Future<List<Todo>> syncTodos() async {
    final todoDataList = syncTodos();

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

/// NostrServiceのProvider
final nostrServiceProvider = Provider<NostrService>((ref) {
  return NostrService();
});

