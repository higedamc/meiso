import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/core/common/usecase.dart';
import 'package:meiso/features/todo/application/usecases/get_all_todos_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late GetAllTodosUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = GetAllTodosUseCase(mockRepository);
  });

  group('GetAllTodosUseCase', () {
    final testTodos = <Todo>[
      Todo(
        id: 'test-id-1',
        title: TodoTitle.unsafe('Todo 1'),
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
      ),
      Todo(
        id: 'test-id-2',
        title: TodoTitle.unsafe('Todo 2'),
        completed: true,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: null,
        customListId: null,
        order: 1,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-2',
      needsSync: false,
      ),
    ];

    test('全てのTodoが取得される', () async {
      // Arrange
      when(() => mockRepository.getAllTodos())
          .thenAnswer((_) async => Right(testTodos));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.length, 2);
          expect(todos[0].id, 'test-id-1');
          expect(todos[1].id, 'test-id-2');
        },
      );

      verify(() => mockRepository.getAllTodos()).called(1);
    });

    test('空リストが返る', () async {
      // Arrange
      when(() => mockRepository.getAllTodos())
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await usecase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.isEmpty, true);
        },
      );
    });

    test('Repository失敗時にエラーが返る', () async {
      // Arrange
      when(() => mockRepository.getAllTodos())
          .thenAnswer((_) async => Left(ServerFailure('Database error')));

      // Act
      final result = await usecase(const NoParams());

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

