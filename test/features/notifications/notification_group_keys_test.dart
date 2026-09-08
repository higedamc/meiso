import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_group_keys.dart';

const String _npub =
    'aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff00000000'
    '11111111';
const String _nsec =
    '1111111122222222333333334444444455555555666666667777777'
    '788888888';
const String _self =
    'a8c52c8bb2a9285abaeaf25e0b2f22a82db6a2d578481afaec6e1b5a7aa4c93c';

NotificationGroupKeys _sample() => const NotificationGroupKeys(
      selfPubkeyHex: _self,
      groups: [
        NotificationGroupKey(
          groupId: 'group-1',
          groupNpubHex: _npub,
          groupNsecHex: _nsec,
        ),
      ],
    );

void main() {
  setUp(() {
    // The literals above are only useful as fixtures if they are the shape the
    // parser demands; a typo would otherwise make every test pass vacuously
    // against `empty`.
    expect(_npub.length, 64);
    expect(_nsec.length, 64);
    expect(_self.length, 64);
  });

  group('NotificationGroupKeys round trip', () {
    test('encode then decode preserves the groups and the self pubkey', () {
      final decoded = NotificationGroupKeys.decode(_sample().encode());

      expect(decoded.selfPubkeyHex, _self);
      expect(decoded.groups, hasLength(1));
      expect(decoded.groups.single.groupId, 'group-1');
      expect(decoded.groups.single.groupNpubHex, _npub);
      expect(decoded.groups.single.groupNsecHex, _nsec);
    });

    test('groupNpubHexes is what the subscription filter needs', () {
      expect(_sample().groupNpubHexes, [_npub]);
    });

    test('lookup by group id and by signing key both resolve', () {
      final keys = _sample();

      expect(keys.forGroup('group-1')?.groupNsecHex, _nsec);
      expect(keys.forGroup('missing'), isNull);
      expect(keys.forNpub(_npub.toUpperCase())?.groupId, 'group-1');
      expect(keys.forNpub('0' * 64), isNull);
    });
  });

  group('NotificationGroupKeys.decode is total', () {
    test('null and empty input yield the empty mirror, not an exception', () {
      expect(NotificationGroupKeys.decode(null).isEmpty, isTrue);
      expect(NotificationGroupKeys.decode('').isEmpty, isTrue);
    });

    test('malformed JSON yields the empty mirror', () {
      expect(NotificationGroupKeys.decode('{not json').isEmpty, isTrue);
      expect(NotificationGroupKeys.decode('[1,2,3]').isEmpty, isTrue);
    });

    test('an unknown version is refused rather than reinterpreted', () {
      final payload = _sample().toJson()..['version'] = 99;

      // Refusing is the point: guessing at an unrecognised shape is how a
      // future field silently becomes the wrong one.
      expect(NotificationGroupKeys.decode(jsonEncode(payload)).isEmpty, isTrue);
    });

    test('a corrupt entry is skipped without losing the healthy ones', () {
      final payload = {
        'version': NotificationGroupKeys.currentVersion,
        'self_pubkey': _self,
        'groups': [
          {'group_id': 'bad', 'group_npub': 'too-short', 'group_nsec': _nsec},
          {'group_id': '', 'group_npub': _npub, 'group_nsec': _nsec},
          {'group_id': 'good', 'group_npub': _npub, 'group_nsec': _nsec},
          'not even a map',
        ],
      };

      final decoded = NotificationGroupKeys.decode(jsonEncode(payload));

      // One bad group must not take down the resident service and with it
      // every later notification.
      expect(decoded.groups, hasLength(1));
      expect(decoded.groups.single.groupId, 'good');
    });

    test('hex is normalised to lower case so comparisons cannot miss', () {
      final payload = {
        'version': NotificationGroupKeys.currentVersion,
        'self_pubkey': _self.toUpperCase(),
        'groups': [
          {
            'group_id': 'g',
            'group_npub': _npub.toUpperCase(),
            'group_nsec': _nsec.toUpperCase(),
          },
        ],
      };

      final decoded = NotificationGroupKeys.decode(jsonEncode(payload));

      expect(decoded.selfPubkeyHex, _self);
      expect(decoded.groups.single.groupNpubHex, _npub);
      expect(decoded.groups.single.groupNsecHex, _nsec);
    });

    test('a non-hex self pubkey degrades to empty, not to a bogus id', () {
      final payload = _sample().toJson()..['self_pubkey'] = 'nope';

      // Self-echo suppression compares against this value. A garbage identity
      // that still looks present is worse than an absent one.
      expect(
        NotificationGroupKeys.decode(jsonEncode(payload)).selfPubkeyHex,
        isEmpty,
      );
    });
  });

  group('secrets do not leak through incidental paths', () {
    test('toString names the group but never the key material', () {
      final text = _sample().groups.single.toString();

      expect(text, contains('group-1'));
      expect(text, isNot(contains(_nsec)));
      expect(text, isNot(contains(_npub)));
    });
  });

  test('the storage key is versioned in the key itself', () {
    // A future shape change takes a new key rather than silently
    // reinterpreting bytes written by an older build.
    expect(NotificationSecureKeys.groupKeys, endsWith('.v1'));
  });
}
