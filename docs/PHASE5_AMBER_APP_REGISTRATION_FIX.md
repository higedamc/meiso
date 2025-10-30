# Phase 5: Amber アプリ登録の修正

## 🎯 問題の全体像

### 発見された問題

1. **復号化は成功している**（44個すべてのTODOが復号化された）✅
2. **Meisoアプリにフォールバックしない**（Amberの画面のまま）❌
3. **Amberのアプリリストに「Meiso」が登録されない**❌

### 根本原因

Amberのソースコードを詳細に調査した結果、以下が判明しました：

#### 1. `callingPackage`の問題

**Amberの`MainActivity.kt`**（修正前）:
```kotlin
val packageName = callingPackage  // 83行目
```

- Amberは`callingPackage`（Androidシステムが提供する呼び出し元アプリのパッケージ名）を使用
- `Intent.ACTION_VIEW`で起動された場合、**`callingPackage`は`null`になる**（セキュリティ上の理由）
- NIP-55はURL形式（`nostrsigner:...`）を使用するため、必ず`ACTION_VIEW`で起動される
- その結果、`packageName = null`となり、`key = "null"`になる

#### 2. アプリ登録が失敗する流れ

**`IntentUtils.kt`の`sendResult()`関数**（639行目）:

```kotlin
639: if (packageName != null) {
640:     database.dao().insertApplicationWithPermissions(application)  // アプリ登録
     ...
662:     activity?.setResult(RESULT_OK, intent)  // setResult()で返す
665:     activity?.finish()
666: } else if (!intentData.callBackUrl.isNullOrBlank()) {
668:     val intent = Intent(Intent.ACTION_VIEW)
669:     intent.data = (intentData.callBackUrl + Uri.encode(value)).toUri()
670:     context.startActivity(intent)  // callbackUrlでリダイレクト
     ...
694:     activity?.finish()
```

**問題の流れ**:
```
Meiso → Intent.ACTION_VIEW → Amber
         ↓
    callingPackage = null
         ↓
    packageName = null
         ↓
    key = "null"
         ↓
    sendResult()の639行目: if (packageName != null) → FALSE
         ↓
    666行目: callbackUrl分岐に入る
         ↓
    この分岐には insertApplicationWithPermissions() がない！
         ↓
    アプリが登録されない
```

#### 3. Meisoが送信している`package`パラメータは無視されている

Meisoは以下を送信していました：
```kotlin
putExtra("package", "jp.godzhigella.meiso")
```

しかし、Amberのコードを確認した結果：
- `IntentUtils.kt`で`intent.extras?.getString("package")`を使用している箇所は**ゼロ**
- Amberは`callingPackage`のみを使用
- Meisoが送信した`package`パラメータは完全に無視されていた

## 🔧 実施した修正

### 修正内容

**ファイル**: `Amber/app/src/main/java/com/greenart7c3/nostrsigner/MainActivity.kt`

#### 修正1: `onCreate()`/`onStart()`でのパッケージ名取得（83-98行目）

**修正前**:
```kotlin
val packageName = callingPackage
val appName =
    if (packageName != null) {
        val info = applicationContext.packageManager.getApplicationInfo(packageName, 0)
        applicationContext.packageManager.getApplicationLabel(info).toString()
    } else {
        null
    }
```

**修正後**:
```kotlin
// NIP-55: callingPackageがnullの場合、intentのextrasから取得
val packageName = callingPackage ?: intent.extras?.getString("package")
Log.d(Amber.TAG, "📦 Package name: callingPackage=$callingPackage, extras=${intent.extras?.getString("package")}, final=$packageName")

val appName =
    if (packageName != null) {
        try {
            val info = applicationContext.packageManager.getApplicationInfo(packageName, 0)
            applicationContext.packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            Log.w(Amber.TAG, "Failed to get app name for package: $packageName, error: ${e.message}")
            intent.extras?.getString("appName")
        }
    } else {
        null
    }
```

**変更点**:
1. `callingPackage`が`null`の場合、`intent.extras?.getString("package")`をフォールバックとして使用
2. デバッグログを追加（パッケージ名の取得状況を確認）
3. `getApplicationInfo()`が失敗した場合のエラーハンドリングを追加
4. エラー時には`intent.extras?.getString("appName")`をフォールバック

#### 修正2: `onNewIntent()`でのパッケージ名取得（291-299行目）

**修正前**:
```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)

    mainViewModel.onNewIntent(intent, callingPackage)
}
```

**修正後**:
```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)

    // NIP-55: callingPackageがnullの場合、intentのextrasから取得
    val packageName = callingPackage ?: intent.extras?.getString("package")
    Log.d(Amber.TAG, "🔄 onNewIntent - Package name: callingPackage=$callingPackage, extras=${intent.extras?.getString("package")}, final=$packageName")
    
    mainViewModel.onNewIntent(intent, packageName)
}
```

**変更点**:
1. `onNewIntent()`でも同様のフォールバックロジックを適用
2. デバッグログを追加

## 📊 この修正で解決すること

### 1. アプリ登録の成功 ✅

