# Amber パーミッション管理ガイド（修正版）

## 問題の概要

Amber経由でログインした場合、TODOの同期時に各TODO（暗号化イベント）ごとに復号化の承認が必要になります。
1000個のTODOがある場合、1000回の承認タップが必要になり、実用的ではありません。

**根本原因（Amberのソースコードを確認して判明）**:
1. `permissions`パラメータが**JSON配列**として送信されていなかった
2. そのため、AmberのアプリケーションリストにMeisoが登録されなかった
3. パーミッション管理ができなかった

## 解決策：正しい形式でパーミッションを送信

### Phase 5（修正版）で実装した改善

#### 1. パーミッションをJSON配列として送信（重要な修正）

**問題**:
- 以前：`putExtra("permissions", "nip44_decrypt")` ← 単なる文字列 ❌
- Amberが期待する形式：JSON配列 `[{"type":"nip44_decrypt","kind":null}]` ✅

**修正内容（MainActivity.kt）**:

```kotlin
// パーミッションをJSON配列として作成
val permissionsJson = """[
    {"type":"nip44_decrypt","kind":null},
    {"type":"nip44_encrypt","kind":null},
    {"type":"sign_event","kind":30078}
]""".trimIndent()

val intent = Intent(Intent.ACTION_VIEW).apply {
    // ... 他のextras ...
    putExtra("permissions", permissionsJson)  // JSON配列として送信
    putExtra("appName", "Meiso")              // アプリ名も送信
}
```

これにより：
1. AmberのアプリケーションリストにMeisoが登録される
2. パーミッション（NIP-44復号化/暗号化、イベント署名）が保存される
3. ユーザーがAmber側で「常に許可」を設定できる

#### 2. Settings画面での案内

Amberモード情報カードを更新し、ユーザーに以下を案内するようにしました：

- NIP-44暗号化が有効であること
- 復号化の承認が必要であること
- **Amberアプリで「常に許可」を設定する方法**

### ユーザー側の設定手順

Amber経由でログインした後、ユーザーは以下の設定を行う必要があります：

#### 方法1: Amber側で設定（推奨）

1. **Amberアプリを開く**
2. **設定（⚙️）→ 接続済みアプリ → Meiso**を選択
3. **「NIP-44 Decrypt」を「常に許可」に設定**
4. Meisoアプリに戻って同期を実行

これにより、以降のNIP-44復号化リクエストは**自動承認**されます（ダイアログなし）。

#### 方法2: 初回ログイン時に「記憶する」を選択

Amberの一部バージョンでは、初回の復号化リクエスト時に：
- 「今回のみ許可」
- **「常に許可」**（記憶する）

のオプションが表示される場合があります。「常に許可」を選択すると、以降は自動承認されます。

## 動作の仕組み

### 通常の復号化フロー（改善前）

```
Todo同期開始
  ↓
各TODOごとに:
  ↓
  Meisoアプリ → Amberアプリ (復号化リクエスト)
  ↓
  Amber: ユーザーに承認ダイアログ表示 👈 **毎回タップが必要**
  ↓
  ユーザー: 承認ボタンをタップ
  ↓
  Amber → Meisoアプリ (復号化結果)
  ↓
次のTODOへ...
```

**問題**: 1000個のTODOがあれば、1000回のタップが必要。

### パーミッション設定後のフロー（改善後）

```
初回ログイン時:
  ↓
  Meisoアプリ → Amberアプリ (公開鍵取得 + permissions=nip44_decrypt)
  ↓
  Amber: 「Meisoに以下の権限を付与しますか？」
          - 署名
          - NIP-44復号化 👈 ここで許可
  ↓
  ユーザー: 「許可」をタップ（1回のみ）
  ↓
  Amber: パーミッション保存

以降のTodo同期:
  ↓
各TODOごとに:
  ↓
  Meisoアプリ → Amberアプリ (復号化リクエスト)
  ↓
  Amber: パーミッションを確認 → **自動承認（ダイアログなし）** ✅
  ↓
  Amber → Meisoアプリ (復号化結果)
  ↓
次のTODOへ...
```

**改善**: 初回ログイン時に1回許可すれば、以降は全て自動承認。

## デバッグ情報

### ログの確認方法

Phase 5で追加したデバッグログにより、以下が確認できます：

