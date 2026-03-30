import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/remove_child_instances_usecase.dart';
import 'package:meiso/features/todo/domain/repositories/todo_repository.dart';
import 'package:meiso/models/todo.dart';
import 'package:mocktail/mocktail.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late RemoveChildInstancesUseCase usecase;
  late MockTodoRepository mockRepository;

  final now = DateTime(2025, 11, 12);
  final today = DateTime(2025, 11, 12);
  final tomorrow = DateTime(2025, 11, 13);
  final dayAfter = DateTime(2025, 11, 14);

  setUp(() {
    mockRepository = MockTodoRepository();
    usecase = RemoveChildInstancesUseCase(mockRepository);
  });

  group('RemoveChildInstancesUseCase', () {
    test('子インスタンスが正しく削除される', () async {
      final parent = Todo(
        id: 'parent-1',
        title: 'Daily standup',
        createdAt: now,
        updatedAt: now,
        date: today,
      );
      final child1 = Todo(
        id: 'child-1',
        title: 'Daily standup',
        createdAt: now,
        updatedAt: now,
        date: tomorrow,
        parentRecurringId: 'parent-1',
      );
      final child2 = Todo(
        id: 'child-2',
        title: 'Daily standup',
        createdAt: now,
        updatedAt: now,
        date: dayAfter,
        parentRecurringId: 'parent-1',
      );
      final unrelated = Todo(
        id: 'other-1',
        title: 'Unrelated task',
        createdAt: now,
        updatedAt: now,
        date: tomorrow,
      );

      when(() => mockRepository.deleteTodoFromLocal(any()))
          .thenAnswer((_) async => const Right(null));

      final params = RemoveChildInstancesParams(
        parentId: 'parent-1',
        currentTodos: {
          today: [parent],
          tomorrow: [child1, unrelated],
          dayAfter: [child2],
        },
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos[today]!.length, 1);
          expect(todos[today]!.first.id, 'parent-1');
          expect(todos[tomorrow]!.length, 1);
          expect(todos[tomorrow]!.first.id, 'other-1');
          expect(todos[dayAfter], isEmpty);
        },
      );

      verify(() => mockRepository.deleteTodoFromLocal('child-1')).called(1);
      verify(() => mockRepository.deleteTodoFromLocal('child-2')).called(1);
    });

    test('子インスタンスがない場合は何も削除されない', () async {
      final parent = Todo(
        id: 'parent-1',
        title: 'Task',
        createdAt: now,
        updatedAt: now,
        date: today,
      );

      final params = RemoveChildInstancesParams(
        parentId: 'parent-1',
        currentTodos: {
          today: [parent],
        },
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos[today]!.length, 1);
        },
      );

      verifyNever(() => mockRepository.deleteTodoFromLocal(any()));
    });

    test('ローカル削除が失敗しても処理は継続する', () async {
      final child = Todo(
        id: 'child-1',
        title: 'Child',
        createdAt: now,
        updatedAt: now,
        date: tomorrow,
        parentRecurringId: 'parent-1',
      );

      when(() => mockRepository.deleteTodoFromLocal('child-1'))
          .thenAnswer((_) async => const Left(ServerFailure('Delete failed')));

      final params = RemoveChildInstancesParams(
        parentId: 'parent-1',
        currentTodos: {
          tomorrow: [child],
        },
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos[tomorrow], isEmpty);
        },
      );
    });
  });
}
