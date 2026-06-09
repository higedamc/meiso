import 'package:hive_flutter/hive_flutter.dart';
import '../services/logger_service.dart';
import '../models/todo.dart';
import '../models/app_settings.dart';
import '../models/custom_list.dart';

/// ローカルストレージサービス（Hive使用）
/// Todoをローカルに永続化し、オフラインファーストを実現
class LocalStorageService {
  static const String _todosBoxName = 'todos';
  static const String _settingsBoxName = 'settings';
  static const String _customListsBoxName = 'custom_lists';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _useAmberKey = 'use_amber';
  static const String _appSettingsKey = 'app_settings';
  static const String _recurringTasksTipsDismissedKey =
      'recurring_tasks_tips_dismissed';
  static const String _languageKey = 'language';
  static const String _lastKeyPackagePublishTimeKey =
      'last_key_package_publish_time'; // Phase 8.1
  static const String _deletedEventIdsKey =
      'deleted_event_ids'; // Issue #80: kind 5削除イベント
  static const String _deletedListIdsKey =
      'deleted_list_ids'; // Issue #101: 削除済みリストID（永久ブラックリスト）
  static const String _deletedTodoIdsKey =
      'deleted_todo_ids'; // Issue #101: 削除済みタスクID（リスト再作成時の復活防止）
  static const String _deletedMlsGroupListIdsKey =
      'deleted_mls_group_list_ids'; // MLS: ローカル削除済みMLSグループリストID
  static const String _processedGw17EventIdsKey =
      'processed_gw17_event_ids'; // GW17: 処理済みイベントID（重複排除用）
  static const int _maxProcessedGw17EventIds = 2000;

  // === Sync state (Joplin-like) ===
  // 背景復帰/再起動時に「全履歴fetch」を避けるため、最終成功同期時刻を永続化する。
  static const String _lastTodoListSyncTimeKey = 'last_todo_list_sync_time';
  static const String _lastAppSettingsSyncTimeKey =
      'last_app_settings_sync_time';
  static const String _lastCustomListsSyncTimeKey =
      'last_custom_lists_sync_time';
  static const String _lastMlsGroupTodosSyncTimesKey =
      'last_mls_group_todos_sync_times';
  static const String _lastSharedGroupTodosSyncTimesKey =
      'last_shared_group_todos_sync_times';
  static const String _sharedGroupCredentialsKey = 'shared_group_credentials';
  static const String _relayRolesKey = 'relay_roles';
  static const String _globalBackfillQueueKey = 'global_backfill_queue';

  Box<Map<dynamic, dynamic>>? _todosBox;
  Box<dynamic>? _settingsBox;
  Box<Map<dynamic, dynamic>>? _customListsBox;

  /// Hiveを初期化
  Future<void> initialize() async {
    await Hive.initFlutter();
    _todosBox = await Hive.openBox<Map<dynamic, dynamic>>(_todosBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
    _customListsBox = await Hive.openBox<Map<dynamic, dynamic>>(
      _customListsBoxName,
    );
  }

  /// すべてのTodoを保存
  Future<void> saveTodos(List<Todo> todos) async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    // 既存データをクリア
    await _todosBox!.clear();

    // 新しいデータを保存
    for (final todo in todos) {
      await _todosBox!.put(todo.id, todo.toJson());
    }
  }

  /// すべてのTodoを取得
  Future<List<Todo>> loadTodos() async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final todos = <Todo>[];

    for (final value in _todosBox!.values) {
      try {
        // Mapをキャストして復元（deep copy）
        final jsonMap = _deepCastMap(value);
        todos.add(Todo.fromJson(jsonMap));
      } catch (e) {
        AppLogger.warning(' Todo復元エラー: $e');
        // エラーがあってもスキップして続行
        continue;
      }
    }

