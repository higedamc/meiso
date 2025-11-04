# Issue #21: カスタムリストごとに独立したNostrイベントを作成

## 概要

Issue #21とSub Issue #26の実装により、カスタムリストごとに独立したNostrイベント（Kind 30001）を作成するように改修しました。

## 実装日

2025-11-04

## 要件

### Issue #21

従来はすべてのタスクが単一のリスト（`meiso-todos`）に保存されていましたが、以下のように変更：

1. **通常のタスク（デフォルトリスト）**
   - `customListId` が `null` のタスク
   - Nostrイベント: `d: "meiso-todos"`, `title: "My TODO List"`

2. **カスタムリストのタスク**
   - `customListId` が設定されているタスク
   - Nostrイベント: `d: "meiso-list-{customListId}"`, `title: "{カスタムリスト名}"`

### Sub Issue #26

MOVE TO機能を拡張し、カスタムリストへのタスク移動を可能にしました：

1. **SOMEDAY LIST**サブメニュー
   - Someday (no list) - 日付なし、リストなし
   - カスタムリスト一覧（BRAIN DUMP, GROCERY LIST, TO BUY, NOSTR, WORK など）

2. **Another day**
   - 日付選択による特定日への移動

## 実装詳細

### Rust側の変更

#### 1. リストごとにTodoをグループ化（`rust/src/api.rs`）

新規関数を追加：

```rust
/// Todoをリストごとにグループ化
fn group_todos_by_list(&self, todos: &[TodoData]) -> std::collections::HashMap<String, Vec<TodoData>> {
    use std::collections::HashMap;
    
    let mut grouped: HashMap<String, Vec<TodoData>> = HashMap::new();
    
    for todo in todos {
        let list_key = todo.custom_list_id.as_deref().unwrap_or("default").to_string();
        grouped.entry(list_key).or_insert_with(Vec::new).push(todo.clone());
    }
    
    grouped
}
```

#### 2. `create_todo_list` - リストごとにイベント作成

修正内容：
- Todoをリストごとにグループ化
- 各リストごとに個別のKind 30001イベントを作成・送信
- d tagの形式:
  - デフォルトリスト: `meiso-todos`
  - カスタムリスト: `meiso-list-{customListId}`

#### 3. `sync_todo_list` - すべてのリストから同期

修正内容：
- すべてのKind 30001イベントを取得（`meiso-todos` + `meiso-list-*`）
- 各リストイベントを復号化してTodoを取得
- すべてのTodoをマージして返す

#### 4. Amberモード対応

新規関数を追加：

```rust
/// リスト識別子とタイトル付きで未署名イベントを作成
pub fn create_unsigned_encrypted_todo_list_event_with_list_id(
    encrypted_content: String,
    public_key_hex: String,
    list_id: Option<String>,
    list_title: Option<String>,
) -> Result<String>

/// すべてのTodoリストを取得
pub fn fetch_all_encrypted_todo_lists_for_pubkey(
    public_key_hex: String,
) -> Result<Vec<EncryptedTodoListEvent>>
```

`EncryptedTodoListEvent`構造体に`list_id`フィールドを追加。

### Flutter側の変更

#### 1. NostrProvider（`lib/providers/nostr_provider.dart`）

新規メソッドを追加：

```dart
/// Amberモード: リスト識別子とタイトル付きで未署名イベントを作成
Future<String> createUnsignedEncryptedTodoListEvent({
  required String encryptedContent,
  String? listId,
  String? listTitle,
})

/// Amberモード: すべての暗号化されたTodoリストを取得
Future<List<rust_api.EncryptedTodoListEvent>> fetchAllEncryptedTodoLists()
```

#### 2. TodosProvider（`lib/providers/todos_provider.dart`）

**送信時の修正（`_syncAllTodosToNostr`）:**
- Todoをリストごとにグループ化
- カスタムリスト情報を取得してリストタイトルを設定
- 各リストごとに暗号化・署名・送信のループ処理

**受信時の修正（`syncFromNostr`）:**
- `fetchAllEncryptedTodoLists()`ですべてのリストを取得
- 各リストを復号化してTodoを取得
- すべてのTodoをマージして状態を更新

#### 3. MOVE TO機能の拡張（`lib/widgets/todo_edit_screen.dart`）

新規メソッドを追加：

```dart
/// SOMEDAY LISTのサブメニューを表示
Future<void> _showSomedayListDialog()

/// Todoを指定した日付とカスタムリストに移動
void _moveToDateAndList(DateTime? targetDate, String? customListId, [String? customListName])
```

MOVE TOダイアログを更新：
- "SOMEDAY" → "SOMEDAY LIST" に変更（サブメニュー付き）
- "Pick a date..." → "Another day" に変更
- chevron_rightアイコンを追加

SOMEDAY LISTサブメニュー：
- Someday (no list) - 日付なし、リストなし
- カスタムリスト一覧の動的表示

## Nostrイベント構造

### デフォルトリスト

