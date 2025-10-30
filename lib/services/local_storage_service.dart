import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo.dart';

/// ローカルストレージサービス（Hive使用）
/// Todoをローカルに永続化し、オフラインファーストを実現
class LocalStorageService {
  static const String _todosBoxName = 'todos';
  static const String _settingsBoxName = 'settings';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _useAmberKey = 'use_amber';
  
  Box<Map>? _todosBox;
  Box? _settingsBox;

  /// Hiveを初期化
  Future<void> initialize() async {
    await Hive.initFlutter();
    _todosBox = await Hive.openBox<Map>(_todosBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
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

  /// すべてのデータをクリア
  Future<void> clearAll() async {
    if (_todosBox == null) {
      throw Exception('LocalStorageService not initialized');
    }

    await _todosBox!.clear();
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _todosBox?.close();
    await _settingsBox?.close();
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
}

/// LocalStorageServiceのシングルトンインスタンス
final localStorageService = LocalStorageService();

