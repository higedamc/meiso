# Kind 30001 (NIP-51 Bookmark List) への移行完了

## 概要

Meisoアプリを **Kind 30078 (Application-specific data)** から **Kind 30001 (NIP-51 Bookmark List)** に移行しました。

### 移行の目的

1. **Amber許可の簡素化**: 各TODOごとに復号化許可が必要だったのを、**1回のみの許可**で全TODO管理が可能に
2. **標準仕様の採用**: NIP-51の標準Kindを使用し、将来的な拡張性向上
3. **効率的なデータ管理**: 全TODOを1つのイベントとして管理し、リレー負荷を削減

---

## 実装変更点

### 1. Rust側の実装 (`rust/src/api.rs`)

#### 新規追加された関数

```rust
// Todoリスト全体を管理（Kind 30001）
pub async fn create_todo_list(&self, todos: Vec<TodoData>) -> Result<String>
pub async fn sync_todo_list(&self) -> Result<Vec<TodoData>>

// Flutter Rust Bridge API
pub fn create_todo_list(todos: Vec<TodoData>) -> Result<String>
pub fn sync_todo_list() -> Result<Vec<TodoData>>

// Amber用の未署名イベント作成（Kind 30001）
pub fn create_unsigned_encrypted_todo_list_event(
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String>

// 暗号化されたTodoリストイベント取得
pub struct EncryptedTodoListEvent { ... }
pub fn fetch_encrypted_todo_list_for_pubkey(
    public_key_hex: String,
) -> Result<Option<EncryptedTodoListEvent>>
```

#### イベント構造

```json
{
  "kind": 30001,
  "tags": [
    ["d", "meiso-todos"],
    ["title", "My TODO List"]
  ],
  "content": "<NIP-44暗号化されたTODO配列JSON>"
}
```

### 2. Flutter側の実装

#### NostrService (`lib/providers/nostr_provider.dart`)

```dart
// 新規追加メソッド
Future<String> createTodoListOnNostr(List<Todo> todos)
Future<List<Todo>> syncTodoListFromNostr()
Future<String> createUnsignedEncryptedTodoListEvent({ required String encryptedContent })
Future<EncryptedTodoListEvent?> fetchEncryptedTodoList()
```

#### TodosProvider (`lib/providers/todos_provider.dart`)

##### 主要な変更

1. **全TODO操作後に`_syncAllTodosToNostr()`を呼び出し**
   - `addTodo()`, `updateTodo()`, `updateTodoTitle()`, `toggleTodo()`, `deleteTodo()`, `reorderTodo()`, `moveTodo()`
   - 各操作後、全TODOをフラット化して1つのイベントとして送信

2. **`_syncAllTodosToNostr()`メソッド追加**
   - 全TODOをJSON配列に変換
   - Amberモード時: JSON → Amber暗号化 → 未署名イベント → Amber署名 → リレー送信
   - 通常モード: Rust側でNIP-44暗号化 → 署名 → リレー送信

3. **`syncFromNostr()`メソッドの大幅修正**
   - 個別イベントの取得 → **1つのイベント（Todoリスト全体）を取得**
   - Amberモード時: 1つの暗号化イベント → Amber復号化 → Todo配列を取得
   - 通常モード: Rust側で復号化済みのTodo配列を取得

##### 削除されたメソッド

- `_syncTodoWithMode()` - 旧実装（Kind 30078用）
- `_updateTodoEventId()` - 不要になった

---

## 動作フロー

### 通常モード（秘密鍵モード）

#### TODO追加・更新時

```
1. UI操作（addTodo, updateTodo等）
2. ローカル状態を更新
3. ローカルストレージに保存
4. _syncAllTodosToNostr()を呼び出し
   ↓
   全TODO → Rust側 → NIP-44暗号化 → 秘密鍵で署名 → Kind 30001イベント作成 → リレー送信
```

#### TODO同期時

```
1. syncFromNostr()を呼び出し
2. Rust側でKind 30001イベントを取得
3. Rust側でNIP-44復号化
4. Todo配列を取得
5. ローカル状態を更新
```

### Amberモード

#### TODO追加・更新時

