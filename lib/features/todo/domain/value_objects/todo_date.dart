/// Todoの日付（Value Object）
///
/// 日付のみを保持し、時刻情報は持たない
class TodoDate {
  const TodoDate(this.value);

  final DateTime value;

  /// 日付のみを保持（時刻を00:00:00にする）
  factory TodoDate.dateOnly(DateTime date) {
    return TodoDate(DateTime(date.year, date.month, date.day));
  }

  /// 今日
  factory TodoDate.today() => TodoDate.dateOnly(DateTime.now());

  /// 明日
  factory TodoDate.tomorrow() =>
      TodoDate.dateOnly(DateTime.now().add(const Duration(days: 1)));

  /// 指定日数後
  factory TodoDate.daysLater(int days) =>
      TodoDate.dateOnly(DateTime.now().add(Duration(days: days)));

  /// 日付が今日かどうか
  bool get isToday {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  /// 日付が明日かどうか
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return value.year == tomorrow.year &&
        value.month == tomorrow.month &&
        value.day == tomorrow.day;
  }

  /// 日付が過去かどうか
  bool get isPast {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return value.isBefore(todayDate);
  }

  /// 日付が未来かどうか
  bool get isFuture {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return value.isAfter(todayDate);
  }

  /// 日数の差を計算（今日を基準に）
  int get daysFromToday {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return value.difference(todayDate).inDays;
  }

  /// 年月日のフォーマット（YYYY-MM-DD）
  String toIso8601DateString() {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoDate &&
          runtimeType == other.runtimeType &&
          value.year == other.value.year &&
          value.month == other.value.month &&
          value.day == other.value.day;

  @override
  int get hashCode => Object.hash(value.year, value.month, value.day);

  @override
  String toString() => toIso8601DateString();
}

