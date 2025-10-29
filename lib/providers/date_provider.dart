import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 現在表示中の日付を管理するProvider
final currentDateProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 日付リストを生成するProvider（今日を中心に前後7日）
final dateListProvider = Provider<List<DateTime>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  final dates = <DateTime>[];
  // 過去7日
  for (var i = 7; i > 0; i--) {
    dates.add(today.subtract(Duration(days: i)));
  }
  // 今日
  dates.add(today);
  // 未来7日
  for (var i = 1; i <= 7; i++) {
    dates.add(today.add(Duration(days: i)));
  }
  
  return dates;
});

/// 初期ページインデックス（今日の位置）
final initialPageIndexProvider = Provider<int>((ref) {
  return 7; // 過去7日分があるので、今日は8番目（index 7）
});

