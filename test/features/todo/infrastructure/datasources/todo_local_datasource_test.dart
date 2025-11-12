import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:meiso/features/todo/infrastructure/datasources/todo_local_datasource.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';

void main() {
  late TodoLocalDataSourceHive dataSource;
  late String testBoxName;
  late Directory tempDir;

  setUp(() async {
    // テンポラリディレクトリを作成
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    
    // Hiveをテスト用に初期化（テンポラリディレクトリ使用）
    Hive.init(tempDir.path);
    testBoxName = 'test_todos_${DateTime.now().millisecondsSinceEpoch}';
    dataSource = TodoLocalDataSourceHive(boxName: testBoxName);
    await dataSource.initialize();
  });

  tearDown(() async {
    // テスト後にボックスを削除
    try {
      final box = Hive.box<Map>(testBoxName);
      await box.clear();
      await box.close();
      await Hive.deleteBoxFromDisk(testBoxName);
    } catch (e) {
      // ボックスが既にクローズされている場合はスキップ
    }
    
    // テンポラリディレクトリを削除
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TodoLocalDataSourceHive', () {
    group('saveTodo / loadTodoById', () {
      test('Todoを保存して読み込める', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        // Act
        await dataSource.saveTodo(todo);
        final loaded = await dataSource.loadTodoById('test-id');

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!.id, todo.id);
        expect(loaded.title.value, todo.title.value);
        expect(loaded.completed, todo.completed);
      });

      test('存在しないIDはnullを返す', () async {
        // Act
        final loaded = await dataSource.loadTodoById('non-existent-id');

        // Assert
        expect(loaded, isNull);
      });

      test('日付付きTodoを保存して読み込める', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: true,
          date: TodoDate.today(),
          order: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: false,
        );

        // Act
        await dataSource.saveTodo(todo);
        final loaded = await dataSource.loadTodoById('test-id');

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!.date, isNotNull);
        expect(loaded.date!.isToday, true);
        expect(loaded.completed, true);
        expect(loaded.order, 5);
      });
    });

    group('loadAllTodos', () {
      test('空のリストを返す（初期状態）', () async {
        // Act
        final todos = await dataSource.loadAllTodos();

        // Assert
        expect(todos, isEmpty);
      });

      test('複数のTodoを保存して読み込める', () async {
        // Arrange
        final todos = [
          Todo(
            id: 'id-1',
            title: TodoTitle.unsafe('タスク1'),
            completed: false,
            order: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
          Todo(
            id: 'id-2',
            title: TodoTitle.unsafe('タスク2'),
            completed: true,
            order: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: false,
          ),
          Todo(
            id: 'id-3',
            title: TodoTitle.unsafe('タスク3'),
            completed: false,
            date: TodoDate.tomorrow(),
            order: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
        ];

        // Act
        for (final todo in todos) {
          await dataSource.saveTodo(todo);
        }
        final loaded = await dataSource.loadAllTodos();

        // Assert
        expect(loaded.length, 3);
        expect(loaded.map((t) => t.id).toSet(), {'id-1', 'id-2', 'id-3'});
      });
    });

    group('saveTodos', () {
      test('一括保存で既存データを置き換える', () async {
        // Arrange
        final oldTodo = Todo(
          id: 'old-id',
          title: TodoTitle.unsafe('古いタスク'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        await dataSource.saveTodo(oldTodo);

        final newTodos = [
          Todo(
            id: 'new-id-1',
            title: TodoTitle.unsafe('新しいタスク1'),
            completed: false,
            order: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
          Todo(
            id: 'new-id-2',
            title: TodoTitle.unsafe('新しいタスク2'),
            completed: false,
            order: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
        ];

        // Act
        await dataSource.saveTodos(newTodos);
        final loaded = await dataSource.loadAllTodos();

        // Assert
        expect(loaded.length, 2);
        expect(loaded.map((t) => t.id).toSet(), {'new-id-1', 'new-id-2'});
        expect(loaded.any((t) => t.id == 'old-id'), false);
      });

      test('空のリストで一括保存すると全削除される', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        await dataSource.saveTodo(todo);

        // Act
        await dataSource.saveTodos([]);
        final loaded = await dataSource.loadAllTodos();

        // Assert
        expect(loaded, isEmpty);
      });
    });

    group('deleteTodo', () {
      test('Todoを削除できる', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        await dataSource.saveTodo(todo);

        // Act
        await dataSource.deleteTodo('test-id');
        final loaded = await dataSource.loadTodoById('test-id');

        // Assert
        expect(loaded, isNull);
      });

      test('存在しないIDを削除してもエラーにならない', () async {
        // Act & Assert
        await dataSource.deleteTodo('non-existent-id');
        // エラーが発生しないことを確認
      });
    });

    group('clear', () {
      test('すべてのTodoを削除できる', () async {
        // Arrange
        final todos = [
          Todo(
            id: 'id-1',
            title: TodoTitle.unsafe('タスク1'),
            completed: false,
            order: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
          Todo(
            id: 'id-2',
            title: TodoTitle.unsafe('タスク2'),
            completed: false,
            order: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
          ),
        ];

        for (final todo in todos) {
          await dataSource.saveTodo(todo);
        }

        // Act
        await dataSource.clear();
        final loaded = await dataSource.loadAllTodos();

        // Assert
        expect(loaded, isEmpty);
      });
    });
  });
}

