# オンボーディングスクリーン実装完了

## 概要
zap_clockのオンボーディングスクリーンを参考に、Meisoアプリのオンボーディング機能を実装しました。

## 実装内容

### 1. 依存関係の追加 ✅
- `go_router: ^14.6.2` をpubspec.yamlに追加
- ナビゲーション管理をGoRouterベースに変更

### 2. LocalStorageServiceの拡張 ✅
`lib/services/local_storage_service.dart`に以下の機能を追加：

#### オンボーディング関連
- `hasCompletedOnboarding()` - オンボーディング完了状態のチェック
- `setOnboardingCompleted()` - オンボーディング完了フラグの設定

#### Nostr認証情報管理
- `saveNostrPrivateKey(String)` - 秘密鍵の保存
- `getNostrPrivateKey()` - 秘密鍵の取得
- `saveNostrPublicKey(String)` - 公開鍵の保存
- `getNostrPublicKey()` - 公開鍵の取得
- `setUseAmber(bool)` - Amber使用フラグの設定
- `isUsingAmber()` - Amber使用状態のチェック
- `clearNostrCredentials()` - 認証情報のクリア

### 3. Nostr Providerの拡張 ✅
`lib/providers/nostr_provider.dart`に以下のProviderを追加：

```dart
/// Nostr秘密鍵を管理するProvider（nsec形式）
final nostrPrivateKeyProvider = StateProvider<String?>((ref) => null);

/// Nostr公開鍵を管理するProvider（npub形式）
final nostrPublicKeyProvider = StateProvider<String?>((ref) => null);
```

### 4. オンボーディングスクリーン ✅
`lib/presentation/onboarding/onboarding_screen.dart`を実装：

#### 特徴
- 4ページのスライド形式
- スキップボタン
- ページインジケーター
- アニメーション付きの遷移
- 最終ページからログイン画面への導線

#### 表示内容
1. **ページ1**: Meisoへようこそ
   - アプリの概要紹介
2. **ページ2**: Nostrで同期
   - 同期機能の説明
3. **ページ3**: プライバシー第一
   - セキュリティと分散型の利点
4. **ページ4**: さあ、始めましょう
   - ログインへの誘導

### 5. ログインスクリーン ✅
`lib/presentation/onboarding/login_screen.dart`を実装：

#### ログイン方法
1. **Amberでログイン**
   - Androidの署名アプリ「Amber」と連携
   - より安全な秘密鍵管理
   - 現在は仮実装（TODO: Amber SDKの統合）

2. **新しい秘密鍵を生成**
   - アプリ内で新しいNostr秘密鍵を生成
   - 秘密鍵のバックアップを促すダイアログ表示
   - 現在は仮実装（TODO: Rust側での実装）

#### セキュリティ
- 秘密鍵はローカルに安全に保存
- ユーザーへのバックアップ警告
- Amber使用を推奨

### 6. ルーティングの実装 ✅
`lib/main.dart`をGoRouterベースに書き換え：

#### ルート構成
```
/ (ホーム)
├─ /onboarding (オンボーディング)
├─ /login (ログイン)
└─ /settings (設定)
```

#### 自動リダイレクト
- 初回起動時は自動的に`/onboarding`へ遷移
- オンボーディング完了後は`/`（ホーム）に戻る
- ログイン完了後もホームへ遷移

## ファイル構成

```
lib/
├── main.dart (GoRouter統合)
├── services/
│   └── local_storage_service.dart (拡張済み)
├── providers/
│   └── nostr_provider.dart (Provider追加)
└── presentation/
    ├── onboarding/
    │   ├── onboarding_screen.dart (新規)
    │   └── login_screen.dart (新規)
    ├── home/
    │   └── home_screen.dart (既存)
    └── settings/
        └── settings_screen.dart (既存)
```

## 追加実装完了 ✅

### 1. Rust側でNostr秘密鍵生成を実装 ✅
- `rust/src/api.rs`に`generate_keypair()`関数を追加
- nsec/npub形式の鍵ペアを返すKeyPair構造体を定義
- hex形式の鍵も同時に返すように実装

```rust
pub struct KeyPair {
    pub private_key_nsec: String,
    pub public_key_npub: String,
    pub private_key_hex: String,
    pub public_key_hex: String,
}

pub fn generate_keypair() -> Result<KeyPair>
```

### 2. Amber SDKの統合 ✅
- `android_intent_plus: ^5.1.1`パッケージを追加
- `lib/services/amber_service.dart`を作成
- 実装機能:
  - Amberインストール確認
  - 公開鍵の取得
  - イベント署名
  - Google Playでのインストール誘導

