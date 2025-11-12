import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/infrastructure/datasources/todo_local_datasource.dart';

void main() {
  group('TodoLocalDataSourceHive', () {
    late TodoLocalDataSourceHive dataSource;
    late Box<Map> testBox;

    setUp(() async {
      // テスト用のインメモリHiveボックスを使用
      Hive.init('./test_cache');
      testBox = await Hive.openBox<Map>('test_todos');
      dataSource = TodoLocalDataSourceHive(todosBox: testBox);
    });

    tearDown(() async {
      await testBox.clear();
      await testBox.close();
      await Hive.deleteFromDisk();
    });

    group('loadAllTodos', () {
      test('空の場合は空リストを返す', () async {
        // Act
        final result = await dataSource.loadAllTodos();

        // Assert
        expect(result, isEmpty);
      });

      test('保存されたTodoを全て読み込める', () async {
        // Arrange
        final todo1 = Todo(
          id: 'id1',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );
        final todo2 = Todo(
          id: 'id2',
          title: TodoTitle.unsafe('掃除'),
          completed: true,
          order: 1,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: false,
        );

        await dataSource.saveTodo(todo1);
        await dataSource.saveTodo(todo2);

        // Act
        final result = await dataSource.loadAllTodos();

        // Assert
        expect(result.length, 2);
        expect(result.any((t) => t.id == 'id1'), true);
        expect(result.any((t) => t.id == 'id2'), true);
      });
    });

    group('loadTodoById', () {
      test('存在するTodoを取得できる', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );
        await dataSource.saveTodo(todo);

        // Act
        final result = await dataSource.loadTodoById('test-id');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'test-id');
        expect(result.title.value, '買い物');
      });

      test('存在しないTodoの場合はnullを返す', () async {
        // Act
        final result = await dataSource.loadTodoById('non-existent');

        // Assert
        expect(result, isNull);
      });
    });

    group('saveTodo', () {
      test('Todoを保存できる', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          date: TodoDate.today(),
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );

        // Act
        await dataSource.saveTodo(todo);

        // Assert
        final loaded = await dataSource.loadTodoById('test-id');
        expect(loaded, isNotNull);
        expect(loaded!.title.value, '買い物');
        expect(loaded.completed, false);
      });

      test('既存のTodoを上書きできる', () async {
        // Arrange
        final original = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );
        await dataSource.saveTodo(original);

        final updated = original.copyWith(
          title: TodoTitle.unsafe('掃除'),
          completed: true,
        );

        // Act
        await dataSource.saveTodo(updated);

        // Assert
        final loaded = await dataSource.loadTodoById('test-id');
        expect(loaded!.title.value, '掃除');
        expect(loaded.completed, true);
      });
    });

    group('saveTodos', () {
      test('複数のTodoをまとめて保存できる', () async {
        // Arrange
        final todos = [
          Todo(
            id: 'id1',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            needsSync: true,
          ),
          Todo(
            id: 'id2',
            title: TodoTitle.unsafe('掃除'),
            completed: false,
            order: 1,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            needsSync: true,
          ),
        ];

        // Act
        await dataSource.saveTodos(todos);

        // Assert
        final loaded = await dataSource.loadAllTodos();
        expect(loaded.length, 2);
      });

      test('既存のTodoを全てクリアして新しいリストを保存する', () async {
        // Arrange
        final original = Todo(
          id: 'old-id',
          title: TodoTitle.unsafe('古いタスク'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );
        await dataSource.saveTodo(original);

        final newTodos = [
          Todo(
            id: 'new-id',
            title: TodoTitle.unsafe('新しいタスク'),
            completed: false,
            order: 0,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            needsSync: true,
          ),
        ];

        // Act
        await dataSource.saveTodos(newTodos);

        // Assert
        final loaded = await dataSource.loadAllTodos();
        expect(loaded.length, 1);
        expect(loaded.first.id, 'new-id');
      });
    });

    group('deleteTodo', () {
      test('指定したTodoを削除できる', () async {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        );
        await dataSource.saveTodo(todo);

        // Act
        await dataSource.deleteTodo('test-id');

        // Assert
        final loaded = await dataSource.loadTodoById('test-id');
        expect(loaded, isNull);
      });
    });

    group('clear', () {
      test('全てのTodoを削除できる', () async {
        // Arrange
        final todos = [
          Todo(
            id: 'id1',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            needsSync: true,
          ),
          Todo(
            id: 'id2',
            title: TodoTitle.unsafe('掃除'),
            completed: false,
            order: 1,
            createdAt: DateTime(2025, 11, 12),
            updatedAt: DateTime(2025, 11, 12),
            needsSync: true,
          ),
        ];
        await dataSource.saveTodos(todos);

        // Act
        await dataSource.clear();

        // Assert
        final loaded = await dataSource.loadAllTodos();
        expect(loaded, isEmpty);
      });
    });
  });
}
