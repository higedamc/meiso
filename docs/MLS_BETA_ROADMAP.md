# Meiso MLS Beta Roadmap: PoC → Beta版への移行計画

## 📋 データ構造の整理

### 現在のアーキテクチャ

1. **個人TODO（日付ベース）**
   - **Nostr**: Kind 30078（NIP-44暗号化）
   - **用途**: Today/Tomorrow/Somedayのタスク
   - **同期**: ✅ 実装済み

2. **個人カスタムリスト**
   - **ストレージ**: ローカル（Hive）のみ
   - **例**: BRAIN DUMP, GROCERY, WISHLIST, NOSTR, WORK
   - **同期**: ❌ Nostr同期は未実装
   - **影響**: kind: 30001廃止の影響を**受けない**
   - **将来**: Phase 9以降で別Kind（Kind 10030等）での同期を検討

3. **グループリスト**
   - **旧実装**: Kind 30001（NIP-51）← **廃止予定**
   - **新実装**: MLS + Kind 30078（NIP-44）
   - **影響**: kind: 30001廃止で旧実装のみが使えなくなる

### kind: 30001廃止の影響範囲

| データ | 影響 | 理由 |
|--------|------|------|
| 個人TODO | ✅ 影響なし | Kind 30078で管理 |
| 個人カスタムリスト | ✅ 影響なし | ローカルストレージ管理 |
| グループリスト（旧） | ❌ 廃止 | fiatjaf方式 → MLSへ移行 |
| グループリスト（新） | ✅ 継続 | MLS実装 |

**結論**: kind: 30001廃止は**グループリストの旧実装のみ**に影響。個人機能は一切影響なし。

---

## 現在の状況（2025-11-11）

### ✅ 完了済み: Option B PoC + Phase 1-7

#### Phase 1-4: MLS基盤 + 2人グループテスト ✅
- Rust側MLS実装（OpenMLS統合）
- Flutter側MLS統合
- MLS統合テストUI
- 2人グループ機能（Key Package生成、グループ作成、TODO暗号化）

#### Phase 5: 実デバイス間での2人グループテスト ✅
- **完了日**: 2025-11-11
- Alice ↔ Bob間でのKey Package交換
- グループ作成・招待受信
- MLSグループ参加成功
- リスト詳細画面への自動遷移

#### Phase 6: アプリ内完結型招待システム ✅
- **6.1**: Key Package公開（Kind 10443）✅
- **6.2**: npubからKey Package自動取得 ✅
- **6.3**: グループ招待通知送信（Kind 30078）✅
- **6.4**: SOMEDAYリスト表示UI（インビテーション対応）✅
- **6.5**: 招待受諾ダイアログ + 自動遷移 ✅

#### Phase 7: Amberモード動作確認 ✅
- 全テストAmberモードで実施
- 実デバイス間での完全動作確認済み

---

## 🎯 Phase 8: Beta版への移行（新定義）

**目的**: PoCから実用レベルのBeta版へ昇格

**期間**: 2-3週間

### 8.1 アプリ内招待システムの完全自動化

**現状**: MLSテストダイアログで手動操作が必要

**Beta版要件**:
1. **通常のグループリスト作成フローへの統合**
   - `AddGroupListDialog`からMLS招待システムを利用
   - npub入力だけでKey Package自動取得
   - Welcome Message自動送信

2. **自動Key Package管理**
   - アプリ起動時にKey Packageを自動公開/更新
   - 有効期限管理（30日ごとに自動更新）
   - バックグラウンド公開

3. **招待フロー改善**
   - Alice: 「グループリスト作成」→ メンバーのnpub入力 → 自動招待
   - Bob: アプリ起動 → 自動で招待表示 → タップして参加

**実装タスク**:
- [x] `CustomListsNotifier.createGroupList()`をMLS対応に拡張
- [x] Key Package自動公開（起動時 + 24時間ごと）
- [x] `AddGroupListDialog`でnpub入力 → KP自動取得
- [x] Welcome Message自動送信（Kind 30078）
- [x] トグルボタンでLegacy/MLS選択可能
- [ ] Key Package未公開時のUX改善（Keychat参考）
- [ ] 招待通知の自動同期（Pull-to-refresh不要に）

