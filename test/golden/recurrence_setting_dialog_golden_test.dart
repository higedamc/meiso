@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/models/recurrence_pattern.dart';
import 'package:meiso/widgets/recurrence_setting_dialog.dart';

import 'golden_harness.dart';

// Every pattern below sets `dayOfMonth` explicitly. The dialog falls back to
// `DateTime.now().day` when it is missing (even when an initialPattern is
// given), which would make the PNG drift daily.
const _daily = RecurrencePattern(
  type: RecurrenceType.daily,
  dayOfMonth: 15,
);
const _weekly = RecurrencePattern(
  type: RecurrenceType.weekly,
  interval: 2,
  weekdays: [1, 3, 5],
  dayOfMonth: 15,
);
const _monthly = RecurrencePattern(
  type: RecurrenceType.monthly,
  dayOfMonth: 15,
);

void main() {
  const size = Size(600, 900);

  testWidgets('RecurrenceSettingDialog daily, light theme', (tester) async {
    await pumpGolden(
      tester,
      const RecurrenceSettingDialog(initialPattern: _daily),
      size: size,
    );
    await expectGolden(tester, 'recurrence_setting_dialog_daily_light');
  });

  testWidgets(
    'RecurrenceSettingDialog every 2 weeks on Mon/Wed/Fri, light theme',
    (tester) async {
      await pumpGolden(
        tester,
        const RecurrenceSettingDialog(initialPattern: _weekly),
        size: size,
      );
      await expectGolden(tester, 'recurrence_setting_dialog_weekly_light');
    },
  );

  testWidgets('RecurrenceSettingDialog monthly on the 15th, dark theme', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const RecurrenceSettingDialog(initialPattern: _monthly),
      brightness: Brightness.dark,
      size: size,
    );
    await expectGolden(tester, 'recurrence_setting_dialog_monthly_dark');
  });
}
