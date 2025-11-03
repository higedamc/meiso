import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_list.freezed.dart';
part 'custom_list.g.dart';

/// カスタムリスト（SOMEDAYページで使用）
@Freezed(makeCollectionsUnmodifiable: false)
class CustomList with _$CustomList {
  const factory CustomList({
    /// UUID
    required String id,
    
    /// リスト名
    required String name,
    
    /// 並び順
    @Default(0) int order,
    
    /// 作成日時
    required DateTime createdAt,
    
    /// 更新日時
    required DateTime updatedAt,
  }) = _CustomList;

  factory CustomList.fromJson(Map<String, dynamic> json) =>
      _$CustomListFromJson(json);
}

/// 時間ベースのカテゴリー（固定）
enum PlanningCategory {
  thisWeek,
  nextWeek,
  thisMonth,
  nextMonth,
}

extension PlanningCategoryExtension on PlanningCategory {
  String get label {
    switch (this) {
      case PlanningCategory.thisWeek:
        return 'THIS WEEK';
      case PlanningCategory.nextWeek:
        return 'NEXT WEEK';
      case PlanningCategory.thisMonth:
        return 'THIS MONTH';
      case PlanningCategory.nextMonth:
        return 'NEXT MONTH';
    }
  }
  
  /// このカテゴリーに該当する日付範囲を取得
  DateRange getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (this) {
      case PlanningCategory.thisWeek:
        // 今週（月曜日〜日曜日）
        final weekday = today.weekday;
        final monday = today.subtract(Duration(days: weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateRange(start: monday, end: sunday);
        
      case PlanningCategory.nextWeek:
        // 来週（月曜日〜日曜日）
        final weekday = today.weekday;
        final thisMonday = today.subtract(Duration(days: weekday - 1));
        final nextMonday = thisMonday.add(const Duration(days: 7));
        final nextSunday = nextMonday.add(const Duration(days: 6));
        return DateRange(start: nextMonday, end: nextSunday);
        
      case PlanningCategory.thisMonth:
        // 今月
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return DateRange(start: firstDay, end: lastDay);
        
      case PlanningCategory.nextMonth:
        // 来月
        final firstDay = DateTime(now.year, now.month + 1, 1);
        final lastDay = DateTime(now.year, now.month + 2, 0);
        return DateRange(start: firstDay, end: lastDay);
    }
  }
}

/// 日付範囲
class DateRange {
  const DateRange({
    required this.start,
    required this.end,
  });
  
  final DateTime start;
  final DateTime end;
  
  /// 指定した日付がこの範囲内にあるかチェック
  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return (normalized.isAfter(start) || normalized.isAtSameMomentAs(start)) &&
           (normalized.isBefore(end) || normalized.isAtSameMomentAs(end));
  }
}

