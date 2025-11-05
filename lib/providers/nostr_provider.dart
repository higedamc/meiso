import 'dart:convert';
import '../services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/logger_service.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../services/logger_service.dart';
import '../models/todo.dart';
import '../services/logger_service.dart';
import '../models/link_preview.dart';
import '../services/logger_service.dart';
import '../models/recurrence_pattern.dart';
import '../services/logger_service.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/nostr_cache_service.dart';
import '../services/logger_service.dart';
import '../services/nostr_subscription_service.dart';
import '../services/logger_service.dart';
import 'sync_status_provider.dart';
import '../services/logger_service.dart';

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
      AppLogger.error(' Failed to convert hex to npub: $e');
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

/// Nostrキャッシュサービスを提供するProvider
final nostrCacheServiceProvider = Provider((ref) {
  final service = NostrCacheService();
  // 初期化は非同期なので、別途initメソッドを呼ぶ必要がある
  return service;
});

/// Nostr Subscriptionサービスを提供するProvider
final nostrSubscriptionServiceProvider = Provider((ref) {
  return NostrSubscriptionService();
});

/// NostrServiceを提供するProvider
final nostrServiceProvider = Provider((ref) => NostrService(ref));

class NostrService {
  NostrService(this._ref);

  final Ref _ref;
  
  /// キャッシュサービスへの参照
  NostrCacheService? _cacheService;
  
