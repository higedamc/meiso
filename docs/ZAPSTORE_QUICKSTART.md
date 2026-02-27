# Zapstore リリース クイックスタート

**Meiso** を Zapstore でリリースする最速手順（zsp 0.3.x）。

---

## 📦 前提条件

```bash
# zsp CLI インストール済み
zsp --version  # 0.3.3+

# zapstore.yaml が最新仕様に対応済み
zsp publish --check zapstore.yaml  # jp.godzhigella.meiso
```

---

## 🚀 リリース手順（5ステップ）

### 1️⃣ バージョン更新

```bash
# CHANGELOG.mdに新バージョンを記載
vim CHANGELOG.md

# pubspec.yamlのバージョンを更新
vim pubspec.yaml
# version: 1.1.8+307 (build number: git rev-list --count HEAD)

# コミット
git add CHANGELOG.md pubspec.yaml
git commit -m "update: release v1.1.8"
git push origin hotifx
```

### 2️⃣ PRマージ

```bash
# PRを作成
gh pr create --title "Release v1.1.8" --base main --head hotifx

# マージ後、mainを最新化
git checkout main
git pull origin main
```

### 3️⃣ APKビルド

```bash
./generate.sh
fvm flutter clean
fvm flutter build apk --release

# 確認
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

### 4️⃣ GitHub Release

```bash
# タグ作成 & プッシュ
git tag -a v1.1.8 -m "Release v1.1.8"
git push origin v1.1.8

# GitHub ReleaseでAPK公開
gh release create v1.1.8 \
  --title "v1.1.8" \
  --notes-file <(sed -n '/## \[1.1.8\]/,/## \[1.1.7\]/p' CHANGELOG.md | head -n -1) \
  build/app/outputs/flutter-apk/app-release.apk
```

### 5️⃣ Zapstore公開

```bash
# ブラウザ署名で公開
SIGN_WITH=browser zsp publish zapstore.yaml

# ✓ ブラウザで署名承認
# ✓ 完了！
```

---

## 🔐 署名方法

| 方法 | コマンド | 用途 |
|-----|---------|------|
| **ブラウザ拡張** | `SIGN_WITH=browser zsp publish` | 手動リリース（推奨） |
| **NIP-46 Bunker** | `SIGN_WITH="bunker://..." zsp publish` | CI/CD自動化 |
| **nsec秘密鍵** | `SIGN_WITH=nsec1... zsp publish` | テスト環境のみ |

---

## 🛠️ よく使うコマンド

```bash
# 設定検証
zsp publish --check zapstore.yaml

# オフラインモード（イベント生成のみ）
zsp publish --offline zapstore.yaml > events.json

# ウィザード（対話式設定）
zsp publish --wizard

# APK情報抽出
zsp apk --extract app-release.apk

# GitHub Releaseを確認
gh release view v1.1.8
```

---

## ❓ トラブルシューティング

### APKが見つからない

```bash
# GitHub Releaseにarm64-v8a APKがあるか確認
gh release view v1.1.8

# zapstore.yamlにmatchパターンを追加
match: ".*meiso.*\\.apk$"
```

### GitHub API制限

```bash
# トークンを設定
export GITHUB_TOKEN=ghp_your_token_here
```

### Nostr署名エラー

```bash
# ブラウザ拡張（Alby等）がインストール&ログイン済みか確認
# または環境変数で直接指定
SIGN_WITH=nsec1... zsp publish
```

---

## 📚 詳細ドキュメント

- [完全版リリースガイド](./ZAPSTORE_RELEASE_GUIDE_JA.md)
- [zapstore.yaml設定](../zapstore.yaml)
- [zsp公式README](https://github.com/zapstore/zsp)

---

**⚡ 最速リリースを！ ⚡**
