# Meiso

Nostrプロトコルを活用した個人用タスク管理アプリ

## 現在のステータス

🚀 **MLS PoC完了！Beta版へ移行中** (2025-11-11)

Phase 1-7が完了し、MLSベースのグループTODOリスト機能のProof of Conceptが成功しました。
実デバイス間での2人グループテスト、アプリ内完結型招待システムが完全動作しています。
現在、PoCからBeta版への移行（Phase 8）を進めています。

## コンセプト

「Meiso（瞑想）」は、TeuxDeux風のシンプルなデザインを持つ、Nostrベースのタスク管理アプリです。
FlutterとRustを活用し、Android向けに開発されています。

## 主な機能

### 現在実装済み（Phase 1）

#### コア機能
- ✅ 3列レイアウト（Today / Tomorrow / Someday）
- ✅ タスクの作成・削除
- ✅ タスクの完了/未完了切り替え
- ✅ タスクの並び替え（ドラッグ&ドロップ）
- ✅ スワイプで削除
- ✅ 削除のキャンセル（取り消し機能）
- ✅ タスクをタップして編集
- ✅ 完了済みタスクを一番下に表示

#### UI/UX機能
- ✅ 日付タブバー（5日分の日付表示）
- ✅ 展開可能なカレンダービュー
- ✅ カレンダーアニメーション（スムーズな展開/折りたたみ）
- ✅ Pull to Refresh（下に引いて同期）
- ✅ スワイプで翌日に延期
- ✅ 設定画面（リレー管理、同期設定）
- ✅ 同期ステータスインジケーター

#### 技術実装
- ✅ Riverpod 2.x による状態管理
- ✅ Freezed によるイミュータブルなデータモデル
- ✅ Rust + flutter_rust_bridge 統合
- ✅ Nostr プロトコル基盤（Kind 30078）
- ✅ NIP-44 暗号化/復号化
- ✅ ローカルストレージ（Hive + SharedPreferences）

### Phase 2 完了済み

#### ✅ オンボーディング & 認証
- ✅ **オンボーディング画面**
  - 初回起動時のウェルカムフロー
  - Nostrアカウントセットアップ（Amber連携 / 新規作成 / インポート）
  - デフォルトリレー設定
- ✅ **Amber統合**（外部署名アプリ連携）
  - Intent経由での署名リクエスト
  - 公開鍵の取得と保存
  - NIP-44暗号化/復号化対応
- ✅ **完全なマルチデバイス同期**
  - リアルタイムリレー監視
  - Nostr経由での同期
  - NIP-44暗号化

#### ✅ リカーリングタスク（2025-11-05完全対応）
- ✅ **TeuxDeux完全対応（全7パターン）**
  - `every day` / `everyday` - 毎日
  - `every other day` - 2日ごと
  - `every weekday` - 平日（月〜金）
  - `every week` / `every monday` など - 毎週/特定曜日
  - `every other week` - 2週間ごと
  - `every month` - 毎月
  - `every year` - 毎年
- ✅ **30日分の事前生成**
  - カレンダーを1ヶ月先まで見ても快適
  - タスク完了時に自動で次の30日分を生成
  - 最大50個まで生成（無限ループ防止）
- ✅ **自動タスク生成**
  - 完了時に次回タスクを自動生成
  - 親子関係の追跡
  - 重複防止ロジック
- ✅ **美しいUI**
  - ダイアログ形式の設定画面
  - リアルタイムプレビュー
  - 視覚的マーカー（🔄アイコン）
- ✅ **Nostr同期対応**
  - RecurrencePatternのシリアライズ
  - NIP-44暗号化に完全対応

### Phase 2 完了済み（MLSグループリスト）

#### ✅ MLS (Messaging Layer Security) 統合
- ✅ **OpenMLS統合**（Keychat kc4ブランチ）
  - Rust側MLS基盤実装
  - Export Secret → Nostr鍵ペア生成
  - 二重暗号化アーキテクチャ（MLS + NIP-44）
- ✅ **Key Package管理**
  - Key Package生成・公開（Kind 10443）
  - npubからの自動取得
  - リレー経由での配布
