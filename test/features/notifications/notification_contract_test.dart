import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_payload.dart';
import 'package:meiso/features/notifications/domain/notification_settings.dart';

/// Tests that pin down the Phase 3 notification contract.
///
/// If one of these fails, nothing "broke" — **the contract was changed**.
/// Leaf 2 (background isolate) and Leaf 3 (settings UI) both assume these
/// keys and these shapes, so a change here has to be made together with both
/// leaves and `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`.
/// 64-char lowercase hex: the defined shape of Nostr event ids and pubkeys.
const String eventIdHex =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String authorPubkeyHex =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// `created_at` validation depends on the current time, so the tests pass a
/// fixed clock.
final DateTime fixedNow = DateTime.utc(2026, 9, 8);

void main() {
  group('NotificationPrefsKeys', () {
    test('key names are fixed (changing them wipes live device settings)', () {
      expect(NotificationPrefsKeys.enabled, 'meiso.notifications.enabled');
      expect(
        NotificationPrefsKeys.sharedTaskComments,
        'meiso.notifications.sharedTaskComments',
      );
      expect(
        NotificationPrefsKeys.deliveredEventIds,
        'meiso.notifications.deliveredEventIds',
      );
      expect(
        NotificationPrefsKeys.lastSeenCreatedAt,
        'meiso.notifications.lastSeenCreatedAt',
      );
    });
  });

  group('NotificationSettings', () {
    test('notifications are opt-in (no resident service by default)', () {
      const defaults = NotificationSettings.defaults;
      expect(defaults.enabled, isFalse);
      expect(defaults.requiresForegroundService, isFalse);
    });

    test('no service is started when every category is off', () {
      const settings = NotificationSettings(
        enabled: true,
        sharedTaskComments: false,
      );
      expect(settings.requiresForegroundService, isFalse);
    });

    test('service is started when enabled and at least one category is on', () {
      const settings = NotificationSettings(enabled: true);
      expect(settings.requiresForegroundService, isTrue);
    });

    test('copyWith changes only the fields given', () {
      const base = NotificationSettings(enabled: true);
      expect(base.copyWith(sharedTaskComments: false).enabled, isTrue);
      expect(base.copyWith(enabled: false).sharedTaskComments, isTrue);
    });
  });

  group('NotificationPayload', () {
    const payload = NotificationPayload(
      eventId: eventIdHex,
      commentId: 'c1',
      taskId: 't1',
      groupId: 'g1',
      authorPubkey: authorPubkeyHex,
      body: 'hello',
      createdAt: 1788514631,
    );

    test('survives a JSON round trip (it crosses the isolate boundary)', () {
      final restored = NotificationPayload.fromJson(
        payload.toJson(),
        now: fixedNow,
      );
      expect(restored.eventId, payload.eventId);
      expect(restored.commentId, payload.commentId);
      expect(restored.taskId, payload.taskId);
      expect(restored.groupId, payload.groupId);
      expect(restored.authorPubkey, payload.authorPubkey);
      expect(restored.body, payload.body);
      expect(restored.createdAt, payload.createdAt);
    });

    test('a missing body falls back to empty (notification still works)', () {
      final json = payload.toJson()..remove('body');
      expect(NotificationPayload.fromJson(json, now: fixedNow).body, '');
    });

    test('toString omits the body (keeps message text out of logs)', () {
      expect(payload.toString(), isNot(contains('hello')));
    });

    test('tryFromJson returns null instead of throwing on malformed input', () {
      // Wrong type / missing required field / non-finite created_at.
      // If one malformed event took the resident service down, every later
      // notification would stop.
      expect(NotificationPayload.tryFromJson(const {}, now: fixedNow), isNull);
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'event_id': 42,
        }, now: fixedNow),
        isNull,
      );
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': double.nan,
        }, now: fixedNow),
        isNull,
      );
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': double.infinity,
        }, now: fixedNow),
        isNull,
      );
    });

    test('rejects far-future created_at (since would jump, muting all)', () {
      // Dart's double.toInt() saturates finite out-of-range values to the
      // int64 ceiling rather than throwing (measured on 3.11.4). Letting one
      // through would advance lastSeenCreatedAt to 9223372036854775807 and
      // filter out every later legitimate event.
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': 1e300,
        }, now: fixedNow),
        isNull,
      );
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': 0,
        }, now: fixedNow),
        isNull,
      );
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': -1,
        }, now: fixedNow),
        isNull,
      );
    });

    test('accepts future times within clock skew (not over-rejecting)', () {
      final soon =
          fixedNow.millisecondsSinceEpoch ~/ 1000 +
          NotificationPayload.maxFutureSkewSeconds -
          60;
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'created_at': soon,
        }, now: fixedNow),
        isNotNull,
      );
    });

    test('rejects event_id / author_pubkey that are not 64-char lowercase hex', () {
      // A dedup list capped only by entry count is uncapped in bytes if a
      // single entry may be arbitrarily long.
      for (final bad in <String>[
        'ev1',
        'A' * 64,
        'g' * 64,
        'a' * 63,
        'a' * 65,
      ]) {
        expect(
          NotificationPayload.tryFromJson({
            ...payload.toJson(),
            'event_id': bad,
          }, now: fixedNow),
          isNull,
          reason: 'event_id=$bad must not be accepted',
        );
        expect(
          NotificationPayload.tryFromJson({
            ...payload.toJson(),
            'author_pubkey': bad,
          }, now: fixedNow),
          isNull,
          reason: 'author_pubkey=$bad must not be accepted',
        );
      }
    });

    test('opaque ids are length-capped', () {
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'task_id': 'x' * (NotificationPayload.maxIdLength + 1),
        }, now: fixedNow),
        isNull,
      );
    });

    test('the body is truncated at the cap', () {
      final long = 'a' * (NotificationPayload.maxBodyCharacters + 100);
      final parsed = NotificationPayload.fromJson({
        ...payload.toJson(),
        'body': long,
      }, now: fixedNow);
      expect(parsed.body.length, NotificationPayload.maxBodyCharacters);
    });

    test('truncation does not split emoji (graphemes, not runes)', () {
      const family = '\u{1F468}\u200D\u{1F469}';
      final body = family * NotificationPayload.maxBodyCharacters;
      final parsed = NotificationPayload.fromJson({
        ...payload.toJson(),
        'body': body,
      }, now: fixedNow);
      // Ending on a ZWJ would mean the cut landed inside a sequence.
      expect(parsed.body.endsWith('\u200D'), isFalse);
      expect(parsed.body.characters.length,
          NotificationPayload.maxBodyCharacters);
    });

    test('strips bidi controls but keeps ZWJ / ZWNJ', () {
      // Only bidi controls can reorder text. Stripping ZWJ wholesale corrupts
      // emoji and Indic / Arabic orthography (measured 2026-09-03).
      final parsed = NotificationPayload.fromJson({
        ...payload.toJson(),
        'body': '\u202Eabc\u2066d\u200Be\uFEFFf\u{1F468}\u200D\u{1F469}',
      }, now: fixedNow);
      for (final stripped in <String>[
        '\u202E',
        '\u2066',
        '\u200B',
        '\uFEFF',
      ]) {
        expect(parsed.body.contains(stripped), isFalse);
      }
      expect(parsed.body.contains('\u200D'), isTrue);
      expect(parsed.body.startsWith('abc'), isTrue);
    });

    test('tryFromJson still accepts valid input (not over-rejecting)', () {
      expect(
        NotificationPayload.tryFromJson(payload.toJson(), now: fixedNow),
        isNotNull,
      );
    });
  });

  group('dedup list cap', () {
    test('a cap is defined (an unbounded cache is a DoS surface)', () {
      expect(NotificationPrefsKeys.maxDeliveredEventIds, greaterThan(0));
      expect(
        NotificationPrefsKeys.maxDeliveredEventIds,
        lessThanOrEqualTo(5000),
      );
    });
  });
}
