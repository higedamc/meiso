import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/delete_todo_usecase.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/models/todo.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late DeleteTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = DeleteTodoUseCase(mockRepository);
  });

  final now = DateTime(2025, 11, 12);
  final today = DateTime(2025, 11, 12);

  Todo makeTodo(String id) => Todo(
        id: id,
        title: 'Test $id',
        createdAt: now,
        updatedAt: now,
        date: today,
      );

  group('DeleteTodoUseCase', () {
    test('正常にTodoが削除される', () async {
      final todo = makeTodo('t-1');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [todo],
      };
      final params = DeleteTodoParams(
        id: 't-1',
        date: today,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.deleteTodoFromLocal('t-1'))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedTodos) {
          expect(updatedTodos[today], isEmpty);
        },
      );
      verify(() => mockRepository.deleteTodoFromLocal('t-1')).called(1);
    });

    test('存在しないTodoIDでValidationFailureが返る', () async {
      final currentTodos = <DateTime?, List<Todo>>{
        today: [makeTodo('t-1')],
      };
      final params = DeleteTodoParams(
        id: 'non-existent',
        date: today,
        currentTodos: currentTodos,
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should fail'),
      );
      verifyNever(() => mockRepository.deleteTodoFromLocal(any()));
    });

    test('Repository削除失敗時にエラーが返る', () async {
      final todo = makeTodo('t-1');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [todo],
      };
      final params = DeleteTodoParams(
        id: 't-1',
        date: today,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.deleteTodoFromLocal('t-1'))
          .thenAnswer((_) async => const Left(ServerFailure('Delete failed')));

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('複数Todoから1つだけ削除される', () async {
      final todos = [makeTodo('t-1'), makeTodo('t-2'), makeTodo('t-3')];
      final currentTodos = <DateTime?, List<Todo>>{today: todos};
      final params = DeleteTodoParams(
        id: 't-2',
        date: today,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.deleteTodoFromLocal('t-2'))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedTodos) {
          final remaining = updatedTodos[today]!;
          expect(remaining.length, 2);
          expect(remaining.any((t) => t.id == 't-2'), false);
        },
      );
    });

    test('date=nullのSomedayタスクが削除される', () async {
      final todo = makeTodo('s-1').copyWith(date: null);
      final currentTodos = <DateTime?, List<Todo>>{
        null: [todo],
      };
      final params = DeleteTodoParams(
        id: 's-1',
        date: null,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.deleteTodoFromLocal('s-1'))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedTodos) {
          expect(updatedTodos[null], isEmpty);
        },
      );
    });
  });
}
