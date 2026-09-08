import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/infrastructure/self_echo_filter.dart';

void main() {
  group('isSelfEcho', () {
    test('true when the decrypted payload author is the local user', () {
      expect(
        isSelfEcho(payloadAuthorPubkey: 'a' * 64, localPubkeyHex: 'a' * 64),
        isTrue,
      );
    });

    test('false for a different author', () {
      expect(
        isSelfEcho(payloadAuthorPubkey: 'a' * 64, localPubkeyHex: 'b' * 64),
        isFalse,
      );
    });

    test(
      'is case-sensitive (both sides are already-normalized lowercase hex '
      'by the time this runs; a mismatch here is a bug upstream, not '
      'something to paper over)',
      () {
        expect(
          isSelfEcho(payloadAuthorPubkey: 'A' * 64, localPubkeyHex: 'a' * 64),
          isFalse,
        );
      },
    );
  });
}
