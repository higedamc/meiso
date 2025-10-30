# Amber署名後のオンボーディング画面リダイレクト問題 - 修正完了

**修正日**: 2025年10月30日  
**ステータス**: ✅ 完了  
**問題**: Amber署名後に必ずオンボーディング画面に戻ってしまう

---

## 🔍 問題の根本原因

### 問題の症状
- Amberで公開鍵取得/署名後、必ず「Meisoへようこそ」（onboarding画面）に戻る
- ホーム画面に遷移できない

### 根本原因
**オンボーディング完了フラグの設定タイミングが遅すぎた**

#### 問題のあったフロー（修正前）
```
1. ユーザーが「Amberでログイン」をタップ
2. Amberアプリに遷移
3. Amberで公開鍵取得/署名を承認
4. Meisoアプリに戻る
   ↓
5. MainActivity.onCreate() または onResume() が呼ばれる
6. Flutterアプリが再起動される可能性がある
7. GoRouterの redirect が実行される
   ↓
8. localStorageService.hasCompletedOnboarding() をチェック
   → まだ false（setOnboardingCompleted()が呼ばれていない）
   ↓
9. '/onboarding' にリダイレクト
   → 「Meisoへようこそ」画面に戻る ❌
```

**問題点**: `setOnboardingCompleted()` を呼ぶのが、Amber処理が完全に終わった後だった。
Amberから戻ってきた時にアプリが再起動されると、まだフラグが立っていないため、onboarding画面にリダイレクトされる。

---

## ✅ 修正内容

### 修正の方針
**Amber呼び出し前にオンボーディング完了フラグを設定する**

これにより、Amberから戻ってきた時には既にフラグが立っているため、GoRouterのredirectでホーム画面に正しく遷移する。

### 修正箇所

#### 1. Amberログイン（`lib/presentation/onboarding/login_screen.dart`）

**修正前**:
```dart
// Amberから公開鍵を取得
final publicKey = await _amberService.getPublicKey();

// ... 処理 ...

// オンボーディング完了フラグを設定（遅すぎる）
await localStorageService.setOnboardingCompleted();
```

**修正後**:
```dart
// ⚠️ 重要: Amber呼び出し前にオンボーディング完了フラグを設定
await localStorageService.setOnboardingCompleted();
await localStorageService.setUseAmber(true);

// Amberから公開鍵を取得
final publicKey = await _amberService.getPublicKey();

// ... 処理 ...
```

#### 2. 秘密鍵生成（`lib/presentation/onboarding/login_screen.dart`）

統一性のため、秘密鍵モードでも同様にNostr初期化前にフラグを設定。

**修正前**:
```dart
// 秘密鍵を保存
await nostrService.saveSecretKey(keypair.privateKeyNsec, password);

// Nostrクライアントを初期化
await nostrService.initializeNostr(secretKey: keypair.privateKeyNsec);

// オンボーディング完了フラグを設定
await localStorageService.setOnboardingCompleted();
```

**修正後**:
```dart
// 秘密鍵を保存
await nostrService.saveSecretKey(keypair.privateKeyNsec, password);

// オンボーディング完了フラグを設定（Nostr初期化前）
await localStorageService.setOnboardingCompleted();
await localStorageService.setUseAmber(false); // 秘密鍵モードを明示

// Nostrクライアントを初期化
await nostrService.initializeNostr(secretKey: keypair.privateKeyNsec);
```

---

## 🎯 修正後のフロー

### Amberログイン（修正後）
```
1. ユーザーが「Amberでログイン」をタップ
2. setOnboardingCompleted() を呼ぶ ✅
3. setUseAmber(true) を呼ぶ ✅
   ↓（フラグが立った状態でAmberへ）
4. Amberアプリに遷移
5. Amberで公開鍵取得/署名を承認
6. Meisoアプリに戻る
   ↓
7. MainActivity.onCreate() または onResume() が呼ばれる
8. Flutterアプリが再起動される可能性がある
9. GoRouterの redirect が実行される
   ↓
10. localStorageService.hasCompletedOnboarding() をチェック
    → true（既にフラグが立っている）✅
    ↓
11. redirect が null を返す
12. context.go('/') でホーム画面に遷移 ✅
```

---

## 📊 修正ファイル

| ファイル | 修正内容 | 変更行数 |
|---------|---------|---------|
| `lib/presentation/onboarding/login_screen.dart` | オンボーディング完了フラグの設定タイミングを変更（Amber呼び出し前） | ~20行 |
| `lib/presentation/onboarding/login_screen.dart` | 秘密鍵モードでも同様に設定タイミングを変更 | ~10行 |

**総変更行数**: 約30行

---

## 🧪 テスト項目

### 必須テスト（リリース前）
- [ ] Amberログインで正常にHomeScreenに遷移できる
- [ ] Amberで公開鍵取得後、onboarding画面に戻らないことを確認
- [ ] Amber署名後、onboarding画面に戻らないことを確認
- [ ] 秘密鍵生成後、正常にHomeScreenに遷移できる
- [ ] アプリを完全に終了→再起動した時、ホーム画面が表示される

### 追加テスト（品質保証）
- [ ] Amberでキャンセルした場合の動作
- [ ] Amberで拒否した場合のエラー表示
- [ ] アプリがバックグラウンドにある時にAmber処理を完了した場合
- [ ] 機内モード等でオフライン時の動作

---

## 🔧 GoRouterのredirectロジック（参考）

`lib/main.dart` の redirect ロジックは正しく動作している：

```dart
redirect: (context, state) {
  final hasCompleted = localStorageService.hasCompletedOnboarding();
  final currentLocation = state.matchedLocation;
  final isOnboarding = currentLocation == '/onboarding';
  final isLogin = currentLocation == '/login';
  
  // オンボーディング未完了の場合
  if (!hasCompleted) {
    // ログイン画面またはオンボーディング画面以外にアクセスした場合
    if (!isOnboarding && !isLogin) {
      return '/onboarding'; // onboarding画面にリダイレクト
    }
  }
  
  // リダイレクト不要
  return null;
},
```

**ポイント**:
- `hasCompleted` が `true` なら、redirect は `null` を返す
- これにより、ユーザーは目的のページ（`'/'` ホーム画面）に正しく遷移できる

---

## 🚀 リリース可否判定

**判定**: ✅ **修正完了 - テスト待ち**

**理由**:
- ✅ オンボーディング完了フラグの設定タイミングを修正
- ✅ Amberから戻ってきた時に既にフラグが立っている状態にした
- ✅ リントエラーなし
- ✅ ロジック的に正しい

**推奨アクション**:
1. 実機でAmberログインのテストを実施
2. onboarding画面に戻らないことを確認
3. 問題なければリリース

---

## 📚 関連ドキュメント

- [AMBER_BLACKOUT_FIX_COMPLETE.md](./AMBER_BLACKOUT_FIX_COMPLETE.md) - ブラックアウト問題の修正
- [PHASE4_AMBER_INTEGRATION_COMPLETE.md](./PHASE4_AMBER_INTEGRATION_COMPLETE.md) - Amber統合の完了レポート

---

**作成者**: AI Assistant (Claude)  
**作成日時**: 2025-10-30 11:30 JST  
**最終更新**: 2025-10-30 11:30 JST  
**次回アクション**: 実機テスト → リリース

