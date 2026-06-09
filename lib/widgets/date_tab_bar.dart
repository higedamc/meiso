import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 日付タブバー（横スクロール対応）
class DateTabBar extends ConsumerStatefulWidget {
  const DateTabBar({
    required this.dates,
    required this.currentIndex,
    required this.onDateTap,
    super.key,
  });

  final List<DateTime> dates;
  final int currentIndex;
  final void Function(int) onDateTap;

  @override
  ConsumerState<DateTabBar> createState() => _DateTabBarState();
}

class _DateTabBarState extends ConsumerState<DateTabBar> {
  late ScrollController _scrollController;
  static const double _itemWidth = 80; // 各日付タブの幅

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 初期位置を設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(widget.currentIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(DateTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 選択されたインデックスが変わったら自動スクロール
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 指定されたインデックスにスクロール
  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    // 画面の中央に表示されるようにスクロール位置を計算
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition = (index * _itemWidth) - (screenWidth / 2) + (_itemWidth / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final scrollTo = targetPosition.clamp(0.0, maxScroll);

    if (animate) {
      _scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(scrollTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 84,
      color: Colors.transparent,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: List.generate(widget.dates.length, (index) {
            final date = widget.dates[index];
            final isSelected = index == widget.currentIndex;

            return SizedBox(
              width: _itemWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => widget.onDateTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('M/d').format(date),
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEE', 'en_US').format(date).toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