- ✅ **アプリ内完結型招待システム**
  - グループ招待通知（Kind 30078）
  - 招待バッジ表示（SOMEDAY画面）
  - ワンタップ招待受諾
  - 自動リスト詳細画面遷移
- ✅ **実デバイス間テスト完了**
  - 2人グループでの動作確認
  - Alice ↔ Bob間でのTODO共有準備完了
  - Amberモードで完全動作

#### 🚧 Phase 8: Beta版への移行（進行中）
- ⏳ **通常フローへの統合**
  - グループリスト作成の自動化
  - Key Package自動管理
  - 手動操作の削除
- ⏳ **TODO送受信機能完全実装**
  - MLS暗号化送信
  - リアルタイム復号化受信
  - 自動同期
- ⏳ **グループリスト統合**
  - MLSグループへの一本化
  - kind: 30001廃止/互換性対応
- ⏳ **エラーハンドリングと安定性**
  - ネットワークエラー対応
  - MLS固有エラー処理
  - オフライン対応

### Phase 3で実装予定

#### 優先度: 高
- ⏳ **カレンダー機能の拡張**
  - 月表示カレンダー
  - 任意の日付への移動
  - タスクの日付変更（MOVE TO機能）
- ⏳ **リカーリングタスクの拡張**
  - スキップ機能
  - 完了履歴の表示
  - 一括編集機能

#### 優先度: 中
- ⏳ **通知機能**
  - リマインダー
  - 期限切れアラート
- ⏳ **タスクカテゴリ/タグ**
  - 仕事/個人などの分類
  - 複数タグ対応

#### 技術的改善
- ⏳ Repository層の切り出し
- ⏳ ユニットテスト/ウィジェットテストの充実
- ⏳ エラーハンドリングの強化

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

## 変更履歴

### 2025-11-11 - MLS PoC完了（Phase 1-7）

#### 新機能
- 🎉 **MLSグループリスト機能PoC完了**
  - OpenMLS統合（Keychat kc4ブランチ）
  - Rust側MLS基盤（MlsStore, User, Export Secret）
  - Flutter側MLS統合（TodosProvider, CustomListsProvider）
  - MLS統合テストUI（設定画面）

- ✅ **Key Package管理システム**
  - Key Package生成・公開（Kind 10443）
  - npubからの自動取得機能
  - リレー経由での配布
  - MLSテストダイアログ内での公開機能

- ✅ **アプリ内完結型招待システム**
  - グループ招待通知（Kind 30078 + NIP-44準備）
  - SOMEDAY画面での招待バッジ表示
  - 招待受諾ダイアログ
  - MLS DB自動初期化
  - グループ参加後の自動画面遷移

- ✅ **実デバイス間2人グループテスト成功**
  - Alice ↔ Bob間でのKey Package交換
  - グループ作成・招待送信
  - 招待受信・表示
  - グループ参加成功
  - TODO共有準備完了

#### 技術的改善
- ✅ PendingCommitエラー修正（self_commit最適化）
- ✅ グループ招待同期機能（起動時 + Pull-to-refresh）
- ✅ MLS DB初期化の明示的実行
- ✅ Amberモード完全対応
- ✅ エラーハンドリング強化

#### バグ修正
- 🐛 PendingCommitエラー（add_members後のコミット重複）
- 🐛 NoMatchingKeyPackageエラー（Key Package公開タイミング）
- 🐛 MLS DB未初期化エラー（招待受諾時）
- 🐛 グループリスト詳細画面の無限ローディング

詳細: [docs/MLS_IMPLEMENTATION_STRATEGY.md](docs/MLS_IMPLEMENTATION_STRATEGY.md), [docs/MLS_BETA_ROADMAP.md](docs/MLS_BETA_ROADMAP.md), [docs/MLS_TEST_FLOW.md](docs/MLS_TEST_FLOW.md)

### 2025-11-03 - Hiveシリアライゼーション修正

#### バグ修正
- 🐛 **RecurrencePatternのHive保存エラーを修正**
  - すべてのモデルに`@JsonSerializable(explicitToJson: true)`を追加
  - ネストされたオブジェクトが正しくシリアライズされるように修正
  - `HiveError: Cannot write, unknown type: _$RecurrencePatternImpl`を解決

