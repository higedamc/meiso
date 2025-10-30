import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 現在表示中の日付を管理するProvider
final currentDateProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 中心となる日付を管理するProvider
final centerDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 日付リストを生成するProvider（中心日付の前後7日）
final dateListProvider = Provider<List<DateTime>>((ref) {
  final centerDate = ref.watch(centerDateProvider);
  
  final dates = <DateTime>[];
  // 過去7日
  for (var i = 7; i > 0; i--) {
    dates.add(centerDate.subtract(Duration(days: i)));
  }
  // 中心日
  dates.add(centerDate);
  // 未来7日
  for (var i = 1; i <= 7; i++) {
    dates.add(centerDate.add(Duration(days: i)));
  }
  
  return dates;
});

/// 初期ページインデックス（中心日の位置）
final initialPageIndexProvider = Provider<int>((ref) {
  return 7; // 過去7日分があるので、中心日は8番目（index 7）
});
