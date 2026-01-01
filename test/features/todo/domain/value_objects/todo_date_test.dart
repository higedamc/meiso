import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';

void main() {
  group('TodoDate', () {
    group('dateOnly', () {
      test('時刻を00:00:00にした日付を作成できる', () {
        // Arrange
        final dateTime = DateTime(2025, 11, 12, 15, 30, 45);

        // Act
        final todoDate = TodoDate.dateOnly(dateTime);

        // Assert
        expect(todoDate.value.year, 2025);
        expect(todoDate.value.month, 11);
        expect(todoDate.value.day, 12);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
      });
    });

    group('today', () {
      test('今日の日付を作成できる', () {
        // Arrange
        final now = DateTime.now();

        // Act
        final todoDate = TodoDate.today();

        // Assert
        expect(todoDate.value.year, now.year);
        expect(todoDate.value.month, now.month);
        expect(todoDate.value.day, now.day);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
      });
    });

    group('tomorrow', () {
      test('明日の日付を作成できる', () {
        // Arrange
        final tomorrow = DateTime.now().add(const Duration(days: 1));

        // Act
        final todoDate = TodoDate.tomorrow();

        // Assert
        expect(todoDate.value.year, tomorrow.year);
        expect(todoDate.value.month, tomorrow.month);
        expect(todoDate.value.day, tomorrow.day);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
      });
    });

    group('isToday', () {
      test('今日の日付の場合はtrueを返す', () {
        // Arrange
        final todoDate = TodoDate.today();

        // Assert
        expect(todoDate.isToday, true);
      });

      test('明日の日付の場合はfalseを返す', () {
        // Arrange
        final todoDate = TodoDate.tomorrow();

        // Assert
        expect(todoDate.isToday, false);
      });

      test('過去の日付の場合はfalseを返す', () {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);

        // Assert
        expect(todoDate.isToday, false);
      });
    });

    group('isTomorrow', () {
      test('明日の日付の場合はtrueを返す', () {
        // Arrange
        final todoDate = TodoDate.tomorrow();

        // Assert
        expect(todoDate.isTomorrow, true);
      });

      test('今日の日付の場合はfalseを返す', () {
        // Arrange
        final todoDate = TodoDate.today();

        // Assert
        expect(todoDate.isTomorrow, false);
      });
    });

    group('isPast', () {
      test('過去の日付の場合はtrueを返す', () {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);

        // Assert
        expect(todoDate.isPast, true);
      });

      test('今日の日付の場合はfalseを返す', () {
        // Arrange
        final todoDate = TodoDate.today();

        // Assert
        expect(todoDate.isPast, false);
      });

      test('未来の日付の場合はfalseを返す', () {
        // Arrange
        final future = DateTime.now().add(const Duration(days: 5));
        final todoDate = TodoDate.dateOnly(future);

        // Assert
        expect(todoDate.isPast, false);
      });
    });

    group('isFuture', () {
      test('未来の日付の場合はtrueを返す', () {
        // Arrange
        final future = DateTime.now().add(const Duration(days: 5));
        final todoDate = TodoDate.dateOnly(future);

        // Assert
        expect(todoDate.isFuture, true);
      });

      test('今日の日付の場合はfalseを返す', () {
        // Arrange
        final todoDate = TodoDate.today();

        // Assert
        expect(todoDate.isFuture, false);
      });

      test('過去の日付の場合はfalseを返す', () {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);

        // Assert
        expect(todoDate.isFuture, false);
      });
    });

    group('equality', () {
      test('同じ日付のTodoDateは等しい', () {
        // Arrange
        final date1 = TodoDate(DateTime(2025, 11, 12));
        final date2 = TodoDate(DateTime(2025, 11, 12));

        // Assert
        expect(date1, date2);
        expect(date1.hashCode, date2.hashCode);
      });

      test('時刻が異なっても日付が同じなら等しい', () {
        // Arrange
        final date1 = TodoDate(DateTime(2025, 11, 12, 10, 30));
        final date2 = TodoDate(DateTime(2025, 11, 12, 15, 45));

        // Assert
        expect(date1, date2);
        expect(date1.hashCode, date2.hashCode);
      });

      test('異なる日付のTodoDateは等しくない', () {
        // Arrange
        final date1 = TodoDate(DateTime(2025, 11, 12));
        final date2 = TodoDate(DateTime(2025, 11, 13));

        // Assert
        expect(date1, isNot(date2));
      });
    });

    group('toString', () {
      test('YYYY-MM-DD形式の文字列を返す', () {
        // Arrange
        final todoDate = TodoDate(DateTime(2025, 11, 12));

        // Assert
        expect(todoDate.toString(), '2025-11-12');
      });

      test('月と日が1桁の場合は0埋めされる', () {
        // Arrange
        final todoDate = TodoDate(DateTime(2025, 1, 5));

        // Assert
        expect(todoDate.toString(), '2025-01-05');
      });
    });
  });
}
