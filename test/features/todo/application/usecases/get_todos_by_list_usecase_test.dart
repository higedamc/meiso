import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/get_todos_by_list_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late GetTodosByListUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = GetTodosByListUseCase(mockRepository);
  });

  group('GetTodosByListUseCase', () {
    final testTodos = <Todo>[
      Todo(
        id: 'test-id-1',
        title: TodoTitle.unsafe('Work Task 1'),
        completed: false,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: null,
        customListId: 'Work',
        order: 0,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-1',
      needsSync: false,
      ),
      Todo(
        id: 'test-id-2',
        title: TodoTitle.unsafe('Work Task 2'),
        completed: true,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: null,
        customListId: 'Work',
        order: 1,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-2',
      needsSync: false,
      ),
    ];

    test('指定リストのTodoが取得される', () async {
      // Arrange
      final params = GetTodosByListParams(customListId: 'Work');

      when(() => mockRepository.getTodosByCustomList('Work'))
          .thenAnswer((_) async => Right(testTodos));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.length, 2);
          expect(todos[0].customListId, 'Work');
          expect(todos[1].customListId, 'Work');
        },
      );

      verify(() => mockRepository.getTodosByCustomList('Work')).called(1);
    });

    test('該当リストのTodoがない場合は空リストが返る', () async {
      // Arrange
      final params = GetTodosByListParams(customListId: 'Shopping');

      when(() => mockRepository.getTodosByCustomList('Shopping'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await usecase(params);

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
      final params = GetTodosByListParams(customListId: 'Work');

      when(() => mockRepository.getTodosByCustomList('Work'))
          .thenAnswer((_) async => Left(ServerFailure('Query failed')));

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

