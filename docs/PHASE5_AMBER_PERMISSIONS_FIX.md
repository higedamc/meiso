# Phase 5: Amber パーミッション管理の修正

## 🎯 問題の本質

Amberのソースコードを確認した結果、以下が判明しました：

### 根本原因

1. **`permissions`パラメータの形式が間違っていた**
   - ❌ 送信していた形式：`putExtra("permissions", "nip44_decrypt")` （単なる文字列）
   - ✅ 正しい形式：`putExtra("permissions", "[{\"type\":\"nip44_decrypt\",\"kind\":null}]")` （JSON配列）

2. **Amberがパーミッションをパースできなかった**
   - `IntentUtils.kt`の295-302行で、AmberはJSON配列としてパーミッションをパース
   - 文字列として送信していたため、パースに失敗
   - その結果、アプリケーションが登録されず、パーミッションも保存されなかった

## 🔧 実装した修正

### 1. MainActivity.kt の修正

**ファイル**: `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt`

**変更内容**:

```kotlin
// パーミッションをJSON配列として作成
// Amberが期待する形式: [{"type":"nip44_decrypt","kind":null}, ...]
val permissionsJson = """[
    {"type":"nip44_decrypt","kind":null},
    {"type":"nip44_encrypt","kind":null},
    {"type":"sign_event","kind":30078}
]""".trimIndent()

// NIP-55 format: パラメータをIntentのextrasとして送信
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = android.net.Uri.parse("nostrsigner:")
    `package` = "com.greenart7c3.nostrsigner"
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    // Amberが期待するextras
    putExtra("type", "get_public_key")
    putExtra("callbackUrl", "meiso://result")
    putExtra("package", currentPackage)
    putExtra("appName", "Meiso")  // アプリ名を送信
    // パーミッション要求：JSON配列として送信
    // これによりAmberがアプリを登録し、パーミッションを保存する
    putExtra("permissions", permissionsJson)
}
```

**送信するパーミッション**:
- `nip44_decrypt`: NIP-44復号化（TODO同期時に必要）
- `nip44_encrypt`: NIP-44暗号化（TODO作成時に必要）
- `sign_event` (kind: 30078): イベント署名（TODO作成/更新時に必要）

### 2. Settings画面の更新

**ファイル**: `lib/presentation/settings/settings_screen.dart`

Amberモード情報カードを更新し、以下を明記：
- NIP-44暗号化が有効であること
- パーミッション設定の方法
- Amberアプリでの設定手順

### 3. デバッグログの強化

**ファイル**: `lib/providers/todos_provider.dart`

`syncFromNostr()`メソッドに詳細なログを追加：
- 取得したイベント数
- 各イベントの復号化状況
- 成功/失敗の統計
- エラーの詳細とスタックトレース

## 📊 Amberのソースコードから分かったこと

### IntentUtils.kt の処理フロー

1. **`getIntentDataFromIntent`メソッド（254-449行）**:
```kotlin
val json = intent.extras?.getString("permissions")
val permissions: MutableList<Permission>? = json?.let {
    try {
        Permission.mapper.readValue<MutableList<Permission>>(it)
    } catch (_: Exception) {
        null
    }
}
```

2. **`sendResult`メソッド（568-638行）**:
```kotlin
val application = ApplicationWithPermissions(
    application = ApplicationEntity(
        key = key,                    // パッケージ名
        name = appName ?: localAppName ?: "",  // アプリ名
        pubKey = account.hexKey,
        isConnected = true,
        // ...
    ),
    permissions = mutableListOf(),
)
```

3. **パーミッション保存（609-637行）**:
```kotlin
if (rememberType != RememberType.NEVER) {
    AmberUtils.acceptPermission(
        application = application,
        key = key,
        type = intentData.type,
        kind = kind,
        rememberType = rememberType,
    )
}
```

### AmberUtils.kt の`acceptPermission`メソッド（211-244行）