**実装済み（2025-11-11）**:
- Phase 8.1完了: AddGroupListDialogからMLS招待統合
- Key Package自動公開（起動時 + 24時間キャッシュ）
- npub入力 → Key Package自動取得 → MLSグループ作成
- Welcome Message自動送信（Amber署名 + Kind 30078）
- Legacy/MLSトグルボタン実装（後方互換性確保）

---

### 8.1.1 Key Package未公開時のUX改善（Keychat参考）

**現状**: Key Package未公開時にエラーメッセージのみ表示

**Keychatの実装パターン**:

```dart
// Keychat: create_group_select_member.dart (200-220行目)
if (user['mlsPK'] == null) {
  return IconButton(
    onPressed: () {
      Get.dialog(
        CupertinoAlertDialog(
          title: const Text('Not upload MLS keys'),
          content: const Text(
            'Notify your friend to restart the app, 
            and the key will be uploaded automatically.',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: Get.back,
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
    icon: const Icon(Icons.warning, color: Colors.orange),
  );
}
```

**Keychatの優れたUX**:

1. **視覚的フィードバック**: ⚠️ オレンジ警告アイコン
2. **明確な説明**: "MLS keysがアップロードされていない"
3. **解決策提示**: "友達にアプリを再起動してもらう"
4. **自動化を強調**: "自動的にアップロードされる"
5. **グループ作成時検証**: 警告メンバーを除外可能

**Meiso適用案**:

```dart
// AddGroupListDialog改善案

// 1. Key Package取得時の状態保存
if (keyPackage == null) {
  setState(() {
    _mlsMembers.add({
      'npub': npub,
      'keyPackage': null,
      'hasWarning': true, // 警告フラグ
    });
  });
  
  // 2. 警告ダイアログ表示
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('Key Package未公開'),
        ],
      ),
      content: Text(
        '相手にアプリを起動してもらうと、'
        '自動的にKey Packageが公開されます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _fetchKeyPackage(); // リトライ
          },
          child: Text('再試行'),
        ),
      ],
    ),
  );
}

// 3. メンバーリスト表示の改善
ListTile(
  leading: member['hasWarning'] == true
      ? const Icon(Icons.warning, color: Colors.orange)
      : const Icon(Icons.check_circle, color: Colors.green),
  title: Text(shortNpub),
  subtitle: member['hasWarning'] == true
      ? Text(
          'Key Package未公開（グループ作成不可）',
          style: TextStyle(color: Colors.orange, fontSize: 10),
        )
      : null,
  trailing: IconButton(
    icon: member['hasWarning'] == true
        ? const Icon(Icons.info_outline, color: Colors.orange)
        : const Icon(Icons.remove_circle_outline),
    onPressed: member['hasWarning'] == true
        ? () => _showKeyPackageWarning(member)
        : () => _removeMember(index),
  ),
)

// 4. グループ作成時の検証
Future<void> _createGroup() async {
  final hasWarning = _mlsMembers.any((m) => m['hasWarning'] == true);
  
  if (hasWarning) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('一部のメンバーのKey Packageが未公開です'),
        content: Text(
          'Key Packageが未公開のメンバーは招待できません。\n'
          'それでもグループを作成しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('作成する'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 警告のあるメンバーを除外
    _mlsMembers.removeWhere((m) => m['hasWarning'] == true);
  }
  
  // グループ作成処理...
}
```

**実装優先度**:

| 機能 | 優先度 | 理由 |
|------|--------|------|
| 警告ダイアログ | 🔥 高 | ユーザーに明確な情報提供 |
| 視覚的アイコン | 🔥 高 | 一目で状態がわかる |
| リトライボタン | 🟡 中 | UX改善 |
| グループ作成時検証 | 🟡 中 | エラー防止 |
| メンバーリスト改善 | 🟢 低 | Nice-to-have |

**実装タスク**:
- [ ] Key Package未公開状態の保存（hasWarningフラグ）
- [ ] 警告ダイアログの実装
- [ ] 視覚的アイコンの追加（オレンジ警告）
- [ ] リトライ機能の実装
- [ ] グループ作成時の検証ロジック
- [ ] メンバーリストUIの改善

**期待される効果**:
- ✅ ユーザーが問題を理解しやすくなる
- ✅ 解決策が明確に提示される
- ✅ エラー防止（警告メンバーを除外）
- ✅ Keychatと同等のUX品質

---

### 8.2 エラーハンドリングと安定性

