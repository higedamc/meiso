import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app_theme.dart';

/// 展開可能なカレンダーウィジェット
class ExpandableCalendar extends StatelessWidget {
  const ExpandableCalendar({
    required this.isVisible,
    required this.onDaySelected,
    super.key,
  });

  final bool isVisible;
  final Function(DateTime) onDaySelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isVisible
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade700,
                    Colors.deepPurple.shade900,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: DateTime.now(),
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (day) {
                  return isSameDay(day, DateTime.now());
                },
                onDaySelected: (selectedDay, focusedDay) {
                  onDaySelected(selectedDay);
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                  leftChevronIcon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  // 今日
                  todayDecoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                  // 選択された日
                  selectedDecoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                  // 通常の日
                  defaultTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  // 範囲外の日
                  outsideTextStyle: const TextStyle(
                    color: Colors.white30,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

