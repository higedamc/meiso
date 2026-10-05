import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/bridge_generated.dart/api.dart' as rust_api;
import 'package:meiso/models/todo.dart';
import 'package:meiso/providers/custom_lists_provider.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/todos_provider.dart';
import 'package:meiso/services/local_storage_service.dart';

/// The per-list "published content signature" cache lets
/// `_syncAllTodosToNostr` skip lists whose content has not changed since the
/// last publish. Rust's `send_event_with_result` reports a failed or timed-out
/// send as `success: false` instead of throwing, so the cache must only be
/// filled after a send that actually succeeded. Otherwise a list that never
/// reached any relay is treated as published and is skipped until its content
/// changes again, which other devices see as tasks that never arrive.
class _FakeNostrService implements NostrService {
  _FakeNostrService({required this.sendSucceeds});

  final bool sendSucceeds;
  int createTodoListCalls = 0;

  @override
  Future<rust_api.EventSendResult> createTodoListOnNostr(
    List<Todo> todos,
  ) async {
    createTodoListCalls += 1;
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
  Future<void> processGlobalBackfillQueue() async {}

  @override
  void setGlobalBackfillResultHandler(dynamic handler) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    tempDir = await Directory.systemTemp.createTemp('meiso_publish_sig_');
    await mockPathProvider(tempDir.path);
    await localStorageService.initialize();

    final now = DateTime.now();
    // needsSync is false so the batch sync that starts when Nostr becomes
    // initialised has nothing to send; the lists are still "changed" for the
    // signature cache because nothing has been published in this session.
    await localStorageService.saveTodos([
      Todo(
        id: 'todo-a',
        title: 'a',
        createdAt: now,
        updatedAt: now,
        needsSync: false,
      ),
      Todo(
        id: 'todo-b',
        title: 'b',
        createdAt: now,
        updatedAt: now,
        needsSync: false,
      ),
    ]);
  });

  tearDown(() async {
    await localStorageService.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<TodosNotifier> startNotifier(_FakeNostrService service) async {
    final container = ProviderContainer(
      overrides: [nostrServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    // Custom lists initialise from local storage; read them first so the
    // notifier is not created for the first time inside a sync.
    container.read(customListsProvider);
    final notifier = container.read(todosProvider.notifier);

    // Wait for the local load before marking Nostr as initialised.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (container.read(todosProvider).valueOrNull?.isNotEmpty != true) {
      if (DateTime.now().isAfter(deadline)) {
        fail('todosProvider did not load local todos in time');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    container.read(nostrInitializedProvider.notifier).state = true;
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  group('_syncAllTodosToNostr signature cache (normal mode)', () {
    test('a failed send is not recorded, so the list is sent again',
        () async {
      final service = _FakeNostrService(sendSucceeds: false);
      final notifier = await startNotifier(service);

      // A send that reached no relay is now reported as a failure
      // (issue c121754a), so manual sync throws instead of claiming success.
      await expectLater(notifier.manualSyncToNostr(), throwsException);
      expect(service.createTodoListCalls, 1);

      await expectLater(notifier.manualSyncToNostr(), throwsException);
      expect(
        service.createTodoListCalls,
        2,
        reason: 'a send that reported success: false must not be treated as '
            'published; the unchanged list has to be resent',
      );
    });

    test('a successful send is recorded, so an unchanged list is skipped',
        () async {
      final service = _FakeNostrService(sendSucceeds: true);
      final notifier = await startNotifier(service);

      await notifier.manualSyncToNostr();
      expect(service.createTodoListCalls, 1);

      await notifier.manualSyncToNostr();
      expect(
        service.createTodoListCalls,
        1,
        reason: 'nothing changed after a successful publish, so the list '
            'must be skipped',
      );
    });
  });
}
