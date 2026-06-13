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
    this.somedayMerged = false,
    this.settingsContextual = false,
    this.mergedLabel,
    super.key,
  });

  final VoidCallback onTodayTap;
  final VoidCallback onAddTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSomedayLongPress;
  final bool isSomedayActive;

  /// SOMEDAY 配下の詳細（カスタムリスト等）を表示中は true。
  /// TODAY セグメントを収納し、SOMEDAY セグメントが全幅に統合される。
  final bool somedayMerged;

  /// 設定ボタンが「リスト固有の設定」として動作するコンテキストでは true。
  /// アイコンが settings → tune にモーフし、動的なコンテキスト変化を表現する。
  final bool settingsContextual;

  /// マージ時に SOMEDAY セグメントへ表示するラベル（リスト名など）。
  final String? mergedLabel;

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
                  merged: somedayMerged,
                  mergedLabel: mergedLabel,
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
                  icon: settingsContextual
                      ? Icons.tune
                      : Icons.settings_outlined,
                  filled: false,
                  onTap: onSettingsTap!,
                  tooltip: settingsContextual ? 'List settings' : 'Settings',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// TODAY/SOMEDAY のセグメント。アクティブ側に白いピルがスライドする。
///
/// [merged] が true のときは TODAY を左へ収納し、SOMEDAY セグメントが
/// 全幅に統合される（カスタムリスト等の詳細表示中）。解除時は TODAY が
/// 左から滑らかに復帰する。
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.isSomedayActive,
    required this.merged,
    required this.onTodayTap,
    required this.onSomedayTap,
    this.mergedLabel,
    this.onSomedayLongPress,
  });

  final bool isSomedayActive;
  final bool merged;
  final String? mergedLabel;
  final VoidCallback onTodayTap;
  final VoidCallback onSomedayTap;
  final VoidCallback? onSomedayLongPress;

  @override
  Widget build(BuildContext context) {
    const dur = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final half = w / 2;

        final todayWidth = merged ? 0.0 : half;
        final somedayLeft = merged ? 0.0 : half;
        final somedayWidth = merged ? w : half;
        final indicatorLeft = merged ? 0.0 : (isSomedayActive ? half : 0.0);
        final indicatorWidth = merged ? w : half;

        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              // スライド/拡縮するアクティブインジケーター
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: indicatorLeft,
                width: indicatorWidth,
                top: 2,
                bottom: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),

              // TODAY セグメント（マージ時は左へ収納）
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: 0,
                width: todayWidth,
                top: 0,
                bottom: 0,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: half,
                    child: SizedBox(
                      width: half,
                      child: AnimatedOpacity(
                        duration: dur,
                        opacity: merged ? 0.0 : 1.0,
                        child: _SegmentItem(
                          icon: Icons.wb_sunny_rounded,
                          label: 'TODAY',
                          selected: !isSomedayActive,
                          onTap: onTodayTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // SOMEDAY セグメント（マージ時は全幅に統合、戻る導線）
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: somedayLeft,
                width: somedayWidth,
                top: 0,
                bottom: 0,
                child: _SegmentItem(
                  icon: merged
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.calendar_month_rounded,
                  label: merged ? (mergedLabel ?? 'SOMEDAY') : 'SOMEDAY',
                  selected: isSomedayActive,
                  onTap: onSomedayTap,
                  onLongPress: onSomedayLongPress,
                ),
              ),
            ],
          ),
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
            // コンテキスト変化（settings ⇄ tune 等）を fade + rotate でモーフ
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: RotationTransition(
                    turns: Tween<double>(begin: 0.85, end: 1)
                        .animate(animation),
                    child: child,
                  ),
                );
              },
              child: Icon(
                icon,
                key: ValueKey(icon.codePoint),
                color: fg,
                size: filled ? 26 : 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
