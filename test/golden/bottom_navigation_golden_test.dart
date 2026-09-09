@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/widgets/bottom_navigation.dart';

import 'golden_harness.dart';

void _noop() {}

Widget _bar({
  bool isSomedayActive = false,
  bool somedayMerged = false,
  bool settingsContextual = false,
  String? mergedLabel,
}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: BottomNavigation(
      onTodayTap: _noop,
      onAddTap: _noop,
      onSomedayTap: _noop,
      onSettingsTap: _noop,
      isSomedayActive: isSomedayActive,
      somedayMerged: somedayMerged,
      settingsContextual: settingsContextual,
      mergedLabel: mergedLabel,
    ),
  );
}

void main() {
  const size = Size(400, 160);

  testWidgets('BottomNavigation TODAY selected, light theme', (tester) async {
    await pumpGolden(tester, _bar(), size: size);
    await expectGolden(tester, 'bottom_navigation_today_light');
  });

  testWidgets('BottomNavigation TODAY selected, dark theme', (tester) async {
    await pumpGolden(tester, _bar(), brightness: Brightness.dark, size: size);
    await expectGolden(tester, 'bottom_navigation_today_dark');
  });

  testWidgets('BottomNavigation SOMEDAY selected, light theme', (tester) async {
    await pumpGolden(tester, _bar(isSomedayActive: true), size: size);
    await expectGolden(tester, 'bottom_navigation_someday_light');
  });

  testWidgets(
    'BottomNavigation merged SOMEDAY, label + contextual settings, light',
    (tester) async {
      await pumpGolden(
        tester,
        _bar(
          isSomedayActive: true,
          somedayMerged: true,
          settingsContextual: true,
          mergedLabel: 'Groceries',
        ),
        size: size,
      );
      await expectGolden(tester, 'bottom_navigation_merged_light');
    },
  );
}
