# Zapstore リリースガイド 🚀

**Meiso** をZapstoreでリリースする手順をまとめたドキュメントです。

> **重要**: このガイドは新しいzsp CLI（v0.3.x以降）に対応しています。

---

## 📋 目次

1. [事前準備](#事前準備)
2. [リリース手順](#リリース手順)
3. [CI/CD統合](#cicd統合)
4. [トラブルシューティング](#トラブルシューティング)
5. [よくある質問](#よくある質問)

---

## 事前準備

### 1. Nostrアカウント

Zapstoreへの公開にはNostrアカウントが必要です。

- **秘密鍵/公開鍵**: Nostr拡張機能（Alby、nos2x等）またはNIP-46 bunkerで管理
- **推奨ツール**: 
  - [Alby](https://getalby.com/) - ブラウザ拡張機能（推奨）
  - [nos2x](https://github.com/fiatjaf/nos2x) - Chrome拡張機能
  - [nsecBunker](https://nsecbunker.com/) - リモート署名サービス

### 2. zsp CLIのインストール

```bash
# Goで最新版をインストール
go install github.com/zapstore/zsp@latest

# バージョン確認
zsp --version
# 出力: 0.3.3 (またはそれ以降)
```

### 3. 必要なツール

```bash
# Flutter環境（fvm使用）
fvm install

# Rustツールチェーン
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Android NDK（Android Studio経由でインストール推奨）
```

### 4. zapstore.yamlの検証

設定ファイルが正しく動作するか確認：

```bash
cd /Users/apple/work/meiso
zsp publish --check zapstore.yaml
# 出力: jp.godzhigella.meiso (パッケージID)
```

---

## リリース手順

### 🎯 概要

新しいzspでは、**GitHubリリースから自動的にAPKを取得**します。手順は以下の通り：

1. バージョン更新 & CHANGELOG記載
2. APKビルド
3. GitHub Releaseを作成（APK添付）
4. `zsp publish` でZapstoreに公開

### ステップ1: バージョン情報の更新

#### 1.1 hotfixブランチでの作業完了確認

```bash
cd /Users/apple/work/meiso
git branch --show-current
# 出力: hotifx (または作業ブランチ)
```

#### 1.2 CHANGELOG.mdの更新

```bash
vim CHANGELOG.md
```

最新バージョンのセクションを追加：

```markdown
## [1.1.7] - 2025-01-16

### Fixed
- OGPリンクプレビューの修正
- Undoボタンの不具合修正

### Changed
- 同期ステータスインジケーター改善
- 多言語対応更新

### Improved
- TodoProviderのリファクタリング
```

#### 1.3 pubspec.yamlのバージョン更新

```bash
# build numberを取得
git rev-list --count HEAD
# 出力: 307

# pubspec.yamlを更新
vim pubspec.yaml
```

```yaml
version: 1.1.7+307  # 1.1.7: バージョン名, 307: ビルド番号
```

#### 1.4 変更をコミット

```bash
git add CHANGELOG.md pubspec.yaml
git commit -m "update: release v1.1.7 - Bug fixes and improvements"
git push origin hotifx
```

### ステップ2: Pull Requestを作成してマージ

```bash
# GitHub CLIでPRを作成
gh pr create --title "Release v1.1.7 - Bug fixes and improvements" \
  --base main --head hotifx \
  --body "$(cat <<EOF
## 📋 Summary
Release v1.1.7 with bug fixes and various improvements.

## 🐛 Bug Fixes
- OGP Link Preview (Issue #114)
- Undo Delete Button (Issue #11)
- Week Start Day Setting (Issue #38)

## 📦 Version
- Version: 1.1.7+307
EOF
)"

# PRをマージ（GitHub WebでApprove後）
gh pr merge --merge
```

マージ後、mainブランチを最新化：

```bash
git checkout main
git pull origin main
```

### ステップ3: APKのビルド

#### 3.1 コード生成

```bash
cd /Users/apple/work/meiso
./generate.sh
```

#### 3.2 Flutter Release APKのビルド

> **重要**: Zapstore 向けは必ず `production` flavor でローカルビルドすること。
> CI の debug keystore はローカルと異なるため、CI ビルドの APK を Zapstore に公開しないこと。

```bash
# リリースビルド (production flavor)
fvm flutter clean
fvm flutter build apk --flavor production --release --dart-define=BUILD_CHANNEL=release

# ビルド成功の確認
ls -lh build/app/outputs/flutter-apk/app-production-release.apk
```

予想されるAPKサイズ: 約30-50MB

#### 3.3 APKの検証（実機テスト）

```bash
# エミュレータまたは実機にインストール
fvm flutter install --flavor production
```

### ステップ4: GitHubリリースの作成

#### 4.1 Gitタグの作成

```bash
# アノテーテッドタグを作成
git tag -a v1.1.7 -m "Release v1.1.7 - Bug fixes and improvements"

# タグをリモートにプッシュ
git push origin v1.1.7
```

#### 4.2 GitHub ReleaseでAPKを公開

```bash
# GitHub CLIでリリースを作成（APK添付）
gh release create v1.1.7 \
  --title "v1.1.7 - Bug fixes and improvements" \
  --notes-file <(sed -n "/## \[1.1.7\]/,/## \[/p" CHANGELOG.md | head -n -1) \
  build/app/outputs/flutter-apk/app-production-release.apk

# リリースが作成されたことを確認
gh release view v1.1.7
```

### ステップ5: Zapstoreへの公開

#### 5.1 署名方法の選択

zspは3つの署名方法をサポート：

**A. ブラウザ拡張機能（推奨）**

```bash
SIGN_WITH=browser zsp publish zapstore.yaml
```

ブラウザが開き、署名を承認するダイアログが表示されます。

**B. NIP-46 Bunker（リモート署名）**

```bash
SIGN_WITH="bunker://pubkey?relay=wss://relay.example.com&secret=..." zsp publish zapstore.yaml
```

**C. nsec秘密鍵（非推奨：セキュリティリスクあり）**

```bash
read -rs SIGN_WITH   # 端末にエコーされず、履歴にも残らない
export SIGN_WITH
zsp publish zapstore.yaml
unset SIGN_WITH
```

> ⚠️ **セキュリティ**: 秘密鍵を環境変数で扱うのはリスクがあります。本番環境ではブラウザ署名またはBunkerを推奨します。`SIGN_WITH=nsec1... zsp publish` のようにコマンド行へ直書きすると、シェル履歴（`.zsh_history` / `.bash_history`）に平文で残ります。

#### 5.2 zsp publishの実行

```bash
cd /Users/apple/work/meiso

# ブラウザ拡張機能で署名（推奨）
SIGN_WITH=browser zsp publish zapstore.yaml
```

#### 5.3 対話式プロンプトの処理

zspは自動的に：

1. **GitHub Releasesから最新APKを取得**
2. **APKを解析**（パッケージID、バージョン、証明書ハッシュ等）
3. **Blossomサーバーにアップロード**（APK、アイコン、スクリーンショット）
4. **Nostrイベントを生成**（Kind 32267, 30063, 3063）
5. **ブラウザで署名を要求**
6. **リレーに公開**

#### 5.4 公開成功の確認

コマンドが成功すると以下のような出力が表示されます：

```
✓ Fetched APK from GitHub release v1.1.7
✓ Parsed APK: jp.godzhigella.meiso v1.1.7 (307)
✓ Uploaded icon to Blossom CDN
✓ Uploaded screenshots to Blossom CDN
✓ Uploaded APK to Blossom CDN (40.2 MB)
✓ App metadata published (kind: 32267)
✓ Release published (kind: 30063)
✓ Asset published (kind: 3063)
✓ Published to relays: wss://relay.zapstore.dev
```

### ステップ6: 公開後の確認

#### 6.1 Zapstoreアプリでの確認

```bash
# Android端末でZapstoreアプリを開く
# 1. 検索で "Meiso" を入力
# 2. アプリが表示されることを確認
# 3. 最新バージョン v1.1.7 が表示されることを確認
```

#### 6.2 Webブラウザでの確認

```bash
# ZapstoreウェブサイトでNostrでログイン
# https://zapstore.dev/
# 自分の公開したアプリを確認
```

---

## CI/CD統合

### GitHub Actionsでの自動リリース

`.github/workflows/zapstore-publish.yml`を作成：

```yaml
name: Zapstore Publish

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      
      - name: Install zsp
        run: go install github.com/zapstore/zsp@latest
      
      - name: Publish to Zapstore
        env:
          SIGN_WITH: ${{ secrets.BUNKER_URL_OR_NSEC }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          zsp publish -y zapstore.yaml
```

### オフラインモード（高セキュリティ環境）

イベントのみを生成して、後で手動で公開：

```bash
# 署名されたイベントを生成（ネットワークアクセスなし）
SIGN_WITH=browser zsp publish --offline zapstore.yaml > events.json

# 生成されたイベントを後でnakで公開
nak event wss://relay.zapstore.dev < events.json
```

---

## トラブルシューティング

### 問題1: GitHub API制限エラー

**エラーメッセージ**:
```
failed to fetch releases: API rate limit exceeded
```

**解決方法**:
```bash
# GitHubトークンを環境変数に設定
export GITHUB_TOKEN=ghp_your_token_here

# または実行時に指定
GITHUB_TOKEN=ghp_xxx zsp publish zapstore.yaml
```

### 問題2: APKが見つからない

**エラーメッセージ**:
```
Error: No suitable APK found in release v1.1.7
```

**解決方法**:
```bash
# GitHub Releaseにarm64-v8a APKが添付されているか確認
gh release view v1.1.7

# APKファイル名が複雑な場合はmatchパターンを指定
# zapstore.yamlに追加：
match: ".*meiso.*\\.apk$"
```

### 問題3: Nostr署名エラー

**エラーメッセージ**:
```
Error: No Nostr signer found
```

**解決方法**:
```bash
# ブラウザ拡張機能（Alby等）がインストールされているか確認
# 拡張機能でログインしているか確認

# 拡張機能が使えない場合はBunker（NIP-46）を使用
SIGN_WITH="bunker://pubkey?relay=wss://relay.example.com&secret=..." zsp publish zapstore.yaml

# Bunkerも使えない場合のみ、nsecを安全に入力（コマンド行に直書きしない）
read -rs SIGN_WITH
export SIGN_WITH
zsp publish zapstore.yaml
unset SIGN_WITH
```

### 問題4: Blossom CDNアップロードエラー

**エラーメッセージ**:
```
Error: Failed to upload to Blossom CDN
```

**解決方法**:
```bash
# カスタムBlossomサーバーを指定
export BLOSSOM_URL=https://your-cdn.example.com
zsp publish zapstore.yaml

# またはオフラインモードで生成
zsp publish --offline zapstore.yaml > events.json
# APKを手動でCDNにアップロード後、イベントを公開
```

### 問題5: 設定ファイル検証エラー

**エラーメッセージ**:
```
Error: Invalid configuration
```

**解決方法**:
```bash
# 設定ファイルを検証
zsp publish --check zapstore.yaml

# wizardモードで対話的に設定
zsp publish --wizard
```

### 問題6: TLS証明書エラー

**エラーメッセージ**:
```
tls: failed to verify certificate: x509: OSStatus -26276
```

**解決方法**:
```bash
# macOSのキーチェーンアクセス問題の可能性
# システム証明書を更新
sudo security update

# または別のターミナルで実行（サンドボックス外）
```

---

## よくある質問

### Q1: リリース頻度はどのくらいが適切？

**A**: 
- メジャーアップデート: 月1-2回程度
- マイナーアップデート（新機能）: 必要に応じて
- バグフィックス: 必要に応じて随時
- ユーザーへの影響が大きいバグは即座にhotfixリリース

### Q2: バージョン番号の付け方は？

**A**: セマンティックバージョニングに従います：

```
MAJOR.MINOR.PATCH+BUILD

例:
1.0.0+1   - 初回リリース
1.0.1+2   - バグフィックス（PATCH）
1.1.0+3   - 新機能追加（MINOR）
2.0.0+4   - 破壊的変更（MAJOR）

BUILD番号は git rev-list --count HEAD で取得
```

### Q3: GitHubリリースとZapstoreリリースの関係は？

**A**: 
- **GitHub Release**: APKの配布プラットフォーム（必須）
- **Zapstore**: NostrベースのAPKインデックス（zspがGitHub Releaseを参照）

手順：
1. APKをビルド
2. GitHub ReleaseでAPKを公開
3. `zsp publish`でZapstoreに登録（GitHubから自動取得）

### Q4: スクリーンショットは毎回更新する必要がある？

**A**: 
- UIに大きな変更がある場合: 更新推奨
- 小さなバグフィックスのみ: 更新不要
- 新機能追加: 新機能のスクリーンショット追加を推奨

zapstore.yamlの`images`セクションで管理。

### Q5: どの署名方法を使うべき？

**A**: セキュリティレベル別の推奨：

| 署名方法 | セキュリティ | 用途 |
|---------|-------------|------|
| **ブラウザ拡張** | 🟢 高 | 手動リリース（推奨） |
| **NIP-46 Bunker** | 🟢 高 | CI/CD自動化 |
| **nsec秘密鍵** | 🔴 低 | テスト環境のみ |

### Q6: 公開後にアプリが見つからない

**A**: 以下を確認：
1. 数分待ってから再検索（リレーへの伝播に時間がかかる場合がある）
2. Zapstoreアプリを再起動
3. 異なるNostrリレーに接続し直す
4. zapstore.yamlの `tags` に適切なキーワードが含まれているか確認

```bash
# パッケージIDが正しく取得できるか確認
zsp publish --check zapstore.yaml
```

### Q7: ローカルAPKを直接公開できる？

**A**: はい、可能です：

```bash
# ローカルAPKを指定
zsp publish build/app/outputs/flutter-apk/app-release.apk \
  -r github.com/higedamc/meiso
```

ただし、継続的なリリースではGitHub Releasesを使う方が管理しやすいです。

### Q8: 複数のAPKバリアント（flavor）をサポートできる？

**A**: はい、`variants`で管理できます：

```yaml
variants:
  fdroid: ".*-fdroid-.*\\.apk$"
  google: ".*-google-.*\\.apk$"
```

### Q9: メタデータを外部から取得できる？

**A**: はい、`metadata_sources`で指定：

```yaml
metadata_sources:
  - github      # README、トピック等
  - playstore   # Google Playのメタデータ
  - fdroid      # F-Droidのメタデータ
```

### Q10: オフラインでリリースできる？

**A**: はい、`--offline`モードで可能：

```bash
# イベントのみ生成（ネットワークアクセスなし）
SIGN_WITH=browser zsp publish --offline zapstore.yaml > events.json

# APKを手動でBlossomにアップロード後、イベントを公開
nak event wss://relay.zapstore.dev < events.json
```

---

## 便利なコマンド集

### 完全リリースフロー（ワンライナー）

```bash
# 完全なリリースフローを実行する関数
meiso_release() {
  VERSION=$1
  BUILD=$(git rev-list --count HEAD)
  
  echo "🚀 Releasing Meiso v${VERSION}+${BUILD}"
  
  # 1. バージョン更新
  sed -i '' "s/version: .*/version: ${VERSION}+${BUILD}/" pubspec.yaml
  echo "✓ Updated pubspec.yaml"
  
  # 2. コミット & プッシュ
  git add pubspec.yaml CHANGELOG.md
  git commit -m "update: release v${VERSION}"
  git push origin $(git branch --show-current)
  echo "✓ Committed and pushed"
  
  # 3. PRマージ後にmainへ移動
  echo "⚠️  Merge PR on GitHub, then press Enter..."
  read
  git checkout main
  git pull origin main
  
  # 4. APKビルド (production flavor)
  ./generate.sh
  fvm flutter clean
  fvm flutter build apk --flavor production --release --dart-define=BUILD_CHANNEL=release
  echo "✓ APK built"
  
  # 5. Gitタグ & GitHub Release
  git tag -a v${VERSION} -m "Release v${VERSION}"
  git push origin v${VERSION}
  gh release create v${VERSION} \
    --title "v${VERSION}" \
    --notes-file <(sed -n "/## \[${VERSION}\]/,/## \[/p" CHANGELOG.md | head -n -1) \
    build/app/outputs/flutter-apk/app-production-release.apk
  echo "✓ GitHub Release created"
  
  # 6. Zapstore公開
  echo "⚠️  Ready to publish to Zapstore. Press Enter to continue..."
  read
  SIGN_WITH=browser zsp publish zapstore.yaml
  
  echo "🎉 Release v${VERSION} completed!"
}

# 使用例:
# meiso_release 1.1.8
```

### zapstore.yaml検証

```bash
# 設定ファイルの検証
zsp publish --check zapstore.yaml

# 対話的ウィザード（初回設定時）
zsp publish --wizard

# 詳細なデバッグ出力
zsp publish --verbose zapstore.yaml
```

### APK情報確認

```bash
# APKサイズ確認
ls -lh build/app/outputs/flutter-apk/app-production-release.apk

# APKのメタ情報確認
aapt dump badging build/app/outputs/flutter-apk/app-production-release.apk | grep -E "package:|version"

# 署名証明書の確認 (Zapstore certificate hash と一致すること)
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-production-release.apk | grep SHA256

# APKの詳細情報をJSON出力
zsp apk --extract build/app/outputs/flutter-apk/app-production-release.apk

# SHA256ファイルハッシュ計算
shasum -a 256 build/app/outputs/flutter-apk/app-production-release.apk
```

### Nostr関連

```bash
# イベント生成のみ（オフラインモード）
SIGN_WITH=browser zsp publish --offline zapstore.yaml > events.json

# 生成したイベントを手動で公開
nak event wss://relay.zapstore.dev < events.json

# 署名キーの確認
zsp identity --link-key <cert_sha256>
```

### GitHub操作

```bash
# リリース一覧
gh release list

# 特定のリリースを確認
gh release view v1.1.7

# APKをダウンロード
gh release download v1.1.7 -p "*.apk"
```

---

## チェックリスト

### リリース前準備

- [ ] `CHANGELOG.md` の更新
- [ ] `pubspec.yaml` のバージョン更新
- [ ] 変更をコミット & プッシュ
- [ ] PRを作成してマージ
- [ ] mainブランチを最新化

### APKビルド

- [ ] `./generate.sh` の実行
- [ ] `fvm flutter clean` でクリーンビルド
- [ ] `fvm flutter build apk --flavor production --release --dart-define=BUILD_CHANNEL=release`
- [ ] APKサイズの確認（30-50MB程度）
- [ ] 署名確認: `keytool -printcert -jarfile build/app/outputs/flutter-apk/app-production-release.apk | grep SHA256`
- [ ] SHA256 が `BA:94:CF:06:8F:15:27:70:BB:90:11:1E:3C:ED:0A:36:5C:3D:8B:EA:...` と一致すること
- [ ] 実機でのインストール & 動作確認

### GitHubリリース

- [ ] Gitタグの作成（`v1.1.x`形式）
- [ ] タグをリモートにプッシュ
- [ ] GitHub ReleaseでAPKを公開
- [ ] リリースノートの記載

### Zapstoreリリース

- [ ] `zapstore.yaml` の検証（`--check`）
- [ ] 署名方法の選択（`SIGN_WITH`環境変数）
- [ ] `zsp publish` の実行
- [ ] ブラウザで署名承認
- [ ] 公開成功メッセージの確認

### リリース後確認

- [ ] Zapstoreアプリで検索可能か確認
- [ ] アプリ詳細ページの表示確認（名前、説明、スクリーンショット）
- [ ] 最新バージョンが表示されるか確認
- [ ] Zapstoreからインストール & 起動確認
- [ ] Nostrで告知投稿（任意）

---

## 参考リンク

- [Zapstore公式サイト](https://zapstore.dev/)
- [zsp GitHub](https://github.com/zapstore/zsp)
- [zsp README](https://github.com/zapstore/zsp/blob/main/README.md) - 詳細なCLIドキュメント
- [NIP-82仕様](https://github.com/nostr-protocol/nips/blob/master/82.md) - Software Events
- [Nostr公式サイト](https://nostr.com/)
- [Meisoリポジトリ](https://github.com/higedamc/meiso)

---

## 関連ドキュメント

- [CHANGELOG.md](../CHANGELOG.md) - リリース履歴
- [README.md](../README.md) - プロジェクト概要
- [zapstore.yaml](../zapstore.yaml) - Zapstore設定ファイル

---

**作成日**: 2025-11-21  
**最終更新**: 2025-02-14  
**バージョン**: 2.0.0 (zsp 0.3.x対応)

**⚡ Happy Zapping! ⚡**

