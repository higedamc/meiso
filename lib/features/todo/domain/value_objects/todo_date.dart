/// Todoの日付（Value Object）
/// 
/// 時刻を持たず、日付のみを表現する。
/// nullの場合は「Someday」を意味する。
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
    final todayStart = DateTime(today.year, today.month, today.day);
    return value.isBefore(todayStart);
  }

  /// 日付が未来かどうか
  bool get isFuture {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return value.isAfter(todayStart);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoDate &&
      value.year == other.value.year &&
      value.month == other.value.month &&
      value.day == other.value.day;

  @override
  int get hashCode => Object.hash(value.year, value.month, value.day);

  @override
  String toString() =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

