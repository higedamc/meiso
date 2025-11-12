import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meiso/features/todo/infrastructure/repositories/todo_repository_impl.dart';
import 'package:meiso/features/todo/infrastructure/datasources/todo_local_datasource.dart';
import 'package:meiso/features/todo/infrastructure/datasources/todo_remote_datasource.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/core/common/failure.dart';

// Mocks
class MockTodoLocalDataSource extends Mock implements TodoLocalDataSource {}

class MockTodoRemoteDataSource extends Mock implements TodoRemoteDataSource {}

// Fake
class FakeTodo extends Fake implements Todo {}

void main() {
  late TodoRepositoryImpl repository;
  late MockTodoLocalDataSource mockLocalDataSource;
  late MockTodoRemoteDataSource mockRemoteDataSource;

  setUpAll(() {
    // Register fallback values for mocktail
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

  group('TodoRepositoryImpl', () {
    final testTodo = Todo(
      id: 'test-id',
      title: TodoTitle.unsafe('テストタスク'),
      completed: false,
      order: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      needsSync: true,
    );

    group('getAllTodos', () {
      test('ローカルデータソースから全Todoを取得できる', () async {
        // Arrange
        final todos = [testTodo];
        when(() => mockLocalDataSource.loadAllTodos())
            .thenAnswer((_) async => todos);

        // Act
        final result = await repository.getAllTodos();

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (fetchedTodos) {
            expect(fetchedTodos.length, 1);
            expect(fetchedTodos.first.id, testTodo.id);
          },
        );
        verify(() => mockLocalDataSource.loadAllTodos()).called(1);
      });

      test('エラー時はCacheFailureを返す', () async {
        // Arrange
        when(() => mockLocalDataSource.loadAllTodos())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.getAllTodos();

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Should be Left'),
        );
      });
    });

    group('getTodoById', () {
      test('IDで特定のTodoを取得できる', () async {
        // Arrange
        when(() => mockLocalDataSource.loadTodoById('test-id'))
            .thenAnswer((_) async => testTodo);

        // Act
        final result = await repository.getTodoById('test-id');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todo) => expect(todo.id, testTodo.id),
        );
      });

      test('Todoが見つからない場合はTodoFailureを返す', () async {
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
          (_) => fail('Should be Left'),
        );
      });
    });

    group('createTodo', () {
      test('Todoを作成してローカルに保存できる', () async {
        // Arrange
        when(() => mockLocalDataSource.saveTodo(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.createTodo(testTodo);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todo) => expect(todo.id, testTodo.id),
        );
        verify(() => mockLocalDataSource.saveTodo(testTodo)).called(1);
      });

      test('エラー時はCacheFailureを返す', () async {
        // Arrange
        when(() => mockLocalDataSource.saveTodo(any()))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.createTodo(testTodo);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<CacheFailure>()),
          (_) => fail('Should be Left'),
        );
      });
    });

    group('updateTodo', () {
      test('Todoを更新してローカルに保存できる', () async {
        // Arrange
        when(() => mockLocalDataSource.saveTodo(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.updateTodo(testTodo);

        // Assert
        expect(result.isRight(), true);
        verify(() => mockLocalDataSource.saveTodo(testTodo)).called(1);
      });
    });

    group('deleteTodo', () {
      test('Todoを削除できる', () async {
        // Arrange
        when(() => mockLocalDataSource.deleteTodo('test-id'))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.deleteTodo('test-id');

        // Assert
        expect(result.isRight(), true);
        verify(() => mockLocalDataSource.deleteTodo('test-id')).called(1);
      });
    });

    group('saveLocal', () {
      test('複数のTodoをローカルに保存できる', () async {
        // Arrange
        final todos = [testTodo];
        when(() => mockLocalDataSource.saveTodos(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.saveLocal(todos);

        // Assert
        expect(result.isRight(), true);
        verify(() => mockLocalDataSource.saveTodos(todos)).called(1);
      });
    });

    group('getTodosByDate', () {
      test('指定日付のTodoを取得できる', () async {
        // Arrange
        final date = DateTime(2025, 11, 12);
        final todo1 = Todo(
          id: 'id-1',
          title: TodoTitle.unsafe('タスク1'),
          completed: false,
          date: TodoDate(date),
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );
        final todo2 = Todo(
          id: 'id-2',
          title: TodoTitle.unsafe('タスク2'),
          completed: false,
          date: TodoDate(DateTime(2025, 11, 13)),
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        when(() => mockLocalDataSource.loadAllTodos())
            .thenAnswer((_) async => [todo1, todo2]);

        // Act
        final result = await repository.getTodosByDate(date);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todos) {
            expect(todos.length, 1);
            expect(todos.first.id, 'id-1');
          },
        );
      });

      test('Someday（日付なし）のTodoを取得できる', () async {
        // Arrange
        final todo1 = Todo(
          id: 'id-1',
          title: TodoTitle.unsafe('Somedayタスク'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );
        final todo2 = Todo(
          id: 'id-2',
          title: TodoTitle.unsafe('明日のタスク'),
          completed: false,
          date: TodoDate.tomorrow(),
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        when(() => mockLocalDataSource.loadAllTodos())
            .thenAnswer((_) async => [todo1, todo2]);

        // Act (null = Someday)
        final result = await repository.getTodosByDate(null);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todos) {
            expect(todos.length, 1);
            expect(todos.first.id, 'id-1');
          },
        );
      });
    });

    group('getTodosByCustomList', () {
      test('カスタムリストIDでフィルタリングできる', () async {
        // Arrange
        final todo1 = Todo(
          id: 'id-1',
          title: TodoTitle.unsafe('リスト1のタスク'),
          completed: false,
          customListId: 'list-1',
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );
        final todo2 = Todo(
          id: 'id-2',
          title: TodoTitle.unsafe('リスト2のタスク'),
          completed: false,
          customListId: 'list-2',
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        when(() => mockLocalDataSource.loadAllTodos())
            .thenAnswer((_) async => [todo1, todo2]);

        // Act
        final result = await repository.getTodosByCustomList('list-1');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todos) {
            expect(todos.length, 1);
            expect(todos.first.customListId, 'list-1');
          },
        );
      });
    });

    group('getTodosByCompletionStatus', () {
      test('完了状態でフィルタリングできる', () async {
        // Arrange
        final todo1 = Todo(
          id: 'id-1',
          title: TodoTitle.unsafe('完了タスク'),
          completed: true,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );
        final todo2 = Todo(
          id: 'id-2',
          title: TodoTitle.unsafe('未完了タスク'),
          completed: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsSync: true,
        );

        when(() => mockLocalDataSource.loadAllTodos())
            .thenAnswer((_) async => [todo1, todo2]);

        // Act
        final result = await repository.getTodosByCompletionStatus(true);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should be Right'),
          (todos) {
            expect(todos.length, 1);
            expect(todos.first.completed, true);
          },
        );
      });
    });
  });
}

