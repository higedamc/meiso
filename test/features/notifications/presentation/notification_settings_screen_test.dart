import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_settings.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_provider.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_screen.dart';
import 'package:meiso/features/notifications/presentation/notification_settings_store.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the platform battery-optimization calls.
class FakeBatteryGate implements BatteryOptimizationGate {
  FakeBatteryGate({required this.exempt, this.failIsIgnoring = false});

  bool exempt;
  bool failIsIgnoring;
  int requestCalls = 0;

  @override
  Future<bool> isIgnoring() async {
    if (failIsIgnoring) {
      throw Exception('platform channel unavailable');
    }
    return exempt;
  }

  @override
  Future<bool> request() async {
    requestCalls += 1;
    exempt = true;
    return true;
  }
}

/// Store whose every write is refused, standing in for a platform store that
/// reports failure.
class ThrowingStore extends NotificationSettingsStore {
  const ThrowingStore(super.prefs);

  @override
  Future<void> write(NotificationSettings settings) =>
      Future<void>.error(const NotificationSettingsWriteException());
}

Widget harness(FakeBatteryGate gate, {bool writesFail = false}) {
  return ProviderScope(
    overrides: [
      batteryOptimizationGateProvider.overrideWithValue(gate),
      if (writesFail)
        notificationSettingsStoreProvider.overrideWith(
          (ref) async => ThrowingStore(await SharedPreferences.getInstance()),
        ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationSettingsScreen(),
    ),
  );
}

const masterKey = Key('notifications_master_switch');
const sharedKey = Key('notifications_shared_comments_switch');
const allowKey = Key('battery_optimization_allow');

SwitchListTile switchAt(WidgetTester tester, Key key) =>
    tester.widget<SwitchListTile>(find.byKey(key));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows contract defaults: master off, shared comments on',
      (tester) async {
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();

    expect(switchAt(tester, masterKey).value, isFalse);
    expect(switchAt(tester, sharedKey).value, isTrue);
    expect(
      switchAt(tester, sharedKey).onChanged,
      isNull,
      reason: 'shared-comments toggle is inert while the master switch is off',
    );
  });

  testWidgets('toggling the master switch persists under the contract key',
      (tester) async {
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(masterKey));
    await tester.pumpAndSettle();

    expect(switchAt(tester, masterKey).value, isTrue);
    expect(switchAt(tester, sharedKey).onChanged, isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationPrefsKeys.enabled), isTrue);
    expect(
      prefs.getBool(NotificationPrefsKeys.sharedTaskComments),
      isTrue,
      reason: 'the untouched setting is written with its default value',
    );
  });

  testWidgets('toggling shared comments off persists and survives a rebuild',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      NotificationPrefsKeys.enabled: true,
    });
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(sharedKey));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationPrefsKeys.sharedTaskComments), isFalse);

    // A fresh ProviderScope re-reads from storage, like an app restart does.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();
    expect(switchAt(tester, masterKey).value, isTrue);
    expect(switchAt(tester, sharedKey).value, isFalse);
  });

  testWidgets('states the restart caveat and the personal-task exclusion',
      (tester) async {
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );

    expect(find.text(l10n.notificationsRestartCaveatBody), findsOneWidget);
    expect(find.text(l10n.notificationsPersonalTasksBody), findsOneWidget);
  });

  testWidgets('battery row: offers Allow when not exempt and refreshes after',
      (tester) async {
    final gate = FakeBatteryGate(exempt: false);
    await tester.pumpWidget(harness(gate));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );

    expect(find.text(l10n.batteryOptimizationRestricted), findsOneWidget);
    expect(find.byKey(allowKey), findsOneWidget);

    await tester.tap(find.byKey(allowKey));
    await tester.pumpAndSettle();

    expect(gate.requestCalls, 1);
    expect(find.text(l10n.batteryOptimizationExempt), findsOneWidget);
    expect(find.byKey(allowKey), findsNothing);
  });

  testWidgets('battery row: no Allow button when already exempt',
      (tester) async {
    await tester.pumpWidget(harness(FakeBatteryGate(exempt: true)));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );

    expect(find.text(l10n.batteryOptimizationExempt), findsOneWidget);
    expect(find.byKey(allowKey), findsNothing);
  });

  testWidgets('battery row: platform failure degrades to "unavailable"',
      (tester) async {
    await tester.pumpWidget(
      harness(FakeBatteryGate(exempt: false, failIsIgnoring: true)),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );

    expect(find.text(l10n.batteryOptimizationUnavailable), findsOneWidget);
    expect(find.byKey(allowKey), findsNothing);
    expect(
      switchAt(tester, masterKey),
      isNotNull,
      reason: 'the switches stay usable when only the battery call fails',
    );
  });

  testWidgets('a failed write keeps the last good values on screen',
      (tester) async {
    await tester.pumpWidget(
      harness(FakeBatteryGate(exempt: true), writesFail: true),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NotificationSettingsScreen)),
    );
    expect(find.text(l10n.notificationsMasterTitle), findsOneWidget);
    expect(find.text(l10n.notificationSettingsSaveError), findsNothing);

    await tester.tap(find.byKey(masterKey));
    await tester.pumpAndSettle();

    // The toggles stay, showing the value that actually persisted, with the
    // save error alongside; the screen must not fall through to the
    // full-screen load error just because the write failed.
    expect(find.byKey(masterKey), findsOneWidget);
    expect(switchAt(tester, masterKey).value, isFalse);
    expect(find.text(l10n.notificationSettingsSaveError), findsOneWidget);
    expect(find.text(l10n.notificationSettingsLoadError), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationPrefsKeys.enabled), isNull);

    // A second attempt after a failure neither throws nor loses the screen.
    await tester.tap(find.byKey(masterKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(masterKey), findsOneWidget);
    expect(switchAt(tester, masterKey).value, isFalse);
    expect(find.text(l10n.notificationSettingsSaveError), findsOneWidget);
  });
}
