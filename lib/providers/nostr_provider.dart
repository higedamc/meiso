import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge_generated.dart/api.dart' as rust_api;
import '../models/todo.dart';
import '../models/link_preview.dart';
import '../models/recurrence_pattern.dart';
import '../models/custom_list.dart';
import '../models/task_link.dart';
import '../models/app_settings.dart';
import '../models/relay_config.dart';
import '../features/custom_list/domain/entities/gw17_group_message.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/nostr_cache_service.dart';
import '../services/nostr_subscription_service.dart';
import '../services/amber_service.dart';
import 'sync_status_provider.dart';
import 'relay_status_provider.dart';
import '../utils/error_handler.dart';
import '../utils/nostr_relay_user_agent.dart';

/// デフォルトのNostrリレーリスト
const List<String> defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
  'wss://nostr.wine',
];

/// Canonical Citrine local relay endpoint.
const String citrineRelayEndpoint = 'ws://localhost:4869';

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
final Provider<NostrCacheService> nostrCacheServiceProvider = Provider((ref) {
  final service = NostrCacheService();
  // 初期化は非同期なので、別途initメソッドを呼ぶ必要がある
  return service;
});

/// Nostr Subscriptionサービスを提供するProvider
final Provider<NostrSubscriptionService> nostrSubscriptionServiceProvider =
    Provider((ref) {
      return NostrSubscriptionService();
    });

/// NostrServiceを提供するProvider
final Provider<NostrService> nostrServiceProvider = Provider(NostrService.new);

/// Result of the three-tier send: Hive (implicit) -> Global relays -> Local relay (Citrine)
class RelaySendResult {
  const RelaySendResult({
    required this.primarySendResult,
    required this.localBackfillQueued,
  });

  final rust_api.EventSendResult primarySendResult;
  final bool localBackfillQueued;
}

@Deprecated('Use RelaySendResult instead')
typedef LocalFirstSendResult = RelaySendResult;

class NostrService {
  NostrService(this._ref);

  final Ref _ref;

  /// キャッシュサービスへの参照
  NostrCacheService? _cacheService;

  /// Subscriptionサービスへの参照
  NostrSubscriptionService? _subscriptionService;

  Future<void> Function(String eventId, bool success, String? errorMessage)?
  _globalBackfillResultHandler;
  bool _processingBackfillQueue = false;
  static const String _localRelayClientId = 'local_first_client';
  static const String _globalRelayClientId = 'global_backfill_client';

