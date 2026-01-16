import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app_theme.dart';

/// 展開可能なカレンダーウィジェット
class ExpandableCalendar extends StatefulWidget {
  const ExpandableCalendar({
    required this.isVisible,
    required this.onDaySelected,
    this.weekStartDay = 1, // デフォルトは月曜日
    super.key,
  });

  final bool isVisible;
  final void Function(DateTime) onDaySelected;
  final int weekStartDay; // 0=日曜, 1=月曜, ..., 6=土曜

  @override
  State<ExpandableCalendar> createState() => _ExpandableCalendarState();
}

class _ExpandableCalendarState extends State<ExpandableCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// weekStartDay (0-6) を StartingDayOfWeek に変換
  StartingDayOfWeek _getStartingDayOfWeek() {
    switch (widget.weekStartDay % 7) {
      case 0:
        return StartingDayOfWeek.sunday;
      case 1:
        return StartingDayOfWeek.monday;
      case 2:
        return StartingDayOfWeek.tuesday;
      case 3:
        return StartingDayOfWeek.wednesday;
      case 4:
        return StartingDayOfWeek.thursday;
      case 5:
        return StartingDayOfWeek.friday;
      case 6:
        return StartingDayOfWeek.saturday;
      default:
        return StartingDayOfWeek.monday; // デフォルト
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        heightFactor: widget.isVisible ? 1.0 : 0.0,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkPurple,
                AppTheme.darkPurple,
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: TableCalendar<void>(
            firstDay: DateTime.utc(2020, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            startingDayOfWeek: _getStartingDayOfWeek(),
            selectedDayPredicate: (day) {
              return _selectedDay != null 
                  ? isSameDay(_selectedDay, day)
                  : isSameDay(day, DateTime.now());
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              widget.onDaySelected(selectedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Colors.white,
              ),
              rightChevronIcon: Icon(
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
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              // 選択された日
              selectedDecoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: AppTheme.darkPurple,
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
        ),
      ),
    );
  }
}
