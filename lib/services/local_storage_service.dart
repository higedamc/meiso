import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo.dart';

/// ローカルストレージサービス（Hive使用）
/// Todoをローカルに永続化し、オフラインファーストを実現
class LocalStorageService {
  static const String _todosBoxName = 'todos';
  
  Box<Map>? _todosBox;

  /// Hiveを初期化
  Future<void> initialize() async {
    await Hive.initFlutter();
    _todosBox = await Hive.openBox<Map>(_todosBoxName);
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
  }
}

/// LocalStorageServiceのシングルトンインスタンス
final localStorageService = LocalStorageService();

