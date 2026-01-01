# [MLS Beta] Phase 8.1-8.5 実装完了とPhase 8.3-8.6 TODO

## 📋 概要

MLS Beta版への移行（Phase 8）の進捗報告と残タスクの整理。

**関連ドキュメント**: `docs/MLS_BETA_ROADMAP.md`

---

## ✅ 完了済み: Phase 8.1-8.2 & Phase 8.5

### Phase 8.1: アプリ内招待システムの完全自動化

#### 8.1.1 Key Package未公開時のUX改善（KeyChatパターン）
- [x] 警告ダイアログ実装
  - 「相手にアプリを起動してもらうと自動的にKey Packageが公開されます」
  - 解決策を明示して、ユーザーが次に何をすべきか理解できる
- [x] 視覚的フィードバック
  - ⚠️ オレンジ警告アイコン（KeyChatと同じパターン）
  - 一目で状態がわかる
- [x] リトライ機能
  - 再試行ボタンで即座にKey Package再取得
  - UIから直接操作可能
- [x] グループ作成時の検証ロジック
  - 警告メンバーを除外して作成
  - 全員が警告状態の場合は作成不可
  - 一部が警告の場合は確認ダイアログ表示
- [x] メンバーリストUIの改善
  - 警告状態を明示（サブタイトルに「Key Package未公開」）
  - 再試行ボタンをメンバーごとに配置

**影響**: Key Packageが見つからない場合でも、ユーザーが次のアクションを理解し、スムーズに対処できるようになった。

#### 8.1.2 招待通知の自動同期
- [x] バックグラウンド定期同期（5分ごとのタイマー）
  - `customListsProvider`に`Timer`を追加
  - アプリ起動中は定期的に招待をチェック
- [x] フォアグラウンド復帰時の自動同期
  - `app_lifecycle_provider`に統合
  - バックグラウンドから復帰した時に招待を自動取得
- [x] アプリ起動時の同期（既存）

**影響**: Pull-to-refreshしなくても招待が自動的に表示されるようになった。

---

### Phase 8.2: エラーハンドリングと安定性

#### 8.2.1 エラーハンドリングの統一
- [x] `ErrorHandler`ユーティリティクラス作成
  - エラーカテゴリ分類（Network/MLS/Nostr/Storage/Auth）
  - 技術的メッセージとユーザーメッセージの分離
- [x] リトライロジック実装
  - 指数バックオフ（1秒 → 2秒 → 4秒...）
  - リトライ可能なエラーのみ再試行
  - 最大試行回数設定可能
- [x] タイムアウト処理実装
  - `withTimeout()`ヘルパー関数
  - デフォルト値でグレースフルデグラデーション

**実装箇所**:
- `lib/utils/error_handler.dart`: 新規作成
- `lib/providers/nostr_provider.dart`: `fetchKeyPackageByNpub()`にリトライ+タイムアウト適用
- `lib/providers/custom_lists_provider.dart`: `createMlsGroupList()`にエラーハンドリング統合

#### 8.2.2 ユーザー向けエラーメッセージ改善
- [x] わかりやすいユーザーメッセージ
  - 技術用語を避けた平易な表現
  - 解決策を含む
- [x] エラーカテゴリごとのメッセージ
  - ネットワークエラー: 「ネットワーク接続を確認してください」
  - NoMatchingKeyPackage: 「メンバーのKey Packageが見つかりません。相手にアプリを起動してもらってください」
  - PendingCommit: 「処理中です。しばらくお待ちください」

#### 8.2.3 オフライン対応
- [x] ネットワークエラーの検出
- [x] タイムアウト処理によるハングの防止
- [x] 接続回復時の自動復旧（リトライロジック）

#### 8.2.4 MLS固有エラーの自動復旧ロジック
- [x] `NoMatchingKeyPackage`、`PendingCommit`等の分類
- [x] リトライ可能なエラーの判定
- [x] 適切なユーザーガイダンス

**影響**: エラー発生時にユーザーが何をすべきか明確になり、自動復旧により手動介入が減少。

---

### Phase 8.5: パフォーマンス最適化

#### 問題点
- 初回起動時の同期処理が逐次実行で、大量のリストがあると端末が重くなる
- AppSettings → カスタムリスト → グループリスト → TODO → グループタスクと順番に実行
- 各処理で10秒のタイムアウト → 全体で50秒以上かかることがある

#### 8.5.1 並列同期処理
- [x] AppSettings同期 + カスタムリスト名抽出を並列実行（`Future.wait()`）
- [x] 独立した処理を同時実行してレイテンシを削減
- [x] `_fetchEncryptedEventsForListNames()`ヘルパー関数

