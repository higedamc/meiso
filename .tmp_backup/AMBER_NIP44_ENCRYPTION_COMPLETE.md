# Amber NIP-44暗号化実装完了

## 概要

**AmberモードでもTODOをNIP-44暗号化できるようになりました！**

ユーザーの指摘は正しく、Amberは署名だけでなくNIP-44暗号化・復号化も完全にサポートしています。
people setsなどのリストデータと同様に、TODOも自分の公開鍵で暗号化し、Nostrリレーに保存できます。

## Amberの暗号化サポート確認

Amberのソースコード（`AmberUtils.kt`）から確認：

```kotlin
SignerType.NIP44_ENCRYPT -> {
    Nip44.encrypt(
        data,
        account.signer.keyPair.privKey!!,
        pubKey.hexToByteArray(),
    ).encodePayload()
}
// ...
SignerType.NIP44_DECRYPT -> {
    Nip44.decrypt(
        data,
        account.signer.keyPair.privKey!!,
        pubKey.hexToByteArray(),
    )
}
```

Amberは`nip44_encrypt`と`nip44_decrypt`の両方をIntentベースで提供しています。

## 実装フロー

### 1. TODO作成・更新時（暗号化フロー）

```
TodoJSON → Amber暗号化 → 暗号化済みcontentで未署名イベント作成 → Amber署名 → リレー送信
```

1. TodoオブジェクトをJSON文字列に変換
2. Amberに`nip44_encrypt`リクエスト（自分の公開鍵で暗号化）
3. 暗号化されたcontentでNostrイベントを作成（未署名）
4. Amberに`sign_event`リクエスト
5. 署名済みイベントをNostrリレーに送信

### 2. TODO同期時（復号化フロー）

```
リレーから暗号化イベント取得 → Amber復号化 → TodoJSON → Todoオブジェクト
```

1. Nostrリレーから暗号化されたTODOイベントを取得
2. 各イベントについてAmberに`nip44_decrypt`リクエスト
3. 復号化されたJSON文字列をパース
4. Todoオブジェクトに変換して状態更新

## 実装詳細

### 1. MainActivity.kt（Android Intent処理）

新規追加メソッド：
- `encryptNip44WithAmber` - NIP-44暗号化リクエスト
- `decryptNip44WithAmber` - NIP-44復号化リクエスト

レスポンス処理：
- `result`パラメータで暗号化・復号化結果を受信

```kotlin
"encryptNip44WithAmber" -> {
    val intent = Intent(Intent.ACTION_VIEW).apply {
        data = android.net.Uri.parse("nostrsigner:$plaintext")
        putExtra("type", "nip44_encrypt")
        putExtra("pubkey", pubkey)
        putExtra("callbackUrl", "meiso://result")
        putExtra("package", currentPackage)
    }
    startActivity(intent)
}
```

### 2. AmberService.dart（Flutter側インターフェース）

新規追加メソッド：
```dart
Future<String> encryptNip44(String plaintext, String pubkey, {Duration timeout})
Future<String> decryptNip44(String ciphertext, String pubkey, {Duration timeout})
```

両メソッドとも：
- EventChannelでAmberからの応答を監視
- タイムアウト処理（デフォルト2分）
- エラーハンドリング

### 3. Rust API（Nostrクライアント）

新規追加関数：

```rust
pub fn create_unsigned_encrypted_todo_event(
    todo_id: String,
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String>
```
- 暗号化済みcontentでNostrイベント（Kind 30078）を作成

```rust
pub struct EncryptedTodoEvent {
    pub event_id: String,
    pub encrypted_content: String,
    pub created_at: i64,
    pub d_tag: String,
}

pub fn fetch_encrypted_todos_for_pubkey(
    public_key_hex: String,
) -> Result<Vec<EncryptedTodoEvent>>
```
- 公開鍵でNostrリレーから暗号化されたTODOイベントを取得

### 4. NostrService（Flutter-Rustブリッジ）

新規追加メソッド：
```dart
Future<String> createUnsignedEncryptedTodoEvent({
  required String todoId,
  required String encryptedContent,
})

Future<List<rust_api.EncryptedTodoEvent>> fetchEncryptedTodos()
```

### 5. TodosProvider（状態管理）

