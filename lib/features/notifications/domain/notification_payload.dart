/// 背景 isolate が通知層へ渡す 1 件分のデータ。
///
/// 設計は `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`(Lead)を参照。
/// **Leaf 1(ネイティブ)・Leaf 2(背景 isolate)・Leaf 3(UI)の共通の型**であり、
/// 契約として先に main へ入れる。
///
/// isolate 境界と(必要なら)MethodChannel を越えるため、**必ず JSON で往復できる形に
/// 保つこと**。ここに Riverpod の provider や Rust の生ハンドルを持ち込まない。
///
/// ## この型が入力検証を持っている理由
///
/// ここに流れてくる値の元はグループのリレー上のイベントで、**そのリレーには
/// 第三者も書き込める**。つまり全フィールドが攻撃者の選んだ値になりうる。
/// 検証を Leaf 2 と Leaf 3 の両方に任せると、片方が忘れた時点で穴が開く。
/// 3 つの Leaf が必ず通る唯一の門であるこの契約側で閉じる。
library;

import 'package:characters/characters.dart';

/// 通知 1 件分のペイロード。
class NotificationPayload {
  const NotificationPayload({
    required this.eventId,
    required this.commentId,
    required this.taskId,
    required this.groupId,
    required this.authorPubkey,
    required this.body,
    required this.createdAt,
  });

