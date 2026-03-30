import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/application/usecases/generate_recurring_instances_usecase.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/models/recurrence_pattern.dart';

void main() {
  late GenerateRecurringInstancesUseCase usecase;

  setUp(() {
    usecase = GenerateRecurringInstancesUseCase();
  });

  final today = DateTime(2025, 11, 12);

  Todo makeRecurringTodo({
    String id = 'parent-1',
    DateTime? date,
    RecurrencePattern? recurrence,
  }) =>
      Todo(
        id: id,
        title: 'Daily standup',
        createdAt: today,
        updatedAt: today,
        date: date ?? today,
        recurrence: recurrence ??
            const RecurrencePattern(type: RecurrenceType.daily, interval: 1),
      );

  group('GenerateRecurringInstancesUseCase', () {
    test('繰り返しパターンがないTodoはスキップされる', () async {
      final todo = Todo(
        id: 't-1',
        title: 'No recurrence',
        createdAt: today,
        updatedAt: today,
        date: today,
      );
      final params = GenerateRecurringInstancesParams(
        parentTodo: todo,
        currentTodos: {today: [todo]},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          expect(todos[today]!.length, 1);
        },
      );
    });

    test('日付がないTodoはスキップされる', () async {
      final todo = Todo(
        id: 't-1',
        title: 'No date',
        createdAt: today,
        updatedAt: today,
        recurrence: const RecurrencePattern(type: RecurrenceType.daily),
      );
      final params = GenerateRecurringInstancesParams(
        parentTodo: todo,
        currentTodos: {null: [todo]},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
    });

    test('日次繰り返しで将来インスタンスが生成される', () async {
      final todo = makeRecurringTodo();
      final params = GenerateRecurringInstancesParams(
        parentTodo: todo,
        currentTodos: {today: [todo]},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          final totalTodos =
              todos.values.fold<int>(0, (sum, list) => sum + list.length);
          expect(totalTodos, greaterThan(1));

          for (final entry in todos.entries) {
            if (entry.key != today) {
              for (final t in entry.value) {
                if (t.parentRecurringId != null) {
                  expect(t.parentRecurringId, 'parent-1');
                  expect(t.title, 'Daily standup');
                }
              }
            }
          }
        },
      );
    });

    test('既に存在するインスタンスは重複生成されない', () async {
      final todo = makeRecurringTodo();
      final tomorrow = today.add(const Duration(days: 1));
      final existingChild = Todo(
        id: 'child-1',
        title: 'Daily standup',
        createdAt: today,
        updatedAt: today,
        date: tomorrow,
        parentRecurringId: 'parent-1',
      );

      final params = GenerateRecurringInstancesParams(
        parentTodo: todo,
        currentTodos: {
          today: [todo],
          tomorrow: [existingChild],
        },
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          final tomorrowTodos = todos[tomorrow]!;
          final childCount =
              tomorrowTodos.where((t) => t.parentRecurringId == 'parent-1').length;
          expect(childCount, 1);
        },
      );
    });

    test('週次繰り返しでインスタンスが生成される', () async {
      final todo = makeRecurringTodo(
        recurrence: const RecurrencePattern(
          type: RecurrenceType.weekly,
          interval: 1,
        ),
      );
      final params = GenerateRecurringInstancesParams(
        parentTodo: todo,
        currentTodos: {today: [todo]},
      );

      final result = await usecase(params);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should succeed'),
        (todos) {
          final totalTodos =
              todos.values.fold<int>(0, (sum, list) => sum + list.length);
          expect(totalTodos, greaterThanOrEqualTo(2));
        },
      );
    });
  });
}
