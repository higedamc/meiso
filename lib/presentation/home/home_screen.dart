import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meiso/l10n/app_localizations.dart';

import '../../models/custom_list.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/bootstrap_sync_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/date_provider.dart';
import '../../widgets/add_list_chooser.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/date_tab_bar.dart';
import '../../widgets/day_page.dart';
import '../../widgets/expandable_calendar.dart';
import '../../widgets/expandable_custom_list_modal.dart';
import '../../widgets/slide_up_route.dart';
import '../../widgets/todo_edit_screen.dart';
import '../list_detail/list_detail_screen.dart';
import '../planning_detail/planning_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../someday/someday_screen.dart';

/// Meisoのメイン画面
/// 1日分を全画面表示し、スワイプで日付移動
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late PageController _somedayPageController;
  int _currentPageIndex = 7; // 初期値は今日（過去7日分があるので）
  bool _showingSomeday = false;

  // SOMEDAY 配下の詳細（カスタムリスト / プランニング）を
  // コンテンツ領域内（ボトムバーの上）に下→上スライドで重ねて表示する。
  CustomList? _activeCustomList;
  PlanningCategory? _activePlanning;
  bool _detailOpen = false; // ボトムバーのマージ状態（即時トグル）
  late AnimationController _detailController;

  bool get _hasDetail => _activeCustomList != null || _activePlanning != null;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _somedayPageController = PageController();
    _detailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addStatusListener((status) {
        // 下スライドで収納し切ったら詳細をツリーから外す
        if (status == AnimationStatus.dismissed && !_detailOpen) {
          setState(() {
            _activeCustomList = null;
            _activePlanning = null;
          });
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _somedayPageController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  /// カスタムリスト詳細を下→上スライドで開く（SOMEDAY を背面に残す）。
  void _openCustomList(CustomList list) {
    setState(() {
      _activeCustomList = list;
      _activePlanning = null;
      _detailOpen = true;
      _showingSomeday = true; // 背面は SOMEDAY
    });
    _detailController.forward(from: 0);
  }

  /// プランニングカテゴリ詳細を下→上スライドで開く。
  void _openPlanning(PlanningCategory category) {
    setState(() {
      _activePlanning = category;
      _activeCustomList = null;
      _detailOpen = true;
      _showingSomeday = true; // 背面は SOMEDAY
    });
    _detailController.forward(from: 0);
  }

  /// 詳細を上→下スライドで収納し、SOMEDAY へ戻る。
  void _closeDetailToSomeday() {
    if (!_hasDetail) return;
    setState(() {
      _detailOpen = false; // ボトムバーは即マージ解除（TODAY が左から復帰）
      _showingSomeday = true;
    });
    _detailController.reverse();
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
    // SOMEDAY画面（フルスクリーン）を表示
    setState(() {
      _showingSomeday = true;
    });
    
    // カレンダーとモーダルは閉じる
    ref.read(calendarVisibleProvider.notifier).state = false;
    ref.read(customListModalVisibleProvider.notifier).state = false;
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
      slideUpRoute<void>(const SettingsScreen()),
    );
  }

  void _showAddTodoDialog(BuildContext context, WidgetRef ref) {
    // 現在表示中の日付を取得
    final dates = ref.read(dateListProvider);
    final currentDate = _showingSomeday ? null : dates[_currentPageIndex];

    Navigator.of(context).push(
      slideUpRoute<void>(
        TodoEditScreen(date: currentDate),
        fullscreenDialog: true,
      ),
    );
  }

  /// 永続ボトムバーの「+」を、現在のコンテキストに応じて振り分ける。
  /// - カスタムリスト詳細表示中: そのリストにタスク追加
  /// - プランニング詳細表示中: 追加は開発中（スナックバー通知）
  /// - SOMEDAY 表示中: リスト追加ダイアログ
  /// - TODAY 表示中: その日付にタスク追加
  void _onAddPressed(BuildContext context, WidgetRef ref) {
    if (_activeCustomList != null) {
      final list = _activeCustomList!;
      Navigator.of(context).push(
        slideUpRoute<void>(
          TodoEditScreen(
            customListId: list.id,
            customListName: list.name,
            isGroupList: list.isGroup,
          ),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    if (_activePlanning != null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.todoAddFeatureInDevelopment)),
      );
      return;
    }
    if (_showingSomeday) {
      showAddListChooser(context);
      return;
    }
    _showAddTodoDialog(context, ref);
  }

  /// SOMEDAY の上に重ねる詳細ビュー（カスタムリスト / プランニング）。
  /// Home 側がボトムバーを提供するため、embedded で描画する。
  Widget _buildDetailView() {
    if (_activeCustomList != null) {
      return ListDetailScreen(
        key: ValueKey('detail-${_activeCustomList!.id}'),
        customList: _activeCustomList!,
        embedded: true,
      );
    }
    if (_activePlanning != null) {
      return PlanningDetailScreen(
        key: ValueKey('detail-planning-${_activePlanning!.name}'),
        category: _activePlanning!,
        embedded: true,
      );
    }
    return const SizedBox.shrink();
  }

  /// AnimatedSwitcher 用に、現在の状態へ対応するメインビューを返す。
  /// 各ビューに状態識別キーを付与し、状態変化時のみ遷移アニメを発火させる。
  Widget _buildMainView({
    required List<DateTime> dates,
    required bool isCalendarVisible,
    required int weekStartDay,
    required bool isCustomListModalVisible,
    required WidgetRef ref,
  }) {
    if (_showingSomeday) {
      return SomedayScreen(
        key: const ValueKey('view-someday'),
        showBottomNav: false,
        onClose: () {
          setState(() {
            _showingSomeday = false;
          });
        },
        onListTap: _openCustomList,
        onPlanningTap: _openPlanning,
      );
    }
    if (isCustomListModalVisible) {
      return ExpandableCustomListModal(
        key: const ValueKey('view-modal'),
        isVisible: isCustomListModalVisible,
        onListSelected: () {
          ref.read(customListModalVisibleProvider.notifier).state = false;
        },
      );
    }
    return Column(
      key: const ValueKey('view-today'),
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              return DayPage(date: dates[index]);
            },
          ),
        ),
        DateTabBar(
          dates: dates,
          currentIndex: _currentPageIndex,
          onDateTap: _onDateTabTap,
        ),
        ExpandableCalendar(
          isVisible: isCalendarVisible,
          weekStartDay: weekStartDay,
          onDaySelected: (selectedDay) =>
              _onCalendarDaySelected(dates, selectedDay),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dates = ref.watch(dateListProvider);
        final isCalendarVisible = ref.watch(calendarVisibleProvider);
        final isCustomListModalVisible = ref.watch(customListModalVisibleProvider);
        final appSettingsAsync = ref.watch(appSettingsProvider);
        final bootstrapState = ref.watch(bootstrapSyncProvider);
        final weekStartDay = appSettingsAsync.maybeWhen(
          data: (settings) => settings.weekStartDay,
          orElse: () => 1, // デフォルトは月曜日
        );

        return PopScope(
          canPop: !(_showingSomeday || _hasDetail),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_hasDetail) {
              _closeDetailToSomeday();
            } else if (_showingSomeday) {
              setState(() => _showingSomeday = false);
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              top: false, // 画面全体を活用
              child: IgnorePointer(
                ignoring: bootstrapState.isBlocking,
                child: Column(
                  children: [
                    // コンテンツ領域（ボトムバーの上）。背面の TODAY/SOMEDAY と
                    // その上に重なる詳細スライドを Stack で重ねる。
                    Expanded(
                      child: Stack(
                        children: [
                          // 背面: TODAY / SOMEDAY のシームレス遷移
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.025),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            child: _buildMainView(
                              dates: dates,
                              isCalendarVisible: isCalendarVisible,
                              weekStartDay: weekStartDay,
                              isCustomListModalVisible: isCustomListModalVisible,
                              ref: ref,
                            ),
                          ),

                          // 前面: SOMEDAY から下→上に出現する詳細。
                          // 閉じる時は上→下に収納される。
                          if (_hasDetail)
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _detailController,
                                  curve: Curves.easeOutCubic,
                                  reverseCurve: Curves.easeInCubic,
                                ),
                              ),
                              child: _buildDetailView(),
                            ),
                        ],
                      ),
                    ),

                    // 底部ナビゲーション（永続表示）。詳細表示中は TODAY を収納し
                    // SOMEDAY が全幅に統合される。
                    BottomNavigation(
                      onTodayTap: () {
                        ref
                            .read(customListModalVisibleProvider.notifier)
                            .state = false;
                        if (_hasDetail) {
                          setState(() {
                            _detailOpen = false;
                            _showingSomeday = false;
                          });
                          _detailController.reverse();
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _jumpToTodayPage(dates),
                          );
                          return;
                        }
                        _jumpToToday(dates);
                      },
                      onAddTap: () => _onAddPressed(context, ref),
                      onSomedayTap: () {
                        if (_hasDetail) {
                          _closeDetailToSomeday();
                        } else {
                          _showSomeday();
                        }
                      },
                      onSettingsTap: _openSettings,
                      onSomedayLongPress: _openSettings,
                      isSomedayActive: _showingSomeday || _detailOpen,
                      somedayMerged: _detailOpen,
                      mergedLabel:
                          _activeCustomList?.name ?? _activePlanning?.label,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

