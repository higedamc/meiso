# Flavor Build System & Issue #128 Implementation

## Overview

v1.1.10 で以下を同時に実装した。

1. **Issue #128**: Reminders-first Subtask Mode
2. **Product Flavors**: beta / production のビルド分離
3. **Feature Gate**: beta チャネル限定の実験機能トグル

## 1. Issue #128 - Reminders-first Subtask Mode

GitHub: https://github.com/higedamc/meiso/issues/128

### 実装内容

| 変更 | ファイル |
|---|---|
| `Todo` モデルに `parentTaskId`, `depth`, `taskLinks` を追加 | `lib/models/todo.dart` |
| Rust 側 `TodoData` に同フィールドを追加 | `rust/src/api.rs` |
| FRB ブリッジコード再生成 | `lib/bridge_generated.dart/`, `rust/src/frb_generated.rs` |
| `TaskLink` モデル新規作成 | `lib/models/task_link.dart` |
| サブタスク CRUD 操作 | `lib/providers/todos_provider.dart` |
| サブタスクセクション UI | `lib/widgets/subtask_section.dart` |
| タスクリンクセクション UI | `lib/widgets/task_link_section.dart` |
| タスク編集画面にサブタスク/リンク統合 | `lib/widgets/todo_edit_screen.dart` |
| サブタスク展開/折り畳み表示 | `lib/widgets/todo_item.dart` |
| 親+子タスクの一括完了 | `lib/widgets/todo_item.dart` |
| リスト詳細画面のサブタスク対応 | `lib/presentation/list_detail/list_detail_screen.dart` |
| Nostr同期の `_todoDataToTodo()` 共通化 | `lib/providers/nostr_provider.dart` |

### 設計方針

- サブタスク深度は1階層のみ (parent -> child)
- 孫タスクの作成はガード (`addSubtask` 内)
- 既存の深いデータは読み取り可能 (破壊的マイグレーションなし)
- タスクリンク (blocks, blocked_by, related_to, duplicate_of) は Asana モード限定

## 2. Product Flavors

### 構成

| Flavor | applicationId | アプリ名 | 用途 |
|---|---|---|---|
| `production` | `jp.godzhigella.meiso` | Meiso | zapstore 配布用 (v1.1.9 互換) |
| `beta` | `jp.godzhigella.meiso.beta` | Meiso Beta | テスト版 (実験機能有効) |

### ファイル変更

- `android/app/build.gradle.kts`: `flavorDimensions` + `productFlavors` 追加
- `lib/core/config/app_config.dart`: `BuildChannel` enum + `--dart-define=BUILD_CHANNEL` 対応

### ビルドコマンド

```bash
# Production (zapstore 互換)
fvm flutter build apk --flavor production --release --dart-define=BUILD_CHANNEL=release

# Beta (実験機能付き)
fvm flutter build apk --flavor beta --release --dart-define=BUILD_CHANNEL=beta
```

### 署名

両 flavor とも `signingConfig = signingConfigs.getByName("debug")` を使用。
v1.1.9 で zapstore に debug 鍵で配布しているため、production の署名方式を変更すると
既存ユーザーがアップデートできなくなる。この互換性を維持している。

## 3. Feature Gate (実験機能トグル)

### 構成

| ファイル | 役割 |
|---|---|
| `lib/features/feature_gate/feature_id.dart` | 機能ID定義 |
| `lib/features/feature_gate/feature_gate_service.dart` | チャネル判定 + フラグ管理 |
| `lib/models/app_settings.dart` | `TaskUiMode`, `featureFlags` 追加 |
| `lib/providers/app_settings_provider.dart` | 設定の永続化 + Nostr同期 |
| `lib/presentation/settings/settings_screen.dart` | 設定画面 UI |

### 実験機能一覧

| Feature ID | 説明 | beta 限定 |
|---|---|---|
| `mode_asana` | Asana 風 UI モード | Yes |
| `mode_wunderlist` | Wunderlist 風 UI モード | Yes |
| `mode_kanban` | Kanban 風 UI モード | Yes |
| `task_linking` | タスクリンク機能 (Asana モード時) | Yes |

beta チャネルの設定画面 > Advanced セクションにトグルスイッチとして表示される。
production チャネルでは非表示。

## 4. CargoKit Flavor 互換性修正

### 問題

`cargokit/gradle/plugin.gradle` が product flavor に非対応だった。

- タスク依存関係が `merge${buildType}NativeLibs` にのみマッチ
- flavor 使用時の実際のタスク名 `merge${variant.name}NativeLibs` にマッチしない
- 結果: Rust `.so` がコンパイルされず APK に含まれない
- `RustLib.init()` が失敗しアプリがスプラッシュスクリーンで停止

### 修正

1. **タスク配線**: `variant.name.capitalize()` を使用して flavor 付きタスク名にマッチ
2. **重複防止**: `registeredBuildTypes` セットで `jniLibs.srcDir` の重複登録を防止
3. **タスク再利用**: 同一 buildType の cargo build タスクを複数 flavor 間で共有

```groovy
// Before (flavor 非対応)
if (newTask.name == "merge${buildType.capitalize()}NativeLibs") {

// After (flavor 対応)
def mergeTaskName = "merge${variant.name.capitalize()}NativeLibs"
if (newTask.name == mergeTaskName) {
```

### stale jniLibs の削除

`android/app/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/librust.so` を削除。
これらは過去にコミットされた古い `.so` で、cargokit の出力を上書きしていた。

## 5. CI ワークフロー変更

### v1.1.9 との差分

| 項目 | v1.1.9 | v1.1.10 |
|---|---|---|
| ビルドコマンド | `flutter build apk --release` | `flutter build apk --flavor production --release --dart-define=BUILD_CHANNEL=release` |
| 出力ファイル名 | `app-release.apk` | `app-production-release.apk` |
| ABI 分割 | なし | なし (維持) |
| 署名方式 | debug 鍵 + 条件付き再署名 | 同一 |
| Keystore ファイル名 | `release-keystore.jks` | 同一 |

### 注意事項

- zapstore 側で APK ファイル名を参照している場合、`app-production-release.apk` に更新が必要
- 署名の整合性は完全に保たれている (debug 鍵)

## 6. その他の変更

| 変更 | 理由 |
|---|---|
| `android/app/build.gradle.kts`: `ndk.abiFilters("arm64-v8a")` 削除 | cargokit が全 ABI をビルドするため |
| `android/app/build.gradle.kts`: `isMinifyEnabled = false` | flutter_rust_bridge の FFI が R8 で壊れるため |
| `android/app/src/main/AndroidManifest.xml`: `extractNativeLibs="true"` | ネイティブライブラリの正しいロード |
| `rust/Cargo.toml`: `panic = "abort"` | リリースビルドのバイナリサイズ削減 |
| `lib/main.dart`: Rust 初期化失敗時に `Error.throwWithStackTrace` | Rust 不在のまま起動を許さない |
| `.gitignore`: `rust/build/` 追加 | cargokit ビルドキャッシュの除外 |
