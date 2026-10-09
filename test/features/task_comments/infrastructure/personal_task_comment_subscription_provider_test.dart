import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/bridge_generated.dart/api.dart' as rust_api;
import 'package:meiso/features/task_comments/domain/repositories/task_comment_repository.dart';
import 'package:meiso/features/task_comments/infrastructure/providers/repository_providers.dart';
import 'package:meiso/providers/nostr_provider.dart';

const _myPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Never touched in these tests (only used by the events callback).
class _FakeTaskCommentRepository implements TaskCommentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNostrService implements NostrService {
  /// One completer per subscribe call, in call order. Each test decides when
  /// (and whether) a call resolves, so the in-flight window is observable.
  final subscribeCalls = <Completer<String>>[];
  final _subscribeStarted = StreamController<void>.broadcast();
  final stopped = <String>[];

  @override
  Future<String?> getPublicKey() async => _myPubkey;

  @override
  Future<String> subscribePersonalTaskComments({
    required String publicKeyHex,
    required void Function(List<rust_api.ReceivedEvent> events)
    onEventsReceived,
  }) {
    final completer = Completer<String>();
    subscribeCalls.add(completer);
    _subscribeStarted.add(null);
    return completer.future;
  }

  @override
  Future<void> stopSubscription(String subscriptionId) async {
    stopped.add(subscriptionId);
  }

