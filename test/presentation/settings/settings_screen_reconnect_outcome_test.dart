import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/l10n/app_localizations.dart';
import 'package:meiso/presentation/settings/settings_screen.dart';
import 'package:meiso/providers/custom_lists_provider.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/relay_status_provider.dart';
import 'package:meiso/providers/todos_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PR C, item 2 (PLANS/MEISO_PR_C_HONEST_STATUS_LEAF.md).
///
/// Before this leaf, a reconnect tap that ran and reached zero relays was
/// pixel-identical to a tap that never ran a reconnect at all: spinner,
/// then the same red badge, no explanation. These tests tap the red badge
/// end to end (real `SettingsScreen` + real `AppLifecycleNotifier`) and
/// check the honest-outcome SnackBar that `_retryConnection` now shows.
class MockNostrService extends Mock implements NostrService {}

class MockTodosNotifier extends Mock implements TodosNotifier {}

class MockCustomListsNotifier extends Mock implements CustomListsNotifier {}

Widget _harness({
  required MockNostrService nostrService,
  required MockTodosNotifier todosNotifier,
  required MockCustomListsNotifier customListsNotifier,
}) {
  return ProviderScope(
    overrides: [
      nostrServiceProvider.overrideWithValue(nostrService),
      todosProvider.overrideWith((ref) => todosNotifier),
      customListsProvider.overrideWith((ref) => customListsNotifier),
      nostrInitializedProvider.overrideWith((ref) => true),
      relayStatusProvider.overrideWith(
        (ref) => RelayStatusNotifier()
          ..initializeWithRelays(
            ['wss://relay-a.example', 'wss://relay-b.example'],
            initialState: RelayConnectionState.disconnected,
          ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );
}

void main() {
  late MockNostrService nostrService;
  late MockTodosNotifier todosNotifier;
  late MockCustomListsNotifier customListsNotifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'meiso',
      packageName: 'com.example.meiso',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );

    nostrService = MockNostrService();
    todosNotifier = MockTodosNotifier();
    customListsNotifier = MockCustomListsNotifier();

    when(() => nostrService.refreshRelayStatus()).thenAnswer((_) async {});
    when(() => nostrService.processGlobalBackfillQueue())
        .thenAnswer((_) async {});
    when(() => todosNotifier.syncFromNostr(trigger: TodoSyncTrigger.appResume))
        .thenAnswer((_) async {});
    when(() => customListsNotifier.syncGroupInvitations())
        .thenAnswer((_) async {});
  });

  Future<void> tapRetryBadge(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.byTooltip(l10n.statusTapToReconnect));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a reconnect that reaches nothing tells the user it tried, not just '
    'that it is still disconnected',
    (tester) async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => false);
      when(() => nostrService.reconnectRelaysWithTimeout())
          .thenAnswer((_) async => 0);

      await tester.pumpWidget(_harness(
        nostrService: nostrService,
        todosNotifier: todosNotifier,
        customListsNotifier: customListsNotifier,
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );

      await tapRetryBadge(tester, l10n);

      // Negative control: with the pre-fix `_retryConnection` (no outcome
      // read at all), neither message ever appears — this find stays
      // empty for every outcome, including this one.
      expect(find.text(l10n.reconnectAttemptFailed), findsOneWidget);
      expect(
        find.text(l10n.reconnectAttemptSucceeded(2, 2)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a reconnect that reaches relays reports the count it actually reached',
    (tester) async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => false);
      when(() => nostrService.reconnectRelaysWithTimeout())
          .thenAnswer((_) async => 2);

      await tester.pumpWidget(_harness(
        nostrService: nostrService,
        todosNotifier: todosNotifier,
        customListsNotifier: customListsNotifier,
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );

      await tapRetryBadge(tester, l10n);

      expect(find.text(l10n.reconnectAttemptSucceeded(2, 2)), findsOneWidget);
      expect(find.text(l10n.reconnectAttemptFailed), findsNothing);
    },
  );

  testWidgets(
    'a tap that did not need to run anything shows neither outcome message',
    (tester) async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => true);

      await tester.pumpWidget(_harness(
        nostrService: nostrService,
        todosNotifier: todosNotifier,
        customListsNotifier: customListsNotifier,
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );

      await tapRetryBadge(tester, l10n);

      expect(find.text(l10n.reconnectAttemptFailed), findsNothing);
      expect(find.text(l10n.reconnectAttemptSucceeded(2, 2)), findsNothing);
      verifyNever(() => nostrService.reconnectRelaysWithTimeout());
    },
  );
}
