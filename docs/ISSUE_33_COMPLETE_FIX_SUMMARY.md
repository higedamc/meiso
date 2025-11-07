# Issue #33 完全修正サマリー

## 発見された問題点

Issue #33の調査中に、以下の追加問題が発見されました：

### 1. カスタムリスト同期問題（Issue #33本体）✅ 修正完了

**問題**: 
- 2byte文字（日本語）でリストIDが空になる
- 新デバイスで初回ログイン時に既存カスタムリストが同期されない

**修正内容**:
- 入力バリデーション追加（英数字・スペース・ハイフンのみ）
- CustomListsProvider._initialize()でNostr同期を優先
- 同期後にリストが空の場合のみデフォルトリスト作成

### 2. TodosProviderの初期化問題 ❌ **要修正**

**問題**:
```dart
// 現在の実装
_initialize() {
  1. ローカルストレージから読み込み → 即座に表示
  2. _backgroundSync() → 1秒遅延 → Nostr同期
}
```

**期待される動作**:
- 初回ログイン時（ローカルデータなし）: Nostr同期を優先
- 既存ユーザー: ローカルデータを表示しつつ、バックグラウンド同期

**影響**:
- 新デバイスでログインした際、Nostrに保存されているTodoが表示されるまで1秒以上かかる
- ローカルの古いデータが優先されてしまう

### 3. カスタムリストの順番（order）が同期されない ❌ **要実装**

**問題**:
- カスタムリストはkind: 30001として個別に保存
- しかし、リストの並び順（`order`フィールド）は同期されない
- 新デバイスでは、Nostrから取得した順番（ランダム）で表示される

**現在のkind: 30078（AppSettings）**:
```json
{
  "dark_mode": bool,
  "week_start_day": int,
  "calendar_view": string,
  "notifications_enabled": bool,
  "relays": List<String>,
  "tor_enabled": bool,
  "proxy_url": string,
  "updated_at": string
}
```

**解決策の選択肢**:

#### 案1: kind: 30078に`custom_list_order`フィールドを追加
```json
{
  ...
  "custom_list_order": ["brain-dump", "grocery", "wishlist", "nostr", "work"]
}
```
- メリット: シンプル、既存の仕組みを活用
- デメリット: リスト追加/削除のたびにAppSettings全体を更新

#### 案2: NIP-51のlist metadata（d tag）に順番情報を含める
```json
{
  "kind": 30001,
  "tags": [
    ["d", "meiso-list-brain-dump"],
    ["title", "BRAIN DUMP"],
    ["order", "0"]  // 順番情報を追加
  ]
}
```
- メリット: リストごとに独立して管理
- デメリット: NIP-51の標準的な使い方ではない

#### 案3: 新しいkind: 30078イベント（`meiso-list-order`）を作成
```json
{
  "kind": 30078,
  "tags": [["d", "meiso-list-order"]],
  "content": "<暗号化されたリスト順番JSON>"
}
```
- メリット: AppSettingsとは独立して管理
- デメリット: 追加のイベントが必要

**推奨**: **案1 - kind: 30078に`custom_list_order`を追加**

### 4. リレーリストの初回同期 ⚠️ **要確認**

**問題**:
- `sync_relay_list()`は実装済み
- しかし、**初回ログイン時に自動的に呼ばれていない**

**現在のフロー**:
```
初回ログイン
  ↓
オンボーディング完了
  ↓
main.dartでNostr初期化
  ↓
todosProvider.syncFromNostr() ← ここでAppSettings同期
  ↓
（リレーリストは同期されるが、タイミングが遅い）
```

**期待されるフロー**:
```
初回ログイン
  ↓
オンボーディング完了
  ↓
1. リレーリスト同期（kind: 10002） ← 最優先
  ↓
2. リレーリストでNostr初期化
  ↓
3. AppSettings同期
  ↓
4. Todo/カスタムリスト同期
```

---