#### 技術的改善
- ✅ `build.yaml`を作成して`json_serializable`のグローバル設定を追加
- ✅ `explicit_to_json: true`をプロジェクト全体で有効化
- ✅ コード生成を実行して`.g.dart`ファイルを再生成
- ✅ `toJson()`メソッドがネストされたオブジェクトに対して正しく呼ばれるように修正
- ✅ すべてのモデルに`@Freezed(makeCollectionsUnmodifiable: false)`を追加

詳細: [docs/HIVE_SERIALIZATION_FIX.md](docs/HIVE_SERIALIZATION_FIX.md)

### 2025-11-03 - 同期エラー修正（Issue #12）

#### バグ修正
- 🐛 **同期インジケーターのスタック問題を修正**
  - タイムアウト処理を追加（通常モード15秒、Amberモード30秒）
  - エラー時の状態更新を改善
  - エラー表示後3秒で自動クリア
- 🐛 **同期完了しない問題を修正**
  - ネットワーク障害時のタイムアウト処理
  - エラーハンドリングの改善
- 🐛 **見せかけの同期完了問題を修正**
  - pendingItemsカウンターの不整合を解消
  - エラー時に明確にエラー表示

#### 技術的改善
- ✅ `_syncToNostr`関数にタイムアウト処理追加
- ✅ `_backgroundSync`関数のエラーハンドリング改善
- ✅ `syncFromNostr`関数のタイムアウト処理追加
- ✅ `SyncStatusIndicator`のエラー表示を5秒後に自動非表示
- ✅ エラーメッセージを短縮表示（「タイムアウト」「接続エラー」）

詳細: [docs/SYNC_ERROR_FIX.md](docs/SYNC_ERROR_FIX.md)

### 2025-11-03 - リカーリングタスク機能実装完了

#### 新機能
- ✅ **リカーリングタスク（繰り返しタスク）**
  - 毎日/毎週/毎月の繰り返しパターン対応
  - 柔軟な間隔設定（2日ごと、2週間ごとなど）
  - 週単位の複数曜日指定
  - 月単位の特定日指定
  - 終了日設定（オプション）
- ✅ **自動タスク生成**
  - 完了時に次回のタスクを自動生成
  - 親子関係の追跡
  - 重複防止ロジック
- ✅ **繰り返し設定UI**
  - ダイアログ形式の美しい設定画面
  - リアルタイムプレビュー
  - 繰り返し解除機能
- ✅ **視覚的マーカー**
  - リカーリングタスクに🔄アイコン表示
  - 編集ダイアログでの繰り返しパターン表示

#### 技術的改善
- ✅ RecurrencePatternモデル作成（Freezed）
- ✅ Todoモデル拡張（recurrence/parentRecurringId）
- ✅ 次回日付計算ロジック実装
- ✅ Nostr同期対応（RecurrencePatternのシリアライズ）
- ✅ 約1200行のコード追加

### 2025-10-30 - Phase 1 完了

#### 実装した主な機能
- ✅ 展開可能なカレンダービュー + アニメーション
- ✅ 日付タブバー（5日分表示）
- ✅ Pull to Refresh（同期機能）
- ✅ スワイプで翌日に延期
- ✅ 削除のキャンセル（取り消しボタン）
- ✅ 設定画面（リレー管理）
- ✅ 同期ステータスインジケーター
- ✅ タスク編集機能（タップして編集）
- ✅ 完了済みタスクを一番下に表示

#### 技術的改善
- ✅ Rust統合（flutter_rust_bridge）
- ✅ Nostr基盤実装（Kind 30078 + NIP-44）
- ✅ イベントID管理
- ✅ キーフォーマットのリファクタリング

### 2025-10-29 - Phase 1 開始

#### 初期実装
- ✅ Flutter プロジェクト作成
- ✅ 3列レイアウト（Today / Tomorrow / Someday）
- ✅ タスクCRUD機能
- ✅ ドラッグ&ドロップ並び替え
- ✅ Riverpod状態管理
- ✅ Freezedデータモデル
- ✅ ローカルストレージ（Hive）

## ライセンス

TBD

## 作者

Kohei Otani  
nostr:npub16lrdq99ng2q4hg5ufre5f8j0qpealp8544vq4ctn2wqyrf4tk6uqn8mfeq