#### 8.5.2 タイムアウト最適化
- [x] タイムアウトを10秒→5秒に短縮
- [x] 早期終了でレスポンス改善

#### 8.5.3 優先度付き同期
- [x] **Phase 1 (並列、優先)**: AppSettings + カスタムリスト名抽出
- [x] **Phase 2**: カスタムリスト同期
- [x] **Phase 3**: TODO同期（メイン処理）
- [x] **Phase 4 (バックグラウンド、並列)**: グループリスト + グループタスク同期
- [x] `_syncGroupDataInBackground()`ヘルパー関数
- [x] メイン同期完了後、UIをブロックせずにグループ系を非同期実行

#### 期待される効果

| 項目 | 従来 | 最適化後 | 改善率 |
|------|------|---------|--------|
| AppSettings + カスタムリスト名 | 逐次実行（20秒） | 並列実行（10秒） | **50%短縮** |
| メイン同期完了 | 50秒+ | 25秒前後 | **50%短縮** |
| UIブロック | 全体完了まで | メイン同期のみ | **大幅改善** |
| グループ系同期 | UIブロック | バックグラウンド | **UX改善** |

**影響**: 
- ✅ 初回起動時の同期時間が大幅短縮（並列化により最大50%削減）
- ✅ UIのブロッキングを最小化（グループ系はバックグラウンド）
- ✅ ユーザー体験が大幅に改善
- ⚠️ グループ系データの同期は若干遅延する（バックグラウンド実行のため）
  - ※ ユーザーにとっては優先度が低いデータなので問題なし

---

## 📝 残タスク: Phase 8.3-8.7

### Phase 8.3: TODO送受信機能の完全実装

**現状**: グループ参加までは成功、TODO共有は未実装

**Beta版要件**:
1. **MLSグループでのTODO暗号化送信**
   - [ ] グループリスト内でTODO作成
   - [ ] 自動的にMLS暗号化
   - [ ] listen_key（Export Secret）で送信
   
2. **MLSグループからのTODO受信**
   - [ ] リレーから暗号化TODO取得
   - [ ] MLS復号化
   - [ ] ローカルDB保存
   - [ ] リアルタイム表示
   
3. **同期ロジック**
   - [ ] バックグラウンド自動同期
   - [ ] 楽観的UI更新
   - [ ] 競合解決

**実装タスク**:
- [ ] `TodosNotifier.addTodo()`でグループ判定
- [ ] MLS暗号化送信フロー統合
- [ ] listen_key購読ロジック実装
- [ ] MLS復号化 → ローカル保存
- [ ] リアルタイム同期

---

### Phase 8.4: グループリストの統合

**現状**:
- **MLSグループ**: 新実装、招待システム有り
- **kind: 30001グループ**: 旧実装（fiatjaf方式）、pタグ管理
- **個人カスタムリスト**: ローカルストレージ管理（影響なし）

**課題**:
- 2つの異なるグループシステムが共存（MLS vs kind: 30001）
- 検証スクリプトで確認されたkind: 30001グループが同期されない
- ユーザー体験が一貫していない

**重要**: kind: 30001廃止の影響範囲
- ✅ **影響なし**: 個人カスタムリスト（BRAIN DUMP, GROCERY等）
  - 現状: ローカルストレージ管理
  - 将来: Phase 9以降でNostr同期を検討
- ✅ **影響なし**: 個人TODO（Kind 30078で管理）
- ❌ **廃止対象**: グループリストの旧実装（fiatjaf方式）のみ

**Beta版要件**:
1. **統一されたグループ体験**
   - [ ] すべてのグループがMLS招待システムを使用
   - [ ] kind: 30001は廃止（または互換性レイヤー実装）
   
2. **グループ種別の判定**
   - [ ] `CustomList.isGroup = true` → MLSグループ
   - [ ] `CustomList.groupMembers` → メンバーリスト
   
3. **既存グループのマイグレーション**
   - [ ] 旧kind: 30001グループをMLSに移行
   - [ ] またはkind: 30001を読み取り専用で表示

**実装タスク**:
- [ ] MLSグループをデフォルトに設定
- [ ] kind: 30001グループの同期ロジック削除/無効化
- [ ] 既存グループの扱いを決定
  - Option A: MLSに自動マイグレーション
  - Option B: 読み取り専用として表示
  - Option C: 互換性レイヤー実装（複雑、非推奨）

**注意**: 
- 現在はPoC段階のため、kind: 30001ユーザーはいない
- 急ぐ必要なし、Phase 8の最後で問題なし

---

