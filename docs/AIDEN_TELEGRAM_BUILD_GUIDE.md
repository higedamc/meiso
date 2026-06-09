# Aiden Telegram Build Guide

Telegram 経由で AI エージェント Aiden に開発タスクを依頼し、GitHub Actions で APK をビルドするまでの手順。

---

## Overview

```
Oracle (Telegram) --> Aiden (LNVPS) --> GitHub (push) --> GitHub Actions (build) --> Telegram (notification)
```

1. Oracle が Telegram で Aiden に作業指示を送る
2. Aiden が LNVPS 上で `openclaw/<task>` ブランチを作成し、コード編集・`dart analyze` を実行
3. Oracle の承認後、Aiden が GitHub に push
4. GitHub Actions (`build-apk.yml`) が APK をビルド
5. ビルド結果と APK ダウンロードリンクが Telegram に通知される (Secrets 設定時)

## Prerequisites

- Telegram で Aiden bot とペアリング済み
- LNVPS 上に meiso リポジトリがクローン済み (`~/.openclaw/workspace/meiso`)
- GitHub に Deploy Key (write) が登録済み
- GitHub Actions ワークフロー (`.github/workflows/build-apk.yml`) がリポジトリに存在

### Optional

- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` を GitHub Secrets に登録するとビルド通知が有効化される
- 未登録でも CI 自体は動作する (通知がスキップされるのみ)

## Workflow

### Step 1: Telegram で作業指示

Aiden に対して自然言語で指示を送る。

```
lib/core/config/app_config.dart に static const String buildChannel = 'dev'; を追加して
```

```
lib/features/custom_list/ の CustomList モデルに description フィールドを追加して
```

Aiden は `meiso-dev` スキルに従い、以下を自動実行する:

1. `git fetch origin && git checkout -b openclaw/<task> origin/main`
2. 対象ファイルの編集
3. `dart analyze lib/` で静的解析
4. 変更差分と解析結果を Oracle に報告

### Step 2: 差分レビューと承認

Aiden から以下の形式で報告が来る:

```
Branch: openclaw/add-build-channel

Changes:
- lib/core/config/app_config.dart: buildChannel 定数を追加

Stats:
 lib/core/config/app_config.dart | 3 +++
 1 file changed, 3 insertions(+)

Analyze:
Clean - no issues introduced
```

内容を確認し、問題なければ push を許可する。

```
LGTM、push して
```

修正が必要な場合はフィードバックを送る。

```
buildChannel の型を enum にして
```

### Step 3: Push and CI Build

Aiden が GitHub に push すると、`build-apk.yml` が自動トリガーされる。

トリガー条件:
- `openclaw/**` ブランチへの push
- `v*` タグの push
- `workflow_dispatch` (手動実行)

CI の処理内容:
1. Flutter SDK + Rust toolchain セットアップ
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter build apk --release` (keystore 未設定時は debug 署名)
5. APK を GitHub Actions Artifacts にアップロード (30日保持)

### Step 4: APK の取得

**Telegram 通知が有効な場合:**

ビルド完了後、Telegram にメッセージが届く:

```
meiso Build OK
Branch: openclaw/add-build-channel
Commit: a1b2c3d
Download APK (リンク)
```

リンクから GitHub Actions の Run ページに飛び、Artifacts セクションから APK をダウンロード。

**Telegram 通知が無効な場合:**

GitHub リポジトリの Actions タブから直接確認:
`https://github.com/higedamc/meiso/actions`

### Step 5: Release (タグ push 時のみ)

`v*` タグを push した場合、追加で GitHub Release が自動作成され、APK が添付される。

```
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

Zapstore への公開は別途手動で行う。詳細は [ZAPSTORE_RELEASE_GUIDE_JA.md](ZAPSTORE_RELEASE_GUIDE_JA.md) を参照。

## Constraints

### LNVPS 上で実行できないもの

LNVPS はリソースが限られているため、以下は CI にオフロードされる:

- `flutter build` (APK ビルド)
- `build_runner` (コード生成: `*.freezed.dart`, `*.g.dart`)
- `flutter_rust_bridge_codegen` (Rust FFI バインディング生成)

### Aiden が実行できるもの

- ファイルの読み書き (`exec` ツール経由)
- `dart analyze lib/` (静的解析)
- `git` 操作 (ブランチ作成、コミット、push)
- コードレビュー、リファクタリング提案

### Branch Rules

- Aiden は `main` ブランチを直接編集しない
- 全ての作業は `openclaw/<task>` ブランチで行われる
- `main` へのマージは Oracle が判断する

## Troubleshooting

### Aiden がコマンドを実行できない

cursor-cli-api-proxy が停止している可能性がある。VPS 上で確認:

```bash
ssh debian@100.73.161.112
sudo systemctl status cursor-cli-proxy
sudo journalctl -u cursor-cli-proxy --since "10 min ago"
```

### CI ビルドが失敗する

GitHub Actions のログを確認: `https://github.com/higedamc/meiso/actions`

よくある原因:
- `cargokit` サブモジュールの初期化失敗 -> CI で `git submodule update --init --recursive cargokit` が実行されているか確認
- Dart コンパイルエラー -> `flutter_rust_bridge` 生成ファイルがコミットされているか確認
- Rust クロスコンパイルエラー -> Android NDK バージョンの不一致

### Telegram 通知が届かない

GitHub Secrets に `TELEGRAM_BOT_TOKEN` と `TELEGRAM_CHAT_ID` が登録されているか確認。
詳細は [Issue #122](https://github.com/higedamc/meiso/issues/122) を参照。

## Related Docs

- [ZAPSTORE_RELEASE_GUIDE_JA.md](ZAPSTORE_RELEASE_GUIDE_JA.md) - Zapstore リリース手順
- [ZAPSTORE_RELEASE_CHECKLIST_v1.1.9.md](ZAPSTORE_RELEASE_CHECKLIST_v1.1.9.md) - リリースチェックリスト
- [LEAF_NODE_PARALLEL_DEVELOPMENT_STRATEGY.md](LEAF_NODE_PARALLEL_DEVELOPMENT_STRATEGY.md) - 開発戦略
- [.github/workflows/build-apk.yml](../.github/workflows/build-apk.yml) - CI ワークフロー定義
