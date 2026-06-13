# Shared-Key Collaborative Lists (shared-v1) 実装 Takeaways

本ドキュメントは `feature/new-group-lists`(1.4.0)で MLS グループリストから
共有鍵方式(`shared-v1`)へ移行する過程で得られた知見を、再発防止のために残す。
設計の前提は `SHARED_LIST_STRATEGY.md` を参照。

## 1. Addressable event のフェッチは `since=0` フルフェッチが正解

shared-v1 のタスクは 1 タスク = 1 addressable event(`kind:35000`, author=`G`,
`d=task-id`)で、relay 側で `(kind, author, d)` ごとに LWW 上書きされる。
つまり relay が保持するのは常に「各タスクの最新版のみ」= タスク数で上限が決まる
有界集合である。

- 増分フェッチ(`since=lastSync`)は **ピア間のクロックずれに脆弱**。送信側端末の
  `created_at` が受信側の `lastSync` より過去になると relay の `since` フィルタで
  恒久的に除外され、「最初の共有時だけ同期される」という症状を生む。
- addressable event では毎回フルフェッチ(`since=0`)するのが最も堅牢かつ安価。
  取得件数はタスク数で頭打ちになるため、増分にするメリットがそもそも薄い。

教訓: replaceable / addressable kind を扱うときは `since` による増分最適化を
安易に入れない。LWW 集合のフルフェッチで十分なケースが多い。

## 2. Rust x Flutter ブリッジの再発しやすい落とし穴

### 2.1 `client.connect()` はリレー接続完了を待たない

`nostr-sdk 0.37` の `client.connect()` は timeout なしで呼ぶと **接続確立を
ブロックしない**。起動直後に即 `subscribe()` すると全 relay が未接続のため
`NotSubscribed` で失敗する。

対策:
- Rust 側 `MeisoNostrClient::subscribe` に短期リトライ(500ms × 6 回、最大 ~3s)を
  実装。
- Flutter 側 `SomedayScreen` の reconcile では、失敗した購読を「起動済み集合」に
  記録せず次回 reconcile で再試行できるようにする。さらに `nostrInitializedProvider`
  を監視し、初期化完了時に reconcile を再走させる。

### 2.2 ポーリング型購読はバックログを取りこぼす(lossy polling)

Flutter から Rust の `receive_subscription_events` を毎回新しい broadcast receiver
で受ける構造のため、購読確立時点で relay が返す既存イベント(バックログ)や
ポーリング間隙に届いたイベントを **構造的に取りこぼす**。

対策: 購読確立直後に `REQ+EOSE` で確定的に現在状態を取得するフルフェッチ
(`_syncSharedGroupTodos`)を必ず 1 回走らせ、バックログ取得はそちらに委ねる。
リアルタイム購読は「以後の差分通知」専用と割り切る。

### 2.3 d タグからの ID パースで UUID を切り詰めない

招待イベントの `d` タグから `group_id` を抽出する際、`split('-').first` のような
雑なパースで UUID を先頭 8 文字に切り詰めてしまうバグがあった
(`525838f8` vs `525838f8-59a8-...`)。結果として credentials map(full UUID)と
照合できず `No credentials` になり、購読も同期も全滅した。

教訓:
- 末尾固定長(`-<64hex>`)を pivot にして末尾から削る等、フォーマットを明示的に
  検証してパースする。
- 既に壊れたデータが端末に残るため、起動時マイグレーションで full UUID への
  差し替えと重複エントリの dedup を行う(`custom_lists_provider` 参照)。

## 3. UI アンチパターン: ネストしたスクロール領域でホワイトアウト

グループ作成ダイアログで、スクロール可能ウィジェットを入れ子にしたことで
レイアウト制約が解けず画面がホワイトアウト / ANR(`meiso isn't responding`)した。
高さ制約のない `Column` へ置き換えて解消。

教訓: ダイアログ内で複数のスクロール領域を重ねない。制約が定まらない構造は
描画失敗(白画面)につながる。

## 4. ゴーストリスト / 削除フィルタの巻き込み事故

MLS グループの「削除済み ID」フィルタが shared-v1 グループまで巻き込み、作成者側に
リストが 1 つも表示されない事象が発生した。

対策:
- 削除フィルタは MLS グループのみを対象にする。
- 作成 / 招待同期の経路で、対象 group_id が削除済み集合にいたら除去する。

## 5. 共同編集の attribution(`editor_pubkey`)

タスクペイロードに `editor_pubkey`(最後に追加/編集した実 npub の hex)を持たせ、
受信側 `Todo.editorPubkey` に保持する。これにより:

- 自分以外が追加/編集したタスクにアイコンを表示できる。
- タスク詳細で相手の npub を表示できる。

注意:
- 比較は hex 同士(`publicKeyProvider` と `editorPubkey`)で行う。npub 表記と
  混在させない。
- `editor_pubkey` は実 npub であり relay には平文で出る。これは「共有リストの
  メンバー間で誰が編集したか」を見せるための意図的な開示。リスト外の第三者には
  署名者 `G` しか見えないため、ソーシャルグラフ漏洩には当たらない。

## 6. LWW ガードでローカル未同期編集を守る

フルフェッチ / リアルタイム両方の取り込み経路で、ローカルに未同期
(`needsSync=true`)かつより新しい(`updatedAt` が新しい)編集がある場合は relay 版で
上書きしない。フルフェッチは過去イベントも返すため、このガードがないと
オフライン中のローカル編集を巻き戻してしまう。

## 7. 背景同期に shared-v1 を含め忘れない

`syncAllGroupTodos` は当初 MLS(`kind:445`)経路しか回しておらず、shared-v1 が
バックグラウンド / 起動時同期から漏れていた。`_syncAllSharedGroupTodos` を追加し、
受諾済み shared-v1 グループを必ずフルフェッチ同期する。

## 8. 既知の制約(1.4.0 時点)

### 8.1 鍵ローテーション(メンバー除外)は未実装

shared-v1 は「グループ秘密鍵 `nsec_G` を全メンバーで共有する」方式のため、
一度 `nsec_G` を受け取ったメンバーを後から排除する手段がない。除外を実現するには
新しい鍵 `G'` を生成して残メンバーへ再配布し、以後のイベントを `G'` で発行する
「鍵ローテーション」が必要だが、1.4.0 では実装していない。

- 招待ペイロードとタスク認証情報には `key_epoch` フィールドを予約済み
  (現状は常に `0`)。将来のローテーション実装はこのエポックの増分で行う。
- 現状の運用上の含意: メンバーを追放したい場合は新しいグループを作り直す。
- 過去イベントは旧鍵で暗号化されたまま relay に残るため、ローテーションを
  実装しても **過去履歴の秘匿は撤回できない**(forward secrecy はない)。

### 8.2 メンバーの後から追加は鍵再配布なしで可能

逆に「後からメンバーを追加する」操作は、既存の `nsec_G` を新メンバーへ
招待イベント(NIP-44 v2 ギフトラップ)で渡すだけで成立する。新メンバーは承認後の
`since=0` フルフェッチで全履歴を取得できる(`inviteMemberToSharedGroup` 参照)。
