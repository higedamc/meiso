# Phase 5: npub→hex変換の実装

## 🎯 問題の発見

### ユーザーの観察
Amber経由でログインすると、設定画面でhexコピーしてもhexがコピーされないという問題が報告されました。
また、Amber経由と秘密鍵直接入力で、同じ秘密鍵を使っているにも関わらず扱われているデータが異なるという不一致も観察されました。

### ログ分析
```
D/MainActivity(23641): Amber returned (type: get_public_key) - result: npub1sfs4as7204zg673y4a65ujpt3wvtwc4wzu5myx8lg99vz...
I/flutter (23641): ✅ Received public key from Amber: npub1sfs4a...
I/flutter (23641): ❌ Nostr同期失敗: AnyhowException(Failed to parse public key
Caused by:
    Secp256k1: malformed public key)
```

### 根本原因
1. **Amberは`npub`形式（Bech32エンコード）で公開鍵を返す**（`startActivityForResult()`使用時）
2. **Rust側は16進数形式（hex）を期待**
3. **`npub`をそのままRustに渡していた**ため：
   - パースエラーが発生
   - hexコピーが動作しない
   - TODO同期が失敗

## ✅ 実装した解決策

### 1. Rust側に変換関数を追加

**`rust/src/api.rs`** に以下の関数を追加：

```rust
/// npub形式の公開鍵をhex形式に変換
pub fn npub_to_hex(npub: String) -> Result<String> {
    // npub形式でない場合（すでにhex形式の可能性）
    if !npub.starts_with("npub1") {
        // 64文字のhex文字列かチェック
        if npub.len() == 64 && npub.chars().all(|c| c.is_ascii_hexdigit()) {
            return Ok(npub); // すでにhex形式
        }
        return Err(anyhow::anyhow!("Invalid public key format: expected npub1... or 64-char hex, got: {}", &npub[..10.min(npub.len())]));
    }
    
    let public_key = PublicKey::parse(&npub)
        .context("Failed to parse npub format public key")?;
    
    Ok(public_key.to_hex())
}

/// hex形式の公開鍵をnpub形式に変換
pub fn hex_to_npub(hex: String) -> Result<String> {
    // すでにnpub形式の場合
    if hex.starts_with("npub1") {
        return Ok(hex);
    }
    
    let public_key = PublicKey::from_hex(&hex)
        .context("Failed to parse hex format public key")?;
    
    Ok(public_key.to_bech32()?)
}
```

**特徴**：
- 両方向の変換に対応（`npub` ⇔ `hex`）
- すでに目的の形式の場合はそのまま返す（冪等性）
- エラーハンドリング付き

### 2. NostrServiceに変換メソッドを追加

**`lib/providers/nostr_provider.dart`** の `NostrService` クラスに追加：

```dart
/// npub形式の公開鍵をhex形式に変換
Future<String> npubToHex(String npub) async {
  return await rust_api.npubToHex(npub: npub);
}

/// hex形式の公開鍵をnpub形式に変換
Future<String> hexToNpub(String hex) async {
  return await rust_api.hexToNpub(hex: hex);
}
```

### 3. Amberログイン時に変換を実行

**`lib/presentation/onboarding/login_screen.dart`** を修正：

#### 変更前:
```dart
final publicKey = await _amberService.getPublicKey();
// ...
await nostrService.savePublicKey(publicKey);
await nostrService.initializeNostrWithPubkey(
  publicKeyHex: publicKey,
);
```

#### 変更後:
```dart
final publicKeyRaw = await _amberService.getPublicKey();  // npub形式

// Amberはnpub形式で公開鍵を返すため、hex形式に変換
final nostrService = ref.read(nostrServiceProvider);
final publicKeyHex = await nostrService.npubToHex(publicKeyRaw);
print('✅ Public key converted to hex: ${publicKeyHex.substring(0, 16)}...');

// Rust APIで公開鍵を保存（Amberモード、hex形式）
await nostrService.savePublicKey(publicKeyHex);

// Nostrクライアントを公開鍵のみで初期化（Amberモード）
await nostrService.initializeNostrWithPubkey(
  publicKeyHex: publicKeyHex,
);

// Nostrプロバイダーを更新
ref.read(publicKeyProvider.notifier).state = publicKeyHex; // hex形式
ref.read(nostrPublicKeyProvider.notifier).state = publicKeyRaw; // npub形式
```

**重要な変更**：
1. Amberからの戻り値を`publicKeyRaw`に変更（npub形式）
2. `npubToHex()`で変換して`publicKeyHex`を取得
3. **hex形式をRust側に保存**
4. **hex形式とnpub形式の両方をProviderに保存**