### Phase 8.6: テストとドキュメント

**Beta版要件**:
1. **統合テスト**
   - [ ] 3人以上のグループテスト
   - [ ] マルチデバイス同期テスト
   - [ ] ストレステスト（大量TODO）
   
2. **ユーザードキュメント**
   - [ ] グループリスト作成方法
   - [ ] 招待の受け方
   - [ ] トラブルシューティング
   
3. **開発者ドキュメント**
   - [ ] MLSアーキテクチャ説明
   - [ ] API仕様
   - [ ] デバッグ方法

---

### Phase 8.7: 既知のバグ修正

**優先度**: Critical（Beta版リリースブロッカー）

#### Bug #1: 招待承諾後も招待マークが再表示される

**発見日**: 2026-01-01  
**ステータス**: 🔴 未修正

**症状**:
1. Alice → Bob へMLSグループリストを共有
2. Bob が招待を承諾し、グループリストに入れる
3. Bob がアプリを終了し、再度起動
4. **承諾済みのはずのグループリストに再度招待マーク（🔔）が表示される**
5. 招待マークが表示されたグループに再度入ることができない

**影響範囲**:
- ✅ 送信処理: 正常（`Successful relays: 2` 確認済み）
- ✅ リレーへのイベント保存: 正常（`nak req -k 445 --tag h=<groupId>` で確認済み）
- ❌ **CustomListsProviderの状態管理**: 異常
  - アプリ再起動後、`CustomList.isPendingInvitation` が再び `true` になる
  - `CustomList.isGroup` が正しく保存/復元されていない可能性
  - `groupMembers` が空になっている可能性

**根本原因（推測）**:
1. **ローカルストレージへの保存タイミングが不適切**
   - 招待承諾時に `CustomList` を更新しているが、ローカルストレージに保存されていない
   - または、保存されているが復元時に上書きされている

2. **`updateList()` の race condition**（既知の問題、修正済み）
   - 以前は `state.whenData()` を使用していたため、`AsyncLoading` 状態時に更新がスキップされていた
   - 修正: `state.valueOrNull` を使用するように変更（2026-01-01）
   - ただし、この修正後も問題が継続している可能性

3. **`syncGroupInvitations()` との競合**
   - アプリ起動時に `syncGroupInvitations()` が実行される
   - 招待情報をリレーから再取得し、既存の `CustomList` を上書きしている可能性
   - Welcome メッセージ（招待情報）がリレーに残っているため、毎回「未承諾」状態として認識される

**修正方針**:

##### Option A: 承諾状態をローカルに永続化（推奨）
```dart
// CustomList に acceptedAt フィールドを追加
class CustomList {
  ...
  final DateTime? acceptedAt; // 招待を承諾した日時
}

// syncGroupInvitations() で承諾済みを判定
if (existingList != null && existingList.acceptedAt != null) {
  // 既に承諾済み → 招待情報を無視
  continue;
}
```

**利点**:
- シンプルで理解しやすい
- ローカルストレージに承諾状態を保存
- リレーから取得した招待情報と照合可能

**欠点**:
- マイグレーション必要（既存の `CustomList` に `acceptedAt` 追加）

##### Option B: 承諾済み招待をリレーから削除
```dart
// 招待承諾時に Welcome メッセージを削除（Kind 5 イベント送信）
await rust_api.deleteEvent(welcomeEventId);
```

**利点**:
- リレーに不要なデータが残らない
- `syncGroupInvitations()` で自動的に承諾済みが除外される

**欠点**:
- NIP-17 Gift Wrap の削除は非標準的
- リレーが削除をサポートしていない可能性
- マルチデバイス同期時に問題が発生する可能性

##### Option C: MLS Group State で判定
```rust
// Rust側で MLS グループの状態を確認
pub fn is_mls_group_member(group_id: String) -> Result<bool> {
    // グループに参加済みかどうかを判定
}
```

```dart
// Flutter側で判定
final isMember = await rust_api.isMlsGroupMember(groupId: groupId);
if (isMember) {
  // 既にメンバー → 招待情報を無視
}
```

**利点**:
- MLS内部状態が真実の情報源（Single Source of Truth）
- マイグレーション不要

**欠点**:
- Rustとのやり取りが増える（パフォーマンス）
- MLS状態とFlutter側の状態が一致しない場合に複雑化

**推奨**: **Option A（acceptedAt フィールド追加）**
- 最もシンプルで確実
- マイグレーションは1回で済む
- 将来的に「招待履歴」機能にも活用可能

