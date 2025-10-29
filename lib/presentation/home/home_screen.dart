import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../providers/date_provider.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/date_tab_bar.dart';
import '../../widgets/day_page.dart';

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

  void _jumpToToday(List<DateTime> dates) {
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
      setState(() {
        _showingSomeday = false;
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dates = ref.watch(dateListProvider);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Todoページ部分
                Expanded(
                  child: _showingSomeday
                      ? const DayPage(date: null) // Somedayページ
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: dates.length,
                          itemBuilder: (context, index) {
                            return DayPage(date: dates[index]);
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

                // 底部ナビゲーション
                BottomNavigation(
                  onTodayTap: () => _jumpToToday(dates),
                  onAddTap: () {
                    // TODO: Phase2でクイック追加ダイアログを実装
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('クイック追加は後で実装します'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onSomedayTap: _showSomeday,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
