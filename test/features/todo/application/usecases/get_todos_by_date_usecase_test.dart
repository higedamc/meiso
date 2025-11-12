import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/get_todos_by_date_usecase.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodoDate extends Fake implements TodoDate {}

void main() {
  late GetTodosByDateUseCase usecase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodoDate());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = GetTodosByDateUseCase(mockRepository);
  });

  group('GetTodosByDateUseCase', () {
    final testDate = TodoDate.dateOnly(DateTime(2025, 11, 12));
    final testTodos = <Todo>[
      Todo(
        id: 'test-id-1',
        title: TodoTitle.unsafe('Todo for 11/12'),
        completed: false,
        createdAt: DateTime(2025, 11, 12),
        updatedAt: DateTime(2025, 11, 12),
        date: testDate,
        customListId: null,
        order: 0,
        linkPreview: null,
        recurrence: null,
        parentRecurringId: null,
        eventId: 'event-1',
      needsSync: false,
      ),
    ];

    test('指定日付のTodoが取得される', () async {
      // Arrange
      final params = GetTodosByDateParams(date: testDate);

      when(() => mockRepository.getTodosByDate(any()))
          .thenAnswer((_) async => Right(testTodos));

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos.length, 1);
          expect(todos[0].date, testDate);
        },
      );

      verify(() => mockRepository.getTodosByDate(testDate.value)).called(1);
    });

    test('該当日付のTodoがない場合は空リストが返る', () async {
      // Arrange
      final params = GetTodosByDateParams(date: testDate);

      when(() => mockRepository.getTodosByDate(any()))
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
      final params = GetTodosByDateParams(date: testDate);

      when(() => mockRepository.getTodosByDate(any()))
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

