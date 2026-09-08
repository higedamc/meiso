# meiso プロジェクトルール

## 言語ポリシー

**対外的な成果物はすべて英語で書く**: GitHub の issue、PR のタイトル・本文、README.md、コード内の実装コメント（注釈）、コミットメッセージ。ユーザーとの会話や CLAUDE.md 等の内部メモは日本語でよい。

## スタック概要

- Flutter（**fvm 管理**: `fvm flutter ...`。素の `flutter` は PATH に無い）+ Rust（flutter_rust_bridge）。Rust はビルド中に cargokit が Android 3 ABI をクロスコンパイルする（初回は非常に重い）。
- 公開 `#[frb]` API を変更したら `./generate.sh` で FRB 再生成（数分かかる）。変更していなければ再生成不要。
- `cui/` は Go 製 CLI（module `github.com/higedamc/meiso/cui`）。アプリと同じ Nostr プロトコルを喋る。

## ブランチの罠

- **`main` には 1.4.0 の実装が未マージ**（2026-07-15 時点で `origin/release/1.4.0` が main より 31 コミット先行）。shared-v1 の Rust 実装（`group_tasks_shared.rs` 等）は main に存在しない。1.4.0 の機能を触る作業は `release/1.4.0` 系をベースにすること。着手前に `git rev-list --count origin/main..origin/release/1.4.0` で最新状況を確認する。

## 実機へのインストール（必読）

実機にアプリを入れる際は、**`flutter run` / `flutter install` を使わず、ビルドのみ行って必ず `adb install --user 0` でインストールする**こと。Flutter コマンドではインストール先のユーザープロファイルを選べないため。

```bash
# 1. ビルドのみ（テスト配布・実機併存は必ず beta flavor を使うこと）
fvm flutter build apk --flavor beta --debug

# 2. adb で --user 0 を指定してインストール
adb install --user 0 build/app/outputs/flutter-apk/app-beta-debug.apk
```

- `adb install` には**必ず `--user 0` を付ける**。

### ⚠️ flavor の罠

`production` flavor は appId・署名ともリリース版と同一（release ビルドも debug keystore 署名。zapstore 互換のため変更不可）。`app-production-debug.apk` を実機に入れると**ユーザーのリリース版を上書きしてしまう**。実機テスト用 APK は必ず `--flavor beta`（appId `jp.godzhigella.meiso.beta`、別アプリとして併存）。復旧は正規リリース APK の再インストール（データ維持）。詳細は `docs/FLAVOR_BUILD_AND_ISSUE_128_IMPLEMENTATION.md`。

## ビルド環境の注意

- **ディスク**: 1 回のビルドで `build/` が 20GB 超になる。ビルド前に `df -h` を確認し、使い終わった worktree は `flutter clean` する。逼迫時は `build/app/intermediates`（再生成可能な Gradle 中間物）から削除。
- **エミュレーター**: `-gpu host` 必須（swiftshader はシステム ANR 連発で使用不能）。RAM は `-memory 4096` 推奨。

## Nostr プロトコル（共同編集リスト）

現行は **shared-v1**（1.4.0〜）。MLS 経路と NIP-72 型 `rust/src/group_tasks.rs` はレガシーで、shared-v1 と混同しないこと。

- **タスク**: `kind:35000`（addressable）、author = グループ専用鍵 `G`、`d=<task-uuid>`、content = NIP-44 自己暗号化。LWW は relay の replaceable で成立。
- **グループメタ**: `kind:35001`、author=`G`、`d="meta"`。
- **招待**: `kind:30078`、author=招待者の実鍵、`d="shared-invite-<group_id>-<recipientHex>"`、`p=<受信者hex>`、content = NIP-44(inviter→recipient) で `{group_id, group_nsec, group_name, key_epoch}`。
- 同じ kind:30078 に旧 MLS 互換の `d="group-invitation-*"` が混在するため、**`d` プレフィクスで必ず分岐**する。
- **既知の構造的欠落**: 作成者（inviter）の新端末復旧経路が無い（`#p=self` の自分宛招待を publish していないため、新端末で招待 0 件 → credentials 復元不能）。「共有リストが新端末で見えない」相談はまずこのパターンを疑う。暫定回避は既存メンバーから作成者を招待し直してもらうこと。

## 同期まわりの開発原則

- **署名・権限コードには触らない**: per-event 署名（Amber の都度承認）は Nostr 理念に沿った仕様であり、「直すべき摩擦」ではない。広い権限へ誘導する変更は NG。
- **ログインモード非依存**: Amber モードとシークレットキー・モードで体験に差を生まない（フェッチの EOSE 化などは両モードに適用してパリティを取る）。
- **group / giftwrap（kind:445 / 1059）のフェッチは all-relay 信頼性が必要なため EOSE 早期打ち切り不可**。todo リスト等の replaceable 取得のみ EOSE 化してよい。
