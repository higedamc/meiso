import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_provider.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_screen.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/presentation/settings/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the pushed Notifications screen off the platform channel.
class _FakeBatteryGate implements BatteryOptimizationGate {
  @override
  Future<bool> isIgnoring() async => true;

  @override
  Future<bool> request() async => true;
}

Widget harness() {
  return ProviderScope(
    overrides: [
      batteryOptimizationGateProvider.overrideWithValue(_FakeBatteryGate()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'meiso',
      packageName: 'com.example.meiso',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
  });

  testWidgets(
      'Notifications entry is reachable in debug builds and co-gated with '
      'Debug Logs (#201)', (tester) async {
    // The gate is `kDebugMode`, which is true under `flutter test`. This guard
    // makes the premise explicit: a run where it is false would make the
    // assertions below vacuous rather than wrong.
    expect(kDebugMode, isTrue,
        reason: 'this test only proves the debug half of the #201 gate');

    // Tall viewport so the whole General card is laid out by the ListView.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    final notificationsTile =
        find.widgetWithText(ListTile, l10n.notificationSettingsTitle);
    final debugLogsTile = find.widgetWithText(ListTile, l10n.debugLogs);

    expect(notificationsTile, findsOneWidget);
    expect(debugLogsTile, findsOneWidget,
        reason: 'the Notifications entry shares its gate with Debug Logs');

    // Still routes to the screen, so the gate only changed reachability.
    await tester.tap(notificationsTile);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });
}