**現状**: エラー処理が各所に散在、一貫性がない

**Beta版要件**:
1. **ネットワークエラー対応**
   - リレー接続失敗時のフォールバック
   - タイムアウト処理
   - リトライロジック

2. **MLS固有エラー対応**
   - NoMatchingKeyPackage → 再取得フロー
   - PendingCommit → 自動解決
   - 状態不整合 → 自動修復

3. **ユーザーフィードバック**
   - エラーメッセージの分かりやすさ
   - ローディング状態の明確化
   - 成功/失敗の通知

4. **オフライン対応**
   - ローカルデータのフォールバック
   - 接続回復時の自動同期
   - オフライン状態の明示

**実装タスク**:
- [ ] エラーハンドリングの統一（Result型パターン）
- [ ] リトライロジック実装（指数バックオフ）
- [ ] ユーザー向けエラーメッセージ改善
- [ ] オフライン対応（ローカルファースト）
- [ ] MLS固有エラーの自動復旧ロジック

---

### 8.3 TODO送受信機能の完全実装

**現状**: グループ参加までは成功、TODO共有は未実装

**Beta版要件**:
1. **MLSグループでのTODO暗号化送信**
   - グループリスト内でTODO作成
   - 自動的にMLS暗号化
   - listen_key（Export Secret）で送信

2. **MLSグループからのTODO受信**
   - リレーから暗号化TODO取得
   - MLS復号化
   - ローカルDB保存
   - リアルタイム表示

3. **同期ロジック**
   - バックグラウンド自動同期
   - 楽観的UI更新
   - 競合解決

**実装タスク**:
- [ ] `TodosNotifier.addTodo()`でグループ判定
- [ ] MLS暗号化送信フロー統合
- [ ] listen_key購読ロジック実装
- [ ] MLS復号化 → ローカル保存
- [ ] リアルタイム同期

---

### 8.4 グループリストの統合 ✅

**完了日**: 2025-11-11

**実装内容**:

1. **kind: 30001グループ同期の無効化**
   - `CustomListsProvider.syncGroupListsFromNostr()` を `@Deprecated` にマーク
   - 実行時に即座に return して何もしない（パフォーマンス改善）
   - 旧コードはコメントアウトで保持（将来の互換性レイヤー実装時に参照可能）

2. **バックグラウンド同期の修正**
   - `TodosProvider._syncGroupDataInBackground()` から kind: 30001グループ同期を削除
   - グループタスク同期とグループ招待同期のみ実行

3. **AddGroupListDialog の簡素化**
   - Legacy/MLSトグルボタンを削除
   - MLSグループのみの作成に統一
   - `GroupListType` enum は残す（後方互換性のため）
   - Legacy用コード（`_addLegacyMember`, `_legacyMembers` など）を削除

4. **パフォーマンス改善**
   - 40リスト以上のアカウントで kind: 30001全取得によるパフォーマンス問題を解決
   - MLSグループのみの同期により、同期時間が大幅に短縮

**現状**:
- ✅ **MLSグループ**: デフォルトかつ唯一のグループシステム
- ❌ **kind: 30001グループ**: 同期無効化（Rust APIは保持）
- ✅ **個人カスタムリスト**: 影響なし（ローカルストレージ管理）
- ✅ **個人TODO**: 影響なし（Kind 30001で管理）

**重要**: kind: 30001廃止の影響範囲
- ✅ **影響なし**: 個人カスタムリスト（BRAIN DUMP, GROCERY等）
  - 現状: ローカルストレージ管理
  - 将来: Phase 9以降でNostr同期を検討
- ✅ **影響なし**: 個人TODO（Kind 30001で管理）
- ❌ **廃止対象**: グループリストの旧実装（fiatjaf方式）のみ

**実装タスク**:
- [x] MLSグループをデフォルトに設定
- [x] kind: 30001グループの同期ロジック削除/無効化
- [x] AddGroupListDialogをMLSのみに統一
- [x] パフォーマンス問題の解決（40リスト以上）

**将来の対応**:
- Rust側の `fetch_encrypted_group_task_lists_for_pubkey()` は保持
  - 互換性レイヤー実装時に使用可能
  - または完全削除は Phase 9 以降に検討
- 既存 kind: 30001 ユーザーのマイグレーション
  - 現在はPoC段階のためユーザーなし
  - 必要になったら Phase 9 で実装

