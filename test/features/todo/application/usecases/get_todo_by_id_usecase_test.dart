import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/get_todo_by_id_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/errors/todo_errors.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late GetTodoByIdUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = GetTodoByIdUseCase(mockRepository);
  });

  group('GetTodoByIdUseCase', () {
    final testTodo = Todo(
      id: 'test-id-1',
      title: TodoTitle.unsafe('Test Todo'),
      completed: false,
      createdAt: DateTime(2025, 11, 12),
      updatedAt: DateTime(2025, 11, 12),
      date: null,
      customListId: null,
      order: 0,
      linkPreview: null,
      recurrence: null,
      parentRecurringId: null,
      eventId: 'event-1',
      needsSync: false,
    );

    test('指定IDのTodoが取得される', () async {
      // Arrange
      final params = GetTodoByIdParams(todoId: 'test-id-1');

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Right(testTodo));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.id, 'test-id-1');
          expect(todo.title.value, 'Test Todo');
        },
      );

      verify(() => mockRepository.getTodoById('test-id-1')).called(1);
    });

    test('存在しないIDでエラーが返る', () async {
      // Arrange
      final params = GetTodoByIdParams(todoId: 'non-existent-id');

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
    });

    test('Repository失敗時にエラーが返る', () async {
      // Arrange
      final params = GetTodoByIdParams(todoId: 'test-id-1');

      when(() => mockRepository.getTodoById('test-id-1'))
          .thenAnswer((_) async => Left(ServerFailure('Database error')));

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