```
1. UI操作（addTodo, updateTodo等）
2. ローカル状態を更新
3. ローカルストレージに保存
4. _syncAllTodosToNostr()を呼び出し
   ↓
   全TODO → JSON配列
   ↓
   Amber暗号化（ContentProvider経由、またはIntent経由）
   ↓
   未署名イベント作成（Kind 30001）
   ↓
   Amber署名（ContentProvider経由、またはIntent経由）
   ↓
   リレー送信
```

#### TODO同期時

```
1. syncFromNostr()を呼び出し
2. Kind 30001の暗号化イベントを取得
3. Amber復号化（ContentProvider経由、またはIntent経由）
4. Todo配列を取得
5. ローカル状態を更新
```

---

## メリット

### 1. Amber許可の簡素化

**旧実装（Kind 30078）**:
- TODO数分の復号化許可が必要
- 例: 100個のTODO → 100回の許可承認が必要（初回のみ）

**新実装（Kind 30001）**:
- **1回のみの復号化許可**で全TODO管理
- Amber側で「このアプリがKind 30001を復号化する」という許可を1回承認するだけ

### 2. リレー負荷の削減

**旧実装**: 1TODO = 1イベント（100個のTODO → 100イベント）  
**新実装**: 全TODO = 1イベント（100個のTODO → 1イベント）

### 3. 効率的な同期

**旧実装**: 各TODOイベントを個別に取得・処理  
**新実装**: 1つのイベントを取得・復号化するだけ

### 4. 標準仕様の採用

- NIP-51の正式なKind（30001 - Bookmark List）を使用
- 将来的に他のNostrアプリとの互換性の可能性

---

## 後方互換性

### 旧実装（Kind 30078）のサポート

- Rust側に旧実装の関数を残している（`create_todo()`, `sync_todos()`, `fetch_encrypted_todos_for_pubkey()`等）
- 将来的にマイグレーション機能を追加可能（Kind 30078 → Kind 30001）

### マイグレーション計画（未実装）

1. 起動時にKind 30078イベントの存在をチェック
2. 存在すれば全TODO取得 → Kind 30001に変換・送信
3. Kind 5（削除イベント）で旧イベントを削除

---

## テスト項目

### 通常モード（秘密鍵モード）

- [ ] TODO追加・更新・削除が正常に動作
- [ ] 複数端末間で同期が正常に動作
- [ ] リレーにKind 30001イベントが正しく送信されている

### Amberモード

- [ ] TODO追加・更新・削除が正常に動作
- [ ] Amber暗号化・署名が正常に動作（ContentProvider経由）
- [ ] パーミッション承認フローが正常に動作（初回のみIntent経由）
- [ ] 複数端末間で同期が正常に動作
- [ ] リレーにKind 30001イベントが正しく送信されている

### エッジケース

- [ ] 空のTODOリスト（0件）の場合
- [ ] 大量のTODO（100件以上）の場合
- [ ] ネットワークエラー時の挙動
- [ ] Amber拒否時の挙動

---

## 既知の制限事項

1. **イベントサイズ**: TODOが増えると1つのイベントサイズが大きくなる
   - 対策: 数百件程度なら問題なし（リレーの最大サイズ制限に注意）

2. **更新頻度**: TODO変更のたびに全体を再送信
   - 対策: Replaceable eventなので古いイベントは自動削除される

3. **マイグレーション未実装**: Kind 30078からの自動移行機能なし
   - 対策: 新規ユーザーは自動的にKind 30001を使用

---

## 次のステップ

1. **実機テスト**:
   - Android実機でAmberモードのテスト
   - 複数端末間での同期テスト

2. **マイグレーション機能の実装**:
   - 既存ユーザー向けにKind 30078 → 30001への移行機能

3. **パフォーマンス最適化**:
   - 大量TODO時のJSON圧縮検討

4. **エラーハンドリング強化**:
   - ネットワークエラー時のリトライロジック改善

---

## 参考

- [NIP-01: Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [NIP-44: Encrypted Payloads](https://github.com/nostr-protocol/nips/blob/master/44.md)
- [NIP-51: Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [Kind 30001 specification](https://github.com/nostr-protocol/nips/blob/master/51.md#standard-lists)

