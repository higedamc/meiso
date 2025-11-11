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
  static const String _recurringTasksTipsDismissedKey = 'recurring_tasks_tips_dismissed';
  static const String _languageKey = 'language';
  static const String _lastKeyPackagePublishTimeKey = 'last_key_package_publish_time'; // Phase 8.1
  static const String _deletedEventIdsKey = 'deleted_event_ids'; // Issue #80: kind 5削除イベント
  
  Box<Map>? _todosBox;
  Box? _settingsBox;
  Box<Map>? _customListsBox;

  /// Hiveを初期化
  Future<void> initialize() async {
    await Hive.initFlutter();
    _todosBox = await Hive.openBox<Map>(_todosBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _customListsBox = await Hive.openBox<Map>(_customListsBoxName);
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

    final List<Todo> todos = [];
    
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
          return MapEntry(key.toString(), value.map((e) {
            if (e is Map) {
              return _deepCastMap(e);
            }
            return e;
          }).toList());
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
  Future<void> clearAllData() async {
    if (_todosBox == null || _settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    
    // Todoデータをクリア
    await _todosBox!.clear();
    AppLogger.info(' Todoデータを削除しました');
    
    // 設定データをクリア（オンボーディング完了フラグ含む）
    await _settingsBox!.clear();
    AppLogger.info(' 設定データを削除しました');
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

    final List<CustomList> lists = [];
    
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
    return _settingsBox!.get(_onboardingCompletedKey, defaultValue: false) as bool;
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
    return _settingsBox!.get(_migrationCompletedKey, defaultValue: false) as bool;
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
    return _settingsBox!.get(_recurringTasksTipsDismissedKey, defaultValue: false) as bool;
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
    await _settingsBox!.put(_lastKeyPackagePublishTimeKey, dateTime.toIso8601String());
  }
  
  /// 最後にKey Packageを公開した時刻を取得
  DateTime? getLastKeyPackagePublishTime() {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    final timeString = _settingsBox!.get(_lastKeyPackagePublishTimeKey) as String?;
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
  
  // === Issue #80: kind 5削除イベント管理 ===
  
  /// 削除済みイベントIDリストを保存
  Future<void> saveDeletedEventIds(List<String> eventIds) async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.put(_deletedEventIdsKey, eventIds);
    AppLogger.info('🗑️ Saved ${eventIds.length} deleted event IDs to storage');
  }
  
  /// 削除済みイベントIDリストを取得
  Future<List<String>> loadDeletedEventIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    
    final dynamic stored = _settingsBox!.get(_deletedEventIdsKey);
    if (stored == null) {
      return [];
    }
    
    if (stored is List) {
      return stored.map((e) => e.toString()).toList();
    }
    
    return [];
  }
  
  /// 削除済みイベントIDリストをクリア
  Future<void> clearDeletedEventIds() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_deletedEventIdsKey);
    AppLogger.info('🗑️ Cleared deleted event IDs from storage');
  }
}

/// LocalStorageServiceのシングルトンインスタンス
final localStorageService = LocalStorageService();

