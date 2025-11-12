import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/entities/todo.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_title.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';

void main() {
  group('Todo', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    group('constructor', () {
      test('必須フィールドのみでTodoを作成できる', () {
        // Act
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        // Assert
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

      test('全フィールドを指定してTodoを作成できる', () {
        // Arrange
        final date = TodoDate.today();

        // Act
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: true,
          date: date,
          order: 5,
          createdAt: now,
          updatedAt: now,
          eventId: 'event-123',
          linkPreviewJson: '{"url":"https://example.com"}',
          recurrenceJson: '{"type":"daily","interval":1}',
          parentRecurringId: 'parent-id',
          customListId: 'list-id',
          needsSync: false,
        );

        // Assert
        expect(todo.id, 'test-id');
        expect(todo.title.value, '買い物');
        expect(todo.completed, true);
        expect(todo.date, date);
        expect(todo.order, 5);
        expect(todo.createdAt, now);
        expect(todo.updatedAt, now);
        expect(todo.eventId, 'event-123');
        expect(todo.linkPreviewJson, '{"url":"https://example.com"}');
        expect(todo.recurrenceJson, '{"type":"daily","interval":1}');
        expect(todo.parentRecurringId, 'parent-id');
        expect(todo.customListId, 'list-id');
        expect(todo.needsSync, false);
      });
    });

    group('toSimpleJson', () {
      test('全フィールドをJSON形式に変換できる', () {
        // Arrange
        final date = TodoDate(DateTime(2025, 11, 12));
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: true,
          date: date,
          order: 5,
          createdAt: DateTime(2025, 11, 12, 10, 0, 0),
          updatedAt: DateTime(2025, 11, 12, 15, 0, 0),
          eventId: 'event-123',
          linkPreviewJson: '{"url":"https://example.com"}',
          recurrenceJson: '{"type":"daily"}',
          parentRecurringId: 'parent-id',
          customListId: 'list-id',
          needsSync: false,
        );

        // Act
        final json = todo.toSimpleJson();

        // Assert
        expect(json['id'], 'test-id');
        expect(json['title'], '買い物');
        expect(json['completed'], true);
        expect(json['date'], '2025-11-12T00:00:00.000');
        expect(json['order'], 5);
        expect(json['createdAt'], '2025-11-12T10:00:00.000');
        expect(json['updatedAt'], '2025-11-12T15:00:00.000');
        expect(json['eventId'], 'event-123');
        expect(json['linkPreview'], '{"url":"https://example.com"}');
        expect(json['recurrence'], '{"type":"daily"}');
        expect(json['parentRecurringId'], 'parent-id');
        expect(json['customListId'], 'list-id');
        expect(json['needsSync'], false);
      });

      test('オプションフィールドがnullの場合もJSON化できる', () {
        // Arrange
        final todo = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        // Act
        final json = todo.toSimpleJson();

        // Assert
        expect(json['id'], 'test-id');
        expect(json['title'], '買い物');
        expect(json['completed'], false);
        expect(json['date'], null);
        expect(json['eventId'], null);
        expect(json['linkPreview'], null);
        expect(json['recurrence'], null);
        expect(json['parentRecurringId'], null);
        expect(json['customListId'], null);
      });
    });

    group('TodoExtension', () {
      group('isRecurring', () {
        test('recurrenceJsonがある場合はtrueを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
            recurrenceJson: '{"type":"daily"}',
          );

          // Assert
          expect(todo.isRecurring, true);
        });

        test('recurrenceJsonがない場合はfalseを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isRecurring, false);
        });
      });

      group('isRecurringInstance', () {
        test('parentRecurringIdがある場合はtrueを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
            parentRecurringId: 'parent-id',
          );

          // Assert
          expect(todo.isRecurringInstance, true);
        });

        test('parentRecurringIdがない場合はfalseを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isRecurringInstance, false);
        });
      });

      group('isToday', () {
        test('dateが今日の場合はtrueを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            date: TodoDate.today(),
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isToday, true);
        });

        test('dateがnull（Someday）の場合はfalseを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isToday, false);
        });
      });

      group('isTomorrow', () {
        test('dateが明日の場合はtrueを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            date: TodoDate.tomorrow(),
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isTomorrow, true);
        });

        test('dateがnull（Someday）の場合はfalseを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isTomorrow, false);
        });
      });

      group('isSomeday', () {
        test('dateがnullの場合はtrueを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isSomeday, true);
        });

        test('dateがある場合はfalseを返す', () {
          // Arrange
          final todo = Todo(
            id: 'test-id',
            title: TodoTitle.unsafe('買い物'),
            completed: false,
            date: TodoDate.today(),
            order: 0,
            createdAt: now,
            updatedAt: now,
            needsSync: true,
          );

          // Assert
          expect(todo.isSomeday, false);
        });
      });
    });

    group('copyWith', () {
      test('指定したフィールドのみ更新できる', () {
        // Arrange
        final original = Todo(
          id: 'test-id',
          title: TodoTitle.unsafe('買い物'),
          completed: false,
          order: 0,
          createdAt: now,
          updatedAt: now,
          needsSync: true,
        );

        // Act
        final updated = original.copyWith(
          completed: true,
          needsSync: false,
        );

        // Assert
        expect(updated.id, 'test-id');
        expect(updated.title.value, '買い物');
        expect(updated.completed, true); // 更新された
        expect(updated.order, 0);
        expect(updated.needsSync, false); // 更新された
      });
    });
  });
}