  /// Subscriptionサービスへの参照
  NostrSubscriptionService? _subscriptionService;

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
    AppLogger.debug(' Secret key encrypted and saved via Rust');
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
      AppLogger.error(' Failed to load encrypted secret key: $e');
      return null;
    }
  }

  /// 秘密鍵を削除（Rust APIを使用）
  Future<void> deleteSecretKey() async {
    final path = await _getKeyStoragePath();
    try {
      await rust_api.deleteStoredKeys(storagePath: path);
      AppLogger.debug(' Secret key deleted via Rust');
    } catch (e) {
      AppLogger.error(' Failed to delete secret key: $e');
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
    AppLogger.debug(' Public key saved via Rust (Amber mode)');
  }

  /// 公開鍵を読み込み（Amber使用時）
  Future<String?> getPublicKey() async {
    final path = await _getKeyStoragePath();
    try {
      return await rust_api.loadPublicKey(storagePath: path);
    } catch (e) {
      AppLogger.error(' Failed to load public key: $e');
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
    String? proxyUrl,
  }) async {
    final relayList = relays ?? defaultRelays;
    
    // プロキシURLが指定されている場合はプロキシ経由で接続
    final String publicKey;
    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      AppLogger.debug(' Connecting via proxy: $proxyUrl');
      publicKey = await rust_api.initNostrClientWithProxy(
        secretKeyHex: secretKey,
        relays: relayList,
        proxyUrl: proxyUrl,
      );
    } else {
      publicKey = await rust_api.initNostrClient(
        secretKeyHex: secretKey,
        relays: relayList,
      );
    }

    // Providerの状態を更新
    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    
    // Amber使用フラグをfalseに設定（秘密鍵モード）
    await localStorageService.setUseAmber(false);
    
    // 同期ステータスを初期化済みに設定
    _ref.read(syncStatusProvider.notifier).setInitialized(true);
    
    // キャッシュとSubscriptionサービスを初期化
    await _initializeCacheAndSubscription(publicKey);

    AppLogger.info(' Nostr client initialized with secret key${proxyUrl != null ? " (via proxy)" : ""}');
    return publicKey;
  }

  /// Nostrクライアントを初期化（公開鍵のみ - Amber使用時）
  Future<String> initializeNostrWithPubkey({
    required String publicKeyHex,
    List<String>? relays,
    String? proxyUrl,
  }) async {
    final relayList = relays ?? defaultRelays;
    
    // プロキシURLが指定されている場合はプロキシ経由で接続
    final String publicKey;
    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      AppLogger.debug(' Connecting via proxy (Amber mode): $proxyUrl');
      publicKey = await rust_api.initNostrClientWithPubkeyAndProxy(
        publicKeyHex: publicKeyHex,
        relays: relayList,
        proxyUrl: proxyUrl,
      );
    } else {
      publicKey = await rust_api.initNostrClientWithPubkey(
        publicKeyHex: publicKeyHex,
        relays: relayList,
      );
    }

    // Providerの状態を更新
    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    
    // hex形式からnpub形式に変換して設定
    try {
      final npubKey = await rust_api.hexToNpub(hex: publicKey);
      _ref.read(nostrPublicKeyProvider.notifier).state = npubKey;
      AppLogger.info(' npub公開鍵を設定しました: ${npubKey.substring(0, 16)}...');
    } catch (e) {
      AppLogger.error(' hex→npub変換エラー: $e');
    }
    
    // Amber使用フラグを設定
    await localStorageService.setUseAmber(true);
    
    // キャッシュとSubscriptionサービスを初期化
    await _initializeCacheAndSubscription(publicKey);
    
    // 同期ステータスを初期化済みに設定
    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    AppLogger.info(' Nostr client initialized in Amber mode${proxyUrl != null ? " (via proxy)" : ""}');
    return publicKey;
  }


  /// TodoリストをNostrに作成（Kind 30001 - 新実装）
  Future<rust_api.EventSendResult> createTodoListOnNostr(List<Todo> todos) async {
    AppLogger.debug(' NostrProvider: createTodoListOnNostr called with ${todos.length} todos');
    
    // カスタムリストIDを持つTodoをログ
    final customListTodos = todos.where((t) => t.customListId != null).toList();
    if (customListTodos.isNotEmpty) {
      AppLogger.debug(' NostrProvider: ${customListTodos.length} todos have customListId:');
      for (final todo in customListTodos) {
        AppLogger.debug('   - "${todo.title}" → customListId: ${todo.customListId}');
      }
    }
    
    final todoDataList = todos.map((todo) {
      final todoData = rust_api.TodoData(
        id: todo.id,
        title: todo.title,
        completed: todo.completed,
        date: todo.date?.toIso8601String(),
        order: todo.order,
        createdAt: todo.createdAt.toIso8601String(),
        updatedAt: todo.updatedAt.toIso8601String(),
        eventId: todo.eventId,
        linkPreview: todo.linkPreview != null 
            ? jsonEncode(todo.linkPreview!.toJson())
            : null,
        recurrence: todo.recurrence != null
            ? jsonEncode(todo.recurrence!.toJson())
            : null,
        parentRecurringId: todo.parentRecurringId,
        customListId: todo.customListId,
      );
      
      // カスタムリストIDが設定されている場合のみログ
      if (todoData.customListId != null) {
        AppLogger.debug(' Sending TodoData to Rust: "${todoData.title}" with customListId: ${todoData.customListId}');
      }
      
      return todoData;
    }).toList();

    AppLogger.debug(' Calling Rust createTodoList with ${todoDataList.length} TodoData objects');
    final result = await rust_api.createTodoList(todos: todoDataList);
    AppLogger.info(' Rust createTodoList completed: success=${result.success}, eventId=${result.eventId}');
    
    return result;
  }

  /// NostrからTodoリストを同期（Kind 30001 - 新実装）
  Future<List<Todo>> syncTodoListFromNostr() async {
    AppLogger.debug(' NostrProvider: syncTodoListFromNostr called');
    final todoDataList = await rust_api.syncTodoList();
    AppLogger.debug(' Received ${todoDataList.length} TodoData objects from Rust');
    
    // カスタムリストIDを持つTodoDataをログ
    final customListTodoData = todoDataList.where((t) => t.customListId != null).toList();
    if (customListTodoData.isNotEmpty) {
      AppLogger.debug(' NostrProvider: ${customListTodoData.length} TodoData have customListId:');
      for (final todoData in customListTodoData) {
        AppLogger.debug('   - "${todoData.title}" → customListId: ${todoData.customListId}');
      }
    } else {
      AppLogger.warning(' NostrProvider: No TodoData with customListId found');
    }

    return todoDataList.map((todoData) {
      // JSON文字列からオブジェクトに復元
      LinkPreview? linkPreview;
      if (todoData.linkPreview != null) {
        try {
          linkPreview = LinkPreview.fromJson(
            jsonDecode(todoData.linkPreview!) as Map<String, dynamic>
          );
        } catch (e) {
          AppLogger.warning(' Failed to parse linkPreview: $e');
        }
      }

      RecurrencePattern? recurrence;
      if (todoData.recurrence != null) {
        try {
          recurrence = RecurrencePattern.fromJson(
            jsonDecode(todoData.recurrence!) as Map<String, dynamic>
          );
        } catch (e) {
          AppLogger.warning(' Failed to parse recurrence: $e');
        }
      }

      return Todo(
        id: todoData.id,
        title: todoData.title,
        completed: todoData.completed,
        date: todoData.date != null ? DateTime.parse(todoData.date!) : null,
        order: todoData.order,
        createdAt: DateTime.parse(todoData.createdAt),
        updatedAt: DateTime.parse(todoData.updatedAt),
        eventId: todoData.eventId,
        linkPreview: linkPreview,
        recurrence: recurrence,
        parentRecurringId: todoData.parentRecurringId,
        customListId: todoData.customListId,
      );
    }).toList();
  }


  // ========================================
  // Amberモード専用メソッド
  // ========================================

  /// Amberモード: 署名済みイベントをリレーに送信
  Future<rust_api.EventSendResult> sendSignedEvent(String signedEventJson) async {
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

  /// Amberモード: 暗号化済みcontentで未署名TodoリストイベントKind 30001を作成
  /// 
  /// [listId] - カスタムリストID（nullの場合はデフォルトリスト）
  /// [listTitle] - リストタイトル（nullの場合はデフォルトタイトル）
  Future<String> createUnsignedEncryptedTodoListEvent({
    required String encryptedContent,
    String? listId,
    String? listTitle,
  }) async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    // Rust側で未署名イベントを作成（リスト識別子とタイトル付き）
    return await rust_api.createUnsignedEncryptedTodoListEventWithListId(
      encryptedContent: encryptedContent,
      publicKeyHex: publicKey,
      listId: listId,
      listTitle: listTitle,
    );
  }

  /// Amberモード: すべての暗号化されたTodoリストイベント（Kind 30001）を取得
  Future<List<rust_api.EncryptedTodoListEvent>> fetchAllEncryptedTodoLists() async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    return await rust_api.fetchAllEncryptedTodoListsForPubkey(
      publicKeyHex: publicKey,
    );
  }

  /// 通常モード: すべてのTodoリストのメタデータ（d tag, title）を取得
  Future<List<rust_api.TodoListMetadata>> fetchAllTodoListMetadata() async {
    AppLogger.debug(' NostrProvider: fetchAllTodoListMetadata called');
    
    final metadata = await rust_api.fetchAllTodoListMetadata();
    AppLogger.debug(' Received ${metadata.length} TodoListMetadata objects from Rust');
    
    // カスタムリストのメタデータをログ
    final customListMetadata = metadata.where((m) => 
      m.listId != null && m.listId!.startsWith('meiso-list-')
    ).toList();
    
    if (customListMetadata.isNotEmpty) {
      AppLogger.debug(' NostrProvider: ${customListMetadata.length} custom list metadata found:');
      for (final meta in customListMetadata) {
        AppLogger.debug('   - listId: ${meta.listId}, title: ${meta.title}');
      }
    } else {
      AppLogger.warning(' NostrProvider: No custom list metadata found');
    }
    
    return metadata;
  }

  /// Amberモード: デフォルトリストのみを取得（互換性のため残す）
  Future<rust_api.EncryptedTodoListEvent?> fetchEncryptedTodoList() async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    return await rust_api.fetchEncryptedTodoListForPubkey(
      publicKeyHex: publicKey,
    );
  }

  /// Amberモード: 暗号化されたTodoイベントを取得（復号化はAmber側で行う）- 旧実装
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

  /// リレーサーバーへ再接続
  /// バックグラウンドから復帰時などに使用
  Future<void> reconnectRelays() async {
    AppLogger.info(' Reconnecting to relays...');
    try {
      await rust_api.reconnectToRelays();
      AppLogger.info(' Successfully reconnected to relays');
    } catch (e) {
      AppLogger.error(' Failed to reconnect to relays: $e');
      rethrow;
    }
  }

  // ========================================
  // マイグレーション関連API
  // ========================================

  /// 指定したイベントIDのリストを削除（Kind 5削除イベントを送信）
  Future<rust_api.EventSendResult> deleteEvents(List<String> eventIds, {String? reason}) async {
    return await rust_api.deleteEvents(
      eventIds: eventIds,
      reason: reason,
    );
  }
  
  // ========================================
  // キャッシュ & Subscription管理
  // ========================================
  
  /// キャッシュとSubscriptionサービスを初期化
  Future<void> _initializeCacheAndSubscription(String publicKey) async {
    try {
      // キャッシュサービスを取得・初期化
      _cacheService = _ref.read(nostrCacheServiceProvider);
      await _cacheService!.init();
      AppLogger.info(' Cache service initialized');
      
      // Subscriptionサービスを取得
      _subscriptionService = _ref.read(nostrSubscriptionServiceProvider);
      
      // TodoリストのSubscriptionを開始
      await _startTodoListSubscription(publicKey);
      
      // 期限切れキャッシュをクリーンアップ
      await _cacheService!.cleanExpiredCache();
      
      AppLogger.info(' Subscription service initialized');
    } catch (e) {
      AppLogger.warning(' Failed to initialize cache/subscription: $e');
    }
  }
  
  /// TodoリストのSubscriptionを開始
  Future<void> _startTodoListSubscription(String publicKey) async {
    if (_subscriptionService == null) return;
    
    try {
      // Kind 30001（Todoリスト）のフィルター
      final filters = [
        {
          'kinds': [30001],
          'authors': [publicKey],
          '#d': ['meiso-todos'],
        }
      ];
      
      await _subscriptionService!.startSubscription(
        filters: filters,
        onEventsReceived: (events) {
          // イベント受信時の処理
          AppLogger.debug(' Received ${events.length} todo list events');
          
          for (final event in events) {
            // キャッシュに保存
            _cacheService?.cacheEvent(
              eventJson: event.eventJson,
              ttlSeconds: 300, // 5分
            );
            
            // TodosProviderに通知（syncが必要）
            // これはTodosProvider側で実装する
          }
        },
      );
      
      AppLogger.debug(' Todo list subscription started');
    } catch (e) {
      AppLogger.warning(' Failed to start todo list subscription: $e');
    }
  }
  
  /// キャッシュからイベントを取得
  Future<String?> getCachedEvent(String eventId) async {
    if (_cacheService == null) return null;
    return await _cacheService!.getCachedEvent(eventId);
  }
  
  /// イベントをキャッシュに保存
  Future<void> cacheEvent({
    required String eventJson,
    int ttlSeconds = 300,
  }) async {
    if (_cacheService == null) return;
    await _cacheService!.cacheEvent(
      eventJson: eventJson,
      ttlSeconds: ttlSeconds,
    );
  }
  
  /// すべてのSubscriptionを停止
  Future<void> stopAllSubscriptions() async {
    if (_subscriptionService == null) return;
    await _subscriptionService!.stopAllSubscriptions();
  }
  
  /// サービスをクリーンアップ
  void dispose() {
    _subscriptionService?.dispose();
  }
}
