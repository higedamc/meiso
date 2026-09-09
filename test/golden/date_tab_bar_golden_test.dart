@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/widgets/date_tab_bar.dart';

import 'golden_harness.dart';

/// A fixed Monday-to-Sunday week so the rendered labels never depend on the
/// wall clock. 2026-01-05 is a Monday.
final List<DateTime> _week = List.generate(
  7,
  (i) => DateTime(2026, 1, 5 + i),
);

Widget _bar({required int currentIndex}) {
  return Align(
    alignment: Alignment.topCenter,
    child: DateTabBar(
      dates: _week,
      currentIndex: currentIndex,
      onDateTap: (_) {},
    ),
  );
}

void main() {
  const size = Size(400, 120);

  testWidgets('DateTabBar week with Wednesday selected, light theme', (
    tester,
  ) async {
    await pumpGolden(tester, _bar(currentIndex: 2), size: size);
    await expectGolden(tester, 'date_tab_bar_light');
  });

  testWidgets('DateTabBar week with Wednesday selected, dark theme', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      _bar(currentIndex: 2),
      brightness: Brightness.dark,
      size: size,
    );
    await expectGolden(tester, 'date_tab_bar_dark');
  });
}
