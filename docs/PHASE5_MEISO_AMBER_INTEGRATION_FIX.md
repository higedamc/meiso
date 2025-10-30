# Phase 5: Meiso側のAmber統合修正

## 🎯 問題と解決策

### 発見された問題

1. **復号化は成功している**（44個すべてのTODOが復号化された）✅
2. **Meisoアプリにフォールバックしない**（Amberの画面のまま）❌
3. **Amberのアプリリストに「Meiso」が登録されない**❌

### 根本原因

Amberのソースコードを詳細に調査した結果、以下が判明しました：

**Amberの実装**:
- Amberは`callingPackage`（Androidシステムが提供）のみを使用してアプリを識別
- `Intent.ACTION_VIEW`で起動された場合、**`callingPackage`は`null`になる**（セキュリティ上の理由）
- NIP-55はURL形式（`nostrsigner:...`）を使用するため、`ACTION_VIEW`が必要
- その結果、`packageName = null`となり、アプリ登録が失敗

**Amberの`sendResult()`関数**（639行目）:
```kotlin
639: if (packageName != null) {
640:     database.dao().insertApplicationWithPermissions(application)  // アプリ登録
     ...
662:     activity?.setResult(RESULT_OK, intent)  // setResult()で返す
665:     activity?.finish()
666: } else if (!intentData.callBackUrl.isNullOrBlank()) {
     // この分岐には insertApplicationWithPermissions() がない！
670:     context.startActivity(intent)  // callbackUrlでリダイレクト
```

- `packageName = null`の場合、`callbackUrl`分岐に入る
- この分岐にはアプリ登録のコードがない
- そのため、Meisoが登録されない

### 解決策：`startActivityForResult()`を使用

**アプローチ**:
- Meisoは自分のプロジェクトなので、**Meiso側を修正する**
- `startActivity()`を`startActivityForResult()`に変更
- これにより、Androidシステムが`callingPackage`を正しく設定
- Amberが`packageName != null`の分岐に入り、アプリ登録が成功

## 🔧 実施した修正

### 修正1: リクエストコードの追加（21行目）

**ファイル**: `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt`

```kotlin
class MainActivity : FlutterActivity() {
    private val AMBER_CHANNEL = "jp.godzhigella.meiso/amber"
    private val AMBER_EVENT_CHANNEL = "jp.godzhigella.meiso/amber_events"
    private var amberMethodChannel: MethodChannel? = null
    private var amberEventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingResult: MethodChannel.Result? = null
    private var bufferedResponse: Map<String, Any?>? = null
    private var pendingIntent: Intent? = null
    
    // Amberリクエスト用のリクエストコード
    private val AMBER_REQUEST_CODE = 1001  // ← 追加
```

### 修正2: `startActivity()`を`startActivityForResult()`に変更

#### 2-1. `getPublicKey`（92-116行目）

**修正前**:
```kotlin
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = android.net.Uri.parse("nostrsigner:")
    `package` = "com.greenart7c3.nostrsigner"
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)  // ← 削除
    putExtra("type", "get_public_key")
    putExtra("callbackUrl", "meiso://result")  // ← 削除（不要）
    putExtra("package", currentPackage)
    putExtra("appName", "Meiso")
    putExtra("permissions", permissionsJson)
}

startActivity(intent)  // ← 変更
```

**修正後**:
```kotlin
// startActivityForResult()を使用することで、Amberが callingPackage を取得でき、
// アプリ登録とパーミッション管理が正常に動作する
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = android.net.Uri.parse("nostrsigner:")
    `package` = "com.greenart7c3.nostrsigner"
    // addFlags削除（startActivityForResult()では不要）
    putExtra("type", "get_public_key")
    // callbackUrl削除（setResult()で返されるため不要）
    putExtra("package", currentPackage)
    putExtra("appName", "Meiso")
    putExtra("permissions", permissionsJson)
}

@Suppress("DEPRECATION")
startActivityForResult(intent, AMBER_REQUEST_CODE)
```

#### 2-2. `signEventWithAmber`（130-148行目）

**修正内容**:
- `addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)`を削除
- `callbackUrl`を削除
- `startActivity()`を`startActivityForResult()`に変更

