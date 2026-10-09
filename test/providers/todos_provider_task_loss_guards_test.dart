import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/bridge_generated.dart/api.dart' as rust_api;
import 'package:meiso/models/todo.dart';
import 'package:meiso/providers/custom_lists_provider.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/sync_status_provider.dart';
import 'package:meiso/providers/todos_provider.dart';
import 'package:meiso/services/local_storage_service.dart';

/// Task-loss guards (PLANS/MEISO_TASK_LOSS_FIX_PLAN.md, decision 1).
///
/// Kind 30001 is replaceable and carries the whole list, so a publish from an
/// incomplete local state replaces every task on the relays. These tests
/// drive the real `TodosNotifier` against a fake `NostrService` and check
/// each guard from the outside: what gets sent, what stays `needsSync`, and
/// what the sync status reports.
///
/// Every test names its negative control: what the assertion sees when the
/// guard under test is removed from `todos_provider.dart`.
class _FakeNostrService implements NostrService {
  bool sendSucceeds = true;

  /// When set, `syncTodoListsFromNostr` throws it instead of returning.
  Object? fetchError;

  /// When set, `syncTodoListsFromNostr` waits for it before returning.
  Completer<void>? fetchGate;

  /// Tasks the relays hold. They are grouped by list for the fetch, each
  /// list stamped with [remoteListCreatedAt]. An empty list here means the
  /// relays returned no list event at all.
  List<Todo> remoteTodos = const [];

  /// `created_at` (unix seconds) given to every list built from
  /// [remoteTodos]. Defaults to "now", i.e. newer than any seeded edit.
  int? remoteListCreatedAt;

  /// Lists returned as-is, in addition to those built from [remoteTodos].
  /// Lets a test return an emptied list or a list for another key.
  List<SyncedTodoList> remoteLists = const [];

  int createTodoListCalls = 0;
  int fetchCalls = 0;
  final List<List<Todo>> sentBatches = [];

  /// Lists published empty (normalised key, null = default list).
  final List<String?> emptyListPublishes = [];

  @override
  Future<rust_api.EventSendResult> createTodoListOnNostr(
    List<Todo> todos,
  ) async {
    createTodoListCalls += 1;
    sentBatches.add(List<Todo>.from(todos));
    return rust_api.EventSendResult(
      eventId: 'event-$createTodoListCalls',
      success: sendSucceeds,
      successfulRelays: BigInt.from(sendSucceeds ? 1 : 0),
      failedRelays: BigInt.from(sendSucceeds ? 0 : 2),
      timedOut: false,
      errorMessage: sendSucceeds ? null : 'Send failed: all relays failed',
    );
  }

  @override
  Future<rust_api.EventSendResult> publishEmptyTodoList({
    String? listKey,
  }) async {
    emptyListPublishes.add(listKey);
    return rust_api.EventSendResult(
      eventId: 'empty-${emptyListPublishes.length}',
      success: sendSucceeds,
      successfulRelays: BigInt.from(sendSucceeds ? 1 : 0),
      failedRelays: BigInt.from(sendSucceeds ? 0 : 2),
      timedOut: false,
      errorMessage: sendSucceeds ? null : 'Send failed: all relays failed',
    );
  }

  @override
  Future<List<SyncedTodoList>> syncTodoListsFromNostr() async {
    fetchCalls += 1;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    final error = fetchError;
    if (error != null) throw error;

    final createdAt =
        remoteListCreatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final byList = <String?, List<Todo>>{};
    for (final todo in remoteTodos) {
      byList.putIfAbsent(todo.customListId, () => []).add(todo);
    }
    return [
      for (final entry in byList.entries)
        (
          listId: entry.key == null ? 'meiso-todos' : 'meiso-list-${entry.key}',
          eventId: 'list-event-${entry.key ?? 'default'}',
          createdAt: createdAt,
          todos: List<Todo>.from(entry.value),
        ),
      ...remoteLists,
    ];
  }

