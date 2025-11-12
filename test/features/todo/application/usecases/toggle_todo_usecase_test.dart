import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/toggle_todo_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late ToggleTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = ToggleTodoUseCase(mockRepository);
  });

  group('ToggleTodoUseCase', () {
    final uncompletedTodo = Todo(
      id: 'test-id-1',
      title: TodoTitle.unsafe('Test Todo'),
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

    test('未完了Todoが完了状態になる', () async {
      // Arrange
      final params = ToggleTodoParams(todoId: 'test-id-1');

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(uncompletedTodo));

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
          expect(todo.needsSync, true); // 更新したので同期が必要
        },
      );

      verify(() => mockRepository.getTodoById('test-id-1')).called(1);
      verify(() => mockRepository.updateTodo(any())).called(1);
    });

    test('完了Todoが未完了状態になる', () async {
      // Arrange
      final completedTodo = uncompletedTodo.copyWith(completed: true);
      final params = ToggleTodoParams(todoId: 'test-id-1');

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(completedTodo));

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
          expect(todo.completed, false);
        },
      );
    });

    test('存在しないTodoIDでエラーが返る', () async {
      // Arrange
      final params = ToggleTodoParams(todoId: 'non-existent-id');

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

      verifyNever(() => mockRepository.updateTodo(any()));
    });

    test('Repository更新失敗時にエラーが返る', () async {
      // Arrange
      final params = ToggleTodoParams(todoId: 'test-id-1');

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(uncompletedTodo));

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