  /// 壊れた入力では [FormatException] を投げる。
  ///
  /// キャストで `TypeError` を投げるのではなく明示的に型を確かめているのは、
  /// **プログラムの誤りとしての `Error` と、外から来た壊れたデータとしての
  /// `Exception` を混ぜないため**。混ぜると呼び出し側が `Error` を握り潰す形になる。
  ///
  /// [now] はテスト用。省略時は現在時刻。
  factory NotificationPayload.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    return NotificationPayload(
      eventId: _requireHex64(json, 'event_id'),
      commentId: _requireId(json, 'comment_id'),
      taskId: _requireId(json, 'task_id'),
      groupId: _requireId(json, 'group_id'),
      authorPubkey: _requireHex64(json, 'author_pubkey'),
      body: sanitizeBody(json['body'] is String ? json['body'] as String : ''),
      createdAt: _requireCreatedAt(json, now ?? DateTime.now()),
    );
  }

  /// 通知に載せる本文の上限(書記素クラスタ数)。
  ///
  /// システム通知はどのみち数行しか出さない。上限が無いと、リレーに数 MB の
  /// 本文を流すだけで背景 isolate の常駐メモリを攻撃者が伸ばせる。
  static const int maxBodyCharacters = 500;

  /// 不透明な ID(comment / task / group)の長さ上限。
  ///
  /// これらはアプリが振る `d` タグ値で、hex とは限らないので形は縛れない。
  /// ただし長さは縛る — `NotificationPrefsKeys.deliveredEventIds` のような
  /// 「件数だけ上限がある」保存先は、1 件あたりが無制限だと結局無制限になる。
  static const int maxIdLength = 128;

  /// `created_at` に許す未来方向のずれ(秒)。
  ///
  /// 端末とリレーの時計はずれるので多少は許すが、無制限に許してはいけない。
  /// 理由は `NotificationPrefsKeys.lastSeenCreatedAt` の項を参照。
  static const int maxFutureSkewSeconds = 24 * 60 * 60;

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Nostr のイベント ID / 公開鍵は 64 桁の小文字 hex と決まっている。
  ///
  /// 形を縛るのは見た目のためではなく、**この値がそのまま重複排除リストの要素として
  /// 端末に保存されるから**。「空でない文字列」しか要求しないと、件数の上限が
  /// バイト数の上限にならない。
  static String _requireHex64(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || !_hex64.hasMatch(value)) {
      throw FormatException('$key is not a 64-char lowercase hex string');
    }
    return value;
  }

  static String _requireId(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty || value.length > maxIdLength) {
      throw FormatException(
        '$key is missing, empty, or longer than $maxIdLength',
      );
    }
    return value;
  }

  /// `created_at` を検証する。
  ///
  /// **未来方向に上限を置くのが要点。**Dart の `double.toInt()` は範囲外の有限値を
  /// 例外ではなく `9223372036854775807` に飽和させるので(3.11.4 で実測)、
  /// `1e300` のような値をそのまま通すと `lastSeenCreatedAt` が int64 上限まで進み、
  /// **以降の正当なイベントが全部 `since` で弾かれて通知が永久に止まる**。
  /// 落ちないので誰も気づかない。1 件のイベントで機能全体を黙らせられてはいけない。
  static int _requireCreatedAt(Map<String, dynamic> json, DateTime now) {
    final value = json['created_at'];
    if (value is! num || !value.isFinite) {
      throw const FormatException('created_at is not a finite number');
    }
    final seconds = value.toInt();
    if (seconds <= 0) {
      throw const FormatException('created_at is not a positive unix time');
    }
    final limit =
        now.toUtc().millisecondsSinceEpoch ~/ 1000 + maxFutureSkewSeconds;
    if (seconds > limit) {
      throw const FormatException('created_at is too far in the future');
    }
    return seconds;
  }

  /// 通知に出す本文を安全な形に整える。
  ///
  /// 消すのは**並び順を変える双方向制御文字**と、**幅を持たない詰め物**だけ。
  /// `U+200C` / `U+200D`(ZWNJ / ZWJ)は**消さない** — 順序を変える力は無い一方で、
  /// 絵文字の合成と Indic・アラビア語の正書法に必須で、消すと文字が壊れる。
  /// (2026-09-03 に PR #165 で一律除去を実際に試して `👨‍👩` が割れることを確認済み)
  ///
  /// 打ち切りは書記素クラスタ単位で行う。`runes` で切ると ZWJ 連結の途中に
  /// 境界が当たって絵文字が割れる。
  static String sanitizeBody(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if (_isDisallowedInvisible(rune)) {
        continue;
      }
      buffer.writeCharCode(rune);
    }
    final cleaned = buffer.toString();
    final characters = cleaned.characters;
    if (characters.length <= maxBodyCharacters) {
      return cleaned;
    }
    return characters.take(maxBodyCharacters).toString();
  }

  static bool _isDisallowedInvisible(int rune) {
    // 双方向制御(表示順を入れ替えて別人・別内容に見せられる)
    // U+061C ALM / U+200E LRM / U+200F RLM / U+202A..202E / U+2066..2069
    final isBidiControl =
        rune == 0x061C ||
        rune == 0x200E ||
        rune == 0x200F ||
        (rune >= 0x202A && rune <= 0x202E) ||
        (rune >= 0x2066 && rune <= 0x2069);
    // 幅を持たない詰め物(見えないまま長さと境界を狂わせる)
    // U+180E / U+200B / U+2060..2064 / U+FFF9..FFFB / U+FEFF
    final isInvisibleFiller =
        rune == 0x180E ||
        rune == 0x200B ||
        (rune >= 0x2060 && rune <= 0x2064) ||
        (rune >= 0xFFF9 && rune <= 0xFFFB) ||
        rune == 0xFEFF;
    return isBidiControl || isInvisibleFiller;
  }

  /// 壊れた入力では例外を投げずに null を返す版。
  ///
  /// **背景 isolate はこちらを使うこと。** ここに流れてくる値の元はリレー上の
  /// イベントであり、内容は攻撃者が決められる。1 件の壊れたイベントで
  /// `fromJson` が投げて常駐サービスが落ちると、**以降の通知が全部止まる**。
  /// 「1 件を捨てる」と「全部止まる」を取り違えないための入口。
  static NotificationPayload? tryFromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    try {
      return NotificationPayload.fromJson(json, now: now);
    } on FormatException {
      return null;
    }
  }

  /// 元の Nostr イベント ID(64 桁小文字 hex)。**重複排除のキーはこれ**。
  ///
  /// BOOT_COMPLETED の重複配送やリレー再接続で同じイベントが複数回届くため、
  /// `commentId` ではなくイベント ID で弾く。
  final String eventId;

  /// コメント ID(addressable event の `d` タグ値)
  final String commentId;

  /// 紐付くタスクの ID。通知タップ時の遷移先に使う。
  final String taskId;

  /// 共有グループの ID。個人コメントは Phase 3 では通知しないので必須にしている。
  final String groupId;

  /// **復号後のペイロードに入っている**投稿者の公開鍵(64 桁小文字 hex)。
  ///
  /// 共有タスクは全メンバーが同一の group 鍵で署名するため、**イベントの封筒からは
  /// 書き手が分からない**。自己エコー抑止(自分の書き込みで自分に通知が飛ぶのを防ぐ)は
  /// 必ずこの復号後の値と自分の pubkey を比較して行うこと。封筒の pubkey で判定しない。
  ///
  /// なお shared-v1 ではこの値は自己申告であり、**権限判定には使えない**。
  /// 通知の表示と自己エコー抑止にのみ使う。
  final String authorPubkey;

  /// 復号済みの本文。通知に表示する。[sanitizeBody] を通した後の値。
  final String body;

  /// 投稿時刻(unix 秒)
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'comment_id': commentId,
    'task_id': taskId,
    'group_id': groupId,
    'author_pubkey': authorPubkey,
    'body': body,
    'created_at': createdAt,
  };

  @override
  String toString() =>
      'NotificationPayload(eventId: $eventId, taskId: $taskId, '
      'groupId: $groupId, createdAt: $createdAt)';
}
