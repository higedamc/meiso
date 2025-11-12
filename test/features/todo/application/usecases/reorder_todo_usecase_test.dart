import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/reorder_todo_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late ReorderTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = ReorderTodoUseCase(mockRepository);
  });

  group('ReorderTodoUseCase', () {
    final existingTodo = Todo(
      id: 'test-id-1',
      title: TodoTitle.unsafe('Test Todo'),
      completed: false,
      createdAt: DateTime(2025, 11, 12),
      updatedAt: DateTime(2025, 11, 12),
      date: null,
      customListId: 'Work',
      order: 1,
      linkPreview: null,
      recurrence: null,
      parentRecurringId: null,
      eventId: 'event-1',
      needsSync: false,
    );

    test('Todoのpositionが正常に更新される', () async {
      // Arrange
      final params = ReorderTodoParams(
        todoId: 'test-id-1',
        newOrder: 3,
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
          expect(todo.order, 3);
          expect(todo.customListId, 'Work'); // 他のフィールドは変更されない
          expect(todo.needsSync, true); // 更新したので同期が必要
        },
      );

      verify(() => mockRepository.getTodoById('test-id-1')).called(1);
      verify(() => mockRepository.updateTodo(any())).called(1);
    });

    test('order 0.0に移動できる', () async {
      // Arrange
      final params = ReorderTodoParams(
        todoId: 'test-id-1',
        newOrder: 0,
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
          expect(todo.order, 0.0);
        },
      );
    });

    test('存在しないTodoIDでエラーが返る', () async {
      // Arrange
      final params = ReorderTodoParams(
        todoId: 'non-existent-id',
        newOrder: 2,
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

      verifyNever(() => mockRepository.updateTodo(any()));
    });
  });
}

