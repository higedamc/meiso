import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/todo/domain/value_objects/todo_date.dart';

void main() {
  group('TodoDate', () {
    group('constructor', () {
      test('DateTimeから作成できる', () {
        final date = DateTime(2025, 11, 12, 14, 30);
        final todoDate = TodoDate(date);
        expect(todoDate.value, date);
      });
    });

    group('dateOnly', () {
      test('時刻を00:00:00にする', () {
        final date = DateTime(2025, 11, 12, 14, 30, 45);
        final todoDate = TodoDate.dateOnly(date);
        expect(todoDate.value.year, 2025);
        expect(todoDate.value.month, 11);
        expect(todoDate.value.day, 12);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
        expect(todoDate.value.millisecond, 0);
      });
    });

    group('today', () {
      test('今日の日付を返す', () {
        final todoDate = TodoDate.today();
        final now = DateTime.now();
        expect(todoDate.value.year, now.year);
        expect(todoDate.value.month, now.month);
        expect(todoDate.value.day, now.day);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
      });
    });

    group('tomorrow', () {
      test('明日の日付を返す', () {
        final todoDate = TodoDate.tomorrow();
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(todoDate.value.year, tomorrow.year);
        expect(todoDate.value.month, tomorrow.month);
        expect(todoDate.value.day, tomorrow.day);
        expect(todoDate.value.hour, 0);
        expect(todoDate.value.minute, 0);
        expect(todoDate.value.second, 0);
      });
    });

    group('daysLater', () {
      test('指定日数後の日付を返す', () {
        final todoDate = TodoDate.daysLater(7);
        final expected = DateTime.now().add(const Duration(days: 7));
        expect(todoDate.value.year, expected.year);
        expect(todoDate.value.month, expected.month);
        expect(todoDate.value.day, expected.day);
      });
    });

    group('isToday', () {
      test('今日の日付はtrueを返す', () {
        final todoDate = TodoDate.today();
        expect(todoDate.isToday, true);
      });

      test('昨日の日付はfalseを返す', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);
        expect(todoDate.isToday, false);
      });

      test('明日の日付はfalseを返す', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(tomorrow);
        expect(todoDate.isToday, false);
      });
    });

    group('isTomorrow', () {
      test('明日の日付はtrueを返す', () {
        final todoDate = TodoDate.tomorrow();
        expect(todoDate.isTomorrow, true);
      });

      test('今日の日付はfalseを返す', () {
        final todoDate = TodoDate.today();
        expect(todoDate.isTomorrow, false);
      });

      test('明後日の日付はfalseを返す', () {
        final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));
        final todoDate = TodoDate.dateOnly(dayAfterTomorrow);
        expect(todoDate.isTomorrow, false);
      });
    });

    group('isPast', () {
      test('過去の日付はtrueを返す', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);
        expect(todoDate.isPast, true);
      });

      test('今日の日付はfalseを返す', () {
        final todoDate = TodoDate.today();
        expect(todoDate.isPast, false);
      });

      test('未来の日付はfalseを返す', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(tomorrow);
        expect(todoDate.isPast, false);
      });
    });

    group('isFuture', () {
      test('未来の日付はtrueを返す', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(tomorrow);
        expect(todoDate.isFuture, true);
      });

      test('今日の日付はfalseを返す', () {
        final todoDate = TodoDate.today();
        expect(todoDate.isFuture, false);
      });

      test('過去の日付はfalseを返す', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);
        expect(todoDate.isFuture, false);
      });
    });

    group('daysFromToday', () {
      test('今日は0を返す', () {
        final todoDate = TodoDate.today();
        expect(todoDate.daysFromToday, 0);
      });

      test('明日は1を返す', () {
        final todoDate = TodoDate.tomorrow();
        expect(todoDate.daysFromToday, 1);
      });

      test('昨日は-1を返す', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final todoDate = TodoDate.dateOnly(yesterday);
        expect(todoDate.daysFromToday, -1);
      });

      test('7日後は7を返す', () {
        final todoDate = TodoDate.daysLater(7);
        expect(todoDate.daysFromToday, 7);
      });
    });

    group('toIso8601DateString', () {
      test('YYYY-MM-DD形式で返す', () {
        final date = DateTime(2025, 11, 12);
        final todoDate = TodoDate(date);
        expect(todoDate.toIso8601DateString(), '2025-11-12');
      });

      test('1桁の月日はゼロパディングされる', () {
        final date = DateTime(2025, 1, 5);
        final todoDate = TodoDate(date);
        expect(todoDate.toIso8601DateString(), '2025-01-05');
      });
    });

    group('equality', () {
      test('同じ日付は等しい', () {
        final date1 = TodoDate(DateTime(2025, 11, 12));
        final date2 = TodoDate(DateTime(2025, 11, 12));
        expect(date1, equals(date2));
      });

      test('時刻が異なっても日付が同じなら等しい', () {
        final date1 = TodoDate(DateTime(2025, 11, 12, 10, 30));
        final date2 = TodoDate(DateTime(2025, 11, 12, 15, 45));
        expect(date1, equals(date2));
      });

      test('異なる日付は等しくない', () {
        final date1 = TodoDate(DateTime(2025, 11, 12));
        final date2 = TodoDate(DateTime(2025, 11, 13));
        expect(date1, isNot(equals(date2)));
      });

      test('hashCodeは日付に基づく', () {
        final date1 = TodoDate(DateTime(2025, 11, 12));
        final date2 = TodoDate(DateTime(2025, 11, 12));
        expect(date1.hashCode, equals(date2.hashCode));
      });
    });

    group('toString', () {
      test('toStringはISO 8601形式を返す', () {
        final date = TodoDate(DateTime(2025, 11, 12));
        expect(date.toString(), '2025-11-12');
      });
    });
  });
}

