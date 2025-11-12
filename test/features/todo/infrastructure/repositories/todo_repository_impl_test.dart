import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/infrastructure/repositories/todo_repository_impl.dart';
import 'package:meiso/features/todo/infrastructure/datasources/todo_local_datasource.dart';
import 'package:meiso/features/todo/infrastructure/datasources/todo_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoLocalDataSource extends Mock implements TodoLocalDataSource {}

class MockTodoRemoteDataSource extends Mock implements TodoRemoteDataSource {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late TodoRepositoryImpl repository;
  late MockTodoLocalDataSource mockLocalDataSource;
  late MockTodoRemoteDataSource mockRemoteDataSource;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockLocalDataSource = MockTodoLocalDataSource();
    mockRemoteDataSource = MockTodoRemoteDataSource();
    repository = TodoRepositoryImpl(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
    );
  });

  group('getAllTodos', () {
    test('ローカルからすべてのTodoを取得できる', () async {
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
      ];
      when(() => mockLocalDataSource.loadAllTodos())
          .thenAnswer((_) async => todos);

      // Act
      final result = await repository.getAllTodos();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (loadedTodos) => expect(loadedTodos.length, 1),
      );
      verify(() => mockLocalDataSource.loadAllTodos()).called(1);
    });

    test('エラーが発生した場合はCacheFailureを返す', () async {
      // Arrange
      when(() => mockLocalDataSource.loadAllTodos())
          .thenThrow(Exception('Test error'));

      // Act
      final result = await repository.getAllTodos();

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });

  group('getTodosByDate', () {
    test('指定した日付のTodoのみ取得できる', () async {
      // Arrange
      final targetDate = DateTime(2025, 11, 12);
      final todos = [
        Todo(
          id: 'id1',
          title: TodoTitle.unsafe('今日のタスク'),
          completed: false,
          date: TodoDate.dateOnly(targetDate),
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
        Todo(
          id: 'id2',
          title: TodoTitle.unsafe('明日のタスク'),
          completed: false,
          date: TodoDate.dateOnly(targetDate.add(const Duration(days: 1))),
          order: 1,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
      ];
      when(() => mockLocalDataSource.loadAllTodos())
          .thenAnswer((_) async => todos);

      // Act
      final result = await repository.getTodosByDate(targetDate);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (filtered) {
          expect(filtered.length, 1);
          expect(filtered.first.id, 'id1');
        },
      );
    });

    test('Somedayタスク（date=null）を取得できる', () async {
      // Arrange
      final todos = [
        Todo(
          id: 'id1',
          title: TodoTitle.unsafe('Somedayタスク'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
        Todo(
          id: 'id2',
          title: TodoTitle.unsafe('今日のタスク'),
          completed: false,
          date: TodoDate.today(),
          order: 1,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
      ];
      when(() => mockLocalDataSource.loadAllTodos())
          .thenAnswer((_) async => todos);

      // Act
      final result = await repository.getTodosByDate(null);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (filtered) {
          expect(filtered.length, 1);
          expect(filtered.first.id, 'id1');
        },
      );
    });
  });

  group('getTodoById', () {
    test('指定したIDのTodoを取得できる', () async {
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
      when(() => mockLocalDataSource.loadTodoById('test-id'))
          .thenAnswer((_) async => todo);

      // Act
      final result = await repository.getTodoById('test-id');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (loadedTodo) => expect(loadedTodo.id, 'test-id'),
      );
    });

    test('存在しないIDの場合はTodoFailureを返す', () async {
      // Arrange
      when(() => mockLocalDataSource.loadTodoById('non-existent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getTodoById('non-existent');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<TodoFailure>());
          expect((failure as TodoFailure).error, TodoError.notFound);
        },
        (_) => fail('Should fail'),
      );
    });
  });

  group('createTodo', () {
    test('Todoを作成してローカルに保存できる', () async {
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
      when(() => mockLocalDataSource.saveTodo(any()))
          .thenAnswer((_) async => {});
      when(() => mockRemoteDataSource.syncPersonalTodoToNostr(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.createTodo(todo);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.saveTodo(todo)).called(1);
    });
  });

  group('updateTodo', () {
    test('Todoを更新してローカルに保存できる', () async {
      // Arrange
      final todo = Todo(
        id: 'test-id',
        title: TodoTitle.unsafe('更新後'),
        completed: true,
        order: 0,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12, 15, 0),
        needsSync: true,
      );
      when(() => mockLocalDataSource.saveTodo(any()))
          .thenAnswer((_) async => {});
      when(() => mockRemoteDataSource.syncPersonalTodoToNostr(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.updateTodo(todo);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.saveTodo(todo)).called(1);
    });
  });

  group('deleteTodo', () {
    test('Todoを削除できる', () async {
      // Arrange
      when(() => mockLocalDataSource.deleteTodo('test-id'))
          .thenAnswer((_) async => {});
      when(() => mockRemoteDataSource.deletePersonalTodoFromNostr('test-id'))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.deleteTodo('test-id');

      // Assert
      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.deleteTodo('test-id')).called(1);
    });
  });

  group('reorderTodos', () {
    test('複数のTodoの並び順を更新できる', () async {
      // Arrange
      final todos = [
        Todo(
          id: 'id1',
          title: TodoTitle.unsafe('タスク1'),
          completed: false,
          order: 0,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
        Todo(
          id: 'id2',
          title: TodoTitle.unsafe('タスク2'),
          completed: false,
          order: 1,
          createdAt: DateTime(2025, 11, 12),
          updatedAt: DateTime(2025, 11, 12),
          needsSync: true,
        ),
      ];
      when(() => mockLocalDataSource.saveTodo(any()))
          .thenAnswer((_) async => {});
      when(() => mockRemoteDataSource.syncPersonalTodoToNostr(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.reorderTodos(todos);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockLocalDataSource.saveTodo(any())).called(2);
    });
  });

  group('moveTodo', () {
    test('Todoを別の日付に移動できる', () async {
      // Arrange
      final originalTodo = Todo(
        id: 'test-id',
        title: TodoTitle.unsafe('買い物'),
        completed: false,
        date: TodoDate.today(),
        order: 0,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        needsSync: false,
      );
      final newDate = DateTime(2025, 11, 13);

      when(() => mockLocalDataSource.loadTodoById('test-id'))
          .thenAnswer((_) async => originalTodo);
      when(() => mockLocalDataSource.saveTodo(any()))
          .thenAnswer((_) async => {});
      when(() => mockRemoteDataSource.syncPersonalTodoToNostr(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.moveTodo('test-id', newDate);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (movedTodo) {
          expect(movedTodo.needsSync, true); // 移動後はneedsSync=true
        },
      );
      verify(() => mockLocalDataSource.saveTodo(any())).called(1);
    });
  });
}