**実装タスク**:
- [ ] `CustomList` に `acceptedAt: DateTime?` フィールドを追加
- [ ] `CustomList.toJson()` / `fromJson()` に `acceptedAt` を追加
- [ ] `_acceptGroupInvitation()` で `acceptedAt: DateTime.now()` を設定
- [ ] `syncGroupInvitations()` で `acceptedAt != null` の場合はスキップ
- [ ] 既存データのマイグレーション処理（`acceptedAt` が `null` の場合、`isGroup && !isPendingInvitation` なら現在時刻を設定）
- [ ] テスト: 招待承諾 → アプリ再起動 → 招待マークが表示されないことを確認

**テストシナリオ**:
1. Alice → Bob へグループ招待
2. Bob が招待を承諾
3. Bob がアプリを終了
4. Bob が再度アプリを起動
5. ✅ グループリストに招待マークが表示されない
6. ✅ グループリストに入れる
7. ✅ グループ内のTODOが同期されている

---

#### Bug #2: MLSグループが CustomListsProvider に登録されない

**発見日**: 2026-01-01  
**ステータス**: 🔴 未修正（Bug #1 と同根の可能性）

**症状**:
- Alice側のログ: `📭 [MLS] No MLS groups to sync`
- `CustomListsProvider` に `isGroup: true` のリストが1つも存在しない
- グループ招待を承諾したはずなのに、バッチ同期でスキップされる

**根本原因**:
- Bug #1 と同じ原因の可能性が高い
- `syncGroupInvitations()` で招待情報が上書きされ、`isGroup` フラグが失われている

**修正方針**:
- Bug #1 の修正（Option A）で同時に解決されるはず
- テストで確認が必要

**実装タスク**:
- [ ] Bug #1 修正後、`isGroup` フラグが正しく保持されるか確認
- [ ] `_syncAllMlsGroupTodos()` でグループが正しく検出されるか確認
- [ ] ログに `🔐 [MLS] Syncing MLS group: <groupId>` が出力されることを確認

---

#### Bug #3: `since` フィルタが新しすぎて過去のイベントを取得できない（修正済み）

**発見日**: 2026-01-01  
**ステータス**: ✅ 修正完了

**症状**:
- Alice側で `since: 1767255574` (17:19:34) でフィルタ
- しかし、Bob のイベントは `created_at: 1767254774` (17:06:14) と `created_at: 1767255299` (17:14:59)
- → フィルタで除外され、0 events になっていた

**修正内容**:
```dart
// Phase 8.3 Fix: 初回同期時は since:0 で全イベントを取得
final effectiveSince = last != null
    ? last.subtract(const Duration(minutes: 2))
    : DateTime.fromMillisecondsSinceEpoch(0);
```

**テスト**:
- ✅ 初回同期時に `since: 0` が使われることを確認
- ✅ nakで確認されたイベントがFlutterでも取得できることを確認

---

## 🎯 Phase 8完了条件

### 必須要件（Must Have）
- ✅ 通常のグループリスト作成フローからMLS招待が使える
- ✅ Key Package自動管理（手動操作不要）
- ⏳ TODO送受信が完全に動作（Phase 8.3）
- ⏳ MLSグループとkind: 30001の統合/廃止完了（Phase 8.4）
- ✅ エラーハンドリング完備
- ⏳ 3人グループでの動作確認（Phase 8.6）
- 🔴 **既知のバグ修正完了（Phase 8.7）** ← **Beta版リリースブロッカー**
  - 🔴 Bug #1: 招待承諾後も招待マークが再表示される
  - 🔴 Bug #2: MLSグループが CustomListsProvider に登録されない

### 推奨要件（Should Have）
- ✅ バックグラウンド同期
- ✅ オフライン対応
- ✅ パフォーマンス最適化
- ⏳ ユーザードキュメント（Phase 8.6）

---

## 🗓️ タイムライン（推定）

### 🔥 Priority 0: 既知のバグ修正（Phase 8.7） - **即時対応**
- **Day 1** (2026-01-02):
  - Bug #1 修正（`acceptedAt` フィールド追加）
  - マイグレーション実装
  - 実機テスト（Alice ↔ Bob）
- **影響**: Phase 8.3 の TODO送受信実装はこの修正後に実施

### Week 1: TODO送受信実装（Phase 8.3）
- Day 2-4: 暗号化送信フロー
- Day 5-6: 復号化受信フロー
- Day 7: 同期ロジック実装

### Week 2: 統合と最適化（Phase 8.4, 8.6）
- Day 1-2: グループリスト統合（kind: 30001廃止）
- Day 3-7: 統合テストとドキュメント

---

## 📊 コミット履歴

