# Phase 5: Amber復号化レスポンスの修正

## 🐛 発見された問題

### 1. **Amberからの復号化レスポンスが正しく解析されていなかった**

**ログから判明した事実**:
```
MainActivity: 🎯 Processing Amber response - scheme: meiso, data: meiso://result%7B%22id%22%3A%22f822367b...
MainActivity: Parsing from path: result{"id":"f822367b-4153-4fa4-abe3-acf10ed41663",...}
W MainActivity: No valid response parameter found from Amber
```

- AmberはNIP-44復号化の結果を`meiso://result{...JSON...}`の形式で返している
- しかし、MainActivity.ktは64文字の公開鍵（hex）のみを処理していた
- JSON形式のデータは無視されてエラーになっていた
- そのため、全てのTODOの復号化が失敗し、同期が完了しなかった

### 2. **パーミッションログが途切れていた**

```
MainActivity: Launching Amber with permissions: [
```

- JSON配列に改行が含まれていたため、logcatで途切れていた
- パーミッションが正しく送信されているか確認できなかった

### 3. **各リクエストでappNameが欠けていた**

- 初回の`get_public_key`リクエストには`appName`が含まれていた
- しかし、NIP-44暗号化/復号化、イベント署名のリクエストには含まれていなかった
- Amber側でアプリを正しく識別できず、パーミッションが適用されなかった可能性

## 🔧 実施した修正

### 修正1: Amberレスポンスの解析を改善

**ファイル**: `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt` (343-373行)

**変更前**:
```kotlin
if (path.startsWith("result")) {
    val keyString = path.substring(6)
    if (keyString.length == 64) { // 公開鍵のみ処理
        pubkey = keyString
    }
}
```

**変更後**:
```kotlin
if (path.startsWith("result")) {
    val dataString = path.substring(6)
    
    when {
        // 64文字のhex → 公開鍵
        dataString.length == 64 && dataString.matches(Regex("^[0-9a-fA-F]{64}$")) -> {
            pubkey = dataString
            Log.d("MainActivity", "✅ Extracted pubkey from path")
        }
        // JSON形式 → NIP-44復号化結果
        dataString.startsWith("{") || dataString.startsWith("[") -> {
            result = dataString
            Log.d("MainActivity", "✅ Extracted result (JSON) from path")
        }
        // その他のデータ → 暗号化ペイロード等
        dataString.isNotEmpty() -> {
            result = dataString
            Log.d("MainActivity", "✅ Extracted result (other) from path")
        }
    }
}
```

**効果**:
- JSON形式の復号化データを正しく処理できるようになった
- 公開鍵、JSON、その他のデータを自動判別

### 修正2: パーミッションJSON を1行に圧縮

**ファイル**: `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt` (85-106行)

**変更前**:
```kotlin
val permissionsJson = """[
    {"type":"nip44_decrypt","kind":null},
    {"type":"nip44_encrypt","kind":null},
    {"type":"sign_event","kind":30078}
]""".trimIndent()
```

**変更後**:
```kotlin
val permissionsJson = """[{"type":"nip44_decrypt","kind":null},{"type":"nip44_encrypt","kind":null},{"type":"sign_event","kind":30078}]"""
```

**効果**:
- logcatで完全なJSON配列が表示される
- パーミッションが正しく送信されているか確認可能

### 修正3: 全てのAmberリクエストに`appName`を追加

**変更箇所**:
1. **NIP-44復号化** (203行): `putExtra("appName", "Meiso")`
2. **NIP-44暗号化** (169行): `putExtra("appName", "Meiso")`
3. **イベント署名** (135行): `putExtra("appName", "Meiso")`

**効果**:
- Amberが全てのリクエストでアプリを正しく識別
- パーミッション設定が各操作で適用される

### 修正4: ログの改善

**変更内容**:
- 各Amberリクエストに絵文字付きログを追加
- パッケージ名も表示
- 復号化成功時にわかりやすいログ

**例**:
```kotlin
Log.d("MainActivity", "🚀 Launching Amber with permissions: $permissionsJson")
Log.d("MainActivity", "🔓 Launching Amber for NIP-44 decryption (package: $currentPackage)")
Log.d("MainActivity", "🔐 Launching Amber for NIP-44 encryption (package: $currentPackage)")
Log.d("MainActivity", "✍️ Launching Amber for signing (package: $currentPackage)")
Log.d("MainActivity", "✅ Extracted result (JSON) from path")
```

## 📊 期待される動作

### 1. 初回ログイン時

```bash
# ログ確認
adb logcat | grep MainActivity
```

期待されるログ:
```
MainActivity: 🚀 Launching Amber with permissions: [{"type":"nip44_decrypt","kind":null},{"type":"nip44_encrypt","kind":null},{"type":"sign_event","kind":30078}]
MainActivity: 📝 App name: Meiso, Package: jp.godzhigella.meiso
```

### 2. TODO同期時（復号化）

```bash
adb logcat | grep MainActivity
```

