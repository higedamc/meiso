import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/todo/application/usecases/create_todo_usecase.dart';
import 'package:meiso/models/todo.dart';

void main() {
  late CreateTodoUseCase usecase;

  setUp(() {
    usecase = CreateTodoUseCase();
  });

  final today = DateTime(2025, 11, 12);

  group('CreateTodoUseCase', () {
    test('タイトルのみで正常にTodoが作成される', () async {
      final params = CreateTodoParams(
        title: 'Buy groceries',
        date: null,
        currentTodos: const {},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.id, isNotEmpty);
          expect(todo.title, 'Buy groceries');
          expect(todo.completed, false);
          expect(todo.date, isNull);
          expect(todo.needsSync, true);
          expect(todo.order, 0);
        },
      );
    });

    test('日付付きでTodoが作成される', () async {
      final params = CreateTodoParams(
        title: 'Meeting',
        date: today,
        currentTodos: const {},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.date, today);
        },
      );
    });

    test('カスタムリスト付きでTodoが作成される', () async {
      final params = CreateTodoParams(
        title: 'Sprint task',
        date: today,
        customListId: 'work-list-1',
        currentTodos: const {},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.customListId, 'work-list-1');
        },
      );
    });

    test('空のタイトルでバリデーションエラーが返る', () async {
      const params = CreateTodoParams(
        title: '',
        date: null,
        currentTodos: {},
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, contains('タイトル'));
        },
        (_) => fail('Should fail'),
      );
    });

    test('空白のみのタイトルでバリデーションエラーが返る', () async {
      const params = CreateTodoParams(
        title: '   ',
        date: null,
        currentTodos: {},
      );

      final result = await usecase(params);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should fail'),
      );
    });

    test('orderが既存Todoの最大値+1になる', () async {
      final existingTodos = <DateTime?, List<Todo>>{
        today: [
          Todo(id: 'a', title: 'A', createdAt: today, updatedAt: today, date: today, order: 0),
          Todo(id: 'b', title: 'B', createdAt: today, updatedAt: today, date: today, order: 3),
        ],
      };

      final params = CreateTodoParams(
        title: 'New task',
        date: today,
        currentTodos: existingTodos,
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.order, 4);
        },
      );
    });

    test('該当日付にTodoがない場合order=0で作成される', () async {
      final tomorrow = DateTime(2025, 11, 13);
      final params = CreateTodoParams(
        title: 'First task',
        date: tomorrow,
        currentTodos: {
          today: [Todo(id: 'a', title: 'A', createdAt: today, updatedAt: today, date: today)],
        },
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todo) {
          expect(todo.order, 0);
        },
      );
    });
  });
}