```json
{
  "kind": 30001,
  "content": "<NIP-44暗号化されたTodoリストJSON>",
  "tags": [
    ["d", "meiso-todos"],
    ["title", "My TODO List"]
  ]
}
```

### カスタムリスト

```json
{
  "kind": 30001,
  "content": "<NIP-44暗号化されたTodoリストJSON>",
  "tags": [
    ["d", "meiso-list-{customListId}"],
    ["title", "{カスタムリスト名}"]
  ]
}
```

## マイグレーション

### 自動マイグレーション

特別なマイグレーション処理は不要です。理由：

1. 既存のデータは単一リスト（`meiso-todos`）に保存されている
2. 新しい実装では、`customListId`フィールドに基づいて自動的にリストごとに分割される
3. 次回の同期時に、複数のリストとして自動的に保存される

### データの流れ

```
既存データ (meiso-todos):
  - Todo A (customListId: null)
  - Todo B (customListId: "list-1")
  - Todo C (customListId: "list-2")

↓ 新しい実装で同期

新しいイベント:
  - meiso-todos: [Todo A]
  - meiso-list-list-1: [Todo B]
  - meiso-list-list-2: [Todo C]
```

## テスト

### 手動テスト項目

1. **デフォルトリストの動作確認**
   - [ ] 通常のタスク作成（customListIdなし）
   - [ ] デフォルトリストに保存されることを確認
   - [ ] 同期後もデータが保持されることを確認

2. **カスタムリストの動作確認**
   - [ ] カスタムリスト（BRAIN DUMP等）にタスク作成
   - [ ] 独立したイベントとして保存されることを確認
   - [ ] 各リストが個別に同期されることを確認

3. **MOVE TO機能の確認**
   - [ ] MOVE TO → SOMEDAY LIST → Someday (no list)
   - [ ] MOVE TO → SOMEDAY LIST → BRAIN DUMP
   - [ ] MOVE TO → Another day → 特定日選択

4. **マルチデバイス同期**
   - [ ] デバイスAでカスタムリストにタスク追加
   - [ ] デバイスBで同期して、正しいリストに表示されることを確認

## 影響範囲

### 変更されたファイル

- `rust/src/api.rs` - リストごとの送信・取得機能
- `lib/providers/nostr_provider.dart` - Amberモード対応
- `lib/widgets/todo_edit_screen.dart` - MOVE TO機能拡張

### 変更されなかったファイル

- `lib/providers/todos_provider.dart` - 既存のAPIで動作
- `lib/models/todo.dart` - customListIdフィールドは既存
- `lib/models/custom_list.dart` - 変更なし

## 今後の拡張

### 可能な改善点

1. **リストのタイトル管理**
   - 現在、Rust側で `"Custom List {id}"` として固定
   - Flutter側からリスト名を渡して、より正確なタイトルを設定

2. **リスト削除時の処理**
   - カスタムリスト削除時、関連するタスクの処理
   - オプション: デフォルトリストに移動 or 削除

3. **リストのマージ**
   - 複数リストを1つに統合する機能

## 関連Issue

- Issue #21: デフォルトのリストは meiso-todos として作成されているが、カスタムリストの場合は、それぞれ独立したリストが存在するべきではないか？
- Sub Issue #26: MOVE TO → の動的なリスト表示

## 参考資料

