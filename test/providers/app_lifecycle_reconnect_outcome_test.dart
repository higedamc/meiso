import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/providers/app_lifecycle_provider.dart';
import 'package:meiso/providers/custom_lists_provider.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/todos_provider.dart';
import 'package:mocktail/mocktail.dart';

/// PR C, item 1 + item 3 (PLANS/MEISO_PR_C_HONEST_STATUS_LEAF.md).
///
/// `manualReconnectAndSync` used to return `Future<void>`, discarding the
/// connected count A threads back from Rust, and only `_onAppResumed`
/// checked `_isReconnecting` before calling `_reconnectAndSync` — the
/// manual (Settings tap) path did not, so a resume and a tap could race.
///
/// These tests drive `AppLifecycleNotifier` through its public API only
/// (`manualReconnectAndSync`), against mocked `NostrService` /
/// `TodosNotifier` / `CustomListsNotifier`, and name their negative control:
/// what the assertion sees with the pre-fix code.
class MockNostrService extends Mock implements NostrService {}

class MockTodosNotifier extends Mock implements TodosNotifier {}

class MockCustomListsNotifier extends Mock implements CustomListsNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNostrService nostrService;
  late MockTodosNotifier todosNotifier;
  late MockCustomListsNotifier customListsNotifier;
  late ProviderContainer container;

  setUp(() {
    nostrService = MockNostrService();
    todosNotifier = MockTodosNotifier();
    customListsNotifier = MockCustomListsNotifier();

    when(() => todosNotifier.syncFromNostr(trigger: TodoSyncTrigger.appResume))
        .thenAnswer((_) async {});
    when(() => customListsNotifier.syncGroupInvitations())
        .thenAnswer((_) async {});
    when(() => nostrService.processGlobalBackfillQueue())
        .thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWithValue(nostrService),
        todosProvider.overrideWith((ref) => todosNotifier),
        customListsProvider.overrideWith((ref) => customListsNotifier),
      ],
    );
  });

  tearDown(() => container.dispose());

  AppLifecycleNotifier notifier() =>
      container.read(appLifecycleProvider.notifier);

  test(
    'threads the real connected count through instead of discarding it',
    () async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => false);
      when(() => nostrService.reconnectRelaysWithTimeout())
          .thenAnswer((_) async => 2);

      final outcome = await notifier().manualReconnectAndSync();

      expect(outcome.attempted, isTrue);
      // Negative control: the pre-fix body is `await
      // nostrService.reconnectRelaysWithTimeout();` with no local binding —
      // there is nothing to put here but 0, which this assertion would then
      // wrongly accept as "reconnected" for both 0 and 2 actually connected.
      expect(outcome.connectedCount, 2);
    },
  );

  test(
    'a reconnect that reaches nothing is distinguishable from one that '
    'never ran',
    () async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => false);
      when(() => nostrService.reconnectRelaysWithTimeout())
          .thenAnswer((_) async => 0);

      final outcome = await notifier().manualReconnectAndSync();

      // attempted:true + connectedCount:0 ("tried, reached nothing") must
      // not collapse into the same value as attempted:false ("didn't try").
      expect(outcome.attempted, isTrue);
      expect(outcome.connectedCount, 0);
    },
  );

  test('already connected: no reconnect is attempted', () async {
    when(() => nostrService.checkConnectionStatus())
        .thenAnswer((_) async => true);

    final outcome = await notifier().manualReconnectAndSync();

    expect(outcome.attempted, isFalse);
    verifyNever(() => nostrService.reconnectRelaysWithTimeout());
  });

  test(
    'a reconnect already in flight is not started a second time',
    () async {
      when(() => nostrService.checkConnectionStatus())
          .thenAnswer((_) async => false);
      final gate = Completer<int>();
      when(() => nostrService.reconnectRelaysWithTimeout())
          .thenAnswer((_) => gate.future);

      final n = notifier();
      // First call (simulates _onAppResumed or an earlier tap) starts and
      // blocks inside reconnectRelaysWithTimeout.
      final first = n.manualReconnectAndSync();
      await Future<void>.delayed(Duration.zero);

      // Second call (simulates a Settings tap while the first is in
      // flight). Negative control: on the pre-fix code, `_isReconnecting`
      // was only checked by `_onAppResumed` before calling
      // `_reconnectAndSync`; `manualReconnectAndSync` called
      // `_reconnectAndSync` directly with no check, so this second call
      // would also reach `reconnectRelaysWithTimeout` and this assertion
      // would see `attempted: true` instead of `false`.
      final second = await n.manualReconnectAndSync();
      expect(
        second.attempted,
        isFalse,
        reason: 'a reconnect already in flight must not start a second one',
      );
      verify(() => nostrService.reconnectRelaysWithTimeout()).called(1);

      gate.complete(1);
      final firstOutcome = await first;
      expect(firstOutcome.attempted, isTrue);
      expect(firstOutcome.connectedCount, 1);
    },
  );
}
