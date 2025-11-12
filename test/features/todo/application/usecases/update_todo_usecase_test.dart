import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/update_todo_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late UpdateTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = UpdateTodoUseCase(mockRepository);
  });

  group('UpdateTodoUseCase', () {
    final existingTodo = Todo(
      id: 'test-id-1',
      title: TodoTitle.unsafe('Original Title'),
      completed: false,
      createdAt: DateTime(2025, 11, 12, 10, 0),
      updatedAt: DateTime(2025, 11, 12, 10, 0),
      date: null,
      customListId: null,
      order: 0,
      linkPreview: null,
      recurrence: null,
      parentRecurringId: null,
      eventId: 'event-1',
      needsSync: false,
    );

    test('タイトルのみ更新される', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'test-id-1',
        title: 'Updated Title',
      );

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(existingTodo));

      when(() => mockRepository.updateTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo);
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.title.value, 'Updated Title');
          expect(todo.completed, false); // 変更されない
        },
      );

      verify(() => mockRepository.getTodoById('test-id-1')).called(1);
      verify(() => mockRepository.updateTodo(any())).called(1);
    });

    test('完了状態のみ更新される', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'test-id-1',
        completed: true,
      );

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(existingTodo));

      when(() => mockRepository.updateTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo);
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.completed, true);
          expect(todo.title.value, 'Original Title'); // 変更されない
        },
      );
    });

    test('複数フィールドが同時に更新される', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'test-id-1',
        title: 'New Title',
        completed: true,
        customListId: 'Work',
        order: 2,
      );

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(existingTodo));

      when(() => mockRepository.updateTodo(any())).thenAnswer(
        (invocation) async {
          final todo = invocation.positionalArguments[0] as Todo;
          return Right(todo);
        },
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.title.value, 'New Title');
          expect(todo.completed, true);
          expect(todo.customListId, 'Work');
          expect(todo.order, 2);
        },
      );
    });

    test('存在しないTodoIDでエラーが返る', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'non-existent-id',
        title: 'Updated Title',
      );

      when(() => mockRepository.getTodoById('non-existent-id'))
          .thenAnswer((_) async => Left(TodoFailure(TodoError.notFound)));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<TodoFailure>());
        },
        (_) => fail('Should fail'),
      );

      verify(() => mockRepository.getTodoById('non-existent-id')).called(1);
      verifyNever(() => mockRepository.updateTodo(any()));
    });

    test('空のタイトルでバリデーションエラーが返る', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'test-id-1',
        title: '',
      );

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(existingTodo));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
        },
        (_) => fail('Should fail'),
      );

      verifyNever(() => mockRepository.updateTodo(any()));
    });

    test('Repository更新失敗時にエラーが返る', () async {
      // Arrange
      final params = UpdateTodoParams(
        todoId: 'test-id-1',
        title: 'Updated Title',
      );

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(existingTodo));

      when(() => mockRepository.updateTodo(any()))
          .thenAnswer((_) async => Left(ServerFailure('Update failed')));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
        },
        (_) => fail('Should fail'),
      );
    });
  });
}

