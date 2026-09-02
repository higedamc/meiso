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
  final subscribeStarted = Completer<void>();
  final subscribeResult = Completer<String>();
  final stopped = <String>[];

  @override
  Future<String?> getPublicKey() async => _myPubkey;

  @override
  Future<String> subscribePersonalTaskComments({
    required String publicKeyHex,
    required void Function(List<rust_api.ReceivedEvent> events)
        onEventsReceived,
  }) {
    subscribeStarted.complete();
    return subscribeResult.future;
  }

  @override
  Future<void> stopSubscription(String subscriptionId) async {
    stopped.add(subscriptionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_FakeNostrService service) {
  final container = ProviderContainer(
    overrides: [
      nostrServiceProvider.overrideWithValue(service),
      taskCommentRepositoryProvider.overrideWithValue(
        _FakeTaskCommentRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(nostrInitializedProvider.notifier).state = true;
  return container;
}

void main() {
  test(
    'disposed while the subscribe round-trip is in flight: '
    'no throw and the orphan subscription is stopped',
    () async {
      final service = _FakeNostrService();
      final container = _container(service);

      final subscription = container.listen(
        personalTaskCommentSubscriptionProvider,
        (_, __) {},
      );
      // The provider is now awaiting subscribePersonalTaskComments.
      await service.subscribeStarted.future;

      // Last listener goes away before the relay round-trip resolves.
      subscription.close();
      await container.pump();

      service.subscribeResult.complete('sub-1');
      await pumpEventQueue();

      // Exactly one stop: the just-created subscription must not leak, and
      // the late onDispose registration must not throw a StateError.
      expect(service.stopped, ['sub-1']);
    },
  );

  test('disposed after the subscription resolved: stopped via onDispose', () async {
    final service = _FakeNostrService();
    final container = _container(service);

    final subscription = container.listen(
      personalTaskCommentSubscriptionProvider,
      (_, __) {},
    );
    await service.subscribeStarted.future;
    service.subscribeResult.complete('sub-1');
    await pumpEventQueue();

    expect(
      container.read(personalTaskCommentSubscriptionProvider).value,
      'sub-1',
    );
    expect(service.stopped, isEmpty);

    subscription.close();
    await container.pump();

    expect(service.stopped, ['sub-1']);
  });
}
