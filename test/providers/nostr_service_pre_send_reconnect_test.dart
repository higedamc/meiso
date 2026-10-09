import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/providers/nostr_provider.dart';
import 'package:meiso/providers/relay_status_provider.dart';

/// PR C, item 5 (PLANS/MEISO_PR_C_HONEST_STATUS_LEAF.md).
///
/// `sendSignedEvent` is the send seam shared by task comments and the send
/// outbox (#212). When the pool is already known to be fully disconnected,
/// it should reconnect (bounded, 1s) before paying for a send that is
/// otherwise certain to fail into the outbox. It must not guess when the
/// state is simply unknown (no relay ever seeded).
///
/// `reconnectRelaysWithTimeout` is overridden on a subclass so the test can
/// observe whether the seam called it, without needing the real Rust
/// bridge for that call. The final `rust_api.sendSignedEvent` call always
/// throws here (`flutter_rust_bridge` is not initialised under `flutter
/// test`) — that is expected and not what these tests assert on.
class _ReconnectSpyNostrService extends NostrService {
  _ReconnectSpyNostrService(super.ref);

  int reconnectCalls = 0;

  @override
  Future<int> reconnectRelaysWithTimeout({int timeoutSeconds = 3}) async {
    reconnectCalls++;
    return 2;
  }
}

void main() {
  late ProviderContainer container;
  late _ReconnectSpyNostrService service;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWith(_ReconnectSpyNostrService.new),
      ],
    );
    service = container.read(nostrServiceProvider) as _ReconnectSpyNostrService;
  });

  tearDown(() => container.dispose());

  test(
    'known fully disconnected: reconnects before attempting the send',
    () async {
      container.read(relayStatusProvider.notifier).initializeWithRelays(
            ['wss://relay.example'],
            initialState: RelayConnectionState.disconnected,
          );

      await expectLater(service.sendSignedEvent('{}'), throwsA(anything));

      // Negative control: with the pre-fix body (`return
      // rust_api.sendSignedEvent(...)` only), this stays 0 even though the
      // pool was known fully disconnected.
      expect(service.reconnectCalls, 1);
    },
  );

  test(
    'at least one relay connected: the seam does not reconnect first',
    () async {
      container.read(relayStatusProvider.notifier).initializeWithRelays(
            ['wss://relay.example'],
            initialState: RelayConnectionState.connected,
          );

      await expectLater(service.sendSignedEvent('{}'), throwsA(anything));

      expect(service.reconnectCalls, 0);
    },
  );

  test(
    'unknown state (no relay ever seeded): does not guess, no reconnect',
    () async {
      await expectLater(service.sendSignedEvent('{}'), throwsA(anything));

      expect(service.reconnectCalls, 0);
    },
  );

  test(
    'a queue drain pays one reconnect, not one per entry',
    () async {
      container.read(relayStatusProvider.notifier).initializeWithRelays(
            ['wss://relay.example'],
            initialState: RelayConnectionState.disconnected,
          );

      // SendOutboxService.flush() walks its entries serially through this same
      // seam, and the status map stays "disconnected" throughout: a successful
      // reconnect does not write it and the connectivity monitor only
      // refreshes every 30s. Without the cooldown each entry reconnects.
      for (var i = 0; i < 5; i++) {
        await expectLater(service.sendSignedEvent('{}'), throwsA(anything));
      }

      expect(service.reconnectCalls, 1);
    },
  );

  test(
    'once the cooldown has elapsed the next send reconnects again',
    () async {
      container.read(relayStatusProvider.notifier).initializeWithRelays(
            ['wss://relay.example'],
            initialState: RelayConnectionState.disconnected,
          );
      service.preSendReconnectCooldown = Duration.zero;

      await expectLater(service.sendSignedEvent('{}'), throwsA(anything));
      await expectLater(service.sendSignedEvent('{}'), throwsA(anything));

      // Guards the other direction: the cooldown must rate-limit, not latch
      // the reconnect off after the first attempt.
      expect(service.reconnectCalls, 2);
    },
  );
}
