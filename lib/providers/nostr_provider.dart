import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/nostr_cache_service.dart';
import '../services/nostr_subscription_service.dart';
import '../services/amber_service.dart';
import 'sync_status_provider.dart';
import '../utils/error_handler.dart';

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

  /// NostrからTodoリストを差分同期（Kind 30001 - 新実装）
  ///
  /// [since] 以降に更新されたリストのみ取得する。復帰/再起動の体感改善用。
  Future<List<Todo>> syncTodoListFromNostrSince({
    required DateTime since,
    int timeoutSeconds = 3,
  }) async {
    AppLogger.debug(' NostrProvider: syncTodoListFromNostrSince called');

    final sinceUnix = since.millisecondsSinceEpoch ~/ 1000;
    final timeout = timeoutSeconds <= 0 ? 1 : timeoutSeconds;

    final todoDataList = await rust_api.syncTodoListSince(
      since: sinceUnix,
      timeoutSecs: BigInt.from(timeout),
    );

    return todoDataList.map((todoData) {
      LinkPreview? linkPreview;
      if (todoData.linkPreview != null) {
        try {
          linkPreview = LinkPreview.fromJson(
            jsonDecode(todoData.linkPreview!) as Map<String, dynamic>,
          );
        } catch (e) {
          AppLogger.warning(' Failed to parse linkPreview: $e');
        }
      }

      RecurrencePattern? recurrence;
      if (todoData.recurrence != null) {
        try {
          recurrence = RecurrencePattern.fromJson(
            jsonDecode(todoData.recurrence!) as Map<String, dynamic>,
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

    try {
      final result = await rust_api.fetchAllEncryptedTodoListsForPubkey(
        publicKeyHex: publicKey,
      );
      
      AppLogger.debug('📥 [NostrProvider] Received ${result.length} encrypted todo list events');
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('❌ [NostrProvider] Failed to fetch encrypted todo lists: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Amberモード: すべての暗号化されたTodoリストイベント（Kind 30001）を差分取得
  ///
  /// [since] 以降のイベントのみ取得し、同一d-tagで最新のものだけ返す。
  Future<List<rust_api.EncryptedTodoListEvent>> fetchAllEncryptedTodoListsSince({
    required DateTime since,
    int timeoutSeconds = 3,
  }) async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    final sinceUnix = since.millisecondsSinceEpoch ~/ 1000;
    final timeout = timeoutSeconds <= 0 ? 1 : timeoutSeconds;

    return await rust_api.fetchAllEncryptedTodoListsForPubkeySince(
      publicKeyHex: publicKey,
      since: sinceUnix,
      timeoutSecs: BigInt.from(timeout),
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

  /// リレーサーバーへ再接続（タイムアウト秒を指定）
  ///
  /// 背景復帰時の「最大10秒待ち」を避けるために使用する。
  Future<void> reconnectRelaysWithTimeout({int timeoutSeconds = 3}) async {
    final timeout = timeoutSeconds <= 0 ? 1 : timeoutSeconds;
    AppLogger.info(' Reconnecting to relays with timeout=${timeout}s...');
    try {
      await rust_api.reconnectToRelaysWithTimeout(timeoutSecs: BigInt.from(timeout));
      AppLogger.info(' Successfully reconnected to relays');
    } catch (e) {
      AppLogger.error(' Failed to reconnect to relays: $e');
      rethrow;
    }
  }

  /// リレー接続状態を確認（1つでも接続が生きていれば true）
  Future<bool> checkConnectionStatus() async {
    try {
      return await rust_api.checkConnectionStatus();
    } catch (e) {
      AppLogger.warning(' Failed to check connection status: $e');
      return false;
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
  
  /// Phase 8.1: npubからKey Packageを取得
  /// Phase 8.2: リトライロジック + タイムアウト対応
  Future<String?> fetchKeyPackageByNpub(String npub) async {
    try {
      AppLogger.debug('🔍 Fetching Key Package for: ${npub.substring(0, 20)}...');
      
      // Phase 8.2.1: リトライ + タイムアウト
      final keyPackage = await ErrorHandler.retryWithBackoff<String?>(
        operation: () => ErrorHandler.withTimeout<String?>(
          operation: () => rust_api.fetchKeyPackageByNpub(npub: npub),
          operationName: 'fetchKeyPackageByNpub',
          timeout: const Duration(seconds: 10),
          defaultValue: null,
        ),
        operationName: 'fetchKeyPackageByNpub',
        maxAttempts: 2, // 1回のリトライのみ
        initialDelay: const Duration(seconds: 2),
      );
      
      if (keyPackage != null) {
        AppLogger.info('✅ Key Package fetched successfully');
      } else {
        AppLogger.warning('⚠️ Key Package not found (null result)');
      }
      
      return keyPackage;
      
    } catch (e, stackTrace) {
      final appError = ErrorHandler.classify(e, stackTrace: stackTrace);
      AppLogger.error(
        '❌ Failed to fetch Key Package\n'
        'User Message: ${appError.userMessage}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
  
  /// Phase 8.4: グループ招待送信（Kind 30078）
  Future<String?> sendGroupInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    required String welcomeMsgBase64,
  }) async {
    try {
      AppLogger.info('📤 [Invitation] Sending group invitation to: ${recipientNpub.substring(0, 20)}...');
      
      // 公開鍵を取得
      final senderPubkeyHex = await getPublicKey();
      if (senderPubkeyHex == null) {
        throw Exception('Sender public key not available');
      }
      
      final senderNpub = await hexToNpub(senderPubkeyHex);
      
      // 未署名イベントを作成
      final unsignedEventJson = await rust_api.createUnsignedGroupInvitationEvent(
        senderPublicKeyHex: senderPubkeyHex,
        recipientNpub: recipientNpub,
        groupId: groupId,
        groupName: groupName,
        welcomeMsgBase64: welcomeMsgBase64,
        inviterName: null, // オプション
      );
      
      AppLogger.debug('📄 [Invitation] Created unsigned event');
      
      // Amberで署名
      final amberService = AmberService();
      
      String signedEvent;
      try {
        // ContentProvider経由で試行（バックグラウンド）
        signedEvent = await amberService.signEventWithContentProvider(
          event: unsignedEventJson,
          npub: senderNpub,
        );
        AppLogger.debug('✅ [Invitation] Signed via ContentProvider');
      } on PlatformException catch (e) {
        // UI経由にフォールバック
        AppLogger.warning('[Invitation] ContentProvider failed (${e.code}), using UI method');
        signedEvent = await amberService.signEventWithTimeout(
          unsignedEventJson,
          timeout: const Duration(minutes: 2),
        );
        AppLogger.debug('✅ [Invitation] Signed via UI');
      }
      
      // リレーに送信
      final sendResult = await sendSignedEvent(signedEvent);
      
      AppLogger.info('✅ [Invitation] Group invitation sent successfully');
      AppLogger.info('   Event ID: ${sendResult.eventId.substring(0, 16)}...');
      
      return sendResult.eventId;
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [Invitation] Failed to send group invitation', error: e, stackTrace: stackTrace);
      return null;
    }
  }
  
  /// Phase 8.1: 起動時にKey Packageを自動公開
  /// 
  /// Amberモードで初回起動時、またはKey Packageが古い場合に自動公開
  Future<void> autoPublishKeyPackageIfNeeded() async {
    try {
      // Amberモードチェック
      if (!localStorageService.isUsingAmber()) {
        AppLogger.debug('⏭️  [KeyPackage] Amberモードではないため、自動公開をスキップ');
        return;
      }
      
      // Nostr初期化チェック
      final publicKey = await getPublicKey();
      if (publicKey == null) {
        AppLogger.warning('⚠️ [KeyPackage] 公開鍵が取得できないため、自動公開をスキップ');
        return;
      }
      
      AppLogger.info('🔑 [KeyPackage] 起動時Key Package自動公開チェック');
      
      // 前回の公開時刻をチェック
      final lastPublished = localStorageService.getLastKeyPackagePublishTime();
      final now = DateTime.now();
      
      if (lastPublished != null) {
        final hoursSincePublish = now.difference(lastPublished).inHours;
        AppLogger.debug('   前回公開: ${hoursSincePublish}時間前');
        
        // 24時間以内なら公開しない
        if (hoursSincePublish < 24) {
          AppLogger.info('✅ [KeyPackage] Key Packageは最新です（${hoursSincePublish}時間前に公開済み）');
          return;
        }
      } else {
        AppLogger.debug('   初回公開');
      }
      
      // Key Package公開
      final eventId = await publishKeyPackage();
      
      if (eventId != null) {
        // 公開時刻を保存
        localStorageService.setLastKeyPackagePublishTime(now);
        AppLogger.info('✅ [KeyPackage] 起動時Key Package自動公開成功');
      } else {
        AppLogger.warning('⚠️ [KeyPackage] 自動公開に失敗しました');
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [KeyPackage] 自動公開エラー', error: e, stackTrace: stackTrace);
      // エラーは無視（アプリ起動に影響を与えない）
    }
  }
  
  /// MLS: Key PackageをKind 10443イベントとして公開
  /// 
  /// Key Packageを公開することで、他のユーザーがnpubから自動的に
  /// Key Packageを取得してグループに招待できるようになる
  /// 
  /// Returns: イベントID（成功時）
  Future<String?> publishKeyPackage() async {
    try {
      AppLogger.info('📦 Key Package公開を開始...');
      
      // 公開鍵を取得
      final publicKeyHex = await getPublicKey();
      if (publicKeyHex == null) {
        throw Exception('Public key not available');
      }
      
      // Amberモード判定
      final isAmber = _ref.read(isAmberModeProvider);
      
      // リレーリストを取得（デフォルトリレーを使用）
      final relays = defaultRelays;
      
      // Phase 8.1.3: MLS DB初期化（Key Package生成前に必須）
      AppLogger.debug('  Step 0: MLS DB初期化中...');
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/mls.db';
      
      await rust_api.mlsInitDb(
        dbPath: dbPath,
        nostrId: publicKeyHex,
      );
      AppLogger.debug('  ✅ MLS DB初期化完了');
      
      // Step 1: Key Package生成
      AppLogger.debug('  Step 1: Key Package生成中...');
      final keyPackageResult = await rust_api.mlsCreateKeyPackage(
        nostrId: publicKeyHex,
      );
      AppLogger.debug('  ✅ Key Package生成完了');
      AppLogger.debug('    Protocol: ${keyPackageResult.mlsProtocolVersion}');
      AppLogger.debug('    Ciphersuite: ${keyPackageResult.ciphersuite}');
      
      // Step 2: 未署名イベント作成
      AppLogger.debug('  Step 2: Kind 10443イベント作成中...');
      final unsignedEventJson = await rust_api.createUnsignedKeyPackageEvent(
        keyPackageResult: keyPackageResult,
        publicKeyHex: publicKeyHex,
        relays: relays,
      );
      
      String signedEvent;
      
      if (isAmber) {
        // Step 3: Amber署名
        AppLogger.debug('  Step 3: Amberで署名中...');
        final amberService = AmberService();
        signedEvent = await amberService.signEventWithTimeout(
          unsignedEventJson,
          timeout: const Duration(minutes: 2),
        );
        AppLogger.debug('  ✅ Amber署名完了');
      } else {
        // 秘密鍵モードは現在pending
        throw Exception('秘密鍵モードでのKey Package公開は未実装です。Amberモードをご利用ください。');
      }
      
      // Step 4: リレーに送信
      AppLogger.debug('  Step 4: リレーに送信中...');
      final sendResult = await sendSignedEvent(signedEvent);
      
      AppLogger.info('✅ Key Package公開完了！');
      AppLogger.info('   Event ID: ${sendResult.eventId}');
      AppLogger.info('   公開先リレー数: ${relays.length}');
      
      return sendResult.eventId;
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ Key Package公開失敗', error: e, stackTrace: stackTrace);
      return null;
    }
  }
  
  /// Phase 9.1: タイムスタンプをランダム化（±2日）
  /// 
  /// NIP-17仕様に従い、アクティビティパターンの追跡を防ぐ
  int _randomizeTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final twoDaysInSeconds = 2 * 24 * 60 * 60; // 172800秒
    final random = Random.secure();
    
    // -2日 ～ +2日の範囲でランダム化
    final offset = random.nextInt(twoDaysInSeconds * 2) - twoDaysInSeconds;
    final randomizedTimestamp = now + offset;
    
    AppLogger.debug('🎲 [NIP-17] Randomized timestamp: $now → $randomizedTimestamp (offset: ${offset}s)');
    
    return randomizedTimestamp;
  }
  
  /// Phase 9.1: NIP-17 Gift Wrapでイベント送信（エフェメラル鍵署名）
  /// 
  /// # Parameters
  /// - [content]: MLS暗号化済みのコンテンツ
  /// - [kind]: イベントKind（通常は1059）
  /// - [tags]: イベントタグ（最小化推奨）
  /// - [randomizeTimestamp]: タイムスタンプをランダム化するか（デフォルト: true）
  /// 
  /// # Returns
  /// - イベントID（成功時）、null（失敗時）
  /// 
  /// # Security
  /// - エフェメラル鍵で署名（送信者匿名化）
  /// - タイムスタンプランダム化（±2日）
  /// - タグ最小化（メタデータ保護）
  Future<String?> sendGiftWrappedEvent({
    required String content,
    required int kind,
    required List<List<String>> tags,
    bool randomizeTimestamp = true,
  }) async {
    try {
      AppLogger.debug('🎁 [NIP-17] Sending Gift Wrapped event');
      AppLogger.debug('   Kind: $kind');
      AppLogger.debug('   Tags: ${tags.length}');
      
      // 1. タイムスタンプをランダム化（±2日）
      final timestamp = randomizeTimestamp ? _randomizeTimestamp() : DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // 2. 未署名イベント作成
      final unsignedEvent = jsonEncode({
        'content': content,
        'kind': kind,
        'tags': tags,
        'created_at': timestamp,
      });
      
      AppLogger.debug('📄 [NIP-17] Created unsigned Gift Wrap event');
      
      // 3. Rust側でエフェメラル鍵署名（秘密鍵はRust内のみ）
      final signedEventJson = await rust_api.signEventWithEphemeralKey(
        unsignedEventJson: unsignedEvent,
      );
      
      AppLogger.debug('✅ [NIP-17] Event signed with ephemeral key');
      
      // 4. リレー送信
      final sendResult = await rust_api.sendSignedEvent(
        eventJson: signedEventJson,
      );
      
      AppLogger.info('✅ [NIP-17] Gift wrapped event sent');
      AppLogger.info('   Event ID: ${sendResult.eventId.substring(0, 16)}...');
      AppLogger.info('   Successful relays: ${sendResult.successfulRelays}');
      
      return sendResult.eventId;
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [NIP-17] Failed to send gift wrapped event', error: e, stackTrace: stackTrace);
      return null;
    }
  }
  
  /// Phase 9.1: MLSグループTODOをNostrに送信（NIP-17 Gift Wrap + エフェメラル鍵署名）
  /// 
  /// Phase 8.3からの改善:
  /// - ✅ エフェメラル鍵で署名（送信者匿名化）
  /// - ✅ タイムスタンプランダム化（±2日）
  /// - ⚠️ `group_id`タグは残す（Phase 9.2で削除予定）
  /// 
  /// [listenKey]: Export SecretからMLSで導出した受信用公開鍵
  /// [encryptedContent]: MLS暗号化済みのTODO JSON（hex）
  /// [groupId]: グループID
  /// 
  /// Returns: イベントID（成功時）
  Future<String?> sendMlsGroupTodo({
    required String listenKey,
    required String encryptedContent,
    required String groupId,
  }) async {
    try {
      AppLogger.debug('📤 [MLS] Sending group TODO to Nostr (Phase 9.1)');
      AppLogger.debug('   Listen Key: ${listenKey.substring(0, 16)}...');
      AppLogger.debug('   Group ID: $groupId');
      AppLogger.debug('   Content size: ${encryptedContent.length} bytes');
      
      // Phase 9.1: NIP-17 Gift Wrap（エフェメラル鍵署名 + タイムスタンプランダム化）
      final eventId = await sendGiftWrappedEvent(
        content: encryptedContent,
        kind: 1059, // NIP-17 Seal
        tags: [
          ['p', listenKey], // 受信者 = listen_key（グループの共有公開鍵）
          ['group_id', groupId], // ⚠️ Phase 9.2で削除予定
        ],
        randomizeTimestamp: true, // ✅ タイムスタンプランダム化
      );
      
      if (eventId != null) {
        AppLogger.info('✅ [MLS] Group TODO sent with Phase 9.1 privacy');
        AppLogger.info('   Event ID: ${eventId.substring(0, 16)}...');
      }
      
      return eventId;
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] Failed to send group TODO', error: e, stackTrace: stackTrace);
      return null;
    }
  }
  
  /// Phase 8.3: MLSグループTODOイベントを取得（一度に全て取得）
  /// 
  /// Listen Keyで受信したKind 1059イベントを全て取得
  /// 
  /// [listenKey]: Export SecretからMLSで導出した受信用公開鍵
  /// [groupId]: グループID（フィルタリング用）
  Future<List<rust_api.ReceivedEvent>> fetchMlsGroupTodoEvents({
    required String listenKey,
    required String groupId,
  }) async {
    try {
      AppLogger.info('📥 [MLS] Fetching MLS group todo events');
      AppLogger.info('   Listen Key: ${listenKey.substring(0, 16)}...');
      AppLogger.info('   Group ID: $groupId');
      
      if (_subscriptionService == null) {
        throw Exception('Subscription service not initialized');
      }
      
      // NIP-17: Kind 1059（Seal）で取得
      // #p タグ = listen_key で受信
      final filters = [
        {
          'kinds': [1059], // NIP-17 Seal
          '#p': [listenKey], // 受信者 = listen_key
        }
      ];
      
      final events = <rust_api.ReceivedEvent>[];
      
      await _subscriptionService!.startSubscription(
        filters: filters,
        onEventsReceived: (receivedEvents) {
          AppLogger.debug('📦 [MLS] Received ${receivedEvents.length} sealed events');
          events.addAll(receivedEvents);
        },
      );
      
      // 少し待機してイベント受信を待つ（最大3秒）
      await Future<void>.delayed(const Duration(seconds: 3));
      
      AppLogger.info('📦 [MLS] Fetched ${events.length} sealed events for listen key');
      
      return events;
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] Failed to fetch MLS group todo events', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// ✅ 体感改善: MLS sealed(kind:1059) を since で差分取得（短タイムアウト）
  ///
  /// [since]: 取得開始時刻（この時刻以降のイベントを取得）
  Future<List<rust_api.ReceivedEvent>> fetchMlsGroupTodoEventsSince({
    required String listenKey,
    required DateTime since,
    int timeoutSeconds = 3,
  }) async {
    try {
      final sinceSec = since.millisecondsSinceEpoch ~/ 1000;
      final events = await rust_api.fetchMlsGroupTodoEventsSince(
        listenKey: listenKey,
        since: sinceSec,
        timeoutSecs: BigInt.from(timeoutSeconds),
      );
      return events;
    } catch (e, st) {
      AppLogger.error('❌ [MLS] Failed to fetch MLS group todo events (since)', error: e, stackTrace: st);
      return [];
    }
  }
  
  /// Phase 8.3: MLSグループTODOを受信（listen_key購読 - リアルタイム）
  /// 
  /// Keychatパターンに従い、NIP-17 (Gift Wrap) を受信
  /// 
  /// [listenKey]: Export SecretからMLSで導出した受信用公開鍵
  /// [groupId]: グループID
  /// [onTodoReceived]: TODO受信時のコールバック
  Future<void> subscribeMlsGroupTodos({
    required String listenKey,
    required String groupId,
    required void Function(String encryptedContent) onTodoReceived,
  }) async {
    try {
      AppLogger.info('📡 [MLS] Starting subscription for group TODOs');
      AppLogger.info('   Listen Key: ${listenKey.substring(0, 16)}...');
      AppLogger.info('   Group ID: $groupId');
      
      if (_subscriptionService == null) {
        throw Exception('Subscription service not initialized');
      }
      
      // NIP-17: Kind 1059（Seal）で購読
      // #p タグ = listen_key で受信
      final filters = [
        {
          'kinds': [1059], // NIP-17 Seal
          '#p': [listenKey], // 受信者 = listen_key
        }
      ];
      
      await _subscriptionService!.startSubscription(
        filters: filters,
        onEventsReceived: (events) {
          AppLogger.debug('📥 [MLS] Received ${events.length} sealed events');
          
          for (final event in events) {
            try {
              // event_jsonをパースしてcontentを取得
              final eventData = jsonDecode(event.eventJson) as Map<String, dynamic>;
              final encryptedContent = eventData['content'] as String;
              
              // group_idタグをチェック（このグループ宛か確認）
              final tags = eventData['tags'] as List<dynamic>?;
              if (tags != null) {
                final groupIdTag = tags.firstWhere(
                  (tag) => tag is List && tag.isNotEmpty && tag[0] == 'group_id',
                  orElse: () => null,
                );
                
                if (groupIdTag != null && groupIdTag[1] != groupId) {
                  // 別のグループ宛のメッセージ
                  AppLogger.debug('⏭️  [MLS] Skipping message for different group');
                  continue;
                }
              }
              
              // コールバックを呼び出し
              onTodoReceived(encryptedContent);
              
              AppLogger.debug('✅ [MLS] Processed TODO event: ${event.eventId.substring(0, 16)}...');
            } catch (e) {
              AppLogger.error('❌ [MLS] Failed to process TODO event', error: e);
            }
          }
        },
      );
      
      AppLogger.info('✅ [MLS] Subscription started for group $groupId');
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MLS] Failed to subscribe to group TODOs', error: e, stackTrace: stackTrace);
    }
  }
}
