import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 底部ナビゲーションバー（TODAY / SOMEDAY + アクション）
///
/// Thor を参考にした、紫基調のフローティングバー。TODAY/SOMEDAY は
/// スライドするインジケーターでアニメーション切り替えし、右側に追加(+)と
/// 設定アイコンを配置する。
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    required this.onTodayTap,
    required this.onAddTap,
    required this.onSomedayTap,
    this.onSettingsTap,
    this.onSomedayLongPress,
    this.isSomedayActive = false,
    super.key,
  });

  final VoidCallback onTodayTap;
  final VoidCallback onAddTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSomedayLongPress;
  final bool isSomedayActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 紫主体のグラデーション。薄いラベンダー背景との親和性を保つ。
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF6D28D9), const Color(0xFF4C1D95)]
          : [AppTheme.primaryPurple, const Color(0xFF6D28D9)],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.0 : 0.30),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // TODAY / SOMEDAY セグメント（スライドインジケーター付き）
              Expanded(
                child: _SegmentedTabs(
                  isSomedayActive: isSomedayActive,
                  onTodayTap: onTodayTap,
                  onSomedayTap: onSomedayTap,
                  onSomedayLongPress: onSomedayLongPress,
                ),
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: Icons.add,
                filled: true,
                onTap: onAddTap,
                tooltip: 'Add',
              ),
              if (onSettingsTap != null) ...[
                const SizedBox(width: 4),
                _CircleAction(
                  icon: Icons.settings_outlined,
                  filled: false,
                  onTap: onSettingsTap!,
                  tooltip: 'Settings',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// TODAY/SOMEDAY のセグメント。アクティブ側の下に白いピルがスライドする。
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.isSomedayActive,
    required this.onTodayTap,
    required this.onSomedayTap,
    this.onSomedayLongPress,
  });

  final bool isSomedayActive;
  final VoidCallback onTodayTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSomedayLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segWidth = constraints.maxWidth / 2;
        return Stack(
          alignment: Alignment.center,
          children: [
            // スライドするアクティブインジケーター
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment:
                  isSomedayActive ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: segWidth,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _SegmentItem(
                    icon: Icons.wb_sunny_rounded,
                    label: 'TODAY',
                    selected: !isSomedayActive,
                    onTap: onTodayTap,
                  ),
                ),
                Expanded(
                  child: _SegmentItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'SOMEDAY',
                    selected: isSomedayActive,
                    onTap: onSomedayTap,
                    onLongPress: onSomedayLongPress,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.72);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                  color: color,
                ),
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右側の円形アクションボタン。filled=true は白丸に紫アイコン（追加）、
/// false は半透明の白丸（設定）。
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.filled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? Colors.white : Colors.white.withValues(alpha: 0.16);
    final fg = filled ? AppTheme.primaryPurple : Colors.white;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: fg, size: filled ? 26 : 22),
          ),
        ),
      ),
    );
  }
}
