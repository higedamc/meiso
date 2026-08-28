import 'package:flutter/material.dart';

/// 下から上へスライドして開き、閉じる際は上から下へ収納されるルート。
///
/// ボトムバー由来の「ピア / モーダル」的な遷移（リスト詳細・タスク追加・設定など）に
/// 使用する。階層を深掘りするドリルダウン遷移（水平スライド）とは意図的に区別し、
/// 縦方向の遷移で文脈の切り替わりを直感的に伝える。
Route<T> slideUpRoute<T>(
  Widget page, {
  bool fullscreenDialog = false,
}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
