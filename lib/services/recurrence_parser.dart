import '../models/recurrence_pattern.dart';

/// タスクのタイトルから繰り返しパターンを自動検出するパーサー
/// 
/// TeuxDeux風の自然言語パース機能を提供
/// 
/// 例:
/// - "clean room every day" → RecurrencePattern(type: daily, interval: 1)
/// - "meeting every monday" → RecurrencePattern(type: weekly, weekdays: [1])
/// - "review every 2 weeks" → RecurrencePattern(type: weekly, interval: 2)
class RecurrenceParser {
  /// タイトルから繰り返しパターンを検出
  /// 
  /// 戻り値:
  /// - pattern: 検出された繰り返しパターン（検出されない場合はnull）
  /// - cleanTitle: 繰り返しキーワードを削除したタイトル
  static RecurrenceParseResult parse(String title, DateTime? date) {
    final trimmedTitle = title.trim().toLowerCase();
    
    // "every" キーワードがない場合は早期リターン
    if (!trimmedTitle.contains('every')) {
      return RecurrenceParseResult(
        pattern: null,
        cleanTitle: title.trim(),
      );
    }
    
    // 各パターンを順番に試す
    
    // 1. "every N days" / "every day" / "everyday"
    final dailyResult = _parseDailyPattern(trimmedTitle, title);
    if (dailyResult != null) return dailyResult;
    
    // 2. "every N weeks" / "every week"
    final weeklyResult = _parseWeeklyPattern(trimmedTitle, title, date);
    if (weeklyResult != null) return weeklyResult;
    
    // 3. "every monday" / "every mon" など（特定曜日）
    final weekdayResult = _parseWeekdayPattern(trimmedTitle, title);
    if (weekdayResult != null) return weekdayResult;
    
    // 4. "every N months" / "every month"
    final monthlyResult = _parseMonthlyPattern(trimmedTitle, title, date);
    if (monthlyResult != null) return monthlyResult;
    
    // 5. "every N years" / "every year"
    final yearlyResult = _parseYearlyPattern(trimmedTitle, title, date);
    if (yearlyResult != null) return yearlyResult;
    
    // パターンにマッチしない場合
    return RecurrenceParseResult(
      pattern: null,
      cleanTitle: title.trim(),
    );
  }
  
