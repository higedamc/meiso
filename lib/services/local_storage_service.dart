import 'package:hive_flutter/hive_flutter.dart';
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
        // Mapをキャストして復元
        final jsonMap = Map<String, dynamic>.from(value);
        todos.add(Todo.fromJson(jsonMap));
      } catch (e) {
        print('⚠️ Todo復元エラー: $e');
        // エラーがあってもスキップして続行
        continue;
      }
    }

    return todos;
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
    print('✅ Todoデータを削除しました');
    
    // 設定データをクリア（オンボーディング完了フラグ含む）
    await _settingsBox!.clear();
    print('✅ 設定データを削除しました');
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
        // Mapをキャストして復元
        final jsonMap = Map<String, dynamic>.from(value);
        lists.add(CustomList.fromJson(jsonMap));
      } catch (e) {
        print('⚠️ CustomList復元エラー: $e');
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
    print('✅ Migration completed flag set');
  }
  
  /// マイグレーション完了フラグをリセット（デバッグ用）
  Future<void> resetMigrationCompleted() async {
    if (_settingsBox == null) {
      throw Exception('LocalStorageService not initialized');
    }
    await _settingsBox!.delete(_migrationCompletedKey);
    print('🔄 Migration completed flag reset');
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
      final jsonMap = Map<String, dynamic>.from(settingsMap as Map);
      return AppSettings.fromJson(jsonMap);
    } catch (e) {
      print('⚠️ アプリ設定復元エラー: $e');
      return null;
    }
  }
}

/// LocalStorageServiceのシングルトンインスタンス
final localStorageService = LocalStorageService();

