import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/date_provider.dart';
import '../../features/settings/presentation/providers/app_settings_providers_compat.dart';
import '../../features/custom_list/presentation/providers/custom_list_providers_compat.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/date_tab_bar.dart';
import '../../widgets/day_page.dart';
import '../../widgets/expandable_calendar.dart';
import '../../widgets/expandable_custom_list_modal.dart';
import '../../widgets/todo_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../someday/someday_screen.dart';
import '../list_detail/list_detail_screen.dart';

/// Meisoのメイン画面
/// 1日分を全画面表示し、スワイプで日付移動
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    // Somedayモード表示中の場合は、今日に戻る
    if (_showingSomeday) {
      setState(() {
        _showingSomeday = false;
      });
      
      // 次のフレームで今日にジャンプ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToTodayPage(dates);
      });
      return;
    }

    // カレンダーの表示/非表示をトグル
    final isVisible = ref.read(calendarVisibleProvider);
    ref.read(calendarVisibleProvider.notifier).state = !isVisible;

    // カレンダーが非表示になる場合は、今日にジャンプ
    if (isVisible) {
      _jumpToTodayPage(dates);
    }
  }
  
  /// 今日のページにジャンプする
  void _jumpToTodayPage(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = dates.indexWhere((date) => 
      date.year == today.year && 
      date.month == today.month && 
      date.day == today.day
    );
    
    if (todayIndex != -1) {
      // 今日が日付リストに存在する場合は、そのページにジャンプ
      _pageController.animateToPage(
        todayIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 今日が日付リストに存在しない場合は、今日を中心とした日付リストを生成
      ref.read(centerDateProvider.notifier).state = today;
      
      // 次のフレームで中心ページにジャンプ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            7, // 中心ページ（index 7）= 今日
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showSomeday() {
    // モーダルが既に表示されている場合は、最後に見たカスタムリストに直接ジャンプ
    final isModalVisible = ref.read(customListModalVisibleProvider);
    
    if (isModalVisible) {
      // 最後に見ていたカスタムリストを取得
      final appSettings = ref.read(appSettingsProviderCompat);
      appSettings.whenData((settings) {
        final lastViewedListId = settings.lastViewedCustomListId;
        
        if (lastViewedListId != null) {
          // カスタムリストを取得
          final customListsAsync = ref.read(customListsProviderCompat);
          customListsAsync.whenData((customLists) {
            final targetList = customLists.firstWhere(
              (list) => list.id == lastViewedListId,
              orElse: () => customLists.first,
            );
            
            // モーダルを閉じる
            ref.read(customListModalVisibleProvider.notifier).state = false;
            
            // リスト詳細画面に遷移
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListDetailScreen(
                  customList: targetList,
                ),
              ),
            );
          });
        } else {
          // 最後に見たリストがない場合は、モーダルを閉じる
          ref.read(customListModalVisibleProvider.notifier).state = false;
        }
      });
    } else {
      // モーダルを表示
      ref.read(customListModalVisibleProvider.notifier).state = true;
      
      // カレンダーは閉じる
      ref.read(calendarVisibleProvider.notifier).state = false;
    }
  }

  void _onDateTabTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onCalendarDaySelected(List<DateTime> dates, DateTime selectedDay) {
    // カレンダーを閉じる
    ref.read(calendarVisibleProvider.notifier).state = false;

    // Somedayモードを解除
    setState(() {
      _showingSomeday = false;
    });

    // 選択された日付を正規化
    final selectedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    
    // 選択された日付が現在の日付リストに存在するか確認
    final selectedIndex = dates.indexWhere((date) => 
      date.year == selectedDate.year && 
      date.month == selectedDate.month && 
      date.day == selectedDate.day
    );
    
    if (selectedIndex != -1) {
      // 日付リストに存在する場合は、そのページにジャンプ
      _pageController.animateToPage(
        selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 日付リストに存在しない場合は、その日付を中心とした新しい日付リストを生成
      ref.read(centerDateProvider.notifier).state = selectedDate;
      
      // 次のフレームで中心ページにジャンプ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(7); // 中心ページ（index 7）にジャンプ
        }
      });
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TodoEditScreen(date: currentDate),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dates = ref.watch(dateListProvider);
        final isCalendarVisible = ref.watch(calendarVisibleProvider);
        final isCustomListModalVisible = ref.watch(customListModalVisibleProvider);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            top: false, // 画面全体を活用
            child: Column(
              children: [
                // Todoページ部分
                Expanded(
                  child: _showingSomeday
                      ? SomedayScreen(
                          onClose: () {
                            setState(() {
                              _showingSomeday = false;
                            });
                          },
                        )
                      : isCustomListModalVisible
                      ? ExpandableCustomListModal(
                          isVisible: isCustomListModalVisible,
                          onListSelected: () {
                            // リストが選択されたらモーダルを閉じる
                            ref.read(customListModalVisibleProvider.notifier).state = false;
                          },
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

                // 日付タブバー（SOMEDAY表示時、モーダル表示時は非表示）
                if (!_showingSomeday && !isCustomListModalVisible)
                  DateTabBar(
                    dates: dates,
                    currentIndex: _currentPageIndex,
                    onDateTap: _onDateTabTap,
                  ),

                // カレンダー（TODAYボタンタップで展開、モーダル表示時は非表示）
                if (!_showingSomeday && !isCustomListModalVisible)
                  ExpandableCalendar(
                    isVisible: isCalendarVisible,
                    onDaySelected: (selectedDay) => 
                        _onCalendarDaySelected(dates, selectedDay),
                  ),

                // 底部ナビゲーション（SOMEDAY表示時は非表示、モーダル表示時は表示）
                if (!_showingSomeday)
                  BottomNavigation(
                    onTodayTap: () {
                      // カスタムリストモーダルを閉じる
                      ref.read(customListModalVisibleProvider.notifier).state = false;
                      _jumpToToday(dates);
                    },
                    onAddTap: () => _showAddTodoDialog(context, ref),
                    onSomedayTap: _showSomeday,
                    onSomedayLongPress: _openSettings,
                    isSomedayActive: isCustomListModalVisible,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