**期待される効果**:
- ✅ パフォーマンス向上（40リスト以上で顕著）
- ✅ グループ体験の統一（MLSのみ）
- ✅ コード複雑度の削減
- ✅ バグ発生リスクの低減

---

### 8.5 パフォーマンス最適化

**Beta版要件**:
1. **MLS DB最適化**
   - 初期化タイミングの最適化
   - キャッシュ戦略
   - バックグラウンド処理

2. **Key Package管理効率化**
   - 定期更新のバックグラウンド化
   - 不要なKP削除
   - ストレージ圧縮

3. **同期効率化**
   - バッチ処理
   - 差分同期
   - 帯域幅最適化

4. **初回同期UX改善**
   - 同期進捗パーセンテージ表示
   - フェーズ別進捗表示
   - 操作ロック（同期完了まで待機）

**実装タスク**:

#### 8.5.1 同期進捗パーセンテージ表示（優先度: 🔥 最高）✅ 完了
- [x] `SyncStatus`モデルに進捗フィールド追加
  - `totalSteps`: 全体のステップ数
  - `completedSteps`: 完了したステップ数
  - `percentage`: 進捗パーセンテージ (0-100)
  - `currentPhase`: 現在のフェーズ名
- [x] `syncFromNostr()`で進捗を追跡
  - Phase 1開始: 0% ("AppSettings同期中")
  - Phase 1完了: 33% ("カスタムリスト名取得完了")
  - Phase 2完了: 66% ("カスタムリスト同期完了")
  - Phase 3完了: 100% ("TODO同期完了")
- [x] ローディング画面の作成/改善
  - 中央に進捗バーを表示
  - パーセンテージ表示 (例: "同期中... 45%")
  - 現在のフェーズ表示 (例: "カスタムリスト同期中")
  - 背景をブラー/半透明にして操作をブロック
- [x] `main.dart`でローディング画面を表示
  - `SyncStatus.syncing`時にオーバーレイ表示
  - 同期完了後に自動で非表示

**実装完了日**: 2025-11-11

#### 8.5.2 カスタムリスト取得の効率化（優先度: 🔥 高）✅ 完了
- [x] Rust側のクエリ最適化
  - 不要なフィールドを除外（contentの完全取得を避ける）
  - リスト名抽出専用のAPIを実装（`fetch_todo_list_names_only`）
  - タグ（`d`, `title`）のみを取得して軽量化
- [ ] リスト名のキャッシュ実装（将来検討）
  - 短時間キャッシュ（5分）
  - ローカルストレージに保存
  - 差分同期（last_sync_timeから更新分のみ）
- [x] 並列化の改善
  - 既に並列化済み（Phase 1）
  - カスタムリスト名取得が軽量化されたため、パフォーマンス改善

**実装完了日**: 2025-11-11

**効果**:
- 40リスト以上のアカウントで同期時間が大幅に短縮
- contentを取得しないため、ネットワーク帯域とCPU使用量を削減
- タグのみの取得により、メモリ使用量も最適化

#### 8.5.3 MLS DB初期化の遅延ロード（優先度: 🟡 中）
- [ ] MLS DB初期化の遅延ロード
- [ ] Key Package定期更新のバックグラウンド化
- [ ] 同期処理のバッチ化
- [ ] メモリ使用量の最適化

---

### 8.6 テストとドキュメント

**Beta版要件**:
1. **統合テスト**
   - 3人以上のグループテスト
   - マルチデバイス同期テスト
   - ストレステスト（大量TODO）

2. **ユーザードキュメント**
   - グループリスト作成方法
   - 招待の受け方
   - トラブルシューティング

3. **開発者ドキュメント**
   - MLSアーキテクチャ説明
   - API仕様
   - デバッグ方法

**実装タスク**:
- [ ] 3人グループテスト実施
- [ ] マルチデバイステスト
- [ ] ユーザーガイド作成
- [ ] API仕様書作成

---

## 📊 Phase 8完了条件

### 必須要件（Must Have）
- ✅ 通常のグループリスト作成フローからMLS招待が使える
- ✅ Key Package自動管理（手動操作不要）
- [ ] TODO送受信が完全に動作
- ✅ MLSグループとkind: 30001の統合/廃止完了
- [ ] エラーハンドリング完備
- [ ] 3人グループでの動作確認

