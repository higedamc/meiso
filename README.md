# Meiso

Nostrプロトコルを活用した個人用タスク管理アプリ

## コンセプト

「Meiso（瞑想）」は、TeuxDeux風のシンプルなデザインを持つ、Nostrベースのタスク管理アプリです。
FlutterとRustを活用し、Android向けに開発されています。

## 主な機能

### 現在実装済み（Phase 1）

- ✅ 3列レイアウト（Today / Tomorrow / Someday）
- ✅ タスクの作成・削除
- ✅ タスクの完了/未完了切り替え
- ✅ タスクの並び替え（ドラッグ&ドロップ）
- ✅ スワイプで削除
- ✅ Riverpodによる状態管理
- ✅ Freezedによるイミュータブルなデータモデル

### Phase 2で実装予定

- ⏳ Rust側のNostr統合
- ⏳ NIP-44による暗号化
- ⏳ Kind 30078（Application-specific data）でのデータ保存
- ⏳ Amber統合（外部署名）
- ⏳ デフォルトリレー + カスタムリレー設定
- ⏳ マルチデバイス同期
- ⏳ カレンダービューでの日付指定

### Phase 3で実装予定（Citrine連携）

- ⏳ **Citrineローカルリレー統合**
  - Citrine検出機能（インストール状態確認）
  - ローカルリレー優先接続（ws://localhost:4869）
  - オフライン時の自動フォールバック
  - Citrine→リモートリレー同期設定
- ⏳ **パフォーマンス最適化**
  - ローカルキャッシュ戦略（Citrine活用）
  - バッテリー効率の向上
  - 起動速度の改善
- ⏳ **プライバシー強化**
  - ローカルファースト設定（Citrineのみ使用）
  - リレー選択のカスタマイズ

## 技術スタック

### Flutter側
- **UI**: Flutter 3.x
- **状態管理**: Riverpod 2.x
- **データモデル**: Freezed + json_serializable
- **ローカルストレージ**: Hive

### Rust側（Phase 2）
- **Nostr**: rust-nostr
- **暗号化**: NIP-44
- **ブリッジ**: flutter_rust_bridge

## Nostr仕様

### イベント構造

```
Kind: 30078 (Application-specific data)
Content: NIP-44で暗号化されたTodoのJSONデータ
Tags: ["d", "todo-{uuid}"]
```

### データモデル

```json
{
  "id": "uuid",
  "title": "タスク名",
  "completed": false,
  "date": "2025-10-29",
  "order": 1,
  "createdAt": "2025-10-29T12:00:00Z",
  "updatedAt": "2025-10-29T12:00:00Z"
}
```

## プロジェクト構造

```
lib/
├── main.dart                    # エントリーポイント
├── app_theme.dart              # テーマ設定
├── models/
│   └── todo.dart               # Todoデータモデル
├── providers/
│   └── todos_provider.dart     # Riverpod Provider
├── presentation/
│   └── home/
│       └── home_screen.dart    # メイン画面
└── widgets/
    ├── add_todo_field.dart     # タスク追加フィールド
    ├── todo_column.dart        # 列ウィジェット
    └── todo_item.dart          # タスクアイテム
```

## セットアップ

### 前提条件

- Flutter 3.x
- FVM（推奨）
- Android SDK

### インストール

```bash
cd ~/work/meiso
fvm flutter pub get
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

### 実行

```bash
# Android実機/エミュレーターで実行
fvm flutter run
```

## 開発方針

### コーディングポリシー

- **状態管理**: Riverpod 2.x を使用、ConsumerWidget は禁止
- **UI**: 原則 StatelessWidget、必要な場合のみ StatefulWidget
- **データモデル**: Freezed でイミュータブルに
- **MVP優先**: Phase1ではRepositoryレイヤーは作成せず、Provider に集約

### Phase 2への移行

1. **Rustセットアップ**
   - flutter_rust_bridge の導入
   - rust-nostr の統合
   
2. **Nostr機能実装**
   - イベント作成/送信
   - NIP-44暗号化/復号
   - リレー接続管理
   
3. **Amber統合**
   - Intent連携
   - 署名フロー実装

## ライセンス

TBD

## 作者

godzhigella