  // The custom-list and app-settings phases of a full sync ask for the
  // pubkey first and bail out quietly when there is none.
  @override
  Future<String?> getPublicKey() async => null;

  @override
  Future<void> processGlobalBackfillQueue() async {}

  @override
  void setGlobalBackfillResultHandler(dynamic handler) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Todo _todo(
  String id, {
  bool needsSync = false,
  String? customListId,
  String? parentRecurringId,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 1, 1, 12);
  return Todo(
    id: id,
    title: id,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    needsSync: needsSync,
    customListId: customListId,
    parentRecurringId: parentRecurringId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  Future<void> mockPathProvider(String path) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getTemporaryDirectory':
              return path;
          }
          return null;
        });
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meiso_task_loss_');
    await mockPathProvider(tempDir.path);
  });

  tearDown(() async {
    try {
      await localStorageService.close();
    } catch (_) {}
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 15),
    required String reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('timed out: $reason');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Background work started by the container keeps reading providers
  /// after a sync resolved: the group sync scheduled by `syncFromNostr` and
  /// `AppSettingsNotifier._backgroundSync`, which fires 1 s after the
  /// container was created. A test that ends before they finish lets their
  /// error escape into whichever test runs next. Call this before returning
  /// from any test that does not already wait longer than that.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 1200));

  /// Initialises local storage and seeds it with already-synced todos.
  Future<void> seedLocal(List<Todo> todos) async {
    await localStorageService.initialize();
    await localStorageService.saveTodos(todos);
  }

  ({ProviderContainer container, TodosNotifier notifier}) createNotifier(
    _FakeNostrService service,
  ) {
    final container = ProviderContainer(
      overrides: [nostrServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    // Custom lists initialise from local storage; read them first so the
    // notifier is not created for the first time inside a sync.
    container.read(customListsProvider);
    final notifier = container.read(todosProvider.notifier);
    return (container: container, notifier: notifier);
  }

  /// Starts the notifier with seeded local data and marks Nostr initialised.
  Future<({ProviderContainer container, TodosNotifier notifier})> startNotifier(
    _FakeNostrService service,
  ) async {
    final started = createNotifier(service);
    await pumpUntil(
      () =>
          started.container.read(todosProvider).valueOrNull?.isNotEmpty == true,
      reason: 'todosProvider did not load local todos',
    );
    started.container.read(nostrInitializedProvider.notifier).state = true;
    await Future<void>.delayed(Duration.zero);
    return started;
  }

  /// Finds a todo by title (`addTodo` generates the id).
  Todo? findTodo(ProviderContainer container, String title) {
    final todos = container.read(todosProvider).valueOrNull;
    if (todos == null) return null;
    for (final list in todos.values) {
      for (final todo in list) {
        if (todo.title == title) return todo;
      }
    }
    return null;
  }

  SyncState syncState(ProviderContainer container) =>
      container.read(syncStatusProvider).state;

  /// Runs [action], which kicks off `_syncToNostrBackground`, and waits for
  /// that background sync to give up. The background sync retries once after
  /// 3 s and only then reports `Background sync error`; inner fetches may
  /// flip the status to error/success earlier, so the final message is the
  /// only reliable "settled" signal. The status is reset first so a message
  /// left over from an earlier action cannot satisfy the wait.
  Future<void> expectBackgroundSyncFailure(
    ProviderContainer container,
    Future<void> Function() action,
  ) async {
    final statusNotifier = container.read(syncStatusProvider.notifier);
    statusNotifier.state = container
        .read(syncStatusProvider)
        .copyWith(state: SyncState.idle, errorMessage: null);
    await action();
    await pumpUntil(
      () =>
          container
              .read(syncStatusProvider)
              .errorMessage
              ?.contains('Background sync error') ==
          true,
      timeout: const Duration(seconds: 20),
      reason: 'background sync did not report its failure',
    );
  }

  group('read failure vs empty', () {
    test(
      'a local load failure becomes an error state, not an empty list',
      () async {
        // Local storage is deliberately NOT initialised, so every read throws.
        // Negative control: with the old `state = const AsyncValue.data({})`
        // fallback this test sees AsyncData with an empty map, and addTodo
        // then publishes a one-task list over the relay copy.
        final service = _FakeNostrService();
        final started = createNotifier(service);

        await pumpUntil(
          () => started.container.read(todosProvider).hasError,
          reason: 'todosProvider did not report the load failure',
        );
        expect(started.container.read(todosProvider).hasValue, isFalse);

        started.container.read(nostrInitializedProvider.notifier).state = true;
        // Edits run through `state.whenData(...).value`, which rethrows the
        // load failure instead of operating on an empty map.
        await expectLater(
          started.notifier.addTodo('created on a broken device', null),
          throwsException,
          reason: 'editing must stay blocked while the local read has failed',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(started.container.read(todosProvider).hasError, isTrue);
        expect(
          service.createTodoListCalls,
          0,
          reason: 'nothing may be published from an unreadable state',
        );
      },
    );
  });

  group('publish gate', () {
    test('no publish until a relay fetch has succeeded this session', () async {
      await seedLocal([_todo('a'), _todo('b')]);
      final service = _FakeNostrService()
        ..fetchError = Exception('relay unreachable');
      final started = await startNotifier(service);

      await expectBackgroundSyncFailure(
        started.container,
        () => started.notifier.addTodo('c', null),
      );

      // Negative control: without the gate createTodoListCalls is 1 here
      // (the three-task list is sent without ever reading the relays).
      expect(
        service.fetchCalls,
        greaterThanOrEqualTo(1),
        reason: 'the gate must try to fetch before publishing',
      );
      expect(
        service.createTodoListCalls,
        0,
        reason: 'publish must be blocked while no fetch has succeeded',
      );
      expect(syncState(started.container), SyncState.error);
      final pending = findTodo(started.container, 'c')!;
      expect(
        pending.needsSync,
        isTrue,
        reason: 'the blocked task must stay queued for a later publish',
      );

      // The relays come back; a successful fetch opens the gate and the
      // pending task is published without another user action.
      service.fetchError = null;
      await started.notifier.syncFromNostr();
      await pumpUntil(
        () => service.createTodoListCalls == 1,
        reason: 'pending task was not published after the fetch succeeded',
      );
      expect(
        service.sentBatches.single.map((t) => t.title),
        containsAll(['a', 'b', 'c']),
      );
      await pumpUntil(
        () => findTodo(started.container, 'c')?.needsSync == false,
        reason: 'published task did not get needsSync cleared',
      );
    });

    test(
      'a retry scheduled before dispose does not touch providers after '
      'dispose (issue #229)',
      () async {
        await seedLocal([_todo('a')]);
        final service = _FakeNostrService();
        final started = await startNotifier(service);
        // Let the container's own startup background work (AppSettings'
        // one-shot sync 1 s after creation, among others — see settle()'s
        // doc comment) finish before we start orchestrating our own
        // dispose-mid-retry below, so the only thing racing dispose is the
        // retry loop under test.
        await settle();

        // Open the gate first so the publish itself is what fails below,
        // not the gate's own fetch-and-retry.
        await started.notifier.syncFromNostr();
        await settle();

        // Attempt 1 will fail at the relay send, which schedules a 3 s
        // delayed retry inside _syncToNostrBackground's microtask.
        service.sendSucceeds = false;
        await started.notifier.addTodo('b', null);
        await pumpUntil(
          () => service.createTodoListCalls >= 1,
          reason: 'attempt 1 did not try to publish',
        );

        // Dispose while the retry delay is still pending, the same shape as
        // a logout, account switch, or widget teardown racing a background
        // sync. Negative control: without the mounted guard at the top of
        // _syncToNostrBackground's retry loop, attempt 2 resumes on this
        // disposed container ~3 s from now and throws "Bad state: Tried to
        // read a provider from a ProviderContainer that was already
        // disposed" from inside the un-awaited microtask — uncaught, and
        // reported by the test runner as this test having "failed after
        // test completion" rather than as a clean assertion failure here.
        started.container.dispose();

        // Outlive the 3 s retry delay inside this test, so that if the
        // guard is missing, the resulting uncaught error is attributed to
        // this test rather than leaking into whichever test runs next.
        await Future<void>.delayed(const Duration(seconds: 4));
      },
    );

    test(
      'a retry is actually scheduled when dispose does not race it '
      '(issue #229)',
      () async {
        // Companion to the test above: that one proves a scheduled retry
        // does not touch a disposed container, but says nothing about
        // whether a retry happens at all. If _syncToNostrBackground's
        // maxAttempts loop were ever removed, that test would stay green
        // for the wrong reason (nothing left to guard). This test never
        // disposes, so it is the one that would catch that: it needs
        // attempt 2 to actually run.
        await seedLocal([_todo('a')]);
        final service = _FakeNostrService();
        final started = await startNotifier(service);
        await settle();

        await started.notifier.syncFromNostr();
        await settle();

        // The notifier also arms a one-shot batch-sync timer at creation
        // (5 s, independent of this test's own addTodo call below) that
        // would itself call _syncToNostrBackground and confound the count
        // this test is about to take. Todo 'a' was seeded already-synced,
        // so that timer finds nothing to send and no-ops — but only if it
        // has already fired by the time 'b' goes unsynced. Let it pass
        // first.
        await Future<void>.delayed(const Duration(seconds: 4));

        // Both attempts fail at the relay send; only their count matters
        // here, not success.
        service.sendSucceeds = false;
        await started.notifier.addTodo('b', null);
        await pumpUntil(
          () => service.createTodoListCalls >= 1,
          reason: 'attempt 1 did not try to publish',
        );

        // Outlive the 3 s retry delay without disposing, so attempt 2 gets
        // to run.
        await pumpUntil(
          () => service.createTodoListCalls >= 2,
          timeout: const Duration(seconds: 6),
          reason: 'attempt 2 was never scheduled',
        );

        expect(service.createTodoListCalls, 2);
      },
    );

    test('logout closes the gate again', () async {
      await seedLocal([_todo('a'), _todo('b')]);
      final service = _FakeNostrService();
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await started.notifier.addTodo('c', null);
      await pumpUntil(
        () => service.createTodoListCalls == 1,
        reason: 'publish after a successful fetch must go through',
      );

      // Logout, then another session before any fetch. Negative control:
      // without the reset on the nostrInitialized listener the second add
      // publishes immediately (createTodoListCalls becomes 2 with
      // fetchCalls unchanged).
      started.container.read(nostrInitializedProvider.notifier).state = false;
      await Future<void>.delayed(Duration.zero);
      service.fetchError = Exception('relay unreachable');
      final fetchCallsBefore = service.fetchCalls;
      started.container.read(nostrInitializedProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      await expectBackgroundSyncFailure(
        started.container,
        () => started.notifier.addTodo('d', null),
      );

      expect(service.fetchCalls, greaterThan(fetchCallsBefore));
      expect(
        service.createTodoListCalls,
        1,
        reason: 'after logout the gate must be closed again',
      );
    });
  });

  group('shrink guard', () {
    test(
      'refuses to publish a list that shrank below half its known count',
      () async {
        await seedLocal([_todo('a'), _todo('b')]);
        // A previous session confirmed 20 tasks in the default list on the
        // relays; this device only managed to load 2 of them.
        await localStorageService.setKnownListTodoCounts({'default': 20});
        final service = _FakeNostrService();
        final started = await startNotifier(service);

        // Open the gate with a fetch that returns nothing (relay-side empty
        // response); local data is kept, the baseline stays at 20.
        await started.notifier.syncFromNostr();

        await expectBackgroundSyncFailure(
          started.container,
          () => started.notifier.addTodo('c', null),
        );

        // Negative control: without _assertNoSuspiciousShrink the 3-task list
        // is sent here (createTodoListCalls == 1) and replaces 20 tasks.
        expect(
          service.createTodoListCalls,
          0,
          reason: '3 of 20 known tasks must not be published',
        );
        expect(syncState(started.container), SyncState.error);
        expect(findTodo(started.container, 'c')!.needsSync, isTrue);

        // Manual sync is the escape hatch: it forces the publish and the new
        // count becomes the baseline.
        await started.notifier.manualSyncToNostr();
        expect(service.createTodoListCalls, 1);
        expect(localStorageService.getKnownListTodoCounts()['default'], 3);

        // Ordinary edits against the new baseline go through again.
        await started.notifier.addTodo('d', null);
        await pumpUntil(
          () => service.createTodoListCalls == 2,
          reason: 'a 4-task publish against a baseline of 3 must go through',
        );
      },
    );

    test('a deliberate bulk delete passes the guard exactly once', () async {
      // One recurring parent with five instances, plus two ordinary tasks.
      await seedLocal([
        _todo('a'),
        _todo('b'),
        _todo('parent'),
        for (var i = 0; i < 5; i++)
          _todo('instance-$i', parentRecurringId: 'parent'),
      ]);
      await localStorageService.setKnownListTodoCounts({'default': 8});
      final service = _FakeNostrService();
      final started = await startNotifier(service);
      await started.notifier.syncFromNostr();

      // 8 -> 2 is a suspicious shrink, but it is what the user asked for.
      // Negative control: without _allowShrinkOnce this publish is blocked
      // and createTodoListCalls stays 0.
      await started.notifier.deleteAllRecurringInstances('parent', null);
      await pumpUntil(
        () => service.createTodoListCalls == 1,
        reason: 'bulk delete must be allowed to publish the shrunken list',
      );
      expect(
        service.sentBatches.single.map((t) => t.title),
        unorderedEquals(['a', 'b']),
      );
      expect(localStorageService.getKnownListTodoCounts()['default'], 2);

      // The allowance is consumed: a later suspicious shrink is blocked.
      // Negative control: if _allowShrinkOnce were never reset this add
      // would publish (createTodoListCalls == 2).
      await localStorageService.setKnownListTodoCounts({'default': 20});
      await expectBackgroundSyncFailure(
        started.container,
        () => started.notifier.addTodo('c', null),
      );
      expect(service.createTodoListCalls, 1);
      expect(syncState(started.container), SyncState.error);
    });
  });

  group('failed relay send (issue c121754a)', () {
    test(
      'a send that reached no relay keeps needsSync and reports an error',
      () async {
        await seedLocal([_todo('a'), _todo('b')]);
        final service = _FakeNostrService()..sendSucceeds = false;
        final started = await startNotifier(service);
        await started.notifier.syncFromNostr();

        await expectBackgroundSyncFailure(
          started.container,
          () => started.notifier.addTodo('c', null),
        );

        // Negative control: with _markTodosSyncedWithEventId running before
        // the success check, 'c' has needsSync == false and eventId
        // 'event-1' here, and the status is SyncState.success.
        expect(service.createTodoListCalls, greaterThanOrEqualTo(1));
        final todo = findTodo(started.container, 'c')!;
        expect(
          todo.needsSync,
          isTrue,
          reason: 'an undelivered task must stay queued for retry',
        );
        expect(
          todo.eventId,
          isNull,
          reason: 'no eventId may be stamped for an undelivered send',
        );
        expect(
          syncState(started.container),
          SyncState.error,
          reason: 'the UI must not report a successful sync',
        );

        // Once the relays accept the send, the task is marked synced.
        service.sendSucceeds = true;
        await started.notifier.manualSyncToNostr();
        final synced = findTodo(started.container, 'c')!;
        expect(synced.needsSync, isFalse);
        expect(synced.eventId, isNotNull);
      },
    );
  });

  group('full sync re-entry', () {
    test('concurrent full syncs share a single relay fetch', () async {
      await seedLocal([_todo('a'), _todo('b')]);
      final service = _FakeNostrService()..fetchGate = Completer<void>();
      final started = await startNotifier(service);

      // Negative control: without _activeFullSync both calls fetch and
      // fetchCalls is 2.
      final first = started.notifier.syncFromNostr();
      final second = started.notifier.syncFromNostr();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      service.fetchGate!.complete();
      await Future.wait([first, second]);

      expect(service.fetchCalls, 1);
      await settle();
    });
  });

  group('emptied list publish', () {
    test('deleting the last task publishes the list empty exactly once',
        () async {
      // The relays confirmed the default list with one task (fetch), then
      // that task is deleted locally. The publish path has no todo left to
      // group, so without this guard nothing is sent and the relay keeps
      // the task forever (seen on device). Negative control: without the
      // emptied-list step emptyListPublishes stays empty.
      await seedLocal([_todo('task-alpha')]);
      final service = _FakeNostrService()..remoteTodos = [_todo('task-alpha')];
      final started = await startNotifier(service);
      await started.notifier.syncFromNostr();

      final alpha = findTodo(started.container, 'task-alpha')!;
      await started.notifier.deleteTodo(alpha.id, alpha.date);
      await pumpUntil(
        () => service.emptyListPublishes.length == 1,
        reason: 'the emptied default list was not published',
      );
      expect(service.emptyListPublishes.single, isNull);

      // A later sync must not send it again: the baseline now says 0.
      await started.notifier.manualSyncToNostr();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(service.emptyListPublishes.length, 1);
      await settle();
    });

    test('a list fetched empty is not published empty again', () async {
      // The relays already hold the default list empty (another device
      // emptied it). This device has no default-list task either, but its
      // persisted baseline still says 1. After the fetch the baseline must
      // read 0, or the next publish run sends an empty default list of its
      // own, which would wipe the list if another device refilled it in
      // between. Negative control: without the zero baseline the manual
      // sync below publishes [null].
      await localStorageService.initialize();
      await localStorageService.setKnownListTodoCounts({'default': 1});
      await localStorageService.saveTodos([
        _todo('task-work', customListId: 'work'),
      ]);
      final service = _FakeNostrService()
        ..remoteTodos = [_todo('task-work', customListId: 'work')]
        ..remoteLists = [
          (
            listId: 'meiso-todos',
            eventId: 'default-empty',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            todos: const [],
          ),
        ];
      final started = await startNotifier(service);
      await started.notifier.syncFromNostr();
      expect(localStorageService.getKnownListTodoCounts()['default'], 0);

      await started.notifier.manualSyncToNostr();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        service.emptyListPublishes,
        isEmpty,
        reason: 'a list the relays returned empty is not re-published empty',
      );
      await settle();
    });

    test('no empty publish before a relay fetch succeeded this session',
        () async {
      // The persisted baseline says the default list has one task on the
      // relays, the local store has no default-list task, and no fetch has
      // succeeded yet: the local state may simply be incomplete. A manual
      // sync bypasses the publish gate for the lists it has todos for, but
      // must not publish the default list empty. Negative control: with
      // the `_remoteFetchSucceeded` check removed from the emptied-list
      // step this manual sync sends the empty list and wipes the relay.
      await localStorageService.initialize();
      await localStorageService.setKnownListTodoCounts({'default': 1});
      await localStorageService.saveTodos([
        _todo('task-work', customListId: 'work'),
      ]);
      final service = _FakeNostrService()
        ..fetchError = Exception('relay unreachable');
      final started = await startNotifier(service);

      await started.notifier.manualSyncToNostr();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        service.emptyListPublishes,
        isEmpty,
        reason: 'no fetch succeeded, so the emptied list must not be sent',
      );
      expect(
        service.createTodoListCalls,
        1,
        reason: 'the manual sync itself still publishes the list it has',
      );
      await settle();
    });
  });

  group('causal deletion inference (decision 2)', () {
    // Local edits happened at this instant; every seeded task is well over
    // 24 hours old by the time the test runs, which is the input the old
    // wall-clock rule deleted on.
    final editedAt = DateTime.utc(2026, 1, 1, 12);
    final editedAtSec = editedAt.millisecondsSinceEpoch ~/ 1000;

    test('a list that was not fetched keeps its tasks, however old', () async {
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-bravo', updatedAt: editedAt),
      ]);
      // The relays return only another list, newer than the local edits.
      // The default list never arrives, so there is nothing to compare.
      // Negative control: the 24-hour rule deleted a and b here (absent
      // from the fetch and older than a day).
      final service = _FakeNostrService()
        ..remoteLists = [
          (
            listId: 'meiso-list-other',
            eventId: 'other-event',
            createdAt: editedAtSec + 86400,
            todos: [_todo('task-xray', customListId: 'other')],
          ),
        ];
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      final a = findTodo(started.container, 'task-alpha');
      final b = findTodo(started.container, 'task-bravo');
      expect(a, isNotNull, reason: 'a must survive: its list was not fetched');
      expect(b, isNotNull, reason: 'b must survive: its list was not fetched');
      expect(
        a!.needsSync,
        isFalse,
        reason: 'no evidence the relays disagree, so no resync either',
      );
      expect(findTodo(started.container, 'task-xray'), isNotNull);
    });

    test('a list older than the local edit keeps the task and resyncs',
        () async {
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-bravo', updatedAt: editedAt),
      ]);
      // The relays hold a version of the default list from before the
      // edit, and it does not contain b. That is not evidence of deletion:
      // b must be kept and published again.
      // Negative control: with the comparison removed (or inverted) b is
      // dropped here exactly as under the 24-hour rule.
      final service = _FakeNostrService()
        ..remoteTodos = [_todo('task-alpha', updatedAt: editedAt)]
        ..remoteListCreatedAt = editedAtSec - 3600;
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      expect(findTodo(started.container, 'task-bravo'), isNotNull);
      // The fetch succeeded, so the gate is open and the resync goes out.
      await pumpUntil(
        () => service.createTodoListCalls >= 1,
        reason: 'the kept task was not re-published',
      );
      expect(
        service.sentBatches.last.map((t) => t.title),
        containsAll(['task-alpha', 'task-bravo']),
      );
    });

    test('a list newer than the local edit drops the absent task', () async {
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-bravo', updatedAt: editedAt),
      ]);
      // The default list was rewritten after the edit and omits b: it was
      // deleted on another device. Negative control: without deletion
      // inference b resurrects on every device.
      final service = _FakeNostrService()
        ..remoteTodos = [_todo('task-alpha', updatedAt: editedAt)]
        ..remoteListCreatedAt = editedAtSec + 3600;
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      expect(findTodo(started.container, 'task-alpha'), isNotNull);
      expect(findTodo(started.container, 'task-bravo'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        service.createTodoListCalls,
        0,
        reason: 'a deletion applied locally must not trigger a publish',
      );
    });

    test('an emptied list drops its tasks', () async {
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-bravo', updatedAt: editedAt),
      ]);
      // Deleting the last task on another device publishes an empty list.
      // Negative control: a fetch flattened to tasks (or a guard on the
      // task count) cannot see this list at all and keeps both forever.
      final service = _FakeNostrService()
        ..remoteLists = [
          (
            listId: 'meiso-todos',
            eventId: 'default-event',
            createdAt: editedAtSec + 3600,
            todos: const [],
          ),
        ];
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      expect(findTodo(started.container, 'task-alpha'), isNull);
      expect(findTodo(started.container, 'task-bravo'), isNull);
    });

    test('a list older than the last publish is sent again, same content',
        () async {
      // B publishes [a, b, c]; a relay later answers with an older copy
      // [a, b]. The merge keeps c and marks it for resync, but the publish
      // signature cache still holds the signature of [a, b, c], which is
      // exactly what is about to be sent. Negative control: without the
      // invalidation the second publish is skipped as "unchanged since last
      // publish" (createTodoListCalls stays 1) and the relay never catches
      // up, which is what the device run showed.
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-bravo', updatedAt: editedAt),
      ]);
      final service = _FakeNostrService()
        ..remoteTodos = [
          _todo('task-alpha', updatedAt: editedAt),
          _todo('task-bravo', updatedAt: editedAt),
        ]
        ..remoteListCreatedAt = editedAtSec + 10;
      final started = await startNotifier(service);
      await started.notifier.syncFromNostr();
      await started.notifier.addTodo('task-charlie', null);
      await pumpUntil(
        () => service.createTodoListCalls == 1,
        reason: 'first publish did not go out',
      );
      final firstBatch = service.sentBatches.single.map((t) => t.title).toSet();
      expect(firstBatch, {'task-alpha', 'task-bravo', 'task-charlie'});

      // The relay now serves a copy that predates task-charlie.
      service.remoteListCreatedAt = editedAtSec - 3600;
      await started.notifier.syncFromNostr();

      await pumpUntil(
        () => service.createTodoListCalls == 2,
        reason: 'the resync after an older fetch was not sent',
      );
      final secondBatch = service.sentBatches[1].map((t) => t.title).toSet();
      expect(
        secondBatch,
        firstBatch,
        reason: 'the resync carries the same content as the first publish',
      );
      await pumpUntil(
        () => findTodo(started.container, 'task-charlie')?.needsSync == false,
        reason: 'needsSync is cleared by the real send',
      );
      await settle();
    });

    test('a custom list with the id "default" is not the built-in list',
        () async {
      // A list named "Default" slugs to the id 'default'; another client can
      // publish any d tag at all. Both are distinct from the built-in list
      // (customListId null). Only the custom list is fetched here, newer and
      // without its task. Negative control: with the map keyed by
      // `customListId ?? 'default'` the built-in list's task compares
      // against the custom list's created_at and is dropped.
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-delta', customListId: 'default', updatedAt: editedAt),
      ]);
      final service = _FakeNostrService()
        ..remoteLists = [
          (
            listId: 'meiso-list-default',
            eventId: 'custom-default-event',
            createdAt: editedAtSec + 3600,
            todos: const [],
          ),
        ];
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      expect(
        findTodo(started.container, 'task-alpha'),
        isNotNull,
        reason: 'the built-in list was not fetched, so its task is kept',
      );
      expect(
        findTodo(started.container, 'task-delta'),
        isNull,
        reason: 'the custom list "default" is newer and omits its task',
      );
    });

    test('a newer snapshot of another list does not touch this one',
        () async {
      await seedLocal([
        _todo('task-alpha', updatedAt: editedAt),
        _todo('task-charlie', customListId: 'other', updatedAt: editedAt),
      ]);
      // Only the default list is fetched, newer and without c. c belongs
      // to 'other', which was not fetched, so c is kept; a is in the
      // snapshot and stays as well.
      final service = _FakeNostrService()
        ..remoteTodos = [_todo('task-alpha', updatedAt: editedAt)]
        ..remoteListCreatedAt = editedAtSec + 3600;
      final started = await startNotifier(service);

      await started.notifier.syncFromNostr();
      await settle();

      expect(findTodo(started.container, 'task-alpha'), isNotNull);
      expect(findTodo(started.container, 'task-charlie'), isNotNull);
    });
  });
}