#### `_syncTodoWithMode`メソッド更新

Amberモード時のフロー：
```dart
// 1. TodoをJSONに変換
final todoJson = jsonEncode({...});

// 2. AmberでNIP-44暗号化
final encryptedContent = await amberService.encryptNip44(todoJson, publicKey);

// 3. 暗号化済みcontentで未署名イベントを作成
final unsignedEvent = await nostrService.createUnsignedEncryptedTodoEvent(
  todoId: todo.id,
  encryptedContent: encryptedContent,
);

// 4. Amberで署名
final signedEvent = await amberService.signEventWithTimeout(unsignedEvent);

// 5. リレーに送信
final eventId = await nostrService.sendSignedEvent(signedEvent);
```

#### `syncFromNostr`メソッド新規追加

Amberモード時のフロー：
```dart
// 1. 暗号化されたイベントを取得
final encryptedEvents = await nostrService.fetchEncryptedTodos();

// 2. 各イベントを復号化
for (final event in encryptedEvents) {
  // Amberで復号化
  final decryptedJson = await amberService.decryptNip44(
    event.encryptedContent,
    publicKey,
  );
  
  // JSONをパース
  final todoMap = jsonDecode(decryptedJson);
  final todo = Todo(...);
  syncedTodos.add(todo);
}

// 3. 状態を更新
_updateStateWithSyncedTodos(syncedTodos);
```

## セキュリティの比較

### 秘密鍵モード
- **暗号化**: Rust側でNIP-44暗号化（自動）
- **鍵管理**: Argon2id + AES-256-GCM（アプリ内）
- **署名**: Rust側で自動署名

### Amberモード（今回実装）
- **暗号化**: Amber経由でNIP-44暗号化
- **鍵管理**: Amber内で管理（ncryptsec）
- **署名**: Amber経由で署名

**どちらのモードでもTODOは完全にNIP-44暗号化されます！**

## ユーザー体験

### Amberモードでのフロー

1. **TODO作成時**:
   - Amberが起動 → 暗号化の確認 → Amber画面に戻る
   - Amberが起動 → 署名の確認 → Meiso画面に戻る

2. **TODO同期時**:
   - 複数のTODOがある場合、各TODOごとにAmberが起動
   - 復号化の確認を繰り返し

3. **TODO更新・削除時**:
   - 作成時と同様に暗号化→署名のフロー

## テスト手順

1. **ビルドと実行**:
```bash
cd /Users/apple/work/meiso
fvm flutter pub get
fvm flutter build apk
fvm flutter run
```

2. **Amberモードでログイン**:
   - Onboarding画面で「Amberで接続」を選択
   - Amberで公開鍵を承認

3. **TODO作成**:
   - 新しいTODOを作成
   - Amber暗号化画面 → 承認
   - Amber署名画面 → 承認
   - リレーに送信されることを確認

4. **別デバイスで同期**:
   - 別デバイスでAmberモードでログイン
   - TODO一覧を開く
   - 各TODOの復号化をAmberで承認
   - TODOが表示されることを確認

## ログ出力

実装には詳細なログを追加しました：

```
🔐 Amber暗号化モードでTodoを同期します
📝 Todo JSON (123 bytes): {"id":"...
🔐 Amberで暗号化中...
✅ 暗号化完了 (256 bytes)
📄 未署名イベント作成完了
✍️ Amberで署名中...
✅ 署名完了
📤 リレーに送信中...
✅ 送信完了: abc123...
```

```
🔐 Amberモードで同期します（復号化あり）
📥 5件の暗号化されたイベントを取得
🔓 イベント abc12345... を復号化中...
✅ 復号化成功: 買い物リスト
✅ 5/5件のTodoを復号化
✅ Nostr同期成功
```

## まとめ

- ✅ Amberは署名だけでなくNIP-44暗号化・復号化もサポート
- ✅ TODOは秘密鍵モードでもAmberモードでも完全に暗号化される
- ✅ people setsと同じくAmberで暗号化・復号化可能
- ✅ 6つのファイルを更新（~350行の追加）
- ✅ セキュアでユーザーフレンドリーな実装

**Amber+Nostr+NIP-44暗号化でプライベートなTODO管理が実現しました！🎉**