  Future<void> nextSubscribeStarted() => _subscribeStarted.stream.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(
  _FakeNostrService service, {
  required bool initialized,
}) {
  final container = ProviderContainer(
    overrides: [
      nostrServiceProvider.overrideWithValue(service),
      taskCommentRepositoryProvider.overrideWithValue(
        _FakeTaskCommentRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(nostrInitializedProvider.notifier).state = initialized;
  return container;
}

void _setInitialized(ProviderContainer container, bool value) {
  container.read(nostrInitializedProvider.notifier).state = value;
}

void main() {
  group('personalTaskCommentSessionProvider', () {
    test(
      'cold start: armed by one root read before login, login opens the '
      'subscription with no listener attached',
      () async {
        final service = _FakeNostrService();
        final container = _container(service, initialized: false);

        // The app root does exactly this once, in initState, while the
        // Nostr session is still being restored.
        container.read(personalTaskCommentSessionProvider);
        await pumpEventQueue();
        expect(service.subscribeCalls, isEmpty);

        _setInitialized(container, true);
        await service.nextSubscribeStarted();
        service.subscribeCalls.single.complete('sub-1');
        await pumpEventQueue();

        expect(
          container.read(personalTaskCommentSessionProvider).subscriptionId,
          'sub-1',
        );
        // Nothing was torn down although nobody listens: this is the session
        // scope the tile badge depends on.
        expect(service.stopped, isEmpty);
      },
    );

    test('already initialised when first read: subscribes at once', () async {
      final service = _FakeNostrService();
      final container = _container(service, initialized: true);

      container.read(personalTaskCommentSessionProvider);
      await service.nextSubscribeStarted();
      service.subscribeCalls.single.complete('sub-1');
      await pumpEventQueue();

      expect(
        container.read(personalTaskCommentSessionProvider).subscriptionId,
        'sub-1',
      );
    });

    test('logout stops the subscription; login arms a new one', () async {
      final service = _FakeNostrService();
      final container = _container(service, initialized: true);

      container.read(personalTaskCommentSessionProvider);
      await service.nextSubscribeStarted();
      service.subscribeCalls.single.complete('sub-1');
      await pumpEventQueue();
      expect(service.stopped, isEmpty);

      // Logout flips nostrInitializedProvider to false (secret-key screen).
      _setInitialized(container, false);
      await pumpEventQueue();

      expect(service.stopped, ['sub-1']);
      expect(
        container.read(personalTaskCommentSessionProvider).subscriptionId,
        isNull,
      );

      // Login flips it back: a fresh subscription, exactly one more.
      _setInitialized(container, true);
      await service.nextSubscribeStarted();
      expect(service.subscribeCalls, hasLength(2));
      service.subscribeCalls[1].complete('sub-2');
      await pumpEventQueue();

      expect(
        container.read(personalTaskCommentSessionProvider).subscriptionId,
        'sub-2',
      );
      expect(service.stopped, ['sub-1']);
    });

    test(
      'logout while the subscribe round-trip is in flight: the orphan is '
      'stopped exactly once and never stored',
      () async {
        final service = _FakeNostrService();
        final container = _container(service, initialized: true);

        container.read(personalTaskCommentSessionProvider);
        await service.nextSubscribeStarted();

        // Session ends before the relay round-trip resolves.
        _setInitialized(container, false);
        await pumpEventQueue();
        expect(service.stopped, isEmpty);

        service.subscribeCalls.single.complete('sub-1');
        await pumpEventQueue();

        expect(service.stopped, ['sub-1']);
        expect(
          container.read(personalTaskCommentSessionProvider).subscriptionId,
          isNull,
        );
      },
    );

    test(
      'logout and re-login while the first round-trip is in flight: the stale '
      'result is stopped, the fresh one is kept',
      () async {
        final service = _FakeNostrService();
        final container = _container(service, initialized: true);

        container.read(personalTaskCommentSessionProvider);
        await service.nextSubscribeStarted();

        _setInitialized(container, false);
        _setInitialized(container, true);
        await service.nextSubscribeStarted();
        expect(service.subscribeCalls, hasLength(2));

        // The stale call resolves after the fresh one was issued.
        service.subscribeCalls[0].complete('stale');
        service.subscribeCalls[1].complete('fresh');
        await pumpEventQueue();

        expect(service.stopped, ['stale']);
        expect(
          container.read(personalTaskCommentSessionProvider).subscriptionId,
          'fresh',
        );
      },
    );

    test('container disposal stops the subscription', () async {
      final service = _FakeNostrService();
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(service),
          taskCommentRepositoryProvider.overrideWithValue(
            _FakeTaskCommentRepository(),
          ),
        ],
      );
      container.read(nostrInitializedProvider.notifier).state = true;

      container.read(personalTaskCommentSessionProvider);
      await service.nextSubscribeStarted();
      service.subscribeCalls.single.complete('sub-1');
      await pumpEventQueue();

      container.dispose();
      await pumpEventQueue();

      expect(service.stopped, ['sub-1']);
    });
  });

  group('personalTaskCommentSubscriptionProvider (detail-screen alias)', () {
    test(
      'watching and un-watching it opens no second REQ and stops nothing',
      () async {
        final service = _FakeNostrService();
        final container = _container(service, initialized: true);

        container.read(personalTaskCommentSessionProvider);
        await service.nextSubscribeStarted();
        service.subscribeCalls.single.complete('sub-1');
        await pumpEventQueue();

        // TaskCommentSection comes on screen...
        final watch = container.listen(
          personalTaskCommentSubscriptionProvider,
          (_, __) {},
        );
        await pumpEventQueue();
        expect(service.subscribeCalls, hasLength(1));

        // ...and goes away. The session subscription must survive it.
        watch.close();
        await container.pump();
        await pumpEventQueue();

        expect(service.stopped, isEmpty);
        expect(
          container.read(personalTaskCommentSessionProvider).subscriptionId,
          'sub-1',
        );
      },
    );

    test(
      'opened before the root armed the session: it arms it, and closing '
      'the screen still leaves the session alive',
      () async {
        final service = _FakeNostrService();
        final container = _container(service, initialized: true);

        final watch = container.listen(
          personalTaskCommentSubscriptionProvider,
          (_, __) {},
        );
        await service.nextSubscribeStarted();
        service.subscribeCalls.single.complete('sub-1');
        await pumpEventQueue();

        watch.close();
        await container.pump();
        await pumpEventQueue();

        expect(service.stopped, isEmpty);
        expect(service.subscribeCalls, hasLength(1));
      },
    );
  });
}