### Phase 8.1-8.2
```
commit d51b3a8 - unfix: Phase 8.1-8.2 implementation (MLS Beta)
5 files changed, 648 insertions(+), 241 deletions(-)
```

**変更ファイル**:
- `lib/widgets/add_group_list_dialog.dart`: KeyChatパターンのUX実装
- `lib/providers/custom_lists_provider.dart`: 自動同期タイマー追加、エラーハンドリング強化
- `lib/providers/app_lifecycle_provider.dart`: フォアグラウンド復帰時の招待同期追加
- `lib/utils/error_handler.dart`: 新規作成（エラーハンドリングユーティリティ）
- `lib/providers/nostr_provider.dart`: リトライ+タイムアウト対応

### Phase 8.5
```
commit 2e9cbc4 - fix: Phase 8.5 performance optimization
1 file changed, 123 insertions(+), 47 deletions(-)
```

**変更ファイル**:
- `lib/providers/todos_provider.dart`: 並列同期、タイムアウト短縮、バックグラウンド同期実装

### Phase 8.7 調査・修正（進行中）
```
commit xxx - unfix: Phase 8.7 Bug investigation and documentation
Date: 2026-01-01
Status: 調査中 → 修正計画作成完了
```

**調査内容**:
- MLS グループ TODO 送受信機能のデバッグ
- Bob → Alice へのTODO送信は成功（`Successful relays: 2`、nakで確認済み）
- Alice側で受信できない原因を調査
- **根本原因判明**: 招待承諾後も招待マークが再表示される（Bug #1）
- CustomListsProvider に MLSグループが登録されていないため、同期がスキップされる

**変更ファイル**:
- `lib/providers/todos_provider.dart`: 
  - `since` フィルタ修正（初回同期時は `since: 0`）
  - グループTODO送信時の `needsSync: true` 追加
  - バッチ同期でのグループTODO処理追加
  - ローカルストレージ保存追加
- `lib/providers/custom_lists_provider.dart`:
  - `updateList()` の race condition 修正（`state.whenData()` → `state.valueOrNull`）
- `lib/features/todo/application/usecases/create_todo_usecase.dart`:
  - `needsSync: true` 追加
- `lib/providers/nostr_provider.dart`:
  - 送信結果の詳細ログ追加（`successfulRelays`, `failedRelays`）

**次のステップ**:
- Bug #1 の修正実装（`acceptedAt` フィールド追加）

---

## 🧪 テスト計画

### 優先度: Critical（Bug修正検証）
0. [ ] **Bug #1 修正検証テスト**
   - Alice → Bob へグループ招待送信
   - Bob が招待を承諾
   - Bob がアプリを終了
   - Bob が再度アプリを起動
   - ✅ グループリストに招待マークが表示されない
   - ✅ グループリストに入れる
   - ✅ CustomListsProvider に `isGroup: true` のリストが存在する
   - ✅ `📭 [MLS] No MLS groups to sync` が表示されない

### 優先度: High
1. [ ] 実デバイスでの初回起動パフォーマンステスト
   - 大量のカスタムリスト（10個以上）がある状態
   - 起動時間を計測
   - グループリストがバックグラウンドで表示されることを確認
   
2. [ ] Key Package未公開時のUXテスト
   - Bob側でKey Packageを未公開のまま、Aliceがグループ作成を試行
   - 警告ダイアログが表示されることを確認
   - リトライ機能が動作することを確認
   
3. [ ] 招待通知の自動同期テスト
   - Alice → Bob に招待送信
   - Bob側で5分以内に自動的に招待が表示されることを確認
   - フォアグラウンド復帰時に招待が取得されることを確認

### 優先度: Medium
4. [ ] エラーハンドリングのストレステスト
   - ネットワークを切断した状態でグループ作成
   - リトライロジックが動作することを確認
   - タイムアウトでハングしないことを確認

---

## 🔗 関連Issue・PR

- 関連ドキュメント: `docs/MLS_BETA_ROADMAP.md`
- 実装戦略: `docs/MLS_IMPLEMENTATION_STRATEGY.md`

---

## 📌 備考

### パフォーマンス最適化の注意点
- グループリスト・グループタスクの同期は若干遅延する（バックグラウンド実行のため）
- ただし、ユーザーにとって優先度が低いデータなので、UX上は問題なし
- 実デバイスでの動作確認で体感速度を評価する必要がある

### 次のPhaseへの移行判断
- Phase 8.3-8.4の実装前に、Phase 8.1-8.2+8.5の実デバイステストを推奨
- 基本的なグループリスト作成・招待フローが安定してから、TODO送受信機能を実装する方が安全

