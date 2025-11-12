import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/todo.dart';
import '../../../../services/logger_service.dart';

/// ローカルストレージDataSource（Hive）
///
/// TodoをローカルHiveデータベースに保存・読み込み
abstract class TodoLocalDataSource {
  /// すべてのTodoを読み込み
  Future<List<Todo>> loadAllTodos();

  /// 特定のTodoを読み込み
  Future<Todo?> loadTodoById(String id);

  /// Todoを保存
  Future<void> saveTodo(Todo todo);

  /// すべてのTodoを保存（一括置換）
  Future<void> saveTodos(List<Todo> todos);

  /// Todoを削除
  Future<void> deleteTodo(String id);

  /// すべてのTodoを削除
  Future<void> clear();
}

/// Hive実装
class TodoLocalDataSourceHive implements TodoLocalDataSource {
  TodoLocalDataSourceHive({required this.boxName});

  final String boxName;
  Box<Map>? _box;

  /// Hiveボックスを初期化
  Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(boxName);
    }
  }

  /// ボックスが初期化されているか確認
  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw Exception('TodoLocalDataSourceHive not initialized. Call initialize() first.');
    }
  }

  @override
  Future<List<Todo>> loadAllTodos() async {
    _ensureInitialized();

    final List<Todo> todos = [];

    for (final value in _box!.values) {
      try {
        final jsonMap = _deepCastMap(value);
        final todo = Todo.fromSimpleJson(jsonMap);
        todos.add(todo);
      } catch (e) {
        AppLogger.warning('❌ Todo復元エラー: $e');
        // エラーがあってもスキップして続行
        continue;
      }
    }

    AppLogger.debug('📦 [LocalDataSource] ${todos.length}件のTodoを読み込み');
    return todos;
  }

  @override
  Future<Todo?> loadTodoById(String id) async {
    _ensureInitialized();

    final value = _box!.get(id);
    if (value == null) {
      return null;
    }

    try {
      final jsonMap = _deepCastMap(value);
      return Todo.fromSimpleJson(jsonMap);
    } catch (e) {
      AppLogger.warning('❌ Todo復元エラー (ID: $id): $e');
      return null;
    }
  }

  @override
  Future<void> saveTodo(Todo todo) async {
    _ensureInitialized();

    final json = todo.toSimpleJson();
    await _box!.put(todo.id, json);
    AppLogger.debug('💾 [LocalDataSource] Todoを保存: ${todo.id}');
  }

  @override
  Future<void> saveTodos(List<Todo> todos) async {
    _ensureInitialized();

    // 既存データをクリア
    await _box!.clear();

    // 新しいデータを保存
    for (final todo in todos) {
      final json = todo.toSimpleJson();
      await _box!.put(todo.id, json);
    }

    AppLogger.debug('💾 [LocalDataSource] ${todos.length}件のTodoを一括保存');
  }

  @override
  Future<void> deleteTodo(String id) async {
    _ensureInitialized();

    await _box!.delete(id);
    AppLogger.debug('🗑️ [LocalDataSource] Todoを削除: $id');
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();

    final count = _box!.length;
    await _box!.clear();
    AppLogger.debug('🗑️ [LocalDataSource] すべてのTodoを削除 ($count件)');
  }

  /// Mapをdeep copyでMap<String, dynamic>に変換
  ///
  /// HiveのMap型はMap<dynamic, dynamic>なので、
  /// Map<String, dynamic>に変換する必要がある
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
              }).toList());
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }
}