## 修正計画

### Priority 1: データ同期の優先順位修正 🔴

1. **TodosProvider._initialize()の修正**
   - ローカルデータがない場合、Nostr同期を待つ
   - CustomListsProviderと同じロジックに統一

2. **初回ログイン時の同期順序の最適化**
   ```
   1. リレーリスト同期（kind: 10002）
   2. AppSettings同期（kind: 30078 - meiso-settings）
   3. カスタムリスト同期（Nostr→ローカル）
   4. Todo同期（kind: 30001 - meiso-list-*）
   ```

### Priority 2: カスタムリストの順番同期 🟡

1. **AppSettingsモデルに`customListOrder`フィールド追加**
   ```dart
   @freezed
   class AppSettings with _$AppSettings {
     const factory AppSettings({
       // 既存フィールド
       required bool darkMode,
       ...
       // 新規フィールド
       @Default([]) List<String> customListOrder,
     }) = _AppSettings;
   }
   ```

2. **CustomListsProviderの修正**
   - `syncListsFromNostr()`で順番も復元
   - `reorderLists()`でAppSettingsも更新

### Priority 3: コードのリファクタリング 🟢

1. **重複コードの削減**
   - Amberモードと通常モードの同期処理を統一
   
2. **エラーハンドリングの改善**
   - タイムアウト処理の一貫性
   
3. **ログの統一**
   - AppLoggerの使用を徹底

---

## 実装の影響範囲

### 変更が必要なファイル

1. **lib/models/app_settings.dart** - customListOrder追加
2. **lib/providers/todos_provider.dart** - 初期化ロジック修正
3. **lib/providers/custom_lists_provider.dart** - 順番同期追加
4. **lib/providers/app_settings_provider.dart** - customListOrder対応
5. **rust/src/api.rs** - AppSettings構造体更新

### 影響を受ける機能

- ✅ 初回ログイン（新規デバイス）
- ✅ マルチデバイス同期
- ✅ カスタムリストの並び替え
- ⚠️ 既存ユーザーのマイグレーション（customListOrderがnullの場合の処理）

---

## テストシナリオ

### シナリオ1: 完全に新規のアカウント

1. 新規アカウント作成
2. デフォルトリスト（BRAIN DUMP等）が表示される
3. リスト順番を並び替える
4. 別デバイスでログイン
5. **期待**: 並び替えた順番で表示される

### シナリオ2: 既存アカウントで新デバイスログイン

1. デバイスAでカスタムリスト作成 + 並び替え
2. デバイスBでログイン
3. **期待**: 同じ順番でカスタムリストが表示される

### シナリオ3: リレーリストのカスタマイズ

1. デバイスAでリレーリストをカスタマイズ
2. デバイスBでログイン
3. **期待**: カスタマイズしたリレーリストが自動適用される

---

## 次のステップ

1. ✅ Issue #33の修正（カスタムリスト同期） - **完了**
2. ⏳ TodosProviderの初期化ロジック修正 - **実装中**
3. ⏳ カスタムリストの順番同期実装 - **実装中**
4. ⏳ 初回ログイン時の同期順序最適化 - **実装中**
5. ⏳ リファクタリング - **実装中**
6. ⏳ ドキュメント更新 - **実装中**

---

## 関連ドキュメント

- [ISSUE_33_CUSTOM_LIST_NAME_FIX.md](./ISSUE_33_CUSTOM_LIST_NAME_FIX.md)
- [ISSUE_33_CUSTOM_LIST_NAME_FIX_PART2.md](./ISSUE_33_CUSTOM_LIST_NAME_FIX_PART2.md)
- [NIP78_APP_SETTINGS_IMPLEMENTATION.md](./NIP78_APP_SETTINGS_IMPLEMENTATION.md)
- [RELAY_LIST_SYNC_IMPLEMENTATION.md](./RELAY_LIST_SYNC_IMPLEMENTATION.md)