### 推奨要件（Should Have）
- ✅ バックグラウンド同期
- ✅ オフライン対応
- ✅ パフォーマンス最適化
- ✅ ユーザードキュメント

### 将来検討（Nice to Have）
- ⏸️ Option A移行（完全なKeychat実装移植）
- ⏸️ グループ管理機能（メンバー追加/削除）
- ⏸️ グループ権限管理
- ⏸️ メッセージ履歴管理

---

## 🗓️ タイムライン

### ✅ Week 1: 統合とパフォーマンス改善（8.1, 8.4）完了
- ✅ Day 1-2: `AddGroupListDialog`統合（Phase 8.1完了）
- ✅ Day 3-4: Key Package自動管理（Phase 8.1完了）
- ✅ Day 5: グループリスト統合（kind: 30001廃止、Phase 8.4完了）

### Week 2: TODO送受信実装（8.3）
- Day 1-3: 暗号化送信フロー
- Day 4-5: 復号化受信フロー
- Day 6-7: 同期ロジック実装

### Week 3: エラーハンドリングと最適化（8.2, 8.5, 8.6）
- Day 1-2: エラーハンドリング統一とオフライン対応
- Day 3-4: パフォーマンス最適化
- Day 5-7: 統合テストとドキュメント

---

## 🎯 成功指標

### 技術的指標
- MLSテストダイアログ不要（通常フローで完結）
- Key Package管理が完全自動
- TODO送受信成功率 > 99%
- 平均応答時間 < 2秒

### UX指標
- グループリスト作成が3ステップ以内
- 招待受諾が1タップで完了
- エラー発生時に分かりやすいメッセージ
- オフラインでも基本操作可能

---

## 📝 今後の課題

### Option A移行の判断（Phase 9?）

**移行する場合**:
- メリット: Production Readyな完全実装
- デメリット: 実装コスト高、TODOアプリには過剰？

**現状維持の場合**:
- メリット: シンプル、メンテナンスしやすい
- デメリット: スケーラビリティに制限

**判断基準**:
- ユーザー数（1グループあたり何人？）
- 機能要件（メンバー管理の頻度は？）
- 開発リソース

**推奨**: Phase 8完了後、ユーザーフィードバックを元に判断

---

## 🔐 Phase 9: メタデータプライバシー保護（NIP-17/59 Gift Wrap完全実装）

**目的**: KeyChatレベルのメタデータプライバシー保護を実現

**期間**: 2-3週間

**優先度**: High（Beta版リリース後の最優先事項）

### 📊 現状の問題点

#### 自己評価レポート（2025-11-11）

現在の実装では、以下のメタデータが**リレー運営者やネットワーク監視者に露出**しています:

| データ種別 | Kind | リスクレベル | 露出メタデータ |
|-----------|------|------------|--------------|
| **個人TODO** | 30001 | 🔴 High | 署名者公開鍵、`d`タグ（meiso-todos）、`title`タグ（リスト名）、正確なタイムスタンプ |
| **グループタスク** | 30001 | 🔴 Critical | 署名者公開鍵、`d`タグ、`title`タグ、**全メンバーの公開鍵（pタグ）**、タイムスタンプ |
| **MLS招待** | 1059 | 🟡 Medium | 本物の公開鍵で署名、正確なタイムスタンプ、group_idタグ |

**最も深刻な問題**: グループタスクで**ソーシャルグラフが完全に露出**
```rust
// 現在の実装（rust/src/api.rs:2360-2367）
for member_pubkey in &group_list.members {
    tags.push(Tag::public_key(
        nostr_sdk::PublicKey::from_hex(member_pubkey)?
    ));
}
// → 誰が誰とグループを作っているか、リレー運営者に完全に把握される
```

#### KeyChatとの比較

| 機能 | Meiso（現状） | KeyChat | 差分 |
|-----|--------------|---------|------|
| **送信者の匿名性** | ❌ 本物の公開鍵で署名 | ✅ ランダム鍵で署名 | 送信者が特定不可能に |
| **タイムスタンプ** | ❌ 正確な時刻 | ✅ ±2日ランダム化 | アクティビティ追跡防止 |
| **タグの最小化** | ❌ `d`, `title`, `p`（複数）を露出 | ✅ `p`タグのみ | メタデータ最小化 |
| **二重暗号化** | ⚠️ MLS招待のみ部分実装 | ✅ 全メッセージで実装 | 完全なGift Wrap |

