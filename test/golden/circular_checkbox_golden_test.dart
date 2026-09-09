@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/widgets/circular_checkbox.dart';

import 'golden_harness.dart';

Widget _states() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularCheckbox(value: false, onChanged: (_) {}),
      const SizedBox(width: 24),
      CircularCheckbox(value: true, onChanged: (_) {}),
      const SizedBox(width: 24),
      CircularCheckbox(value: true, size: 40, onChanged: (_) {}),
    ],
  );
}

void main() {
  testWidgets('CircularCheckbox unchecked/checked/large, light theme', (
    tester,
  ) async {
    await pumpGolden(tester, _states(), size: const Size(240, 120));
    await expectGolden(tester, 'circular_checkbox_light');
  });

  testWidgets('CircularCheckbox unchecked/checked/large, dark theme', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      _states(),
      brightness: Brightness.dark,
      size: const Size(240, 120),
    );
    await expectGolden(tester, 'circular_checkbox_dark');
  });
}