#### 2-3. `encryptNip44WithAmber`（164-182行目）

**修正内容**: 同上

#### 2-4. `decryptNip44WithAmber`（198-216行目）

**修正内容**: 同上

### 修正3: `onActivityResult()`の実装（267-342行目）

**新規追加**:

```kotlin
@Deprecated("Deprecated in Java")
override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    
    android.util.Log.d("MainActivity", "🎯 onActivityResult called - requestCode: $requestCode, resultCode: $resultCode")
    
    if (requestCode == AMBER_REQUEST_CODE) {
        if (resultCode == RESULT_OK && data != null) {
            android.util.Log.d("MainActivity", "✅ Amber returned successfully")
            
            // Amberから返されたデータを取得（Intent.extras）
            val pubkey = data.getStringExtra("pubkey")
            val result = data.getStringExtra("result") ?: data.getStringExtra("signature")
            val signedEvent = data.getStringExtra("event")
            val id = data.getStringExtra("id")
            val error = data.getStringExtra("error")
            val rejected = data.getStringExtra("rejected")
            
            when {
                rejected != null -> {
                    // ユーザーが拒否
                    pendingResult?.error("AMBER_REJECTED", "User rejected the request", null)
                    eventSink?.error("AMBER_REJECTED", "User rejected the request", null)
                }
                error != null -> {
                    // エラー発生
                    pendingResult?.error("AMBER_ERROR", error, null)
                    eventSink?.error("AMBER_ERROR", error, null)
                }
                pubkey != null || result != null || signedEvent != null -> {
                    // 成功レスポンス
                    val response = mapOf(
                        "pubkey" to pubkey,
                        "result" to result,
                        "signature" to result,
                        "event" to signedEvent,
                        "id" to id
                    )
                    
                    pendingResult?.success(response)
                    eventSink?.success(response)
                }
                else -> {
                    pendingResult?.error("AMBER_ERROR", "No valid response from Amber", null)
                    eventSink?.error("AMBER_ERROR", "No valid response from Amber", null)
                }
            }
            
            pendingResult = null
        } else {
            // キャンセルまたはエラー
            pendingResult?.error("AMBER_CANCELLED", "Request was cancelled", null)
            eventSink?.error("AMBER_CANCELLED", "Request was cancelled", null)
            pendingResult = null
        }
    }
}
```

**動作**:
- Amberが`setResult()`で結果を返す
- `onActivityResult()`がコールバックされる
- `Intent.extras`からデータを取得
- Flutter側に結果を返す（MethodChannel & EventChannel）

## 📊 修正の効果

### 1. アプリ登録の成功 ✅

- `startActivityForResult()`により、`callingPackage`が正しく設定される
- Amberの`packageName != null`の分岐に入る
- `insertApplicationWithPermissions()`が実行される
- **Amberのアプリリストに「Meiso」が登録される**

### 2. Meisoへの自動フォールバック ✅

- Amberが`setResult()`と`finish()`を実行（665行目）
- Meisoアプリが自動的にフォアグラウンドに戻る
- `onActivityResult()`が呼ばれ、結果が処理される

### 3. パーミッション管理の有効化 ✅

アプリが登録されることで：
- Amberの「設定 → 接続済みアプリ」に「Meiso」が表示される
- パーミッション設定が可能になる：
  - ✅ NIP-44 Decrypt → 常に許可
  - ✅ NIP-44 Encrypt → 常に許可
  - ✅ イベント署名 (kind 30078) → 常に許可

### 4. 復号化承認タップの削減 ✅

パーミッションを「常に許可」に設定することで：
- 44個のTODOを同期する際に、44回の承認タップが不要になる
- Amberは自動的に復号化を承認し、Meisoに結果を返す

## 🧪 テスト手順

### ステップ1: Meisoアプリをビルド

```bash
cd /Users/apple/work/meiso
flutter build apk --debug
```

または、Android Studioで「Run」します。

### ステップ2: Meisoアプリでログアウト

既存のAmber接続をクリアするため、Meisoアプリでログアウトします。

### ステップ3: Amber経由で再ログイン