---

### 9.1 個人TODOリストのGift Wrap化

**現状**: Kind 30001で`d`, `title`タグが平文露出

**目標**: NIP-17 Gift Wrap（Kind 1059）へ移行し、メタデータを完全に隠蔽

**実装要件**:

1. **ランダム公開鍵で署名**
   ```rust
   // 一時的な鍵ペアを生成
   let ephemeral_keys = Keys::generate();
   
   // Gift Wrapをランダム鍵で署名
   let event = EventBuilder::new(Kind::Custom(1059), encrypted_content)
       .tags(vec![Tag::public_key(keys.public_key())]) // 自分宛て
       .sign(&ephemeral_keys) // ⚠️ ランダム鍵
       .await?;
   ```

2. **タイムスタンプのランダム化**
   ```rust
   // ±2日（172800秒）ランダム化
   let random_offset = rand::thread_rng().gen_range(-172800..172800);
   let randomized_timestamp = Timestamp::now().as_u64() as i64 + random_offset;
   ```

3. **タグの最小化**
   - `d` タグ: 削除（リスト識別はcontentに含める）
   - `title` タグ: 削除（contentに含める）
   - `p` タグ: 自分の公開鍵のみ（受信用）

4. **二重暗号化**
   - 内側: NIP-44でTODO JSONを暗号化
   - 外側: Gift Wrapでさらに保護
   - メタデータは全てcontentに含める

**実装タスク**:
- [ ] `rust/src/api.rs`: `create_todo_list_giftwrapped()` 実装
- [ ] ランダム鍵生成ロジック
- [ ] タイムスタンプランダム化ユーティリティ
- [ ] Gift Wrap受信・復号化ロジック
- [ ] Kind 30001 → Kind 1059マイグレーション

**期待される効果**:
- ✅ Meisoアプリ使用が特定不可能に
- ✅ リスト名が露出しない
- ✅ 送信者が特定不可能に
- ✅ アクティビティパターンが追跡不可能に

---

### 9.2 グループタスクのGift Wrap完全実装

**現状**: Kind 30001で全メンバーの公開鍵が`p`タグで露出（Critical Risk）

**目標**: MLS + Gift Wrapでソーシャルグラフを完全に隠蔽

**実装要件**:

1. **メンバー公開鍵の完全隠蔽**
   ```rust
   // 改善前（現在）
   for member_pubkey in &group_list.members {
       tags.push(Tag::public_key(...)); // ❌ 全員露出
   }
   
   // 改善後
   // タグは listen_key のみ
   // メンバー情報は MLS暗号化されたcontentに含める
   let event = EventBuilder::new(Kind::Custom(1059), encrypted_content)
       .tags(vec![Tag::public_key(listen_key)]) // ✅ グループ共有鍵のみ
       .sign(&ephemeral_keys)
       .await?;
   ```

2. **Listen Key方式の完全統合**
   - Export SecretからListen Keyを導出
   - 全メンバーが同じListen Keyで受信
   - 個人の公開鍵は露出しない

3. **グループメタデータの暗号化**
   ```rust
   // グループ名、メンバーリストを全てMLS暗号化
   let group_metadata = GroupMetadata {
       group_name: "...",
       members: vec![...],
       created_at: ...,
   };
   let encrypted_metadata = mls_encrypt(group_metadata)?;
   ```

4. **Kind 30001の完全廃止**
   - グループタスクは全てKind 1059で送信
   - 旧Kind 30001イベントは読み取り専用（互換性）
   - 新規作成は全てGift Wrap化

**実装タスク**:
- [ ] `rust/src/group_tasks_mls.rs`: Gift Wrap統合
- [ ] Listen Key購読ロジックの改善
- [ ] メンバー情報の完全暗号化
- [ ] Kind 30001グループの自動マイグレーション
- [ ] ソーシャルグラフ露出の検証テスト

**期待される効果**:
- ✅ **ソーシャルグラフが完全に隠蔽**
- ✅ グループ名が露出しない
- ✅ メンバー数が推測不可能に
- ✅ KeyChatと同等のプライバシー保護

---

### 9.3 Amberモード対応とランダム鍵署名

**課題**: Amberは本物の秘密鍵でしか署名できない（ランダム鍵署名が不可能）

