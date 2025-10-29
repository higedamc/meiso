import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';

/// 日付タブバー
class DateTabBar extends StatelessWidget {
  const DateTabBar({
    required this.dates,
    required this.currentIndex,
    required this.onDateTap,
    super.key,
  });

  final List<DateTime> dates;
  final int currentIndex;
  final Function(int) onDateTap;

  @override
  Widget build(BuildContext context) {
    // 現在の日付を中心に5日分表示
    final displayDates = _getDisplayDates();

    return Container(
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade400,
            Colors.deepPurple.shade600,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: displayDates.map((dateInfo) {
          final isSelected = dateInfo['index'] == currentIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onDateTap(dateInfo['index'] as int),
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      )
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dateInfo['monthDay'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSelected ? 16 : 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateInfo['weekday'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSelected ? 20 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 表示する日付を取得（現在を中心に前後2日）
  List<Map<String, dynamic>> _getDisplayDates() {
    final result = <Map<String, dynamic>>[];
    final start = (currentIndex - 2).clamp(0, dates.length - 5);
    final end = (start + 5).clamp(5, dates.length);

    for (var i = start; i < end; i++) {
      final date = dates[i];
      result.add({
        'index': i,
        'monthDay': DateFormat('M/d').format(date),
        'weekday': DateFormat('EEE', 'en_US').format(date).toUpperCase(),
      });
    }

    return result;
  }
}