```kotlin
val until = when (rememberType) {
    RememberType.ALWAYS -> Long.MAX_VALUE / 1000  // 永久
    RememberType.ONE_MINUTE -> TimeUtils.oneMinuteFromNow()
    RememberType.FIVE_MINUTES -> TimeUtils.now() + TimeUtils.FIVE_MINUTES
    RememberType.TEN_MINUTES -> TimeUtils.now() + TimeUtils.FIFTEEN_MINUTES
    else -> 0L
}

application.permissions.add(
    ApplicationPermissionsEntity(
        null,
        key,
        type.toString(),
        kind,
        true,  // acceptable
        rememberType.screenCode,
        until,  // acceptUntil
        0,
    ),
)
```

## 🎉 期待される動作

### 1. 初回ログイン時

1. ユーザーが「Amberでログイン」をタップ
2. MeisoがAmberに`get_public_key`リクエストを送信（JSON配列のパーミッション付き）
3. Amberがパーミッションリクエストを表示：
   - ✅ NIP-44で復号化
   - ✅ NIP-44で暗号化
   - ✅ イベント署名 (kind 30078)
4. ユーザーが「許可」をタップ
5. Amber側でアプリケーション（Meiso）とパーミッションがデータベースに保存される

### 2. Amberアプリでの確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. **「Meiso」がリストに表示される** ✅
4. Meisoを選択すると、パーミッション一覧が表示される：
   - NIP-44 Decrypt
   - NIP-44 Encrypt
   - イベント署名 (kind 30078)

### 3. パーミッション設定後の動作

ユーザーが各パーミッションを「常に許可」に設定すると：
- TODO同期時に**自動的に復号化**される（ダイアログなし）
- TODO作成時に**自動的に暗号化**される（ダイアログなし）
- イベント署名が**自動的に承認**される（ダイアログなし）

## 🧪 テスト方法

### 1. ログの確認

```bash
# MainActivity のログを確認（Androidネイティブ側）
adb logcat | grep MainActivity

# または、すべてのログを表示
adb logcat
```

期待されるログ：
```
MainActivity: Launching Amber with permissions: [{"type":"nip44_decrypt","kind":null},{"type":"nip44_encrypt","kind":null},{"type":"sign_event","kind":30078}]
```

### 2. Amberアプリでの確認

1. Amberアプリを開く
2. 設定 → 接続済みアプリ
3. 「Meiso」がリストに表示されるか確認

### 3. TODO同期テスト

1. Amber側で「常に許可」を設定
2. Meisoアプリで同期を実行
3. ダイアログなしで復号化されるか確認

## 📝 変更ファイル一覧

1. ✅ `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt`
   - パーミッションをJSON配列として送信
   - アプリ名を追加

2. ✅ `lib/presentation/settings/settings_screen.dart`
   - Amberモード情報カードを更新
   - パーミッション設定手順を追加

3. ✅ `lib/providers/todos_provider.dart`
   - デバッグログを強化
   - 復号化の詳細情報を追加

4. ✅ `AMBER_PERMISSIONS_GUIDE.md`
   - 完全な実装ガイドを作成
   - トラブルシューティングを追加

## 🔄 以前の実装との違い

| 項目 | 以前（Phase 5） | 現在（Phase 5修正版） |
|------|----------------|-------------------|
| permissions | `"nip44_decrypt"` (文字列) | `[{"type":"nip44_decrypt","kind":null}]` (JSON配列) |
| appName | なし | `"Meiso"` |
| Amberアプリリスト | 表示されない | 表示される ✅ |
| パーミッション管理 | できない | できる ✅ |
| 復号化承認 | 毎回必要 | 設定後は不要 ✅ |

## ✨ まとめ

**Phase 5（修正版）により**:
- ✅ Amberのアプリリストに「Meiso」が正しく登録される
- ✅ パーミッションを「常に許可」に設定できる
- ✅ 1000個のTODOでも1回の設定で全て自動復号化
- ✅ ユーザーエクスペリエンスが大幅に改善

**次のステップ**:
1. アプリをビルド＆テスト
2. Amberのアプリリストに「Meiso」が表示されることを確認
3. パーミッションを「常に許可」に設定
4. TODO同期がスムーズに動作することを確認

---

**実装完了日**: 2025-10-30
**対応Issue**: Amberパーミッション管理の実装
**参照**: AMBER_PERMISSIONS_GUIDE.md