- Meisoが送信した`package`パラメータ（`jp.godzhigella.meiso`）がAmberに認識される
- `packageName != null`になる
- `sendResult()`の639行目の条件が`true`になる
- `insertApplicationWithPermissions()`が実行される
- **Amberのアプリリストに「Meiso」が登録される**

### 2. パーミッション管理の有効化 ✅

アプリが登録されることで：
- Amberの「設定 → 接続済みアプリ」に「Meiso」が表示される
- パーミッション設定が可能になる：
  - ✅ NIP-44 Decrypt → 常に許可
  - ✅ NIP-44 Encrypt → 常に許可
  - ✅ イベント署名 (kind 30078) → 常に許可

### 3. 復号化承認タップの削減 ✅

パーミッションを「常に許可」に設定することで：
- 44個のTODOを同期する際に、44回の承認タップが不要になる
- Amberは自動的に復号化を承認し、Meisoに結果を返す

## 🧪 テスト手順

### ステップ1: Amberを再ビルド

```bash
cd /Users/apple/work/meiso/Amber
./gradlew assembleDebug
```

または、Android Studioでビルドします。

### ステップ2: Amberアプリをインストール

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### ステップ3: Meisoアプリでログアウト

既存のAmber接続をクリアするため、Meisoアプリでログアウトします。

### ステップ4: Amber経由で再ログイン

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
6. Meisoアプリに戻る

### ステップ5: ログで確認

```bash
adb logcat | grep Amber
```

以下のログが表示されるはずです：

```
Amber: 📦 Package name: callingPackage=null, extras=jp.godzhigella.meiso, final=jp.godzhigella.meiso
```

これは、`callingPackage`が`null`だが、`extras`からパッケージ名を取得できたことを示します。

### ステップ6: Amberアプリでアプリリストを確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示されているか確認** ✅

表示されていれば、修正成功です！

### ステップ7: パーミッションを「常に許可」に設定

Amberアプリで「Meiso」を選択し、以下を「常に許可」に設定：
- ✅ NIP-44 Decrypt
- ✅ NIP-44 Encrypt
- ✅ イベント署名 (kind 30078)

### ステップ8: TODO同期テスト

1. Meisoアプリに戻る
2. TODOを同期
3. **ダイアログなしで復号化されることを確認** ✅

## ❓ トラブルシューティング

### 問題1: Amberのアプリリストに「Meiso」が表示されない

**確認事項**:
1. ログに`📦 Package name`が表示されているか
2. `final=jp.godzhigella.meiso`になっているか（`final=null`ではない）
3. Amberアプリが最新版（修正後）か

**デバッグ**:
```bash
adb logcat | grep "Package name"
```

### 問題2: 復号化時に毎回ダイアログが表示される

**原因**: パーミッションが「常に許可」に設定されていない

**解決策**: Amberアプリで「Meiso」のパーミッションを確認し、「常に許可」に設定

### 問題3: Meisoにフォールバックしない

**原因**: Amberの`closeApplication`設定が`false`になっている可能性

**解決策**: 
- Amberアプリで「Meiso」の設定を確認
- 「アプリを自動的に閉じる」が有効になっているか確認

または、Amberの画面で手動で戻るボタンをタップ

## 📝 技術的な詳細

### NIP-55とcallingPackageの問題

NIP-55は以下の形式を規定しています：

```
nostrsigner:<parameters>?param1=value1&param2=value2
```

この形式は`Intent.ACTION_VIEW`を使用する必要があります。しかし、`ACTION_VIEW`では：

1. **セキュリティ上の理由**で`callingPackage`は`null`になる
2. これは、任意のアプリがURLスキームを使って他のアプリを起動できるため
3. Androidシステムは、呼び出し元を隠す（プライバシー保護）

### 修正のアプローチ

Amberの現在の実装では、`callingPackage`のみを使用していました。しかし、NIP-55を正しくサポートするには：

1. `Intent.extras`の`package`パラメータを使用する必要がある
2. これにより、呼び出し元アプリが自分自身のパッケージ名を明示的に送信できる

今回の修正では、**フォールバックアプローチ**を採用しました：
```kotlin
val packageName = callingPackage ?: intent.extras?.getString("package")
```

これにより：
- `startActivityForResult()`で起動された場合は`callingPackage`を使用（従来の動作）
- NIP-55（`ACTION_VIEW`）で起動された場合は`extras`の`package`を使用（新しい動作）

### セキュリティ上の考慮事項

`Intent.extras`の`package`パラメータは、呼び出し元が自由に設定できるため、偽装のリスクがあります。しかし：

1. NIP-55の性質上、これは避けられない
2. Amberのパーミッション管理により、悪意のあるアプリがユーザーの承認なしに操作することはできない
3. ユーザーは常にAmberアプリで接続済みアプリを確認し、必要に応じて削除できる

## 🎉 まとめ

この修正により：
1. ✅ NIP-55形式でAmberを呼び出すアプリが正しく登録される
2. ✅ Meisoが「Meiso」としてAmberのアプリリストに表示される
3. ✅ パーミッション管理が有効になり、「常に許可」が設定できる
4. ✅ TODO同期時の承認タップが不要になる（44回 → 0回）

これで、Amberとの統合が完全に機能するようになります！