- [NIP-51: Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [NIP-44: Encrypted Payloads](https://github.com/nostr-protocol/nips/blob/master/44.md)
- [Kind 30001: Bookmark Lists](https://github.com/nostr-protocol/nips/blob/master/51.md#standard-lists)

## 修正履歴

### 2025-11-04: リストIDミスマッチ問題を解決（カスタムリストの同期）

**問題:** Nostrから同期されたカスタムリストのIDと、ローカルのCustomListsProviderが管理するIDが一致せず、Todoが表示されない。

**修正:**
1. **Rust側** (`rust/src/api.rs`):
   - `EncryptedTodoListEvent`に`title`フィールドを追加
   - `fetch_all_encrypted_todo_lists_for_pubkey_with_client_id`でイベントから`title`タグも取得

2. **CustomListsProvider** (`lib/providers/custom_lists_provider.dart`):
   - 新規メソッド`syncListsFromNostr`を追加
   - Nostrから取得したカスタムリスト情報（IDと名前）をローカルに同期

3. **TodosProvider** (`lib/providers/todos_provider.dart`):
   - Amberモードの同期時に、取得したすべてのカスタムリスト情報を抽出
   - `customListsProvider.syncListsFromNostr`を呼び出してローカルに反映

**結果:** 他のデバイスで作成されたカスタムリストも自動的に同期され、Todoが正しく表示されるようになった。

### 2025-11-04: eventIdが付与されない問題を解決

**問題:** TODAYからもSOMEDAYからもTodoを作成した場合、eventIdが付与されない。

**原因:** 
- `_syncAllTodosToNostr`でNostrに送信し、eventIdを取得していた
- しかし、**取得したeventIdをTodoオブジェクトに反映する処理がなかった**

**修正:** (`lib/providers/todos_provider.dart`)
1. 新規メソッド`_updateTodoEventIdInState`を追加
   - 指定されたTodoのeventIdを更新
   - needsSyncフラグをクリア
   - ローカルストレージに保存

2. Amberモードの送信ループ内で、eventId取得後に各Todoを更新：
```dart
final sendResult = await nostrService.sendSignedEvent(signedEvent);
for (final todo in listTodos) {
  await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
}
```

3. 通常モードでも同様に、全Todoを更新：
```dart
final sendResult = await nostrService.createTodoListOnNostr(allTodos);
for (final todo in allTodos) {
  await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
}
```

**結果:** Todoを作成した直後にNostrに送信され、eventIdが正しく付与されるようになった。

---

### 2025-11-04: NIP-51準拠の名前ベースリストID戦略を実装 🎯

**問題:** 同じリスト名（例: "BRAIN DUMP"）を異なるデバイスで作成すると、UUID v4ベースのIDが異なるため、別々のNostrイベントとして保存され、リストが無限に増殖する。

**原因:** 
- UUID v4ベースのランダムなID生成
- デバイスごとに異なるIDが生成される
- Nostrのd tagも異なるため、同じリストとして認識されない

**NIP-51の標準アプローチ:**
- リスト識別子（d tag）には**意味のある決定的な値**を使用
- 例: `bookmark-list`, `mute-list`, `pin-list`

**修正:** 
1. **リスト名から決定的なIDを生成** (`lib/models/custom_list.dart`)
   ```dart
   extension CustomListHelpers on CustomList {
     static String generateIdFromName(String name) {
       return name
           .toLowerCase()
           .trim()
           .replaceAll(RegExp(r'[^\w\s-]'), '') // 特殊文字を削除
           .replaceAll(RegExp(r'\s+'), '-')     // スペースをハイフンに
           .replaceAll(RegExp(r'-+'), '-')      // 連続するハイフンを1つに
           .replaceAll(RegExp(r'^-|-$'), '');   // 先頭・末尾のハイフンを削除
     }
   }
   ```
   
   例:
   - "BRAIN DUMP" → "brain-dump"
   - "Grocery List" → "grocery-list"
   - "TO BUY!!!" → "to-buy"

2. **CustomListsProviderの修正**
   - 新規リスト追加時に名前ベースのIDを使用
   - UUID v4の使用を廃止
   - 同じIDのリストが既に存在する場合はスキップ

3. **Nostr同期の修正**
   - 送信時: Todoをリストごとにグループ化する際、UUIDベースのIDを名前ベースIDに変換
   - 受信時: `title` tagからリスト名を抽出し、名前ベースIDを生成してローカルに同期

4. **マイグレーション処理**
   - 既存のUUIDベースの`customListId`を持つTodoを、名前ベースIDに自動変換
   - 同期時にバックグラウンドで実行

**Nostrイベント構造:**
```json
{
  "kind": 30001,
  "content": "<NIP-44暗号化されたTodoリスト>",
  "tags": [
    ["d", "meiso-list-brain-dump"],
    ["title", "BRAIN DUMP"]
  ]
}
```

**結果:** 
- ✅ 異なるデバイスで同じ名前のリストを作成しても、同じd tagになる
- ✅ Replaceable Eventなので、最新版に自動的に統一される
- ✅ NIP-51の標準パターンに準拠
- ✅ リストが無限に増殖しなくなる

詳細は [`docs/NIP_51_LIST_ID_STRATEGY.md`](./NIP_51_LIST_ID_STRATEGY.md) を参照。

---

### 2025-11-04: Amberモードのリストごとの分割処理を追加

**問題:** Amberモードでは、すべてのTodoを1つのJSONに変換して1つのイベントとして送信していたため、リストごとの分割が行われていなかった。

**修正:**
- `lib/providers/todos_provider.dart`の`_syncAllTodosToNostr`でリストごとにグループ化し、各リストを個別に暗号化・署名・送信するように変更
- `lib/providers/todos_provider.dart`の`syncFromNostr`で`fetchAllEncryptedTodoLists()`を使用し、すべてのリストを取得・復号化するように変更
- `custom_lists_provider.dart`のインポートを追加

### 2025-11-04: 重複イベント処理の追加

**問題:** リレーがKind 30001の古いイベントも返すため、同じリストのイベントが複数取得され、Todoが重複していた（70件取得して36件しかマージされない問題）。

**修正:**
- `rust/src/api.rs`の`fetch_all_encrypted_todo_lists_for_pubkey_with_client_id`: HashMapで同じ`d`タグを持つイベントの最新版のみを保持
- `rust/src/api.rs`の`sync_todo_list`: 同様に最新イベントのみを処理
- 詳細なデバッグログを追加（`d`タグ、イベントID、`created_at`タイムスタンプを出力）