```
🔐 Amberモードで同期します（復号化あり）
📥 10件の暗号化されたイベントを取得
🔑 公開鍵: abc123def456...

🔓 [1/10] イベント abc12345... を復号化中...
   暗号化content (最初50文字): AgBb3Dn...
   復号化結果 (最初100文字): {"id":"abc-123","title":"タスク1"...
   ✅ 復号化成功: タスク1

...

✅ 復号化完了: 成功 10件 / 失敗 0件 / 合計 10件
✅ Nostr同期成功
```

### トラブルシューティング

#### 問題1: 「何も表示されない」

**ログ確認**:
```
📥 0件の暗号化されたイベントを取得
⚠️ 暗号化されたイベントが0件です。リレーに接続されているか確認してください。
```

**原因**:
- リレーに接続されていない
- 公開鍵が異なる（秘密鍵モードとAmberモードで別のアカウントを使用）
- まだTODOを作成していない

**解決策**:
1. Settings画面でリレー接続を確認
2. 公開鍵（npub）が同じか確認
3. Amberモードで新しいTODOを作成してテスト

#### 問題2: 「復号化に毎回承認が必要」

**ログ確認**:
```
🔓 [1/10] イベント abc12345... を復号化中...
(Amberアプリに切り替わり、承認ダイアログが表示される)
```

**原因**:
- Amber側でパーミッションが保存されていない
- Amberのバージョンが古い（パーミッション機能未対応）

**解決策**:
1. Amberアプリを最新バージョンにアップデート
2. Amber側で手動設定：
   - Amberアプリを開く
   - 設定 → 接続済みアプリ → Meiso
   - 「NIP-44 Decrypt」を「常に許可」に設定

#### 問題3: 「復号化に失敗する」

**ログ確認**:
```
⚠️ イベント abc12345... の復号化に失敗:
   エラー: Exception: Amber error: user rejected
```

**原因**:
- ユーザーが承認をキャンセルした
- Amberとの通信エラー

**解決策**:
- 再度同期を実行
- Amberアプリが正しくインストールされているか確認

## NIP-55準拠の実装詳細

### Intent extras（Android）

```kotlin
// 初回ログイン時
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = Uri.parse("nostrsigner:")
    `package` = "com.greenart7c3.nostrsigner"
    putExtra("type", "get_public_key")
    putExtra("callbackUrl", "meiso://result")
    putExtra("package", currentPackage)
    putExtra("permissions", "nip44_decrypt") // 👈 追加
}
```

### Amberが返すレスポンス

```
meiso://result?pubkey={public_key_hex}
```

Amber側でパーミッションが記録され、以降のNIP-44復号化リクエストは自動承認されます。

## 今後の改善案

### 1. バッチ復号化（将来のAmber対応待ち）

現在、各TODOごとに復号化リクエストを送っていますが、将来的にAmberが**バッチ復号化**をサポートすれば、
複数の暗号文を1回のリクエストでまとめて復号化できるようになります。

```kotlin
// 将来の実装案
putExtra("type", "nip44_decrypt_batch")
putExtra("ciphertexts", jsonArrayOfCiphertexts)
```

### 2. 復号化の進捗表示

パーミッション設定がない場合でも、ユーザーエクスペリエンスを改善するために、
復号化の進捗状況を表示する機能を追加できます：

- プログレスバー：「10/100件を復号化中...」
- スキップボタン：「後で同期」

### 3. ローカルキャッシュ

一度復号化したTODOをローカルに保存し、次回起動時は復号化をスキップすることで、
パフォーマンスを改善できます。

## まとめ

Phase 5の改善により：

✅ **ログイン時にNIP-44復号化のパーミッションを要求**
✅ **Settings画面でユーザーに設定方法を案内**
✅ **デバッグログで問題の原因を特定可能**

**重要**: ユーザーは**Amber側で「常に許可」を設定する必要**があります。
これにより、1000個のTODOでも**1回の許可で全て復号化**できます。

---

## 🚀 テスト手順

### ステップ1: アプリの準備
1. Amberアプリを最新バージョンにアップデート
2. Meisoアプリをビルド＆インストール（修正版）
3. Meisoアプリで既存のAmberログインがある場合はログアウト

### ステップ2: Amber経由でログイン
1. Meisoアプリを起動
2. 「Amberでログイン」をタップ
3. Amberアプリに切り替わる

### ステップ3: パーミッション確認
Amberアプリで以下が表示されるはずです：