**解決策の検討**:

#### Option A: Amberに機能追加を提案（推奨）

**提案内容**:
```kotlin
// Amber側に新機能追加
SignerType.SIGN_EVENT_WITH_RANDOM_KEY -> {
    val ephemeralKeyPair = randomKeyPair()
    val signedEvent = signEvent(event, ephemeralKeyPair.privKey)
    // ランダム鍵で署名、実際の秘密鍵は使用しない
    signedEvent
}
```

**メリット**:
- ✅ セキュリティとプライバシーの両立
- ✅ 秘密鍵はAmber内に留まる
- ✅ 業界標準（Signal/KeyChat方式）

**デメリット**:
- ⏳ Amber側の実装が必要
- ⏳ リリースまでの時間がかかる可能性

**実装タスク**:
- [ ] Amber開発者にNIP-17/59対応を提案
- [ ] 仕様書・ユースケースを文書化
- [ ] Amber側のPR作成（コントリビューション）

---

#### Option B: ローカルでランダム鍵生成（妥協案）

**実装内容**:
```dart
// Flutter側でランダム鍵を生成して署名
final ephemeralKeys = await rust_api.generateRandomKeypair();
final signedEvent = await rust_api.signEventWithKeys(
  unsignedEvent: event,
  privateKeyHex: ephemeralKeys.privateKey,
);
```

**メリット**:
- ✅ 即座に実装可能
- ✅ Amber側の変更不要

**デメリット**:
- ⚠️ 秘密鍵がFlutter側に一時的に存在（セキュリティリスク）
- ⚠️ Amberの「秘密鍵を持たない」という理念に反する

**セキュリティ対策**:
- ランダム鍵は使い捨て（メモリ上のみ、保存しない）
- 署名後に即座にメモリクリア
- 監査ログで追跡可能に

**実装タスク**:
- [ ] `rust/src/api.rs`: `generate_random_keypair()` 実装
- [ ] `sign_event_with_keys()` 実装（通常の秘密鍵署名とは別）
- [ ] Flutter側でメモリ管理実装
- [ ] セキュリティ監査

---

#### Option C: Amberモードではメタデータリークを許容（非推奨）

**実装内容**:
- Amberモードでは従来通り本物の公開鍵で署名
- 秘密鍵モードのみGift Wrap対応

**メリット**:
- ✅ 実装が簡単

**デメリット**:
- ❌ Amberユーザーのプライバシーが保護されない
- ❌ Amber = 最優先ターゲット（Memory 11028688）に矛盾
- ❌ 二重基準（Amberユーザーが不利）

**推奨しない理由**:
- Meisoの理念「プライバシー最優先」に反する
- Amberユーザーは最もセキュリティ意識が高いユーザー層
- 機能の分断はユーザー体験を損なう

---

### 実装戦略（推奨）

**Phase 9.1-9.2**: Option Bで先行実装（2週間）
- 個人TODOとグループタスクをGift Wrap化
- ローカルランダム鍵で署名（妥協案）
- セキュリティ対策を万全に

**Phase 9.3**: Amberへの提案と移行（並行作業）
- Amber開発者に機能追加を提案
- 仕様書・PR作成
- Amber側の実装が完了したらOption Aに移行

**期間**:
- Phase 9.1-9.2: 2週間（即座に開始可能）
- Phase 9.3: 4-8週間（Amber側の開発期間含む）

---

### 実装タスク一覧

#### Phase 9.1: 個人TODOのGift Wrap化
- [ ] ランダム鍵生成ユーティリティ（Rust）
- [ ] タイムスタンプランダム化ユーティリティ（Rust）
- [ ] `create_todo_list_giftwrapped()` 実装（Rust）
- [ ] Gift Wrap受信・復号化ロジック（Rust）
- [ ] Flutter側統合（`TodosProvider`）
- [ ] マイグレーションスクリプト（Kind 30001 → 1059）
- [ ] 動作確認テスト

#### Phase 9.2: グループタスクのGift Wrap化
- [ ] Listen Key方式の完全統合（Rust）
- [ ] メンバー情報の完全暗号化（Rust）
- [ ] `save_group_task_list_giftwrapped()` 実装（Rust）
- [ ] Kind 30001廃止（グループのみ）
- [ ] Flutter側統合（`CustomListsProvider`）
- [ ] ソーシャルグラフ露出の検証テスト
- [ ] 3人グループでの動作確認