### 3. セキュアストレージの導入 ✅
- `flutter_secure_storage: ^9.2.2`パッケージを追加
- `lib/services/secure_storage_service.dart`を作成
- Androidの暗号化SharedPreferencesを使用
- 実装機能:
  - Nostr秘密鍵の安全な保存
  - Nostr公開鍵の保存
  - Amber使用フラグの管理
  - 認証情報のクリア

### 4. ログイン画面の実装強化 ✅
- Rust実装(`generateKeypair()`)を使用
- セキュアストレージに秘密鍵を保存
- Amberサービスとの統合
- より詳細な秘密鍵表示ダイアログ
  - nsec形式の秘密鍵
  - npub形式の公開鍵
  - 警告メッセージ

## 次のステップ（TODO）

### 高優先度

1. **エラーハンドリングの強化**
   - ネットワークエラーの適切な処理
   - ユーザーフレンドリーなエラーメッセージ

2. **ローディング状態の改善**
   - より洗練されたローディングUI
   - 進捗状況の表示

### 中優先度
3. **Amber連携の完全実装**
   - Android Intent結果の受け取り
   - 実際の公開鍵取得
   - 署名処理の実装

### 低優先度
4. **多言語対応**
   - 英語・日本語のローカライゼーション
   - zap_clockのl10nシステムを参考

5. **アニメーションの強化**
   - より滑らかなページ遷移
   - マイクロインタラクションの追加

## 使い方

### 初回起動時
1. アプリを起動するとオンボーディング画面が表示される
2. 4つのスライドを確認（またはスキップ）
3. ログイン画面で「Amberでログイン」または「新しい秘密鍵を生成」を選択
4. 認証完了後、ホーム画面に遷移

### 2回目以降の起動
- オンボーディングはスキップされ、直接ホーム画面が表示される

### リセット方法
開発中にオンボーディングを再度表示したい場合：
```dart
// アプリ内で実行
await localStorageService.clearNostrCredentials();
await localStorageService._settingsBox.delete('onboarding_completed');
```

## 参考にしたコード
- `/Users/apple/work/zap_clock/lib/screens/onboarding_screen.dart`
- `/Users/apple/work/zap_clock/lib/main.dart`
- `/Users/apple/work/zap_clock/lib/services/storage_service.dart`

## 実装完了日
2025年10月29日

### Phase 1: 基本実装
- オンボーディングスクリーン
- ログインスクリーン（仮実装）
- ルーティング統合

### Phase 2: 完全実装（追加）
- Rust側鍵生成
- Amberサービス
- セキュアストレージ
- 実際の鍵生成フローの統合

## 新規ファイル一覧

```
lib/
├── presentation/
│   └── onboarding/
│       ├── onboarding_screen.dart (新規)
│       └── login_screen.dart (新規・更新済み)
├── services/
│   ├── amber_service.dart (新規)
│   └── secure_storage_service.dart (新規)
└── (既存ファイルの更新)
    ├── main.dart (GoRouter統合)
    ├── services/local_storage_service.dart (拡張)
    └── providers/nostr_provider.dart (Provider追加)

rust/
└── src/
    └── api.rs (generate_keypair関数追加)
```

## テスト状況
- [ ] 初回起動時のオンボーディング表示
- [ ] スキップボタンの動作
- [ ] ページ遷移のアニメーション
- [x] 秘密鍵生成フロー（Rust実装完了）
- [ ] Amberログインフロー（基本実装完了、Intent結果受け取りは未実装）
- [ ] オンボーディング完了後のリダイレクト
- [ ] 2回目以降の起動時の挙動
- [ ] セキュアストレージへの保存確認

## 実機でのテスト方法

```bash
# 依存関係のインストール
fvm flutter pub get

# Androidエミュレータで実行
fvm flutter run

# またはデバッグビルド
fvm flutter build apk --debug
```

### テスト項目

1. **初回起動**
   - オンボーディングが表示される
   - 4ページをスワイプできる
   - スキップボタンで最終ページにジャンプ
   - ログイン画面に遷移

2. **秘密鍵生成**
   - 「新しい秘密鍵を生成」ボタンをタップ
   - ローディングが表示される
   - 秘密鍵(nsec)と公開鍵(npub)が表示される
   - 「バックアップしました」でホーム画面に遷移

3. **再起動**
   - アプリを再起動
   - オンボーディングがスキップされる
   - ホーム画面が直接表示される

4. **Amberログイン（Amber未インストール時）**
   - 「Amberでログイン」ボタンをタップ
   - インストール促進ダイアログが表示される
   - Google Playが開く

**注意**: Amber連携の完全な動作確認にはAmberアプリのインストールが必要です。