1. Meisoアプリを起動
2. 「Amberでログイン」をタップ
3. Amberアプリに切り替わる
4. パーミッション要求が表示される：
   ```
   Meisoが以下の権限を要求しています：
   - NIP-44で復号化
   - NIP-44で暗号化
   - イベント署名 (kind 30078)
   ```
5. 「許可」をタップ
6. **Meisoアプリに自動的に戻る** ✅

### ステップ4: ログで確認

```bash
adb logcat | grep MainActivity
```

以下のログが表示されるはずです：

```
MainActivity: 🚀 Launching Amber with startActivityForResult (permissions: [...])
MainActivity: 🎯 onActivityResult called - requestCode: 1001, resultCode: -1
MainActivity: ✅ Amber returned successfully
MainActivity: Amber returned - pubkey: npub1...
MainActivity: ✨ Result sent to Flutter
```

### ステップ5: Amberアプリでアプリリストを確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示されているか確認** ✅

表示されていれば、修正成功です！

### ステップ6: パーミッションを「常に許可」に設定

Amberアプリで「Meiso」を選択し、以下を「常に許可」に設定：
- ✅ NIP-44 Decrypt
- ✅ NIP-44 Encrypt
- ✅ イベント署名 (kind 30078)

### ステップ7: TODO同期テスト

1. Meisoアプリに戻る
2. TODOを同期
3. **ダイアログなしで復号化されることを確認** ✅
4. **同期完了後もMeisoアプリが表示されたまま** ✅

## ❓ トラブルシューティング

### 問題1: Amberのアプリリストに「Meiso」が表示されない

**確認事項**:
1. ログに`startActivityForResult`が表示されているか
2. `onActivityResult`がコールバックされているか
3. Amberアプリが最新版か

**デバッグ**:
```bash
adb logcat | grep "startActivityForResult\|onActivityResult"
```

### 問題2: 復号化時に毎回ダイアログが表示される

**原因**: パーミッションが「常に許可」に設定されていない

**解決策**: Amberアプリで「Meiso」のパーミッションを確認し、「常に許可」に設定

### 問題3: `onActivityResult`が呼ばれない

**原因**: `FLAG_ACTIVITY_NEW_TASK`が設定されている可能性

**解決策**: `FLAG_ACTIVITY_NEW_TASK`を削除（既に修正済み）

### 問題4: `DEPRECATION`警告が表示される

**これは正常です**:
- `startActivityForResult()`はAPI 30+で非推奨
- しかし、FlutterActivityでは動作する
- `@Suppress("DEPRECATION")`で警告を抑制

将来的には`registerForActivityResult()`に移行することを推奨しますが、現時点では`startActivityForResult()`で十分です。

## 📝 技術的な詳細

### `startActivity()`vs `startActivityForResult()`

| 項目 | startActivity() | startActivityForResult() |
|------|-----------------|---------------------------|
| callingPackage | null | 正しく設定される |
| コールバック | onNewIntent() | onActivityResult() |
| 戻り方 | メソッドで指定（callbackUrl） | 自動（finish()） |
| アプリ登録 | 失敗（packageName=null） | 成功 |

### NIP-55との互換性

- NIP-55は`Intent.ACTION_VIEW`を規定している
- `startActivityForResult()`でも`ACTION_VIEW`は使用可能
- Androidネイティブアプリの場合、`startActivityForResult()`がベストプラクティス

### セキュリティ上の考慮事項

`startActivityForResult()`を使用することで：
- Androidシステムが呼び出し元を検証
- 偽装が困難になる（`callingPackage`はシステムが設定）
- Amberのパーミッション管理が正しく機能

## 🎉 まとめ

この修正により：
1. ✅ Meisoが「Meiso」としてAmberのアプリリストに登録される
2. ✅ パーミッション管理が有効になり、「常に許可」が設定できる
3. ✅ TODO同期時の承認タップが不要になる（44回 → 0回）
4. ✅ 操作後にMeisoアプリに自動的に戻る

**重要なポイント**:
- Amberの仕様に合わせて**Meiso側を修正**
- `startActivityForResult()`を使用することで、Amberの標準的なアプリ登録フローに乗る
- 外部プロジェクト（Amber）を修正する必要がない

これで、AmberとMeisoの統合が完全に機能するようになります！ 🚀

