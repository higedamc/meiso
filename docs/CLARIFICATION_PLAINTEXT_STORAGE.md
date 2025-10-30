# 「平文保存」の明確化ドキュメント

**日付**: 2025-10-30  
**目的**: ドキュメント内の「平文保存」という記述について明確化

---

## 🔍 問題

Phase 4のドキュメントで「Amberモードでは平文保存」という記述があり、これが誤解を招く可能性がありました。

**誤解の可能性**:
- Amber上の秘密鍵が平文で保存されている？
- Amberのセキュリティに問題がある？

---

## ✅ 正しい理解

### 1. **Amber上の秘密鍵管理（完全に安全）**

```
✅ Amber上の秘密鍵は、ncryptsecプロトコルに準拠して暗号化保存されています
```

**Amberのセキュリティ**:
- ncryptsec規格準拠
- 秘密鍵は暗号化されてAmber内に保存
- Meisoアプリはアクセス不可
- パスワードロック機能あり

**何も問題ありません！** ✅

---

### 2. **Todoのcontentの扱い（現在の制限）**

```
⚠️ 「平文保存」とは、Nostrリレーに送信されるTodoのcontentが暗号化されていないことを指します
```

#### 秘密鍵モード（暗号化あり）

```rust
// rust/src/api.rs - create_todo()
let encrypted_content = nip44::encrypt(
    self.keys.secret_key(),  // ← 秘密鍵で暗号化
    &public_key,
    &todo_json,
    nip44::Version::V2,
)?;
```

**結果**: Todoのcontentが**暗号化されて**リレーに送信される ✅

#### Amberモード（暗号化なし）

```rust
// rust/src/api.rs - create_unsigned_todo_event()
let unsigned_event = json!({
    "pubkey": public_key.to_hex(),
    "created_at": created_at,
    "kind": 30078,
    "tags": tags,
    "content": todo_json,  // ← 平文のJSON
});
```

**結果**: Todoのcontentが**平文で**リレーに送信される ⚠️

---

## 🤔 なぜAmberモードで暗号化できないのか？

### 技術的な理由

**NIP-44暗号化には秘密鍵が必要**:
```rust
pub fn encrypt(
    secret_key: &SecretKey,  // ← 秘密鍵が必要
    public_key: &PublicKey,
    plaintext: &str,
    version: Version,
) -> Result<String>
```

**Amberモードの制約**:
1. Meisoアプリに秘密鍵がない（Amber内にのみ存在）
2. Amberは「署名」のみをサポート（「暗号化」機能なし）
3. 未署名イベントを作成 → Amberで署名 → リレー送信

**フロー**:
```
Meiso: 未署名イベント作成
       ↓ content: 平文
Amber: 署名を追加（contentはそのまま）
       ↓ content: 平文（署名付き）
Meiso: リレーに送信
       ↓
Relay: content: 平文で保存 ⚠️
```

---

## 💡 解決策（Phase 5で検討）

### オプション1: Amberに暗号化機能を追加（推奨）

Amber側に「NIP-44暗号化 + 署名」機能を実装：

```
Meiso: 暗号化リクエスト送信
       ↓ encrypt_request: { content: "Buy milk", algorithm: "nip44" }
Amber: NIP-44で暗号化 + 署名
       ↓ encrypted_content: "AQBcF3e..." + signature
Meiso: 暗号化済み・署名済みイベント受信
       ↓
Relay: content: 暗号化済み ✅
```

**メリット**:
- 秘密鍵はAmber内に留まる
- プライバシー保護
- セキュリティとUXの両立

**デメリット**:
- Amber側の実装が必要
- 既存のAmberアプリとの互換性

---

### オプション2: NIP-04（DM）を使う

自分宛てのDMとしてTodoを暗号化：

```rust
// NIP-04は公開鍵のみで暗号化可能（要調査）
let encrypted_content = nip04::encrypt(
    &public_key,
    &todo_json,
)?;
```

**メリット**:
- Amber側の変更不要（署名のみ）
- 暗号化が可能

**デメリット**:
- NIP-04は古い暗号化方式（NIP-44より弱い）
- DMとして扱うため、UIで区別が必要
- **要調査**: 公開鍵のみで暗号化できるか？

---

### オプション3: ハイブリッドアプローチ

ローカルで暗号化 → Amberで署名：

```
Meiso: 公開鍵で暗号化（可能な方式を使用）
       ↓ content: 暗号化済み
Amber: 署名のみ追加（contentはそのまま）
       ↓ content: 暗号化済み（署名付き）
Meiso: リレーに送信
       ↓
Relay: content: 暗号化済み ✅
```

**課題**:
- 公開鍵のみでの暗号化方式が必要
- NIP-44は共有秘密鍵ベース（秘密鍵が必要）

---

## 📊 比較表

| 項目 | 秘密鍵モード | Amberモード（現在） | Amberモード（Phase 5目標） |
|------|-------------|---------------------|---------------------------|
| **秘密鍵保管** | Meisoアプリ内<br>（Argon2+AES-256） | Amber内<br>（ncryptsec） ✅ | Amber内<br>（ncryptsec） ✅ |
| **Todoの暗号化** | NIP-44 ✅ | なし ⚠️ | NIP-44 ✅ |
| **署名方式** | アプリ内 | Amberで承認 ✅ | Amberで承認 ✅ |
| **UX** | 高速 ✅ | 承認必要 ⚠️ | 承認必要 ⚠️ |
| **プライバシー** | 高 ✅ | 低 ⚠️ | 高 ✅ |
| **セキュリティ** | 中（鍵管理リスク） ⚠️ | 高（鍵分離） ✅ | 高（鍵分離） ✅ |

---

## 📝 ドキュメント修正内容

### 修正前
```
⚠️ 注意: Amberモードでは、Todoが平文でリレーに保存されます。
```

### 修正後
```
⚠️ 注意: Amberモードでは、Todoの内容（content）が暗号化されずに
Nostrリレーに送信されます。

重要: Amber上の秘密鍵は、ncryptsecプロトコルで暗号化されて
安全に保存されています。
```

---

## 🎯 ユーザーへの推奨

### 秘密鍵モードを推奨する場合
- ✅ プライバシーを最優先したい
- ✅ 頻繁にTodoを操作する
- ✅ オフライン使用が必要
- ⚠️ 秘密鍵管理のリスクを許容できる

### Amberモードを推奨する場合
- ✅ 秘密鍵の分離を最優先したい
- ✅ すべての署名操作を確認したい
- ✅ 複数アプリで同じ秘密鍵を使いたい
- ⚠️ Todoが公開リレーで見られることを許容できる

---

## 🚀 今後のロードマップ

### Phase 5: Amber暗号化対応
1. Amber側への機能提案・実装
2. NIP-04代替案の検討
3. ハイブリッド暗号化の実装

### Phase 6: プライバシー機能強化
1. プライベートリレーのサポート
2. E2E暗号化の完全実装
3. ローカル専用モード

---

## ✅ まとめ

### 明確化された事実

1. **Amber上の秘密鍵**: ncryptsecで暗号化保存 ✅ **安全**
2. **Todoのcontent**: 平文でリレー送信 ⚠️ **Phase 5で改善予定**

### ユーザーへのメッセージ

```
Amberモードは、秘密鍵管理において非常に安全です。
ただし、現在はTodoの内容が暗号化されずにリレーに送信されます。

プライベートなTodoを管理する場合は、秘密鍵モードをご利用ください。
将来のアップデートで、Amberモードでも暗号化をサポート予定です。
```

---

**作成日**: 2025-10-30  
**更新**: Phase 5で暗号化対応を実装予定

