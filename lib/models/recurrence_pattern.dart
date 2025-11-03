import 'package:freezed_annotation/freezed_annotation.dart';

part 'recurrence_pattern.freezed.dart';
part 'recurrence_pattern.g.dart';

/// リカーリングタスクの繰り返しパターン
@Freezed(makeCollectionsUnmodifiable: false)
class RecurrencePattern with _$RecurrencePattern {
  const factory RecurrencePattern({
    /// 繰り返しタイプ
    required RecurrenceType type,
    
    /// 繰り返し間隔 (例: 2 = 2日ごと、2週間ごと)
    @Default(1) int interval,
    
    /// 週単位の繰り返しで使用する曜日リスト
    /// 1=月曜, 2=火曜, ..., 7=日曜
    /// 例: [1, 3, 5] = 月・水・金
    List<int>? weekdays,
    
    /// 月単位の繰り返しで使用する日
    /// 1-31 または null (日付がない月はスキップ)
    int? dayOfMonth,
    
    /// 繰り返し終了日 (null = 無期限)
    DateTime? endDate,
  }) = _RecurrencePattern;

  factory RecurrencePattern.fromJson(Map<String, dynamic> json) =>
      _$RecurrencePatternFromJson(json);
}

/// 繰り返しタイプ
@JsonEnum()
enum RecurrenceType {
  /// 毎日
  daily,
  
  /// 毎週
  weekly,
  
  /// 毎月
  monthly,
  
  /// カスタム（将来拡張用）
  custom,
}

extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.daily:
        return '毎日';
      case RecurrenceType.weekly:
        return '毎週';
      case RecurrenceType.monthly:
        return '毎月';
      case RecurrenceType.custom:
        return 'カスタム';
    }
  }
}

/// RecurrencePatternの便利なヘルパー
extension RecurrencePatternExtension on RecurrencePattern {
  /// 次回の日付を計算
  DateTime? calculateNextDate(DateTime currentDate) {
    // 終了日をチェック
    if (endDate != null && currentDate.isAfter(endDate!)) {
      return null; // 繰り返し終了
    }
    
    switch (type) {
      case RecurrenceType.daily:
        return currentDate.add(Duration(days: interval));
        
      case RecurrenceType.weekly:
        if (weekdays == null || weekdays!.isEmpty) {
          // 曜日指定なし = 単純に週を追加
          return currentDate.add(Duration(days: 7 * interval));
        }
        
        // 次の対象曜日を探す
        DateTime nextDate = currentDate.add(const Duration(days: 1));
        int weeksChecked = 0;
        
        while (weeksChecked < interval + 1) {
          final weekday = nextDate.weekday; // 1=月曜, 7=日曜
          
          if (weekdays!.contains(weekday)) {
            // 指定曜日の中で次の日を見つけた
            final daysSinceStart = nextDate.difference(currentDate).inDays;
            if (daysSinceStart >= interval * 7) {
              return nextDate;
            }
            if (weeksChecked >= interval) {
              return nextDate;
            }
          }
          
          nextDate = nextDate.add(const Duration(days: 1));
          if (nextDate.weekday == 1) {
            // 月曜になったら週カウント増加
            weeksChecked++;
          }
        }
        
        return nextDate;
        
      case RecurrenceType.monthly:
        if (dayOfMonth == null) {
          return null;
        }
        
        // 月を追加
        int targetYear = currentDate.year;
        int targetMonth = currentDate.month + interval;
        
        // 年をまたぐ場合の調整
        while (targetMonth > 12) {
          targetMonth -= 12;
          targetYear++;
        }
        
        // その月の最終日を取得
        final lastDayOfMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final targetDay = dayOfMonth! > lastDayOfMonth ? lastDayOfMonth : dayOfMonth!;
        
        return DateTime(targetYear, targetMonth, targetDay);
        
      case RecurrenceType.custom:
        // カスタムは今後実装
        return null;
    }
  }
  
  /// 人間が読める形式での説明文
  String get description {
    final buffer = StringBuffer();
    
    switch (type) {
      case RecurrenceType.daily:
        if (interval == 1) {
          buffer.write('毎日');
        } else {
          buffer.write('$interval日ごと');
        }
        break;
        
      case RecurrenceType.weekly:
        if (interval == 1) {
          buffer.write('毎週');
        } else {
          buffer.write('$interval週間ごと');
        }
        
        if (weekdays != null && weekdays!.isNotEmpty) {
          final dayNames = weekdays!.map((day) {
            switch (day) {
              case 1: return '月';
              case 2: return '火';
              case 3: return '水';
              case 4: return '木';
              case 5: return '金';
              case 6: return '土';
              case 7: return '日';
              default: return '';
            }
          }).join('・');
          buffer.write(' ($dayNames)');
        }
        break;
        
      case RecurrenceType.monthly:
        if (interval == 1) {
          buffer.write('毎月');
        } else {
          buffer.write('$intervalヶ月ごと');
        }
        
        if (dayOfMonth != null) {
          buffer.write(' ${dayOfMonth}日');
        }
        break;
        
      case RecurrenceType.custom:
        buffer.write('カスタム繰り返し');
        break;
    }
    
    if (endDate != null) {
      final formattedDate = '${endDate!.year}/${endDate!.month}/${endDate!.day}';
      buffer.write(' ($formattedDateまで)');
    }
    
    return buffer.toString();
  }
}

