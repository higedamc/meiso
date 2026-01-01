# Zapstore リリースガイド 🚀

ZapClockをZapstoreでリリースする手順をまとめたドキュメントです。

---

## 📋 目次

1. [事前準備](#事前準備)
2. [リリース手順](#リリース手順)
3. [トラブルシューティング](#トラブルシューティング)
4. [よくある質問](#よくある質問)

---

## 事前準備

### 1. Nostrアカウント

Zapstoreへの公開にはNostrアカウントが必要です。

- **秘密鍵/公開鍵**: Nostr拡張機能（Alby、nos2x等）で管理
- **推奨ツール**: 
  - [Alby](https://getalby.com/) - ブラウザ拡張機能
  - [nos2x](https://github.com/fiatjaf/nos2x) - Chrome拡張機能

### 2. 必要なツール

```bash
# Rustツールチェーン
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# cargo-ndk（Android向けRustビルド）
cargo install cargo-ndk

# flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen

# Android NDK（Android Studio経由でインストール推奨）
```

### 3. zapstore CLIの確認

```bash
cd /Users/apple/work/zap_clock
./zapstore --version
# 出力: 0.2.4 (またはそれ以降)
```

---

## リリース手順

### ステップ1: バージョン情報の更新

#### 1.1 pubspec.yamlの更新

```bash
vim pubspec.yaml
```

```yaml
version: 1.0.2+3  # 1.0.2: バージョン名, 3: ビルド番号
```

#### 1.2 zapstore.yamlの確認

```bash
vim zapstore.yaml
```

重要な項目を確認：

```yaml
name: ZapClock
summary: Wake up and support the community with Lightning payments
repository: https://github.com/higedamc/zap_clock
license: MIT

# ビルド成果物のパス
assets:
  - build/app/outputs/flutter-apk/app-release.apk

# スクリーンショット
images:
  - screenshots/01_alarm_list.png
  - screenshots/02_alarm_edit.png
  - screenshots/03_alarm_ring.png
  - screenshots/04_settings.png

# Changelog
changelog: CHANGELOG.md
```

#### 1.3 CHANGELOG.mdの更新

```bash
vim CHANGELOG.md
```

最新バージョンのセクションを追加：

```markdown
## [1.0.2] - 2025-11-21

### Added
- 新機能の説明

### Changed
- 変更内容

### Fixed
- 修正したバグ
```

### ステップ2: APKのビルド

#### 2.1 Rustライブラリのビルド

```bash
cd /Users/apple/work/zap_clock/rust

# 各アーキテクチャ向けにビルド
cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release
cargo ndk -t armeabi-v7a -o ../android/app/src/main/jniLibs build --release
cargo ndk -t x86_64 -o ../android/app/src/main/jniLibs build --release

# ビルドが成功したか確認
ls -la ../android/app/src/main/jniLibs/
```

#### 2.2 Flutter APKのビルド

```bash
cd /Users/apple/work/zap_clock

# リリースビルド
fvm flutter clean
fvm flutter build apk --release

# ビルド成功の確認
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

予想されるAPKサイズ: 約25-40MB

### ステップ3: APKの検証

#### 3.1 エミュレータ/実機でのテスト

```bash
# エミュレータまたは実機にインストール
fvm flutter install
```

#### 3.2 動作確認チェックリスト

- [ ] アプリが起動する
- [ ] アラームを作成できる
- [ ] アラームが鳴動する
- [ ] Lightning送金機能が動作する（NWC接続テスト）
- [ ] 設定が保存される
- [ ] クラッシュしない

### ステップ4: Zapstoreへの公開

#### 4.1 zapstore publishコマンドの実行

```bash
cd /Users/apple/work/zap_clock

# Nostr拡張機能が有効になっていることを確認してから実行
./zapstore publish
```

#### 4.2 対話式プロンプトの処理

zapstore publishコマンドは対話式で以下の情報を確認します：

1. **Nostr署名の確認**
   - ブラウザ拡張機能（Alby等）で署名を承認

2. **アプリ情報の確認**
   - zapstore.yamlの内容が表示されるので確認

3. **リリースノートの確認**
   - CHANGELOG.mdの最新版が表示されるので確認

4. **公開の確認**
   - `y`を入力して公開を実行

#### 4.3 公開成功の確認

コマンドが成功すると以下のような出力が表示されます：

```
✓ App metadata published (kind: 32267)
✓ Release published (kind: 1063)
✓ Published to relays: wss://relay.damus.io, wss://nos.lol, ...
```

### ステップ5: 公開後の確認

#### 5.1 Zapstoreアプリでの確認

```bash
# Android端末でZapstoreアプリを開く
# 1. 検索で "ZapClock" を入力
# 2. アプリが表示されることを確認
# 3. 最新バージョンが表示されることを確認
```

#### 5.2 Webブラウザでの確認

```bash
# ZapstoreウェブサイトでNostrでログイン
# https://zapstore.dev/
# 自分の公開したアプリを確認
```

---

## トラブルシューティング

### 問題1: Rustビルドエラー

**エラーメッセージ**:
```
error: linking with `cc` failed
```

**解決方法**:
```bash
# Android NDKのパスを確認
echo $ANDROID_NDK_HOME

# 未設定の場合は設定
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/26.1.10909125

# ~/.zshrc または ~/.bash_profile に追加
echo 'export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/26.1.10909125' >> ~/.zshrc
```

### 問題2: Flutter APKビルドエラー

**エラーメッセージ**:
```
Error: No *.so files found
```

**解決方法**:
```bash
# jniLibsディレクトリを確認
ls -R android/app/src/main/jniLibs/

# 空の場合はRustライブラリを再ビルド
cd rust
./build.sh
```

### 問題3: zapstore publishが失敗する

**エラーメッセージ**:
```
Error: No Nostr signer found
```

**解決方法**:
```bash
# 1. Nostr拡張機能（Alby等）がブラウザで有効になっているか確認
# 2. 拡張機能でログインしているか確認
# 3. ブラウザを再起動して再試行
```

### 問題4: APKが見つからない

**エラーメッセージ**:
```
Error: File not found: build/app/outputs/flutter-apk/app-release.apk
```

**解決方法**:
```bash
# zapstore.yamlのassetsパスを確認
vim zapstore.yaml

# 正しいパスに修正
assets:
  - build/app/outputs/flutter-apk/app-release.apk

# APKが存在するか確認
ls -la build/app/outputs/flutter-apk/
```

### 問題5: リレーへの接続エラー

**エラーメッセージ**:
```
Warning: Failed to connect to some relays
```

**対処方法**:
- 通常は警告のみで公開は完了しています
- 複数のリレーが設定されているため、一部が失敗しても問題ありません
- `zapstore discover` コマンドで公開されたアプリが検索できれば成功です

---

## よくある質問

### Q1: リリース頻度はどのくらいが適切？

**A**: 
- メジャーアップデート: 月1-2回程度
- バグフィックス: 必要に応じて随時
- ユーザーへの影響が大きいバグは即座にhotfixリリース

### Q2: バージョン番号の付け方は？

**A**: セマンティックバージョニングに従います：

```
MAJOR.MINOR.PATCH+BUILD

例:
1.0.0+1   - 初回リリース
1.0.1+2   - バグフィックス
1.1.0+3   - 新機能追加
2.0.0+4   - 破壊的変更
```

### Q3: スクリーンショットは毎回更新する必要がある？

**A**: 
- UIに大きな変更がある場合: 更新推奨
- 小さなバグフィックスのみ: 更新不要
- 新機能追加: 新機能のスクリーンショット追加を推奨

### Q4: リリース前のテストはどこまでやるべき？

**A**: 最低限のチェックリスト：
- [ ] 実機でのインストール確認
- [ ] アプリ起動確認
- [ ] 主要機能（アラーム作成、鳴動、Lightning送金）の動作確認
- [ ] クラッシュしないことの確認

### Q5: GitHub Actionsとzapstore CLIどちらを使うべき？

**A**: 
- **GitHub Actions**: 自動化されたビルド・リリースプロセス（推奨）
- **zapstore CLI**: 手動での即座のリリース、テスト公開

両方の組み合わせも可能：
1. GitHub Actionsで自動ビルド
2. GitHub Releasesから手動でzapstore publish

### Q6: 公開後にアプリが見つからない

**A**: 以下を確認：
1. 数分待ってから再検索（リレーへの伝播に時間がかかる場合がある）
2. Zapstoreアプリを再起動
3. 異なるNostrリレーに接続し直す
4. zapstore.yamlの `tags` に適切なキーワードが含まれているか確認

---

## 便利なコマンド集

### ワンライナーリリース（上級者向け）

```bash
# バージョンを引数で受け取ってリリース
release() {
  VERSION=$1
  BUILD=$2
  
  # バージョン更新
  sed -i '' "s/version: .*/version: $VERSION+$BUILD/" pubspec.yaml
  
  # Rustビルド
  cd rust && \
  cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release && \
  cargo ndk -t armeabi-v7a -o ../android/app/src/main/jniLibs build --release && \
  cargo ndk -t x86_64 -o ../android/app/src/main/jniLibs build --release && \
  cd ..
  
  # Flutter APKビルド
  fvm flutter build apk --release
  
  echo "✓ Build completed. Run './zapstore publish' to release."
}

# 使用例:
# release 1.0.2 3
```

### APK情報確認

```bash
# APKサイズ確認
ls -lh build/app/outputs/flutter-apk/app-release.apk

# APKのメタ情報確認
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "package:|version"

# SHA256ハッシュ計算
shasum -a 256 build/app/outputs/flutter-apk/app-release.apk
```

### ログ確認

```bash
# 実機でのログ確認
adb logcat | grep -i zapclock

# クラッシュログ確認
adb logcat | grep -E "AndroidRuntime|FATAL"
```

---

## チェックリスト

### リリース前

- [ ] `pubspec.yaml` のバージョン更新
- [ ] `CHANGELOG.md` の更新
- [ ] Rustライブラリのビルド（3アーキテクチャ）
- [ ] Flutter APKのビルド
- [ ] 実機でのインストール確認
- [ ] 主要機能の動作確認
- [ ] `zapstore.yaml` の内容確認

### リリース実行

- [ ] `./zapstore publish` の実行
- [ ] Nostr署名の承認
- [ ] 公開成功メッセージの確認
- [ ] リレーへの伝播確認

### リリース後

- [ ] Zapstoreアプリで検索可能か確認
- [ ] アプリ詳細ページの表示確認
- [ ] インストール・起動確認
- [ ] GitHubにリリースタグを作成（任意）
- [ ] Nostrで告知投稿（任意）

---

## 参考リンク

- [Zapstore公式サイト](https://zapstore.dev/)
- [Zapstore GitHub](https://github.com/zapstore)
- [NIP-89仕様](https://github.com/nostr-protocol/nips/blob/master/89.md)
- [Nostr公式サイト](https://nostr.com/)
- [ZapClockリポジトリ](https://github.com/higedamc/zap_clock)

---

## 関連ドキュメント

- [ZAPSTORE_RELEASE.md](../ZAPSTORE_RELEASE.md) - 英語版詳細ガイド
- [ZAPSTORE_CHECKLIST.md](../ZAPSTORE_CHECKLIST.md) - 詳細チェックリスト
- [QUICKSTART_RELEASE.md](../QUICKSTART_RELEASE.md) - GitHub Actionsを使った自動リリース
- [GITHUB_ACTIONS_RELEASE.md](../GITHUB_ACTIONS_RELEASE.md) - CI/CDパイプライン

---

**作成日**: 2025-11-21  
**最終更新**: 2025-11-21  
**バージョン**: 1.0.0

**⚡ Happy Zapping! ⚡**

