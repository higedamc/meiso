import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/notifications/domain/notification_payload.dart';
import 'package:meiso/features/notifications/domain/notification_settings.dart';

/// Phase 3 通知の契約を固定するテスト。
///
/// このテストが落ちたら、それは「壊れた」のではなく **契約を変えた**ということ。
/// Leaf 2(背景 isolate)と Leaf 3(設定 UI)が同じキーと同じ形を前提にしているので、
/// 変更するなら両 Leaf と `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md` を同時に直すこと。
/// 64 桁小文字 hex。Nostr のイベント ID / 公開鍵はこの形と決まっている。
const String eventIdHex =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String authorPubkeyHex =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// `created_at` の検証が現在時刻に依存するので、テストは時刻を固定して渡す。
final DateTime fixedNow = DateTime.utc(2026, 9, 8);

void main() {
  group('NotificationPrefsKeys', () {
    test('キー名は固定である(勝手に変えると既存端末の設定が消える)', () {
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
    test('通知はオプトイン(既定で常駐サービスを起こさない)', () {
      const defaults = NotificationSettings.defaults;
      expect(defaults.enabled, isFalse);
      expect(defaults.requiresForegroundService, isFalse);
    });

    test('種別が全部 off ならサービスを起こさない', () {
      const settings = NotificationSettings(
        enabled: true,
        sharedTaskComments: false,
      );
      expect(settings.requiresForegroundService, isFalse);
    });

    test('enabled かつ種別が 1 つでも on ならサービスを起こす', () {
      const settings = NotificationSettings(enabled: true);
      expect(settings.requiresForegroundService, isTrue);
    });

    test('copyWith は指定した項目だけを変える', () {
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

    test('JSON を往復しても壊れない(isolate 境界を越えるため)', () {
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

    test('body 欠損は空文字にフォールバックする(通知が落ちない)', () {
      final json = payload.toJson()..remove('body');
      expect(NotificationPayload.fromJson(json, now: fixedNow).body, '');
    });

    test('toString に本文を含めない(ログへの本文流出を防ぐ)', () {
      expect(payload.toString(), isNot(contains('hello')));
    });

    test('tryFromJson は壊れた入力で例外を投げず null を返す', () {
      // 型違い / 必須欠損 / 非有限の created_at。
      // 1 件の壊れたイベントで常駐サービスが落ちると以降の通知が全部止まる。
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

    test('遠い未来の created_at を拒否する(since が飛んで通知が永久停止する)', () {
      // Dart の double.toInt() は範囲外の有限値を例外ではなく int64 上限に
      // 飽和させる(3.11.4 実測)。素通しすると lastSeenCreatedAt が
      // 9223372036854775807 まで進み、以降の正当なイベントが全部弾かれる。
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

    test('時計ずれの範囲内なら未来でも通す(過剰拒否していない)', () {
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

    test('event_id / author_pubkey は 64 桁小文字 hex でなければ拒否する', () {
      // 件数だけ上限のある重複排除リストは、1 件あたりが無制限だと結局無制限。
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
          reason: 'event_id=$bad を通してはいけない',
        );
        expect(
          NotificationPayload.tryFromJson({
            ...payload.toJson(),
            'author_pubkey': bad,
          }, now: fixedNow),
          isNull,
          reason: 'author_pubkey=$bad を通してはいけない',
        );
      }
    });

    test('不透明な ID は長さに上限がある', () {
      expect(
        NotificationPayload.tryFromJson({
          ...payload.toJson(),
          'task_id': 'x' * (NotificationPayload.maxIdLength + 1),
        }, now: fixedNow),
        isNull,
      );
    });

    test('本文は上限で打ち切られる', () {
      final long = 'a' * (NotificationPayload.maxBodyCharacters + 100);
      final parsed = NotificationPayload.fromJson({
        ...payload.toJson(),
        'body': long,
      }, now: fixedNow);
      expect(parsed.body.length, NotificationPayload.maxBodyCharacters);
    });

    test('打ち切りで絵文字が割れない(runes ではなく書記素で切る)', () {
      const family = '\u{1F468}\u200D\u{1F469}';
      final body = family * NotificationPayload.maxBodyCharacters;
      final parsed = NotificationPayload.fromJson({
        ...payload.toJson(),
        'body': body,
      }, now: fixedNow);
      // ZWJ で終わる = 連結の途中で切れている。
      expect(parsed.body.endsWith('\u200D'), isFalse);
      expect(parsed.body.characters.length,
          NotificationPayload.maxBodyCharacters);
    });

    test('双方向制御文字は消すが ZWJ / ZWNJ は残す', () {
      // 並び順を変えられるのは双方向制御文字だけ。ZWJ を一律に消すと
      // 絵文字と Indic / アラビア語の表記が壊れる(2026-09-03 実測)。
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

    test('tryFromJson は正常な入力ではちゃんと通る(過剰拒否していない)', () {
      expect(
        NotificationPayload.tryFromJson(payload.toJson(), now: fixedNow),
        isNotNull,
      );
    });
  });

  group('重複排除リストの上限', () {
    test('上限が定義されている(無制限に伸びるキャッシュは DoS の口)', () {
      expect(NotificationPrefsKeys.maxDeliveredEventIds, greaterThan(0));
      expect(
        NotificationPrefsKeys.maxDeliveredEventIds,
        lessThanOrEqualTo(5000),
      );
    });
  });
}