  /// "every N days" / "every day" / "everyday" / "every other day" / "every weekday" パターンをパース
  static RecurrenceParseResult? _parseDailyPattern(String lowerTitle, String originalTitle) {
    // "everyday" (1単語)
    final everydayRegex = RegExp(r'\beveryday\b');
    if (everydayRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(RegExp(r'\beveryday\b', caseSensitive: false), '').trim();
      return RecurrenceParseResult(
        pattern: const RecurrencePattern(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every other day" (2日ごと)
    final everyOtherDayRegex = RegExp(r'\bevery\s+other\s+day\b');
    if (everyOtherDayRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+other\s+day\b', caseSensitive: false),
        '',
      ).trim();
      return RecurrenceParseResult(
        pattern: const RecurrencePattern(
          type: RecurrenceType.daily,
          interval: 2,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every weekday" (月〜金)
    final everyWeekdayRegex = RegExp(r'\bevery\s+weekday\b');
    if (everyWeekdayRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+weekday\b', caseSensitive: false),
        '',
      ).trim();
      return RecurrenceParseResult(
        pattern: const RecurrencePattern(
          type: RecurrenceType.weekly,
          interval: 1,
          weekdays: [1, 2, 3, 4, 5], // 月〜金
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every N days"
    final everyNDaysRegex = RegExp(r'\bevery\s+(\d+)\s+days?\b');
    final match = everyNDaysRegex.firstMatch(lowerTitle);
    if (match != null) {
      final interval = int.parse(match.group(1)!);
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+\d+\s+days?\b', caseSensitive: false),
        '',
      ).trim();
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.daily,
          interval: interval,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every day"
    final everyDayRegex = RegExp(r'\bevery\s+day\b');
    if (everyDayRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+day\b', caseSensitive: false),
        '',
      ).trim();
      return RecurrenceParseResult(
        pattern: const RecurrencePattern(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    return null;
  }
  
  /// "every N weeks" / "every week" / "every other week" パターンをパース
  static RecurrenceParseResult? _parseWeeklyPattern(
    String lowerTitle,
    String originalTitle,
    DateTime? date,
  ) {
    // "every other week" (2週間ごと)
    final everyOtherWeekRegex = RegExp(r'\bevery\s+other\s+week\b');
    if (everyOtherWeekRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+other\s+week\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の曜日を使用
      final targetDate = date ?? DateTime.now();
      final weekday = targetDate.weekday;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.weekly,
          interval: 2,
          weekdays: [weekday],
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every N weeks"
    final everyNWeeksRegex = RegExp(r'\bevery\s+(\d+)\s+weeks?\b');
    final matchN = everyNWeeksRegex.firstMatch(lowerTitle);
    if (matchN != null) {
      final interval = int.parse(matchN.group(1)!);
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+\d+\s+weeks?\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の曜日を使用（dateが指定されていない場合は今日）
      final targetDate = date ?? DateTime.now();
      final weekday = targetDate.weekday;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.weekly,
          interval: interval,
          weekdays: [weekday],
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every week"
    final everyWeekRegex = RegExp(r'\bevery\s+week\b');
    if (everyWeekRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+week\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の曜日を使用
      final targetDate = date ?? DateTime.now();
      final weekday = targetDate.weekday;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.weekly,
          interval: 1,
          weekdays: [weekday],
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    return null;
  }
  
  /// "every monday" / "every mon" など（特定曜日）パターンをパース
  static RecurrenceParseResult? _parseWeekdayPattern(String lowerTitle, String originalTitle) {
    // 曜日マッピング（完全名 + 略称）
    final weekdayMap = {
      // 完全名
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
      // 略称
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };
    
    for (final entry in weekdayMap.entries) {
      final weekdayName = entry.key;
      final weekdayNumber = entry.value;
      
      final regex = RegExp('\\bevery\\s+$weekdayName\\b');
      if (regex.hasMatch(lowerTitle)) {
        final cleanTitle = originalTitle.replaceAll(
          RegExp('\\bevery\\s+$weekdayName\\b', caseSensitive: false),
          '',
        ).trim();
        
        return RecurrenceParseResult(
          pattern: RecurrencePattern(
            type: RecurrenceType.weekly,
            interval: 1,
            weekdays: [weekdayNumber],
          ),
          cleanTitle: cleanTitle,
        );
      }
    }
    
    return null;
  }
  
  /// "every N months" / "every month" パターンをパース
  static RecurrenceParseResult? _parseMonthlyPattern(
    String lowerTitle,
    String originalTitle,
    DateTime? date,
  ) {
    // "every N months"
    final everyNMonthsRegex = RegExp(r'\bevery\s+(\d+)\s+months?\b');
    final matchN = everyNMonthsRegex.firstMatch(lowerTitle);
    if (matchN != null) {
      final interval = int.parse(matchN.group(1)!);
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+\d+\s+months?\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の日付を使用
      final targetDate = date ?? DateTime.now();
      final dayOfMonth = targetDate.day;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.monthly,
          interval: interval,
          dayOfMonth: dayOfMonth,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every month"
    final everyMonthRegex = RegExp(r'\bevery\s+month\b');
    if (everyMonthRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+month\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の日付を使用
      final targetDate = date ?? DateTime.now();
      final dayOfMonth = targetDate.day;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.monthly,
          interval: 1,
          dayOfMonth: dayOfMonth,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    return null;
  }
  
  /// "every N years" / "every year" パターンをパース
  static RecurrenceParseResult? _parseYearlyPattern(
    String lowerTitle,
    String originalTitle,
    DateTime? date,
  ) {
    // "every N years"
    final everyNYearsRegex = RegExp(r'\bevery\s+(\d+)\s+years?\b');
    final matchN = everyNYearsRegex.firstMatch(lowerTitle);
    if (matchN != null) {
      final interval = int.parse(matchN.group(1)!);
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+\d+\s+years?\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の日付を使用
      final targetDate = date ?? DateTime.now();
      final dayOfMonth = targetDate.day;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.yearly,
          interval: interval,
          dayOfMonth: dayOfMonth,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    // "every year"
    final everyYearRegex = RegExp(r'\bevery\s+year\b');
    if (everyYearRegex.hasMatch(lowerTitle)) {
      final cleanTitle = originalTitle.replaceAll(
        RegExp(r'\bevery\s+year\b', caseSensitive: false),
        '',
      ).trim();
      
      // 今日の日付を使用
      final targetDate = date ?? DateTime.now();
      final dayOfMonth = targetDate.day;
      
      return RecurrenceParseResult(
        pattern: RecurrencePattern(
          type: RecurrenceType.yearly,
          interval: 1,
          dayOfMonth: dayOfMonth,
        ),
        cleanTitle: cleanTitle,
      );
    }
    
    return null;
  }
}

/// パース結果
class RecurrenceParseResult {
  final RecurrencePattern? pattern;
  final String cleanTitle;
  
  const RecurrenceParseResult({
    required this.pattern,
    required this.cleanTitle,
  });
}