  /// 暗号化鍵ファイルのパスを取得
  Future<String> _getKeyStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/nostr_key.enc';
  }

  /// Subscriptionを停止（購読解除）
  Future<void> stopSubscription(String subscriptionId) async {
    _subscriptionService ??= _ref.read(nostrSubscriptionServiceProvider);
    await _subscriptionService!.stopSubscription(subscriptionId);
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
    return rust_api.generateSecretKey();
  }

  /// Relay WebSocket User-Agent (#130) and NIP-89 toggle (#131) before any relay connect.
  Future<void> _applyRelayConnectionMetadata() async {
    try {
      final ua = await buildNostrRelayUserAgent();
      await rust_api.setRelayWebsocketUserAgent(userAgent: ua);
    } catch (e, st) {
      AppLogger.warning('Relay User-Agent not set', error: e, stackTrace: st);
    }
    try {
      final s = await localStorageService.loadAppSettings();
      final enabled = s?.nip89ClientTagEnabled ?? true;
      await rust_api.setNip89ClientTagEnabled(enabled: enabled);
    } catch (e, st) {
      AppLogger.warning('NIP-89 client tag flag not set', error: e, stackTrace: st);
    }
  }

  /// Nostrクライアントを初期化（秘密鍵を使用）
  Future<String> initializeNostr({
    required String secretKey,
    List<String>? relays,
    TorMode? torMode,
    String? proxyUrl,
  }) async {
    final relayList = relays ?? defaultRelays;
    final effectiveTorMode = torMode ?? TorMode.disabled;

    await _applyRelayConnectionMetadata();

    // TorMode に応じて接続方法を選択
    final String publicKey;

    switch (effectiveTorMode) {
      case TorMode.disabled:
        // 直接接続（Torなし）
        AppLogger.debug('🔓 Connecting directly (no Tor)');
        publicKey = await rust_api.initNostrClient(
          secretKeyHex: secretKey,
          relays: relayList,
        );
        break;

      case TorMode.internal:
        // 内蔵Tor (Embedded Tor)
        AppLogger.debug('🧅 Connecting via embedded Tor');
        publicKey = await rust_api.initNostrClientWithTorMode(
          secretKeyHex: secretKey,
          relays: relayList,
          torMode: rust_api.TorMode.internal,
          proxyUrl: null,
        );
        break;

      case TorMode.orbot:
        // Orbot経由 (SOCKS5 Proxy)
        final effectiveProxyUrl = proxyUrl ?? 'socks5://127.0.0.1:9050';
        AppLogger.debug('🔐 Connecting via Orbot proxy: $effectiveProxyUrl');
        publicKey = await rust_api.initNostrClientWithTorMode(
          secretKeyHex: secretKey,
          relays: relayList,
          torMode: rust_api.TorMode.orbot,
          proxyUrl: effectiveProxyUrl,
        );
        break;
    }

    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    _ref.read(relayStatusProvider.notifier).initializeAsConnected(relayList);

    await localStorageService.setUseAmber(false);
    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    await _initializeCacheAndSubscription(publicKey);
    unawaited(processGlobalBackfillQueue());

    final modeStr = effectiveTorMode == TorMode.disabled
        ? ''
        : effectiveTorMode == TorMode.internal
        ? ' (via embedded Tor)'
        : ' (via Orbot proxy)';
    AppLogger.info('✅ Nostr client initialized with secret key$modeStr');
    return publicKey;
  }

  /// Nostrクライアントを初期化（公開鍵のみ - Amber使用時）
  Future<String> initializeNostrWithPubkey({
    required String publicKeyHex,
    List<String>? relays,
    TorMode? torMode,
    String? proxyUrl,
  }) async {
    final relayList = relays ?? defaultRelays;
    final effectiveTorMode = torMode ?? TorMode.disabled;

    await _applyRelayConnectionMetadata();

    // TorMode に応じて接続方法を選択
    final String publicKey;

    switch (effectiveTorMode) {
      case TorMode.disabled:
        // 直接接続（Torなし）
        AppLogger.debug('🔓 Connecting directly (no Tor, Amber mode)');
        publicKey = await rust_api.initNostrClientWithPubkey(
          publicKeyHex: publicKeyHex,
          relays: relayList,
        );
        break;

      case TorMode.internal:
        // 内蔵Tor (Embedded Tor)
        AppLogger.debug('🧅 Connecting via embedded Tor (Amber mode)');
        publicKey = await rust_api.initNostrClientWithPubkeyAndTorMode(
          publicKeyHex: publicKeyHex,
          relays: relayList,
          torMode: rust_api.TorMode.internal,
          proxyUrl: null,
        );
        break;

      case TorMode.orbot:
        // Orbot経由 (SOCKS5 Proxy)
        final effectiveProxyUrl = proxyUrl ?? 'socks5://127.0.0.1:9050';
        AppLogger.debug(
          '🔐 Connecting via Orbot proxy (Amber mode): $effectiveProxyUrl',
        );
        publicKey = await rust_api.initNostrClientWithPubkeyAndTorMode(
          publicKeyHex: publicKeyHex,
          relays: relayList,
          torMode: rust_api.TorMode.orbot,
          proxyUrl: effectiveProxyUrl,
        );
        break;
    }

    _ref.read(publicKeyProvider.notifier).state = publicKey;
    _ref.read(nostrInitializedProvider.notifier).state = true;
    _ref.read(relayStatusProvider.notifier).initializeAsConnected(relayList);

    try {
      final npubKey = await rust_api.hexToNpub(hex: publicKey);
      _ref.read(nostrPublicKeyProvider.notifier).state = npubKey;
      AppLogger.info('ℹ️ npub公開鍵を設定しました: ${npubKey.substring(0, 16)}...');
    } catch (e) {
      AppLogger.error('❌ hex→npub変換エラー: $e');
    }

    await localStorageService.setUseAmber(true);

    await _initializeCacheAndSubscription(publicKey);
    unawaited(processGlobalBackfillQueue());

    _ref.read(syncStatusProvider.notifier).setInitialized(true);

    final modeStr = effectiveTorMode == TorMode.disabled
        ? ''
        : effectiveTorMode == TorMode.internal
        ? ' (via embedded Tor)'
        : ' (via Orbot proxy)';
    AppLogger.info('✅ Nostr client initialized in Amber mode$modeStr');
    return publicKey;
  }

  /// TodoリストをNostrに作成（Kind 30001 - 新実装）
  Future<rust_api.EventSendResult> createTodoListOnNostr(
    List<Todo> todos,
  ) async {
    AppLogger.debug(
      ' NostrProvider: createTodoListOnNostr called with ${todos.length} todos',
    );

    // カスタムリストIDを持つTodoをログ
    final customListTodos = todos.where((t) => t.customListId != null).toList();
    if (customListTodos.isNotEmpty) {
      AppLogger.debug(
        ' NostrProvider: ${customListTodos.length} todos have customListId:',
      );
      for (final todo in customListTodos) {
        AppLogger.debug(
          '   - "${todo.title}" → customListId: ${todo.customListId}',
        );
      }
    }

    final todoDataList = todos.map<rust_api.TodoData>((todo) {
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
        customListId: CustomListHelpers.normalizeListIdFromNostr(
          todo.customListId,
        ),
        parentTaskId: todo.parentTaskId,
        depth: todo.depth,
        taskLinks: todo.taskLinks.isNotEmpty
            ? jsonEncode(todo.taskLinks.map((l) => l.toJson()).toList())
            : null,
        imageUrl: todo.imageUrl,
      );

      // カスタムリストIDが設定されている場合のみログ
      if (todoData.customListId != null) {
        AppLogger.debug(
          ' Sending TodoData to Rust: "${todoData.title}" with customListId: ${todoData.customListId}',
        );
      }

      return todoData;
    }).toList();

    AppLogger.debug(
      ' Calling Rust createTodoList with ${todoDataList.length} TodoData objects',
    );
    final result = await rust_api.createTodoList(todos: todoDataList);
    AppLogger.info(
      ' Rust createTodoList completed: success=${result.success}, eventId=${result.eventId}',
    );

    return result;
  }

  /// NostrからTodoリストを同期（Kind 30001 - 新実装）
  Future<List<Todo>> syncTodoListFromNostr() async {
    AppLogger.debug(' NostrProvider: syncTodoListFromNostr called');
    final todoDataList = await rust_api.syncTodoList();
    AppLogger.debug(
      ' Received ${todoDataList.length} TodoData objects from Rust',
    );

    // カスタムリストIDを持つTodoDataをログ
    final customListTodoData = todoDataList
        .where((t) => t.customListId != null)
        .toList();
    if (customListTodoData.isNotEmpty) {
      AppLogger.debug(
        ' NostrProvider: ${customListTodoData.length} TodoData have customListId:',
      );
      for (final todoData in customListTodoData) {
        AppLogger.debug(
          '   - "${todoData.title}" → customListId: ${todoData.customListId}',
        );
      }
    } else {
      AppLogger.warning(' NostrProvider: No TodoData with customListId found');
    }

    return todoDataList.map((todoData) {
      return _todoDataToTodo(todoData);
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
      return _todoDataToTodo(todoData);
    }).toList();
  }

  /// TodoData → Todo 変換（Nostr受信時の共通ロジック）
  Todo _todoDataToTodo(rust_api.TodoData todoData) {
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

    List<TaskLink> taskLinks = [];
    if (todoData.taskLinks != null) {
      try {
        final decoded = jsonDecode(todoData.taskLinks!) as List;
        taskLinks = decoded
            .map((e) => TaskLink.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        AppLogger.warning(' Failed to parse taskLinks: $e');
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
      customListId: CustomListHelpers.normalizeListIdFromNostr(
        todoData.customListId,
      ),
      parentTaskId: todoData.parentTaskId,
      depth: todoData.depth,
      taskLinks: taskLinks,
      imageUrl: todoData.imageUrl,
    );
  }

  // ========================================
  // Amberモード専用メソッド
  // ========================================

  /// Amberモード: 署名済みイベントをリレーに送信
  Future<rust_api.EventSendResult> sendSignedEvent(
    String signedEventJson,
  ) async {
    return rust_api.sendSignedEvent(eventJson: signedEventJson);
  }

  void setGlobalBackfillResultHandler(
    Future<void> Function(String eventId, bool success, String? errorMessage)?
    handler,
  ) {
    _globalBackfillResultHandler = handler;
  }

  /// Three-tier send: Global relays (primary) -> Local relay (Citrine, backfill)
  ///
  /// Global relays are the source of truth. Local relay is supplementary
  /// for faster reads. If local relay is down, the send still succeeds.
  Future<RelaySendResult> sendSignedEventGlobalFirst(
    String signedEventJson,
  ) async {
    final relaySplit = await _resolveRelaySplit();
    final localRelays = relaySplit.$1;
    final globalRelays = relaySplit.$2;

    final primaryRelays = globalRelays.isNotEmpty
        ? globalRelays
        : defaultRelays;

    // Send to global relays (primary)
    await _ensureClientForRelays(
      clientId: _globalRelayClientId,
      relays: primaryRelays,
    );
    final globalSend = await rust_api.sendSignedEventWithClientId(
      eventJson: signedEventJson,
      clientId: _globalRelayClientId,
    );

    // Queue local relay backfill (non-blocking, fire-and-forget)
    var localQueued = false;
    if (globalSend.success && localRelays.isNotEmpty) {
      await _enqueueLocalBackfill(
        signedEventJson: signedEventJson,
        eventId: globalSend.eventId,
        localRelays: localRelays,
      );
      localQueued = true;
      unawaited(processLocalBackfillQueue());
    }

    return RelaySendResult(
      primarySendResult: globalSend,
      localBackfillQueued: localQueued,
    );
  }

  /// Backward-compatible alias
  Future<RelaySendResult> sendSignedEventLocalFirst(
    String signedEventJson,
  ) async {
    return sendSignedEventGlobalFirst(signedEventJson);
  }

  /// Process the local relay backfill queue (sends pending events to Citrine).
  Future<void> processLocalBackfillQueue() async {
    if (_processingBackfillQueue) return;
    _processingBackfillQueue = true;

    try {
      final queue = localStorageService.loadGlobalBackfillQueue();
      if (queue.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      for (final item in queue) {
        final retries = (item['retries'] as int?) ?? 0;
        final eventJson = item['event_json'] as String?;
        final eventId = item['event_id'] as String?;
        // Support both old 'global_relays' key and new 'local_relays' key
        final relays =
            ((item['local_relays'] ?? item['global_relays']) as List?)
                ?.map((r) => r.toString())
                .toList() ??
            <String>[];

        if (eventJson == null || eventId == null || relays.isEmpty) {
          continue;
        }

        try {
          await _ensureClientForRelays(
            clientId: _localRelayClientId,
            relays: relays,
          );
          final result = await rust_api.sendSignedEventWithClientId(
            eventJson: eventJson,
            clientId: _localRelayClientId,
          );

          if (result.success) {
            if (_globalBackfillResultHandler != null) {
              await _globalBackfillResultHandler!(eventId, true, null);
            }
            continue;
          }

          final nextRetries = retries + 1;
          if (nextRetries >= 3) {
            // Local relay failures are non-critical; drop after 3 retries
            AppLogger.debug(
              ' [Backfill] Dropping local relay backfill for $eventId after $nextRetries retries',
            );
            if (_globalBackfillResultHandler != null) {
              await _globalBackfillResultHandler!(
                eventId,
                false,
                result.errorMessage,
              );
            }
          } else {
            remaining.add({
              ...item,
              'retries': nextRetries,
              'last_error': result.errorMessage,
            });
          }
        } catch (e) {
          final nextRetries = retries + 1;
          if (nextRetries >= 3) {
            AppLogger.debug(
              ' [Backfill] Dropping local relay backfill for $eventId: $e',
            );
            if (_globalBackfillResultHandler != null) {
              await _globalBackfillResultHandler!(eventId, false, e.toString());
            }
          } else {
            remaining.add({
              ...item,
              'retries': nextRetries,
              'last_error': e.toString(),
            });
          }
        }
      }

      await localStorageService.saveGlobalBackfillQueue(remaining);
    } finally {
      _processingBackfillQueue = false;
    }
  }

  /// Backward-compatible alias
  Future<void> processGlobalBackfillQueue() async {
    return processLocalBackfillQueue();
  }

  Future<void> _enqueueLocalBackfill({
    required String signedEventJson,
    required String eventId,
    required List<String> localRelays,
  }) async {
    final queue = localStorageService.loadGlobalBackfillQueue();
    queue.add({
      'event_json': signedEventJson,
      'event_id': eventId,
      'local_relays': localRelays,
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await localStorageService.saveGlobalBackfillQueue(queue);
  }

  Future<(List<String>, List<String>)> resolveRelaySplit() async {
    return _resolveRelaySplit();
  }

  Future<void> updateActiveRelays(
    List<String> relays, {
    String? clientId,
  }) async {
    final uniqueRelays = relays.toSet().toList();
    if (uniqueRelays.isEmpty) return;

    if (clientId != null) {
      await _ensureClientForRelays(
        clientId: clientId,
        relays: uniqueRelays,
      );
      return;
    }

    final isAmberMode = _ref.read(isAmberModeProvider);
    if (isAmberMode) {
      final pubkey = _ref.read(publicKeyProvider);
      if (pubkey == null) {
        throw Exception('Public key is not initialized');
      }
      await _applyRelayConnectionMetadata();
      await rust_api.initNostrClientWithPubkey(
        publicKeyHex: pubkey,
        relays: uniqueRelays,
      );
      return;
    }

    await rust_api.updateRelayList(relays: uniqueRelays);
  }

  Future<(List<String>, List<String>)> _resolveRelaySplit() async {
    final settings = await localStorageService.loadAppSettings();
    final relays = settings?.relays.isNotEmpty == true
        ? settings!.relays
        : defaultRelays;
    final roleMap = localStorageService.loadRelayRoles();

    final local = <String>[];
    final global = <String>[];
    for (final relay in relays) {
      final explicitRole = roleMap[relay];
      if (explicitRole == RelayRole.local.name) {
        local.add(relay);
      } else if (explicitRole == RelayRole.global.name) {
        global.add(relay);
      } else if (isLikelyLocalRelayUrl(relay)) {
        local.add(relay);
      } else {
        global.add(relay);
      }
    }

    return (local, global);
  }

  Future<void> _ensureClientForRelays({
    required String clientId,
    required List<String> relays,
  }) async {
    final uniqueRelays = relays.toSet().toList();
    if (uniqueRelays.isEmpty) return;

    final isAmberMode = _ref.read(isAmberModeProvider);
    if (isAmberMode) {
      final pubkey = _ref.read(publicKeyProvider);
      if (pubkey == null) {
        throw Exception('Public key is not initialized');
      }
      await _applyRelayConnectionMetadata();
      await rust_api.initNostrClientWithPubkeyAndId(
        clientId: clientId,
        publicKeyHex: pubkey,
        relays: uniqueRelays,
      );
      return;
    }

    // Secret-key mode currently keeps using default client for signing flow.
    await rust_api.updateRelayListWithClientId(
      clientId: clientId,
      relays: uniqueRelays,
    );
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
    return rust_api.createUnsignedEncryptedTodoEvent(
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
    return rust_api.createUnsignedEncryptedTodoListEventWithListId(
      encryptedContent: encryptedContent,
      publicKeyHex: publicKey,
      listId: listId,
      listTitle: listTitle,
    );
  }

  /// Amberモード: すべての暗号化されたTodoリストイベント（Kind 30001）を取得
  Future<List<rust_api.EncryptedTodoListEvent>>
  fetchAllEncryptedTodoLists() async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    try {
      final result = await rust_api.fetchAllEncryptedTodoListsForPubkey(
        publicKeyHex: publicKey,
      );

      AppLogger.debug(
        '📥 [NostrProvider] Received ${result.length} encrypted todo list events',
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [NostrProvider] Failed to fetch encrypted todo lists: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Amberモード: すべての暗号化されたTodoリストイベント（Kind 30001）を差分取得
  ///
  /// [since] 以降のイベントのみ取得し、同一d-tagで最新のものだけ返す。
  Future<List<rust_api.EncryptedTodoListEvent>>
  fetchAllEncryptedTodoListsSince({
    required DateTime since,
    int timeoutSeconds = 3,
  }) async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    final sinceUnix = since.millisecondsSinceEpoch ~/ 1000;
    final timeout = timeoutSeconds <= 0 ? 1 : timeoutSeconds;

    return rust_api.fetchAllEncryptedTodoListsForPubkeySince(
      publicKeyHex: publicKey,
      since: sinceUnix,
      timeoutSecs: BigInt.from(timeout),
    );
  }

  /// 通常モード: すべてのTodoリストのメタデータ（d tag, title）を取得
  Future<List<rust_api.TodoListMetadata>> fetchAllTodoListMetadata() async {
    AppLogger.debug(' NostrProvider: fetchAllTodoListMetadata called');

    final metadata = await rust_api.fetchAllTodoListMetadata();
    AppLogger.debug(
      ' Received ${metadata.length} TodoListMetadata objects from Rust',
    );

    // カスタムリストのメタデータをログ
    final customListMetadata = metadata
        .where((m) => m.listId != null && m.listId!.startsWith('meiso-list-'))
        .toList();

    if (customListMetadata.isNotEmpty) {
      AppLogger.debug(
        ' NostrProvider: ${customListMetadata.length} custom list metadata found:',
      );
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

    return rust_api.fetchEncryptedTodoListForPubkey(
      publicKeyHex: publicKey,
    );
  }

  /// Amberモード: 暗号化されたTodoイベントを取得（復号化はAmber側で行う）- 旧実装
  Future<List<rust_api.EncryptedTodoEvent>> fetchEncryptedTodos() async {
    final publicKey = _ref.read(publicKeyProvider);
    if (publicKey == null) {
      throw Exception('公開鍵が設定されていません');
    }

    return rust_api.fetchEncryptedTodosForPubkey(
      publicKeyHex: publicKey,
    );
  }

  /// npub形式の公開鍵をhex形式に変換
  Future<String> npubToHex(String npub) async {
    return rust_api.npubToHex(npub: npub);
  }

  /// hex形式の公開鍵をnpub形式に変換
  Future<String> hexToNpub(String hex) async {
    return rust_api.hexToNpub(hex: hex);
  }

  /// リレーサーバーへ再接続
  /// バックグラウンドから復帰時などに使用
  Future<void> reconnectRelays() async {
    AppLogger.info(' Reconnecting to relays...');
    try {
      await rust_api.reconnectToRelays();
      _ref.read(relayStatusProvider.notifier).markAllConnected();
      AppLogger.info(' Successfully reconnected to relays');
    } catch (e) {
      _ref.read(relayStatusProvider.notifier).markAllDisconnected();
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
      await rust_api.reconnectToRelaysWithTimeout(
        timeoutSecs: BigInt.from(timeout),
      );
      _ref.read(relayStatusProvider.notifier).markAllConnected();
      AppLogger.info(' Successfully reconnected to relays');
    } catch (e) {
      _ref.read(relayStatusProvider.notifier).markAllDisconnected();
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
  Future<rust_api.EventSendResult> deleteEvents(
    List<String> eventIds, {
    String? reason,
  }) async {
    return rust_api.deleteEvents(
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
        },
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
    return _cacheService!.getCachedEvent(eventId);
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
      AppLogger.debug(
        '🔍 Fetching Key Package for: ${npub.substring(0, 20)}...',
      );

      // Phase 8.2.1: リトライ + タイムアウト
      final keyPackage = await ErrorHandler.retryWithBackoff<String?>(
        operation: () => ErrorHandler.withTimeout<String?>(
          operation: () => rust_api.fetchKeyPackageByNpub(npub: npub),
          operationName: 'fetchKeyPackageByNpub',
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
      AppLogger.info(
        '📤 [Invitation] Sending group invitation to: ${recipientNpub.substring(0, 20)}...',
      );

      // 公開鍵を取得
      final senderPubkeyHex = await getPublicKey();
      if (senderPubkeyHex == null) {
        throw Exception('Sender public key not available');
      }

      final senderNpub = await hexToNpub(senderPubkeyHex);

      // 未署名イベントを作成
      final unsignedEventJson = await rust_api
          .createUnsignedGroupInvitationEvent(
            senderPublicKeyHex: senderPubkeyHex,
            recipientNpub: recipientNpub,
            groupId: groupId,
            groupName: groupName,
            welcomeMsgBase64: welcomeMsgBase64,
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
        AppLogger.warning(
          '[Invitation] ContentProvider failed (${e.code}), using UI method',
        );
        signedEvent = await amberService.signEventWithTimeout(
          unsignedEventJson,
        );
        AppLogger.debug('✅ [Invitation] Signed via UI');
      }

      // リレーに送信
      final sendResult = await sendSignedEvent(signedEvent);

      AppLogger.info('✅ [Invitation] Group invitation sent successfully');
      AppLogger.info('   Event ID: ${sendResult.eventId.substring(0, 16)}...');

      return sendResult.eventId;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [Invitation] Failed to send group invitation',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> sendGw17GroupInvitation({
    required String recipientNpub,
    required String groupId,
    required String groupName,
    String? inviterName,
  }) async {
    try {
      final senderPubkey = await getPublicKey();
      if (senderPubkey == null) {
        throw Exception('Sender public key not available');
      }
      final recipientPubkeyHex = await npubToHex(recipientNpub);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = Gw17GroupMessage(
        type: Gw17MessageType.invitation,
        groupId: groupId,
        groupName: groupName,
        protocolVersion: CustomListHelpers.protocolGw17V1,
        senderPubkey: senderPubkey,
        createdAtSec: nowSec,
      ).toJson()..['inviter_name'] = inviterName;

      return sendGiftWrappedEvent(
        content: jsonEncode(payload),
        kind: 1059,
        tags: [
          ['p', recipientPubkeyHex],
          ['client', 'meiso'],
          ['protocol', CustomListHelpers.protocolGw17V1],
          ['t', 'group-invitation'],
          ['g', groupId],
        ],
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [GW17] Failed to send group invitation',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<String?> sendGw17TodoUpdate({
    required String recipientPubkeyHex,
    required String groupId,
    required String groupName,
    required String action,
    required Map<String, dynamic> todoPayload,
  }) async {
    try {
      final senderPubkey = await getPublicKey();
      if (senderPubkey == null) {
        throw Exception('Sender public key not available');
      }
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = Gw17GroupMessage(
        type: Gw17MessageType.todoUpdate,
        groupId: groupId,
        groupName: groupName,
        protocolVersion: CustomListHelpers.protocolGw17V1,
        senderPubkey: senderPubkey,
        createdAtSec: nowSec,
        action: action,
        todo: todoPayload,
      ).toJson();

      return sendGiftWrappedEvent(
        content: jsonEncode(payload),
        kind: 1059,
        tags: [
          ['p', recipientPubkeyHex],
          ['client', 'meiso'],
          ['protocol', CustomListHelpers.protocolGw17V1],
          ['t', 'todo-update'],
          ['g', groupId],
        ],
      );
    } catch (e, st) {
      AppLogger.error(
        '❌ [GW17] Failed to send todo update',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<List<Gw17GroupMessage>> fetchGw17Messages({
    required DateTime since,
    String? groupId,
    Gw17MessageType? type,
  }) async {
    try {
      final publicKey = await getPublicKey();
      if (publicKey == null) return const [];
      final sinceSec = since.millisecondsSinceEpoch ~/ 1000;
      final events = await rust_api.fetchMlsGroupTodoEventsSince(
        listenKey: publicKey,
        since: sinceSec,
        timeoutSecs: BigInt.from(5),
      );
      final out = <Gw17GroupMessage>[];
      final seenIds = <String>{};
      for (final event in events) {
        if (seenIds.contains(event.eventId)) continue;
        seenIds.add(event.eventId);

        final raw = jsonDecode(event.eventJson);
        if (raw is! Map<String, dynamic>) continue;
        final tags = raw['tags'];
        if (tags is! List) continue;
        final hasClientTag = _hasTag(tags, 'client', 'meiso');
        final hasProtocolTag = _hasTag(
          tags,
          'protocol',
          CustomListHelpers.protocolGw17V1,
        );
        if (!hasClientTag || !hasProtocolTag) continue;
        if (groupId != null && !_hasTag(tags, 'g', groupId)) continue;
        final content = raw['content'] as String?;
        if (content == null || content.isEmpty) continue;
        final message = Gw17GroupMessage.fromJsonString(content);
        if (message == null) continue;
        if (type != null && message.type != type) continue;
        out.add(message.copyWith(eventId: event.eventId));
      }
      return out;
    } catch (e, st) {
      AppLogger.error(
        '❌ [GW17] Failed to fetch messages',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  bool _hasTag(List<dynamic> tags, String key, String value) {
    for (final t in tags) {
      if (t is List && t.length >= 2 && t[0] == key && t[1] == value) {
        return true;
      }
    }
    return false;
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
        AppLogger.debug('   前回公開: $hoursSincePublish時間前');

        // 24時間以内なら公開しない
        if (hoursSincePublish < 24) {
          AppLogger.info(
            '✅ [KeyPackage] Key Packageは最新です（$hoursSincePublish時間前に公開済み）',
          );
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
      AppLogger.error(
        '❌ [KeyPackage] 自動公開エラー',
        error: e,
        stackTrace: stackTrace,
      );
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
      const relays = defaultRelays;

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
    const twoDaysInSeconds = 2 * 24 * 60 * 60; // 172800秒
    final random = Random.secure();

    // -2日 ～ +2日の範囲でランダム化
    final offset = random.nextInt(twoDaysInSeconds * 2) - twoDaysInSeconds;
    final randomizedTimestamp = now + offset;

    AppLogger.debug(
      '🎲 [NIP-17] Randomized timestamp: $now → $randomizedTimestamp (offset: ${offset}s)',
    );

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
      final timestamp = randomizeTimestamp
          ? _randomizeTimestamp()
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
      AppLogger.error(
        '❌ [NIP-17] Failed to send gift wrapped event',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// NIP-EE: MLS Group Event を送信（kind:445 + `h` tag）
  ///
  /// 最新仕様（@/Users/apple/work/nips/EE.md）では、
  /// グループ内メッセージは `kind:445` で配布し、`tags:[["h", <group id>]]` でルーティングする。
  /// `content` は exporter_secret 由来のキーで NIP-44(v2) 暗号化された MLSMessage（ここでは hex）。
  ///
  /// [encryptedContent]: MLS暗号化済みメッセージ（hex / mlsAddTodo の戻り値）
  /// [groupId]: グループID（h tag）
  Future<String?> sendMlsGroupTodo({
    required String encryptedContent,
    required String groupId,
  }) async {
    try {
      final publicKey = await getPublicKey();
      if (publicKey == null) {
        throw Exception('User public key not available');
      }

      AppLogger.debug('📤 [MLS] Sending MLS group event (kind:445)');
      AppLogger.debug('   Group ID (h): $groupId');
      AppLogger.debug(
        '   MLS payload(hex) size: ${encryptedContent.length} bytes',
      );

      // NIP-EE: exporter_secret 由来のキーで NIP-44 暗号化（Rust内で実施）
      final encryptedNip44 = await rust_api.mlsEncryptGroupEventContent(
        nostrId: publicKey,
        groupId: groupId,
        mlsMessageHex: encryptedContent,
      );

      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final unsignedEvent = jsonEncode({
        'kind': 445,
        'created_at': createdAt,
        'tags': [
          ['h', groupId],
        ],
        'content': encryptedNip44,
      });

      final signedEventJson = await rust_api.signEventWithEphemeralKey(
        unsignedEventJson: unsignedEvent,
      );

      final sendResult = await rust_api.sendSignedEvent(
        eventJson: signedEventJson,
      );

      AppLogger.info('✅ [MLS] Group event sent (kind:445)');
      AppLogger.info('   Event ID: ${sendResult.eventId.substring(0, 16)}...');
      AppLogger.info('   Success: ${sendResult.success}');
      AppLogger.info('   Successful relays: ${sendResult.successfulRelays}');
      AppLogger.info('   Failed relays: ${sendResult.failedRelays}');
      AppLogger.info('   Timed out: ${sendResult.timedOut}');

      if (sendResult.errorMessage != null) {
        AppLogger.warning('   Error: ${sendResult.errorMessage}');
      }

      // 🔥 重要: 少なくとも1つのリレーに成功していない場合はnullを返す
      if (sendResult.successfulRelays == 0) {
        AppLogger.error('❌ [MLS] Failed to send to any relay!');
        return null;
      }

      return sendResult.eventId;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [MLS] Failed to send group event (kind:445)',
        error: e,
        stackTrace: stackTrace,
      );
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
    required String groupId,
  }) async {
    try {
      AppLogger.info('📥 [MLS] Fetching MLS group todo events');
      AppLogger.info('   Group ID: $groupId');

      if (_subscriptionService == null) {
        throw Exception('Subscription service not initialized');
      }

      // NIP-EE: kind:445 + #h で取得
      final filters = [
        {
          'kinds': [445], // NIP-EE: Group Event
          '#h': [groupId],
        },
      ];

      final events = <rust_api.ReceivedEvent>[];

      final subscriptionId = await _subscriptionService!.startSubscription(
        filters: filters,
        onEventsReceived: (receivedEvents) {
          AppLogger.debug(
            '📦 [MLS] Received ${receivedEvents.length} group events',
          );
          events.addAll(receivedEvents);
        },
      );

      // 少し待機してイベント受信を待つ（最大3秒）
      await Future<void>.delayed(const Duration(seconds: 3));

      await _subscriptionService!.stopSubscription(subscriptionId);

      AppLogger.info(
        '📦 [MLS] Fetched ${events.length} group events for groupId',
      );

      return events;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [MLS] Failed to fetch MLS group todo events',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// ✅ 体感改善: MLS group events(kind:445) を since で差分取得（短タイムアウト）
  ///
  /// [since]: 取得開始時刻（この時刻以降のイベントを取得）
  /// Phase 8.3 Fix: subscription方式から fetch_events() に変更
  ///
  /// より確実にイベントを取得するため、Rust側の fetch_events() を直接使用する
  Future<List<rust_api.ReceivedEvent>> fetchMlsGroupTodoEventsSince({
    required String groupId,
    required DateTime since,
    int timeoutSeconds = 5,
  }) async {
    try {
      final sinceSec = since.millisecondsSinceEpoch ~/ 1000;

      AppLogger.debug('📡 [MLS] Fetching events with filter (fetch_events):');
      AppLogger.debug('   kinds: [445]');
      AppLogger.debug('   #h: [$groupId]');
      AppLogger.debug('   since: $sinceSec (${since.toIso8601String()})');

      // 🔥 Phase 8.3 Fix: subscription方式ではなく、one-shot fetch を使用
      final events = await rust_api.fetchMlsGroupEventsByGroupId(
        groupId: groupId,
        since: sinceSec, // PlatformInt64 = int
        timeoutSecs: BigInt.from(timeoutSeconds), // BigInt
      );

      AppLogger.info(
        '📨 [MLS] Received ${events.length} events for group $groupId',
      );

      return events;
    } catch (e, st) {
      AppLogger.error(
        '❌ [MLS] Failed to fetch MLS group todo events (since)',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Phase 8.3: MLSグループTODOを受信（listen_key購読 - リアルタイム）
  ///
  /// Keychatパターンに従い、NIP-17 (Gift Wrap) を受信
  ///
  /// [listenKey]: Export SecretからMLSで導出した受信用公開鍵
  /// [groupId]: グループID
  /// [onEventsReceived]: TODO受信時のコールバック（ReceivedEvent単位）
  ///
  /// Returns: subscriptionId（停止に使用）
  Future<String> subscribeMlsGroupTodos({
    required String groupId,
    required void Function(List<rust_api.ReceivedEvent> events)
    onEventsReceived,
  }) async {
    try {
      AppLogger.info('📡 [MLS] Starting subscription for group TODOs');
      AppLogger.info('   Group ID: $groupId');

      if (_subscriptionService == null) {
        throw Exception('Subscription service not initialized');
      }

      // NIP-EE: kind:445 + #h で購読
      final filters = [
        {
          'kinds': [445], // NIP-EE: Group Event
          '#h': [groupId],
        },
      ];

      final subscriptionId = await _subscriptionService!.startSubscription(
        filters: filters,
        onEventsReceived: (events) {
          AppLogger.debug('📥 [MLS] Received ${events.length} group events');
          onEventsReceived(events);
        },
      );

      AppLogger.info('✅ [MLS] Subscription started for group $groupId');
      return subscriptionId;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [MLS] Failed to subscribe to group TODOs',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
