import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../models/todo.dart';
import '../services/local_storage_service.dart';
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

/// Nostr秘密鍵を管理するProvider（nsec形式）
final nostrPrivateKeyProvider = StateProvider<String?>((ref) => null);

/// Nostr公開鍵を管理するProvider（npub形式）
final nostrPublicKeyProvider = StateProvider<String?>((ref) => null);

/// Amberモードかどうかを判定するProvider
/// 公開鍵のみで初期化されている場合はAmberモード
final isAmberModeProvider = Provider<bool>((ref) {
  final isInitialized = ref.watch(nostrInitializedProvider);
  final publicKey = ref.watch(publicKeyProvider);
  
  // 初期化済みかつ公開鍵のみの場合はAmberモード
  // (秘密鍵で初期化した場合も公開鍵は設定されるが、Rust側に秘密鍵が保存されている)
  if (!isInitialized || publicKey == null) {
    return false;
  }
  
  // Amber使用フラグで判定
  return localStorageService.isUsingAmber();
});

/// 公開鍵（npub形式）を取得するProvider
final publicKeyNpubProvider = FutureProvider<String?>((ref) async {
  final isInitialized = ref.watch(nostrInitializedProvider);
  final publicKeyHex = ref.watch(publicKeyProvider);
  
  if (!isInitialized || publicKeyHex == null) return null;
  
  // Amberモードの場合、publicKeyProviderに保存されているhex形式から変換
  final isAmberMode = ref.read(isAmberModeProvider);
  if (isAmberMode) {
    try {
      return await rust_api.hexToNpub(hex: publicKeyHex);
    } catch (e) {
      print('❌ Failed to convert hex to npub: $e');
      return null;
    }
  }
  
  // 秘密鍵モードの場合、Rust側から取得
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

  /// 暗号化鍵ファイルのパスを取得
  Future<String> _getKeyStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/nostr_key.enc';
  }

  /// 秘密鍵を暗号化して保存（Rust APIを使用）
  Future<void> saveSecretKey(String secretKey, String password) async {
    final path = await _getKeyStoragePath();
    await rust_api.saveEncryptedSecretKey(
      storagePath: path,
      secretKey: secretKey,
      password: password,
    );
    print('🔐 Secret key encrypted and saved via Rust');
  }

  /// 暗号化された秘密鍵を読み込み（Rust APIを使用）
  Future<String?> getSecretKey(String password) async {
    final path = await _getKeyStoragePath();
    try {
      return await rust_api.loadEncryptedSecretKey(
        storagePath: path,
        password: password,
      );
    } catch (e) {
      print('❌ Failed to load encrypted secret key: $e');
      return null;
    }
  }

  /// 秘密鍵を削除（Rust APIを使用）
  Future<void> deleteSecretKey() async {
    final path = await _getKeyStoragePath();
    try {
      await rust_api.deleteStoredKeys(storagePath: path);
      print('🗑️ Secret key deleted via Rust');
    } catch (e) {
      print('❌ Failed to delete secret key: $e');
    }
  }

  /// 暗号化された秘密鍵が存在するか確認
  Future<bool> hasEncryptedKey() async {
    final path = await _getKeyStoragePath();
    return rust_api.hasEncryptedKey(storagePath: path);
  }

  /// 公開鍵を保存（Amber使用時）
  Future<void> savePublicKey(String publicKey) async {
    final path = await _getKeyStoragePath();
    await rust_api.savePublicKey(
      storagePath: path,
      publicKey: publicKey,
    );
    print('🔐 Public key saved via Rust (Amber mode)');
  }

  /// 公開鍵を読み込み（Amber使用時）
  Future<String?> getPublicKey() async {
    final path = await _getKeyStoragePath();
    try {
      return await rust_api.loadPublicKey(storagePath: path);
    } catch (e) {
      print('❌ Failed to load public key: $e');
      return null;
    }
  }

  /// 公開鍵が存在するか確認
  Future<bool> hasPublicKey() async {
    final path = await _getKeyStoragePath();
    return rust_api.hasPublicKey(storagePath: path);
  }

  /// 新しい秘密鍵を生成
  Future<String> generateNewSecretKey() async {
    return await rust_api.generateSecretKey();
  }

  /// Nostrクライアントを初期化（秘密鍵を使用）
  Future<String> initializeNostr({
    required String secretKey,
    List<String>? relays,
  }) async {
    final relayList = relays ?? defaultRelays;
    final publicKey = await rust_api.initNostrClient(
      secretKeyHex: secretKey,
      relays: relayList,
    );

    // Providerの状態を更新
    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    
    // Amber使用フラグをfalseに設定（秘密鍵モード）
    await localStorageService.setUseAmber(false);
    
    // 同期ステータスを初期化済みに設定
    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    print('✅ Nostr client initialized with secret key');
    return publicKey;
  }

  /// Nostrクライアントを初期化（公開鍵のみ - Amber使用時）
  Future<String> initializeNostrWithPubkey({
    required String publicKeyHex,
    List<String>? relays,
  }) async {
    final relayList = relays ?? defaultRelays;
    final publicKey = await rust_api.initNostrClientWithPubkey(
      publicKeyHex: publicKeyHex,
      relays: relayList,
    );

    // Providerの状態を更新
    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    
    // Amber使用フラグを設定
    await localStorageService.setUseAmber(true);
    
    // 同期ステータスを初期化済みに設定
    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    print('✅ Nostr client initialized in Amber mode');
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

  // ========================================
  // Amberモード専用メソッド
  // ========================================

  /// Amberモード: 未署名Todoイベントを作成
  Future<String> createUnsignedTodoEvent(Todo todo) async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

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

    // Rust側で未署名イベントを作成
    return await rust_api.createUnsignedTodoEvent(
      todo: todoData,
      publicKeyHex: publicKey,
    );
  }

  /// Amberモード: 署名済みイベントをリレーに送信
  Future<String> sendSignedEvent(String signedEventJson) async {
    return await rust_api.sendSignedEvent(eventJson: signedEventJson);
  }

  /// Amberモード: 暗号化済みcontentで未署名Todoイベントを作成
  Future<String> createUnsignedEncryptedTodoEvent({
    required String todoId,
    required String encryptedContent,
  }) async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    // Rust側で未署名イベントを作成
    return await rust_api.createUnsignedEncryptedTodoEvent(
      todoId: todoId,
      encryptedContent: encryptedContent,
      publicKeyHex: publicKey,
    );
  }

  /// Amberモード: 暗号化されたTodoイベントを取得（復号化はAmber側で行う）
  Future<List<rust_api.EncryptedTodoEvent>> fetchEncryptedTodos() async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    return await rust_api.fetchEncryptedTodosForPubkey(
      publicKeyHex: publicKey,
    );
  }

  /// npub形式の公開鍵をhex形式に変換
  Future<String> npubToHex(String npub) async {
    return await rust_api.npubToHex(npub: npub);
  }

  /// hex形式の公開鍵をnpub形式に変換
  Future<String> hexToNpub(String hex) async {
    return await rust_api.hexToNpub(hex: hex);
  }
}
