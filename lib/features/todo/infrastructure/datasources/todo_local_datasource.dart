import 'package:hive_flutter/hive_flutter.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/todo.dart';
import '../../domain/value_objects/todo_title.dart';
import '../../domain/value_objects/todo_date.dart';
import '../../../../models/link_preview.dart';
import '../../../../models/recurrence_pattern.dart';

/// Todoローカルデータソースのインターフェース
abstract class TodoLocalDataSource {
  Future<List<Todo>> loadAllTodos();
  Future<Todo?> loadTodoById(String id);
  Future<void> saveTodo(Todo todo);
  Future<void> saveTodos(List<Todo> todos);
  Future<void> deleteTodo(String id);
  Future<void> clear();
}

/// Hive実装
class TodoLocalDataSourceHive implements TodoLocalDataSource {
  TodoLocalDataSourceHive({Box<Map>? todosBox}) : _todosBox = todosBox;

  static const String _boxName = 'todos';
  Box<Map>? _todosBox;

  /// Hive初期化（アプリ起動時に一度だけ呼ぶ）
  static Future<void> initialize() async {
    await Hive.initFlutter();
  }

  /// Boxを開く
  Future<void> open() async {
    _todosBox ??= await Hive.openBox<Map>(_boxName);
  }

  /// Boxが初期化されているか確認
  void _ensureInitialized() {
    if (_todosBox == null) {
      throw Exception('TodoLocalDataSourceHive not initialized. Call open() first.');
    }
  }

  @override
  Future<List<Todo>> loadAllTodos() async {
    _ensureInitialized();

    final List<Todo> todos = [];

    for (final value in _todosBox!.values) {
      try {
        // Mapをキャストして復元（deep copy）
        final jsonMap = _deepCastMap(value);
        final todo = _todoFromJson(jsonMap);
        todos.add(todo);
      } catch (e, stackTrace) {
        AppLogger.warning('[TodoLocalDataSource] Todo復元エラー: $e', stackTrace: stackTrace);
        // エラーがあってもスキップして続行
        continue;
      }
    }

    return todos;
  }

  @override
  Future<Todo?> loadTodoById(String id) async {
    _ensureInitialized();

    final value = _todosBox!.get(id);
    if (value == null) return null;

    try {
      final jsonMap = _deepCastMap(value);
      return _todoFromJson(jsonMap);
    } catch (e, stackTrace) {
      AppLogger.error('[TodoLocalDataSource] Todo復元エラー (ID: $id): $e', 
        error: e, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> saveTodo(Todo todo) async {
    _ensureInitialized();

    final json = _todoToJson(todo);
    await _todosBox!.put(todo.id, json);
  }

  @override
  Future<void> saveTodos(List<Todo> todos) async {
    _ensureInitialized();

    // 既存データをクリア
    await _todosBox!.clear();

    // 新しいデータを保存
    for (final todo in todos) {
      final json = _todoToJson(todo);
      await _todosBox!.put(todo.id, json);
    }
  }

  @override
  Future<void> deleteTodo(String id) async {
    _ensureInitialized();

    await _todosBox!.delete(id);
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();

    await _todosBox!.clear();
  }

  /// Boxを閉じる
  Future<void> close() async {
    await _todosBox?.close();
    _todosBox = null;
  }

  // === Private Helpers ===

  /// TodoエンティティをJSONに変換
  Map<String, dynamic> _todoToJson(Todo todo) {
    return {
      'id': todo.id,
      'title': todo.title.value,
      'completed': todo.completed,
      'date': todo.date?.value.toIso8601String(),
      'order': todo.order,
      'createdAt': todo.createdAt.toIso8601String(),
      'updatedAt': todo.updatedAt.toIso8601String(),
      'eventId': todo.eventId,
      'linkPreview': todo.linkPreviewJson,
      'recurrence': todo.recurrenceJson,
      'parentRecurringId': todo.parentRecurringId,
      'customListId': todo.customListId,
      'needsSync': todo.needsSync,
    };
  }

  /// JSONからTodoエンティティを復元
  Todo _todoFromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: TodoTitle.unsafe(json['title'] as String),
      completed: json['completed'] as bool? ?? false,
      date: json['date'] != null
          ? TodoDate.dateOnly(DateTime.parse(json['date'] as String))
          : null,
      order: json['order'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      eventId: json['eventId'] as String?,
      linkPreviewJson: json['linkPreview'] as String?,
      recurrenceJson: json['recurrence'] as String?,
      parentRecurringId: json['parentRecurringId'] as String?,
      customListId: json['customListId'] as String?,
      needsSync: json['needsSync'] as bool? ?? true,
    );
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
}

/// グローバルインスタンス（既存のlocalStorageServiceとの互換性のため）
final todoLocalDataSource = TodoLocalDataSourceHive();