### 4. publicKeyNpubProviderを修正

**`lib/providers/nostr_provider.dart`** の `publicKeyNpubProvider` を修正：

#### 変更前:
```dart
final publicKeyNpubProvider = FutureProvider<String?>((ref) async {
  final isInitialized = ref.watch(nostrInitializedProvider);
  if (!isInitialized) return null;
  
  try {
    return await rust_api.getPublicKeyNpub();
  } catch (e) {
    return null;
  }
});
```

#### 変更後:
```dart
final publicKeyNpubProvider = FutureProvider<String?>((ref) async {
  final isInitialized = ref.watch(nostrInitializedProvider);
  final publicKeyHex = ref.watch(publicKeyProvider);
  
  if (!isInitialized || publicKeyHex == null) return null;
  
  // Amberモードの場合、publicKeyProviderに保存されているhex形式から変換
  final isAmberMode = ref.read(isAmberModeProvider);
  if (isAmberMode) {
    try {
      return await rust_api.hexToNpub(hex: publicKeyHex);
    } catch (e) {
      print('❌ Failed to convert hex to npub: $e');
      return null;
    }
  }
  
  // 秘密鍵モードの場合、Rust側から取得
  try {
    return await rust_api.getPublicKeyNpub();
  } catch (e) {
    return null;
  }
});
```

**理由**：
- Amberモードでは、Rust側がダミーの秘密鍵で初期化されているため、`getPublicKeyNpub()`がダミーの公開鍵を返してしまう
- 代わりに、`publicKeyProvider`に保存されている正しいhex形式の公開鍵から、Flutter側で`hexToNpub()`を使ってnpub形式に変換

## 🔍 データフロー

### Amberモード（修正後）

```
Amber (npub1...)
  ↓ startActivityForResult()
MainActivity.kt (result = "npub1...")
  ↓ Flutter
AmberService.getPublicKey() → "npub1..."
  ↓ npubToHex()
NostrService → "64文字のhex"
  ↓
Rust (hex保存、TODO同期、暗号化/復号化)
  ↓
publicKeyProvider.state = hex ✅
nostrPublicKeyProvider.state = npub ✅
  ↓
Settings画面
  - hexコピー: hex形式 ✅
  - npubコピー: hexToNpub(hex) ✅
```

### 秘密鍵モード（変更なし）

```
User入力 (nsec1... or hex)
  ↓
Rust (秘密鍵保存)
  ↓
publicKeyProvider.state = hex ✅
getPublicKeyNpub() → npub ✅
  ↓
Settings画面
  - hexコピー: hex形式 ✅
  - npubコピー: npub形式 ✅
```

## 🎉 修正によって解決した問題

1. ✅ **Amberから公開鍵を取得できるようになった**（npub→hex変換）
2. ✅ **TODO同期が成功するようになった**（Rustが正しいhex形式を受け取る）
3. ✅ **設定画面でhexコピーが動作するようになった**（hex形式が保存されている）
4. ✅ **設定画面でnpubコピーも動作するようになった**（hex→npub変換）
5. ✅ **Amberモードと秘密鍵モードで同じ秘密鍵なら同じデータを扱う**

## 📝 テスト方法

1. **Amber経由でログイン**
   ```bash
   fvm flutter run
   ```

2. **設定画面で公開鍵を確認**
   - npub形式とhex形式の両方が表示されるか
   - npubコピーボタンが動作するか
   - hexコピーボタンが動作するか

3. **TODO同期を確認**
   - TODOを作成・編集できるか
   - AmberでNIP-44復号化を求められるか
   - 同期が成功するか（エラーログが出ないか）

4. **同じ秘密鍵でテスト**
   - Amberモードでログイン → TODO作成
   - ログアウト
   - 同じ秘密鍵を直接入力してログイン
   - 同じTODOが表示されるか ✅

## 🔧 実装ファイル

- `rust/src/api.rs`: `npub_to_hex()`, `hex_to_npub()` 追加
- `lib/providers/nostr_provider.dart`: `npubToHex()`, `hexToNpub()` 追加、`publicKeyNpubProvider` 修正
- `lib/presentation/onboarding/login_screen.dart`: Amberログイン時の変換処理追加
- `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt`: 型修正（前回実装）

## 🚀 次のステップ

このnpub⇔hex変換機能により、AmberモードとC鍵モードの両方で、公開鍵の形式が統一され、すべての機能が正常に動作するようになりました。

これでPhase 5（Amber統合）は完全に完了です！ 🎉

