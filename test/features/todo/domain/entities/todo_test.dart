import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';
import 'package:meiso/models/link_preview.dart';
import 'package:meiso/models/recurrence_pattern.dart';

void main() {
  group('Todo', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    group('constructor', () {
      test('creates Todo with required fields', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.id, 'test-id');
        expect(todo.title.value, '買い物');
        expect(todo.completed, false);
        expect(todo.order, 0);
        expect(todo.createdAt, now);
        expect(todo.updatedAt, now);
        expect(todo.needsSync, true);
        expect(todo.date, null);
        expect(todo.eventId, null);
      });

      test('creates Todo with optional fields', () {
        final date = TodoDate.today();
        final linkPreview = const LinkPreview(
          url: 'https://example.com',
          title: 'Example',
        );
        final recurrence = const RecurrencePattern(
          type: RecurrenceType.daily,
          interval: 1,
        );

        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: true,
          date: date,
          order: 5,
          createdAt: now,
          updatedAt: now,
          eventId: 'event-123',
          linkPreview: linkPreview,
          recurrence: recurrence,
          parentRecurringId: 'parent-id',
          customListId: 'list-id',
          needsSync: false,
        );

        expect(todo.date, date);
        expect(todo.eventId, 'event-123');
        expect(todo.linkPreview, linkPreview);
        expect(todo.recurrence, recurrence);
        expect(todo.parentRecurringId, 'parent-id');
        expect(todo.customListId, 'list-id');
        expect(todo.needsSync, false);
      });
    });

    group('TodoExtension', () {
      test('isRecurring returns true when recurrence is set', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          recurrence: const RecurrencePattern(
            type: RecurrenceType.daily,
            interval: 1,
          ),
          needsSync: true,
        );

        expect(todo.isRecurring, true);
      });

      test('isRecurring returns false when recurrence is null', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isRecurring, false);
      });

      test('isRecurringInstance returns true when parentRecurringId is set',
          () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          parentRecurringId: 'parent-id',
          needsSync: true,
        );

        expect(todo.isRecurringInstance, true);
      });

      test('isRecurringInstance returns false when parentRecurringId is null',
          () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isRecurringInstance, false);
      });

      test('isToday returns true for today date', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          date: TodoDate.today(),
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isToday, true);
      });

      test('isTomorrow returns true for tomorrow date', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          date: TodoDate.tomorrow(),
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isTomorrow, true);
      });

      test('isSomeday returns true when date is null', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isSomeday, true);
      });

      test('isSomeday returns false when date is set', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          date: TodoDate.today(),
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        expect(todo.isSomeday, false);
      });
    });

    group('toSimpleJson / fromSimpleJson', () {
      test('converts Todo to JSON and back', () {
        final originalTodo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          date: TodoDate.today(),
          order: 5,
          createdAt: now,
          updatedAt: now,
          eventId: 'event-123',
          needsSync: true,
        );

        final json = originalTodo.toSimpleJson();
        final restoredTodo = Todo.fromSimpleJson(json);

        expect(restoredTodo.id, originalTodo.id);
        expect(restoredTodo.title.value, originalTodo.title.value);
        expect(restoredTodo.completed, originalTodo.completed);
        expect(restoredTodo.date, originalTodo.date);
        expect(restoredTodo.order, originalTodo.order);
        expect(restoredTodo.createdAt, originalTodo.createdAt);
        expect(restoredTodo.updatedAt, originalTodo.updatedAt);
        expect(restoredTodo.eventId, originalTodo.eventId);
        expect(restoredTodo.needsSync, originalTodo.needsSync);
      });

      test('handles null date', () {
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        final json = todo.toSimpleJson();
        final restored = Todo.fromSimpleJson(json);

        expect(restored.date, null);
      });

      test('handles LinkPreview', () {
        final linkPreview = const LinkPreview(
          url: 'https://example.com',
          title: 'Example',
          description: 'Test description',
        );

        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          linkPreview: linkPreview,
          needsSync: true,
        );

        final json = todo.toSimpleJson();
        final restored = Todo.fromSimpleJson(json);

        expect(restored.linkPreview?.url, linkPreview.url);
        expect(restored.linkPreview?.title, linkPreview.title);
        expect(restored.linkPreview?.description, linkPreview.description);
      });

      test('handles RecurrencePattern', () {
        const recurrence = RecurrencePattern(
          type: RecurrenceType.daily,
          interval: 2,
        );

        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('タスク'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          recurrence: recurrence,
          needsSync: true,
        );

        final json = todo.toSimpleJson();
        final restored = Todo.fromSimpleJson(json);

        expect(restored.recurrence?.type, recurrence.type);
        expect(restored.recurrence?.interval, recurrence.interval);
      });
    });
  });
}