```
Meisoが以下の権限を要求しています：
- NIP-44で復号化
- NIP-44で暗号化  
- イベント署名 (kind 30078)
```

「許可」をタップしてMeisoアプリに戻る。

### ステップ4: Amberアプリでアプリリストを確認
1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示されているか確認** ← これが重要！

表示されていれば、修正成功です 🎉

### ステップ5: パーミッション設定
Amberアプリで「Meiso」を選択し、以下を「常に許可」に設定：
- ✅ NIP-44 Decrypt
- ✅ NIP-44 Encrypt
- ✅ イベント署名 (kind 30078)

### ステップ6: TODO同期テスト
1. Meisoアプリに戻る
2. TODOを同期
3. **ダイアログなしで復号化されることを確認**

---

## ❓ トラブルシューティング

### 問題1: Amberのアプリリストに「Meiso」が表示されない

**原因**: パーミッションが正しく送信されていない

**確認方法**:
```bash
# MainActivity のログを確認
adb logcat | grep MainActivity
```

以下のログが表示されるはず：
```
MainActivity: Launching Amber with permissions: [{"type":"nip44_decrypt","kind":null},{"type":"nip44_encrypt","kind":null},{"type":"sign_event","kind":30078}]
```

**解決策**:
- アプリを再ビルド
- ログアウトして再ログイン

### 問題2: 復号化の承認が毎回求められる

**原因**: Amber側でパーミッションが「常に許可」に設定されていない

**解決策**:
1. Amberアプリを開く
2. 設定 → 接続済みアプリ → Meiso
3. 各パーミッションを「常に許可」に設定

### 問題3: 「何も表示されない」（TODO が0件）

**原因**: 
- リレーに接続されていない
- 公開鍵が異なる（秘密鍵モードとAmberモードで別のアカウント）

**デバッグ**:
```bash
# TODO同期のログを確認（すべてのログ）
adb logcat -s flutter

# または、Amberモード関連のみ
adb logcat | grep "Amberモード"
```

以下を確認：
```
📥 X件の暗号化されたイベントを取得  ← 0件なら問題
🔑 公開鍵: abc123...                  ← 公開鍵が同じか確認
✅ 復号化完了: 成功 X件               ← 成功数を確認
```

---

## 📝 実装の詳細（開発者向け）

### Amberが期待するIntent extraの形式

```kotlin
Intent(Intent.ACTION_VIEW).apply {
    data = Uri.parse("nostrsigner:")
    `package` = "com.greenart7c3.nostrsigner"
    
    // 必須パラメータ
    putExtra("type", "get_public_key")
    putExtra("callbackUrl", "meiso://result")
    putExtra("package", packageName)           // アプリのパッケージ名
    putExtra("appName", "Meiso")               // 人間が読める名前
    
    // パーミッション（JSON配列）
    putExtra("permissions", """[
        {"type":"nip44_decrypt","kind":null},
        {"type":"nip44_encrypt","kind":null},
        {"type":"sign_event","kind":30078}
    ]""")
}
```

### Amberのデータベースに保存される内容

`ApplicationEntity`:
- `key`: パッケージ名（`jp.godzhigella.meiso`）
- `name`: アプリ名（`Meiso`）
- `pubKey`: ユーザーの公開鍵

`ApplicationPermissionsEntity`:
- `type`: パーミッションタイプ（`NIP44_DECRYPT`等）
- `kind`: イベントkind（`30078`等、nullもあり）
- `acceptable`: true（許可）/ false（拒否）
- `acceptUntil`: 有効期限（`Long.MAX_VALUE`なら永久）

### パーミッションチェックのロジック

Amber側（`IntentUtils.kt`）:
```kotlin
val isRemembered = isRemembered(signPolicy, permission)
// true  → 自動承認
// false → 自動拒否
// null  → ユーザーに確認
```

---

## まとめ

**Phase 5（修正版）の変更内容**:

✅ `permissions`をJSON配列として送信（**最重要**）
✅ `appName`を送信してAmberのアプリリストに表示
✅ Settings画面でユーザーに設定方法を案内
✅ デバッグログで問題を特定可能

**これにより**:
- AmberのアプリリストにMeisoが登録される
- パーミッションを「常に許可」に設定できる
- 1000個のTODOでも1回の設定で自動復号化

**テストしてフィードバックをお願いします！** 🙏