期待されるログ:
```
MainActivity: 🔓 Launching Amber for NIP-44 decryption (package: jp.godzhigella.meiso)
MainActivity: 🎯 Processing Amber response - scheme: meiso, data: meiso://result{"id":"..."}
MainActivity: Parsing from path: result{"id":"f822367b-4153-4fa4-abe3-acf10ed41663",...}
MainActivity: ✅ Extracted result (JSON) from path: {"id":"f822367b-4153-4fa4-abe3-acf10ed41663",...}
MainActivity: Parsed - result: {"id":"f822367b-4153-4fa4-abe3-acf10ed41663",...}
MainActivity: ✅ Sending response via EventSink immediately
```

### 3. Amber側での確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示される** ✅
4. Meisoを選択すると、以下のパーミッションが表示される：
   - ✅ NIP-44 Decrypt
   - ✅ NIP-44 Encrypt
   - ✅ Sign Event (kind 30078)

### 4. 「常に許可」設定後の動作

各パーミッションを「常に許可」に設定すると：
- TODO同期時に**自動的に復号化**される（ダイアログなし）
- TODO作成時に**自動的に暗号化**される（ダイアログなし）
- イベント署名が**自動的に承認**される（ダイアログなし）

## 🧪 テスト手順

### ステップ1: アプリの再ビルドとインストール

```bash
cd /Users/apple/work/meiso
fvm flutter clean
fvm flutter pub get
fvm flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### ステップ2: ログアウトして再ログイン

1. Meisoアプリで既存のAmberログインがある場合はログアウト
2. 「Amberでログイン」をタップ
3. Amberアプリに切り替わる

### ステップ3: パーミッションを確認・設定

Amberアプリで以下が表示されるはず：
```
Meisoが以下の権限を要求しています：
- NIP-44で復号化
- NIP-44で暗号化
- イベント署名 (kind 30078)
```

「許可」をタップ。

### ステップ4: Amberアプリでアプリリストを確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示されているか確認** ← 最重要！

表示されていれば、修正成功です 🎉

### ステップ5: パーミッションを「常に許可」に設定

Amberアプリで「Meiso」を選択し、以下を「常に許可」に設定：
- ✅ NIP-44 Decrypt
- ✅ NIP-44 Encrypt
- ✅ Sign Event (kind 30078)

### ステップ6: TODO同期テスト

1. Meisoアプリに戻る
2. TODOを同期
3. **ダイアログなしで復号化されることを確認**

期待される動作：
- 最初の数個のTODOはAmberのダイアログが表示される（初回のみ）
- その後、自動的に復号化される
- 同期が正常に完了する

### ステップ7: ログで詳細確認

```bash
# 別ターミナルでログを監視
adb logcat | grep -E "MainActivity|flutter"
```

確認ポイント：
```
✅ パーミッションJSON が完全に表示される
✅ 復号化レスポンスが正しく解析される（"Extracted result (JSON)"）
✅ EventSink経由でFlutter側にデータが送信される
✅ Flutter側で復号化成功のログが表示される
```

## ❓ トラブルシューティング

### 問題1: 復号化レスポンスが"No valid response"エラーになる

**原因**: パスの解析が失敗している

**確認方法**:
```bash
adb logcat | grep "Parsing from path"
```

以下が表示されるはず：
```
MainActivity: Parsing from path: result{"id":"..."}
MainActivity: ✅ Extracted result (JSON) from path
```

**解決策**: アプリを再ビルドして再インストール

### 問題2: Amberのアプリリストに「Meiso」が表示されない

**原因**: パーミッションが正しく送信されていない

**確認方法**:
```bash
adb logcat | grep "Launching Amber with permissions"
```

以下が表示されるはず：
```
MainActivity: 🚀 Launching Amber with permissions: [{"type":"nip44_decrypt",...}]
```

**解決策**:
- ログアウトして再ログイン
- アプリを再ビルド

### 問題3: 同期が途中で止まる（タイムアウト）

**原因**: 
- 復号化レスポンスがFlutter側に届いていない
- EventChannelの問題

**デバッグ**:
```bash
adb logcat | grep EventSink
```

以下が表示されるはず：
```
MainActivity: ✅ Sending response via EventSink immediately
```

**解決策**:
- アプリを再起動
- ログを確認してエラーメッセージを特定

## 📝 変更ファイル

1. ✅ `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt`
   - Amberレスポンスの解析を改善（JSON対応）
   - パーミッションJSON を1行に圧縮
   - 全てのリクエストに`appName`を追加
   - ログを改善

## ✨ まとめ

**この修正により**:
- ✅ Amberからの復号化レスポンスが正しく処理される
- ✅ パーミッションが完全にログに表示される
- ✅ Amber側でアプリが正しく識別される
- ✅ 「常に許可」設定後、自動復号化が機能する
- ✅ TODO同期が正常に完了する

**次のステップ**:
1. アプリをビルド＆テスト
2. Amberのアプリリストに「Meiso」が表示されることを確認
3. パーミッションを「常に許可」に設定
4. TODO同期がスムーズに動作することを確認

---

**テストしてフィードバックをお願いします！** 🙏

今回の修正で、復号化レスポンスが正しく処理され、同期が完了するはずです。

