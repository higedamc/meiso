/// Phase 3 通知(Pokey 型のリレー常時接続 + 端末通知)の設定エンティティと
/// 永続化キー。
///
/// 設計は `PLANS/MEISO_PHASE3_NOTIFY_PLAN.md`(Lead)を参照。
/// このファイルは **Leaf 2(背景 isolate)と Leaf 3(設定 UI)の唯一の接点**であり、
/// 契約として先に main へ入れる。以降 Leaf 側でキー名や既定値を変えないこと。
///
/// ## なぜ AppSettings(NIP-78 kind 30078)に入れないのか
///
/// 通知設定は **端末ローカル**である。foreground service を動かせるか、電池最適化を
/// 除外できているかは端末ごとの事情で、これをリレー同期すると「片方の端末で切ったら
/// もう片方も鳴らなくなる」という挙動になる。加えて `AppSettings` は freezed 生成物
/// (`app_settings.freezed.dart` / `.g.dart`)を巻き込む God File で、並行 Leaf と衝突する。
///
/// ## 永続化先は SharedPreferences であり Hive ではない
///
/// 背景 isolate から Hive の box を開いてはいけない。UI isolate が開いている box を
/// 別 isolate から開くと壊れる。`flutter_foreground_task` 自身も Dart callback の
/// 復元に SharedPreferences を使うため、同じ土俵に揃える。
library;

/// 通知設定の永続化キー。
///
/// SharedPreferences に平文で入るため、**秘密値をここに置かないこと**
/// (group nsec / ユーザー秘密鍵は従来どおり既存の保管先に置く)。
abstract final class NotificationPrefsKeys {
  static const String _prefix = 'meiso.notifications';

  /// 通知機能そのものの ON/OFF。既定 false(オプトイン)。
  ///
  /// 常駐 foreground service を起こすかどうかがこれで決まるので、
  /// 既定を true にしてはいけない。
  static const String enabled = '$_prefix.enabled';

  /// 共有タスクのコメント通知の ON/OFF。既定 true。
  ///
  /// 個人タスクのコメント(author = 自分)は Phase 3 では通知しないため、
  /// 対応するキーは存在しない。
  static const String sharedTaskComments = '$_prefix.sharedTaskComments';

  /// 背景 isolate が通知済みイベント ID を覚えておくためのキー。
  ///
  /// **背景 isolate 専用。UI 側から書かないこと。**
  /// BOOT_COMPLETED は重複配送されうるので、重複排除は必須である。
  ///
  /// **必ず [maxDeliveredEventIds] 件で打ち切ること(古いものから捨てる)。**
  /// グループのリレーには第三者もイベントを流せるので、上限の無い重複排除リストは
  /// 攻撃者が伸ばせる保存領域になる。無制限に伸びるキャッシュは
  /// それ自体が DoS の口である。
  static const String deliveredEventIds = '$_prefix.deliveredEventIds';

  /// [deliveredEventIds] に保持するイベント ID の上限件数。
  ///
  /// 通知の重複を防ぐのに必要なのは「直近」だけで、全履歴ではない。
  /// 併せて [lastSeenCreatedAt] で購読の since を進めるので、
  /// 打ち切ったところで古いイベントが再通知されることはない。
  static const int maxDeliveredEventIds = 500;

  /// 背景 isolate が最後に処理したイベントの created_at(unix 秒)。
  ///
  /// **背景 isolate 専用。** 再購読時の since に使う。
  ///
  /// **ここに入れてよいのは `NotificationPayload` の検証を通った値だけ。**
  /// リレーには第三者も書けるので、生の `created_at` をそのまま進めると
  /// 遠い未来の 1 件で since が飛び、以降の正当なイベントが全部弾かれて
  /// 通知が静かに永久停止する。上限の根拠は
  /// `NotificationPayload.maxFutureSkewSeconds` を参照。
  /// あわせて **この値は後退させないこと**(巻き戻すと再通知が起きる)。
  static const String lastSeenCreatedAt = '$_prefix.lastSeenCreatedAt';
}

/// 通知設定。
class NotificationSettings {
  const NotificationSettings({
    this.enabled = false,
    this.sharedTaskComments = true,
  });

  /// 既定値。**通知はオプトイン**である。
  static const NotificationSettings defaults = NotificationSettings();

  /// 通知機能全体の ON/OFF
  final bool enabled;

  /// 共有タスクのコメントを通知するか
  final bool sharedTaskComments;

  /// 常駐サービスを起こす必要があるか。
  ///
  /// 通知種別が 1 つも有効でなければサービスを起こさない(電池を無駄にしない)。
  bool get requiresForegroundService => enabled && sharedTaskComments;

  NotificationSettings copyWith({bool? enabled, bool? sharedTaskComments}) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      sharedTaskComments: sharedTaskComments ?? this.sharedTaskComments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          other.enabled == enabled &&
          other.sharedTaskComments == sharedTaskComments;

  @override
  int get hashCode => Object.hash(enabled, sharedTaskComments);
}
