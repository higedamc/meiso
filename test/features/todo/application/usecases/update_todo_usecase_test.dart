import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/update_todo_usecase.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/models/todo.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late UpdateTodoUseCase usecase;
  late MockTodoRepository mockRepository;

  final now = DateTime(2025, 11, 12);
  final today = DateTime(2025, 11, 12);

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = UpdateTodoUseCase(mockRepository);
  });

  setUpAll(() {
    registerFallbackValue(
      Todo(id: 'fallback', title: 'fb', createdAt: DateTime(2025), updatedAt: DateTime(2025)),
    );
  });

  Todo makeTodo(String id, {String title = 'Original', bool completed = false}) => Todo(
        id: id,
        title: title,
        completed: completed,
        createdAt: now,
        updatedAt: now,
        date: today,
        order: 0,
      );

  group('UpdateTodoUseCase', () {
    test('Todoが正常に更新される', () async {
      final todo = makeTodo('t-1');
      final updatedTodo = todo.copyWith(title: 'Updated Title');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [todo],
      };
      final params = UpdateTodoParams(
        todo: updatedTodo,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.saveTodoToLocal(any()))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedMap) {
          final list = updatedMap[today]!;
          expect(list.first.title, 'Updated Title');
          expect(list.first.needsSync, true);
        },
      );
      verify(() => mockRepository.saveTodoToLocal(any())).called(1);
    });

    test('完了状態の更新', () async {
      final todo = makeTodo('t-1');
      final toggled = todo.copyWith(completed: true);
      final currentTodos = <DateTime?, List<Todo>>{
        today: [todo],
      };
      final params = UpdateTodoParams(
        todo: toggled,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.saveTodoToLocal(any()))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedMap) {
          expect(updatedMap[today]!.first.completed, true);
        },
      );
    });

    test('存在しないTodoでValidationFailureが返る', () async {
      final todo = makeTodo('non-existent');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [makeTodo('t-1')],
      };
      final params = UpdateTodoParams(
        todo: todo,
        currentTodos: currentTodos,
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should fail'),
      );
      verifyNever(() => mockRepository.saveTodoToLocal(any()));
    });

    test('Repository保存失敗時にエラーが返る', () async {
      final todo = makeTodo('t-1');
      final updated = todo.copyWith(title: 'New');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [todo],
      };
      final params = UpdateTodoParams(
        todo: updated,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.saveTodoToLocal(any()))
          .thenAnswer((_) async => const Left(ServerFailure('Save failed')));

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('複数Todoの中から正しいTodoだけが更新される', () async {
      final t1 = makeTodo('t-1', title: 'First');
      final t2 = makeTodo('t-2', title: 'Second');
      final t3 = makeTodo('t-3', title: 'Third');
      final updatedT2 = t2.copyWith(title: 'Updated Second');
      final currentTodos = <DateTime?, List<Todo>>{
        today: [t1, t2, t3],
      };
      final params = UpdateTodoParams(
        todo: updatedT2,
        currentTodos: currentTodos,
      );

      when(() => mockRepository.saveTodoToLocal(any()))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (updatedMap) {
          final list = updatedMap[today]!;
          expect(list[0].title, 'First');
          expect(list[1].title, 'Updated Second');
          expect(list[2].title, 'Third');
        },
      );
    });
  });
}
