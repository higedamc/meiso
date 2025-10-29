import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/date_provider.dart';
import '../../providers/todos_provider.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/date_tab_bar.dart';
import '../../widgets/day_page.dart';
import '../../widgets/expandable_calendar.dart';
import '../settings/settings_screen.dart';

/// Meisoのメイン画面
/// 1日分を全画面表示し、スワイプで日付移動
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  late PageController _somedayPageController;
  int _currentPageIndex = 7; // 初期値は今日（過去7日分があるので）
  bool _showingSomeday = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _somedayPageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _somedayPageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
      _showingSomeday = false;
    });
  }

  void _jumpToToday(WidgetRef ref, List<DateTime> dates) {
    // カレンダーの表示/非表示をトグル
    final isVisible = ref.read(calendarVisibleProvider);
    ref.read(calendarVisibleProvider.notifier).state = !isVisible;

    // カレンダーが非表示になる場合は、今日にジャンプ
    if (isVisible) {
      // まずSomedayモードを解除
      setState(() {
        _showingSomeday = false;
      });

      // 次のフレームでアニメーション実行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayIndex = dates.indexWhere((date) => 
          date.year == today.year && 
          date.month == today.month && 
          date.day == today.day
        );
        
        if (todayIndex != -1) {
          _pageController.animateToPage(
            todayIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showSomeday() {
    setState(() {
      _showingSomeday = true;
    });
  }

  void _onDateTabTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onCalendarDaySelected(WidgetRef ref, List<DateTime> dates, DateTime selectedDay) {
    // カレンダーを閉じる
    ref.read(calendarVisibleProvider.notifier).state = false;

    // Somedayモードを解除
    setState(() {
      _showingSomeday = false;
    });

    // 選択された日付のページにジャンプ
    final selectedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final selectedIndex = dates.indexWhere((date) => 
      date.year == selectedDate.year && 
      date.month == selectedDate.month && 
      date.day == selectedDate.day
    );
    
    if (selectedIndex != -1) {
      _pageController.animateToPage(
        selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context, WidgetRef ref) {
    // 現在表示中の日付を取得
    final dates = ref.read(dateListProvider);
    final currentDate = _showingSomeday ? null : dates[_currentPageIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddTodoBottomSheet(date: currentDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dates = ref.watch(dateListProvider);
        final isCalendarVisible = ref.watch(calendarVisibleProvider);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            top: false, // 画面全体を活用
            child: Column(
              children: [
                // Todoページ部分
                Expanded(
                  child: _showingSomeday
                      ? DayPage(
                          date: null, // Somedayページ
                          onSettingsTap: _openSettings,
                        )
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: dates.length,
                          itemBuilder: (context, index) {
                            return DayPage(
                              date: dates[index],
                              onSettingsTap: _openSettings,
                            );
                          },
                        ),
                ),

              // 日付タブバー（Someday表示時は非表示）
              if (!_showingSomeday)
                DateTabBar(
                  dates: dates,
                  currentIndex: _currentPageIndex,
                  onDateTap: _onDateTabTap,
                ),

                // カレンダー（TODAYボタンタップで展開）
                ExpandableCalendar(
                  isVisible: isCalendarVisible,
                  onDaySelected: (selectedDay) => 
                      _onCalendarDaySelected(ref, dates, selectedDay),
                ),

                // 底部ナビゲーション
                BottomNavigation(
                  onTodayTap: () => _jumpToToday(ref, dates),
                  onAddTap: () => _showAddTodoDialog(context, ref),
                  onSomedayTap: _showSomeday,
                  onSomedayLongPress: _openSettings,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Todo追加用のボトムシート
class _AddTodoBottomSheet extends StatefulWidget {
  const _AddTodoBottomSheet({required this.date});

  final DateTime? date;

  @override
  State<_AddTodoBottomSheet> createState() => _AddTodoBottomSheetState();
}

class _AddTodoBottomSheetState extends State<_AddTodoBottomSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 表示されたらすぐにフォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 入力フィールド
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'タスクを入力',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.deepPurple.shade700,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: AppTheme.todoTitle,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveTodo(ref),
              ),
              const SizedBox(height: 16),
              // SAVEボタン
              ElevatedButton(
                onPressed: () => _saveTodo(ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveTodo(WidgetRef ref) {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(todosProvider.notifier).addTodo(text, widget.date);
      Navigator.of(context).pop();
    }
  }
}