#### Phase 9.3: Amberモード対応
- [ ] Amberへの機能提案文書作成
- [ ] NIP-17/59仕様書の共有
- [ ] Amber側PR作成（コントリビューション）
- [ ] Amber更新後の統合テスト
- [ ] Option B（ローカルランダム鍵）からOption Aへの移行

---

### 検証方法

#### メタデータリークの検証

**テスト環境**:
- リレーログを監視（Citrineローカルリレー）
- Wiresharkでネットワークパケットをキャプチャ
- リレー運営者視点でのメタデータ可視性を評価

**検証項目**:
1. **送信者の匿名性**
   - [ ] イベントの`pubkey`がランダム鍵になっているか
   - [ ] 実際の公開鍵と紐付けられないか

2. **タイムスタンプのランダム化**
   - [ ] `created_at`が±2日の範囲でランダムか
   - [ ] アクティビティパターンが推測できないか

3. **タグの最小化**
   - [ ] `d`, `title`タグが存在しないか
   - [ ] `p`タグが受信者のみか（送信者情報なし）

4. **ソーシャルグラフの隠蔽**
   - [ ] グループメンバーの公開鍵が露出していないか
   - [ ] グループ名が平文で見えないか

5. **暗号化の完全性**
   - [ ] `content`が完全に暗号化されているか
   - [ ] メタデータが`content`に平文で含まれていないか

**合格基準**:
- 全項目で「リレー運営者が読み取れない」ことを確認
- KeyChatと同等のプライバシー保護レベル

---

## 📊 Phase 9完了条件

### 必須要件（Must Have）
- ✅ 個人TODOがGift Wrap（Kind 1059）で送信される
- ✅ グループタスクがGift Wrap化され、メンバー公開鍵が露出しない
- ✅ ランダム鍵署名が実装されている（Option B以上）
- ✅ タイムスタンプがランダム化されている
- ✅ メタデータリーク検証テストに合格

### 推奨要件（Should Have）
- ✅ Amberへの機能提案完了
- ✅ Option A（Amber側実装）への移行パス確保
- ✅ セキュリティ監査完了
- ✅ パフォーマンス影響の評価

### 将来検討（Nice to Have）
- ⏸️ NIP-59（Gift Wrap V2）完全準拠
- ⏸️ Torネットワーク統合（Orbot連携強化）
- ⏸️ リレーローテーション（メタデータ分散）

---

## 🎯 Phase 9完了後の到達点

### プライバシー保護レベル

| 項目 | Phase 8完了後 | Phase 9完了後 | KeyChat |
|-----|--------------|--------------|---------|
| **送信者匿名性** | ❌ 本物の公開鍵 | ✅ ランダム鍵 | ✅ |
| **タイムスタンプ** | ❌ 正確 | ✅ ランダム化 | ✅ |
| **ソーシャルグラフ** | ❌ 露出 | ✅ 完全隠蔽 | ✅ |
| **メタデータ最小化** | ❌ 複数タグ | ✅ `p`タグのみ | ✅ |
| **二重暗号化** | ⚠️ 部分実装 | ✅ 完全実装 | ✅ |

**結論**: Phase 9完了により、MeisoはKeyChatと同等のプライバシー保護を達成

---

## 🎉 まとめ

### PoC → Beta版 → Privacy版への移行

**PoC（Phase 1-7完了後）**:
- ✅ MLSの技術検証完了
- ✅ 2人グループ動作確認
- ✅ 基本的な招待フロー実装

**Beta版（Phase 8完了後）**:
- ✅ 通常フローで使える
- ✅ 手動操作不要
- ✅ TODO送受信完全動作
- ✅ エラーハンドリング完備
- ✅ 実用レベルの安定性
- ⚠️ **メタデータリークあり**

**Privacy版（Phase 9完了後）**:
- ✅ Beta版の全機能
- ✅ **KeyChatレベルのプライバシー保護**
- ✅ ソーシャルグラフ完全隠蔽
- ✅ 送信者匿名性確保
- ✅ メタデータ最小化
- ✅ **真のプライバシーフォーカスアプリ**

**Phase 8完了 = Beta版リリース可能！**

**Phase 9完了 = Privacy版リリース（推奨）！**