    return todos;
  }

  /// Mapをdeep copyでMap<String, dynamic>に変換
  Map<String, dynamic> _deepCastMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _deepCastMap(value));
        } else if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((e) {
              if (e is Map) {
                return _deepCastMap(e);
              }
              return e;
            }).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  /// 単一のTodoを保存
  Future<void> saveTodo(Todo todo) async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    await _todosBox!.put(todo.id, todo.toJson());
  }

  /// 単一のTodoを削除
  Future<void> deleteTodo(String id) async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    await _todosBox!.delete(id);
  }

  /// すべてのTodoデータをクリア
  Future<void> clearAll() async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    await _todosBox!.clear();
  }

  /// アプリ内の全データを完全に削除（ログアウト用）
  ///
  /// ログアウト後にローカルキャッシュから古いユーザーのデータが
  /// 再表示・再同期されないよう、すべての永続ストレージを消去する。
  ///
  /// 注意: 単純な `Box.clear()` は append-only な Hive のフレームを論理的に
  /// クリアするだけで、`.hive` ファイル上には旧データのバイト列が残る
  /// （forensic ツールで復元可能）。よって `close()` → `deleteBoxFromDisk()`
  /// → 同名で `openBox()` し直す手順で物理的にファイルを再生成する。
  Future<void> clearAllData() async {
    if (_todosBox == null ||
        _settingsBox == null ||
        _customListsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    // close() しないと `deleteBoxFromDisk` が同期失敗する場合があるため、
    // 既に保持している Box ハンドル経由で確実に閉じてから物理削除する。
    // Hive はジェネリクス引数まで含めて Box を識別するので、開いた時と同じ
    // 型引数で `box(name)` を呼ばないと `HiveError` が出る。よってフィールド
    // 経由でクローズする。
    await _todosBox!.close();
    await Hive.deleteBoxFromDisk(_todosBoxName);
    _todosBox = await Hive.openBox<Map<dynamic, dynamic>>(_todosBoxName);
    AppLogger.info(' Todoデータを物理削除しました');

    await _customListsBox!.close();
    await Hive.deleteBoxFromDisk(_customListsBoxName);
    _customListsBox =
        await Hive.openBox<Map<dynamic, dynamic>>(_customListsBoxName);
    AppLogger.info(' カスタムリストデータを物理削除しました');

    await _settingsBox!.close();
    await Hive.deleteBoxFromDisk(_settingsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
    AppLogger.info(' 設定データを物理削除しました');
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _todosBox?.close();
    await _settingsBox?.close();
    await _customListsBox?.close();
  }

  // === カスタムリスト関連 ===

  /// すべてのカスタムリストを保存
  Future<void> saveCustomLists(List<CustomList> lists) async {
    if (_customListsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    // 既存データをクリア
    await _customListsBox!.clear();

    // 新しいデータを保存
    for (final list in lists) {
      await _customListsBox!.put(list.id, list.toJson());
    }
  }

  /// すべてのカスタムリストを取得
  Future<List<CustomList>> loadCustomLists() async {
    if (_customListsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final lists = <CustomList>[];

    for (final value in _customListsBox!.values) {
      try {
        // Mapをキャストして復元（deep copy）
        final jsonMap = _deepCastMap(value);
        lists.add(CustomList.fromJson(jsonMap));
      } catch (e) {
        AppLogger.warning(' CustomList復元エラー: $e');
        // エラーがあってもスキップして続行
        continue;
      }
    }

    return lists;
  }

  // === オンボーディング関連 ===

  /// オンボーディングが完了しているかチェック
  bool hasCompletedOnboarding() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    return _settingsBox!.get(_onboardingCompletedKey, defaultValue: false)
        as bool;
  }

  /// オンボーディング完了フラグを設定
  Future<void> setOnboardingCompleted() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_onboardingCompletedKey, true);
  }

  // === Nostr認証情報関連 ===
  // 注意: 秘密鍵はRust側で暗号化保存されるため、ここでは管理しない

  /// Amber使用フラグを保存
  Future<void> setUseAmber(bool useAmber) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_useAmberKey, useAmber);
  }

  /// Amber使用フラグを取得
  bool isUsingAmber() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    return _settingsBox!.get(_useAmberKey, defaultValue: false) as bool;
  }

  /// Nostr認証情報をクリア（Amber使用フラグのみ）
  Future<void> clearNostrCredentials() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_useAmberKey);
  }

  // === マイグレーション関連 ===

  static const String _migrationCompletedKey = 'migration_kind30001_completed';

  /// マイグレーション（Kind 30078 → 30001）が完了しているかチェック
  Future<bool> isMigrationCompleted() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    return _settingsBox!.get(_migrationCompletedKey, defaultValue: false)
        as bool;
  }

  /// マイグレーション完了フラグをセット
  Future<void> setMigrationCompleted() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_migrationCompletedKey, true);
    AppLogger.info(' Migration completed flag set');
  }

  /// マイグレーション完了フラグをリセット（デバッグ用）
  Future<void> resetMigrationCompleted() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_migrationCompletedKey);
    AppLogger.info(' Migration completed flag reset');
  }

  // === アプリ設定関連 ===

  /// アプリ設定を保存
  Future<void> saveAppSettings(AppSettings settings) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_appSettingsKey, settings.toJson());
  }

  /// アプリ設定を読み込み
  Future<AppSettings?> loadAppSettings() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final settingsMap = _settingsBox!.get(_appSettingsKey);
    if (settingsMap == null) {
      return null;
    }

    try {
      final jsonMap = _deepCastMap(settingsMap);
      return AppSettings.fromJson(jsonMap);
    } catch (e) {
      AppLogger.warning(' アプリ設定復元エラー: $e');
      return null;
    }
  }

  // === Recurring Tasks Tips関連 ===

  /// Recurring Tasks Tipsが表示済みかチェック
  bool hasSeenRecurringTasksTips() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    return _settingsBox!.get(
          _recurringTasksTipsDismissedKey,
          defaultValue: false,
        )
        as bool;
  }

  /// Recurring Tasks Tipsを表示済みとしてマーク
  Future<void> markRecurringTasksTipsAsSeen() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_recurringTasksTipsDismissedKey, true);
  }

  // === 言語設定関連 ===

  /// 言語設定を保存
  Future<void> setLanguage(String languageCode) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_languageKey, languageCode);
  }

  /// 言語設定を取得
  String? getLanguage() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    return _settingsBox!.get(_languageKey) as String?;
  }

  /// 言語設定をクリア（システムデフォルトに戻す）
  Future<void> clearLanguage() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_languageKey);
  }

  // === Phase 8.1: Key Package自動公開関連 ===

  /// 最後にKey Packageを公開した時刻を保存
  Future<void> setLastKeyPackagePublishTime(DateTime dateTime) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(
      _lastKeyPackagePublishTimeKey,
      dateTime.toIso8601String(),
    );
  }

  /// 最後にKey Packageを公開した時刻を取得
  DateTime? getLastKeyPackagePublishTime() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final timeString =
        _settingsBox!.get(_lastKeyPackagePublishTimeKey) as String?;
    if (timeString == null) return null;

    try {
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// Key Package公開時刻をクリア
  Future<void> clearLastKeyPackagePublishTime() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_lastKeyPackagePublishTimeKey);
  }

  // === Issue #80: kind 5削除イベント管理（LWW対応） ===

  /// 削除済みイベントメタデータを保存（eventId -> deletion_created_at）
  Future<void> saveDeletedEventMetadata(Map<String, int> metadata) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_deletedEventIdsKey, metadata);
    AppLogger.info(
      '🗑️ Saved ${metadata.length} deleted event metadata to storage',
    );
  }

  /// 削除済みイベントメタデータを取得
  Future<Map<String, int>> loadDeletedEventMetadata() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic stored = _settingsBox!.get(_deletedEventIdsKey);
    if (stored == null) {
      return {};
    }

    // 後方互換性: 古いList<String>形式をMapに変換
    if (stored is List) {
      AppLogger.warning(
        '🔄 Converting old deleted event IDs format to metadata format',
      );
      final Map<String, int> converted = {};
      for (final eventId in stored) {
        converted[eventId.toString()] = 0; // タイムスタンプ不明なので0（常に古いとみなす）
      }
      // 新しい形式で保存
      await saveDeletedEventMetadata(converted);
      return converted;
    }

    if (stored is Map) {
      return Map<String, int>.from(
        stored.map((k, v) => MapEntry(k.toString(), v as int)),
      );
    }

    return {};
  }

  /// 削除済みイベントメタデータをクリア
  Future<void> clearDeletedEventIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_deletedEventIdsKey);
    AppLogger.info('🗑️ Cleared deleted event metadata from storage');
  }

  // === Issue #101: 削除済みリストID管理（LWW対応） ===

  /// 削除済みリストメタデータを保存（listId -> deletion_created_at）
  Future<void> saveDeletedListMetadata(Map<String, int> metadata) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_deletedListIdsKey, metadata);
    AppLogger.info(
      '🗑️ [Issue#101] Saved ${metadata.length} deleted list metadata',
    );
  }

  /// 削除済みリストメタデータを取得
  Future<Map<String, int>> loadDeletedListMetadata() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic stored = _settingsBox!.get(_deletedListIdsKey);
    if (stored == null) {
      return {};
    }

    // 後方互換性: 古いList<String>形式をMapに変換
    if (stored is List) {
      AppLogger.warning(
        '🔄 [Issue#101] Converting old deleted list IDs format to metadata format',
      );
      final Map<String, int> converted = {};
      for (final listId in stored) {
        converted[listId.toString()] = 0; // タイムスタンプ不明なので0（常に古いとみなす）
      }
      // 新しい形式で保存
      await saveDeletedListMetadata(converted);
      return converted;
    }

    if (stored is Map) {
      return Map<String, int>.from(
        stored.map((k, v) => MapEntry(k.toString(), v as int)),
      );
    }

    return {};
  }

  /// 削除済みMLSグループリストIDを保存
  Future<void> saveDeletedMlsGroupListIds(Set<String> ids) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_deletedMlsGroupListIdsKey, ids.toList());
    AppLogger.info('🗑️ [MLS] Saved ${ids.length} deleted MLS group list IDs');
  }

  /// 削除済みMLSグループリストIDを取得
  Future<Set<String>> loadDeletedMlsGroupListIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic stored = _settingsBox!.get(_deletedMlsGroupListIdsKey);
    if (stored == null) {
      return {};
    }

    if (stored is List) {
      return stored.map((e) => e.toString()).toSet();
    }

    return {};
  }

  /// 削除済みリストメタデータをクリア
  Future<void> clearDeletedListIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_deletedListIdsKey);
    AppLogger.info(
      '🗑️ [Issue#101] Cleared deleted list metadata from storage',
    );
  }

  // === Issue #101: 削除済みタスクID（リスト再作成時の復活防止） ===

  /// 削除済みタスクIDリストを保存（Todo IDベース）
  /// リスト削除時に削除されたタスクを記録し、リスト再作成時に復活しないようにする
  Future<void> saveDeletedTodoIds(List<String> todoIds) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_deletedTodoIdsKey, todoIds);
    AppLogger.info(
      '🗑️ [Issue#101] Saved ${todoIds.length} deleted todo IDs to blacklist',
    );
    AppLogger.debug(
      '📝 [Issue#101] First 3 IDs: ${todoIds.take(3).map((id) => id.substring(0, 16)).join(", ")}${todoIds.length > 3 ? "..." : ""}',
    );
  }

  /// 削除済みタスクIDリストを取得
  Future<List<String>> loadDeletedTodoIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic stored = _settingsBox!.get(_deletedTodoIdsKey);
    if (stored == null) {
      AppLogger.debug(
        '📂 [Issue#101] No deleted todo IDs found in storage (key not found)',
      );
      return [];
    }

    if (stored is List) {
      final result = stored.map((e) => e.toString()).toList();
      AppLogger.debug(
        '📂 [Issue#101] Loaded ${result.length} deleted todo IDs from storage',
      );
      return result;
    }

    AppLogger.warning(
      '⚠️ [Issue#101] Unexpected type for deleted todo IDs: ${stored.runtimeType}',
    );
    return [];
  }

  /// 削除済みタスクIDリストをクリア
  Future<void> clearDeletedTodoIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_deletedTodoIdsKey);
    AppLogger.info(
      '🗑️ [Issue#101] Cleared deleted todo IDs blacklist from storage',
    );
  }

  // === Sync timestamps ===

  Future<void> setLastTodoListSyncTime(DateTime dateTime) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(
      _lastTodoListSyncTimeKey,
      dateTime.toIso8601String(),
    );
  }

  DateTime? getLastTodoListSyncTime() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final timeString = _settingsBox!.get(_lastTodoListSyncTimeKey) as String?;
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastTodoListSyncTime() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_lastTodoListSyncTimeKey);
  }

  Future<void> setLastAppSettingsSyncTime(DateTime dateTime) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(
      _lastAppSettingsSyncTimeKey,
      dateTime.toIso8601String(),
    );
  }

  DateTime? getLastAppSettingsSyncTime() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final timeString =
        _settingsBox!.get(_lastAppSettingsSyncTimeKey) as String?;
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastAppSettingsSyncTime() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_lastAppSettingsSyncTimeKey);
  }

  Future<void> setLastCustomListsSyncTime(DateTime dateTime) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(
      _lastCustomListsSyncTimeKey,
      dateTime.toIso8601String(),
    );
  }

  DateTime? getLastCustomListsSyncTime() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final timeString =
        _settingsBox!.get(_lastCustomListsSyncTimeKey) as String?;
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastCustomListsSyncTime() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_lastCustomListsSyncTimeKey);
  }

  // === MLS group todos sync timestamps ===

  DateTime? getLastMlsGroupTodosSyncTime(String groupId) {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic raw = _settingsBox!.get(_lastMlsGroupTodosSyncTimesKey);
    if (raw is! Map) return null;

    final timeString = raw[groupId]?.toString();
    if (timeString == null || timeString.isEmpty) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastMlsGroupTodosSyncTime(
    String groupId,
    DateTime? dateTime,
  ) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic raw = _settingsBox!.get(_lastMlsGroupTodosSyncTimesKey);
    final map = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    if (dateTime == null) {
      // nullの場合はマップから削除（初回同期として扱う）
      map.remove(groupId);
    } else {
      map[groupId] = dateTime.toIso8601String();
    }
    await _settingsBox!.put(_lastMlsGroupTodosSyncTimesKey, map);
  }

  Future<void> clearLastMlsGroupTodosSyncTimes() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_lastMlsGroupTodosSyncTimesKey);
  }

  // === shared-v1 group keys (nsec_G / npub_G) ===

  Map<String, dynamic> loadSharedGroupCredentials() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final raw = _settingsBox!.get(_sharedGroupCredentialsKey);
    if (raw is! Map) {
      return {};
    }
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Future<void> saveSharedGroupCredentials(
    Map<String, dynamic> credentialsByGroupId,
  ) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_sharedGroupCredentialsKey, credentialsByGroupId);
  }

  DateTime? getLastSharedGroupTodosSyncTime(String groupId) {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final raw = _settingsBox!.get(_lastSharedGroupTodosSyncTimesKey);
    if (raw is! Map) return null;

    final timeString = raw[groupId]?.toString();
    if (timeString == null || timeString.isEmpty) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastSharedGroupTodosSyncTime(
    String groupId,
    DateTime? dateTime,
  ) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    final dynamic raw = _settingsBox!.get(_lastSharedGroupTodosSyncTimesKey);
    final map = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    if (dateTime == null) {
      map.remove(groupId);
    } else {
      map[groupId] = dateTime.toIso8601String();
    }
    await _settingsBox!.put(_lastSharedGroupTodosSyncTimesKey, map);
  }

  // === Relay roles + global backfill queue ===

  Future<void> saveRelayRoles(Map<String, String> roles) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_relayRolesKey, roles);
  }

  Map<String, String> loadRelayRoles() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final raw = _settingsBox!.get(_relayRolesKey);
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<void> saveGlobalBackfillQueue(
    List<Map<String, dynamic>> queueItems,
  ) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_globalBackfillQueueKey, queueItems);
  }

  List<Map<String, dynamic>> loadGlobalBackfillQueue() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final raw = _settingsBox!.get(_globalBackfillQueueKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  // === GW17 processed event IDs (dedup) ===

  Set<String> loadProcessedGw17EventIds() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final raw = _settingsBox!.get(_processedGw17EventIdsKey);
    if (raw is! List) return {};
    return raw.whereType<String>().toSet();
  }

  Future<void> saveProcessedGw17EventIds(Set<String> ids) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    // Ring-buffer: keep only the most recent entries to avoid unbounded growth
    var list = ids.toList();
    if (list.length > _maxProcessedGw17EventIds) {
      list = list.sublist(list.length - _maxProcessedGw17EventIds);
    }
    await _settingsBox!.put(_processedGw17EventIdsKey, list);
  }

  Future<void> addProcessedGw17EventIds(Iterable<String> newIds) async {
    final existing = loadProcessedGw17EventIds();
    existing.addAll(newIds);
    await saveProcessedGw17EventIds(existing);
  }

  Future<void> clearProcessedGw17EventIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_processedGw17EventIdsKey);
  }
}

/// LocalStorageServiceのシングルトンインスタンス
final localStorageService = LocalStorageService();
