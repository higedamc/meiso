import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/infrastructure/background_notify_task_handler.dart';
import 'package:meiso/features/notifications/infrastructure/background_session_source.dart';

void main() {
  group('BackgroundNotifyTaskHandler lifecycle', () {
    test(
      'onStart returns without subscribing when no user is logged in',
      () async {
        final handler = BackgroundNotifyTaskHandler(
          sessionSource: _FakeSessionSource(localPubkeyHex: null),
        );

        await handler.onStart(DateTime(2026, 1, 1), TaskStarter.system);
      },
    );

    test(
      'onStart returns without subscribing when no group keys are mirrored',
      () async {
        final handler = BackgroundNotifyTaskHandler(
          sessionSource: _FakeSessionSource(localPubkeyHex: _pubkey),
        );

        await handler.onStart(DateTime(2026, 1, 1), TaskStarter.system);
      },
    );

    test('onDestroy is safe before onStart completes', () async {
      final handler = BackgroundNotifyTaskHandler(
        sessionSource: _FakeSessionSource(localPubkeyHex: null),
      );

      await handler.onDestroy(DateTime(2026, 1, 1), false);
    });
  });
}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _FakeSessionSource implements BackgroundSessionSource {
  _FakeSessionSource({required this.localPubkeyHex});

  final String? localPubkeyHex;

  @override
  Future<String?> loadLocalPubkeyHex() async => localPubkeyHex;

  @override
  Future<Map<String, GroupCredential>> loadGroupCredentials() async => {};
}
