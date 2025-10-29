# Meiso - Phase 1 完了サマリー

## プロジェクト概要

**Meiso（瞑想）** は、Nostrプロトコルを活用した個人用タスク管理アプリです。

### 基本情報
- **パッケージ名**: `jp.godzhigella.meiso`
- **プロジェクトパス**: `~/work/meiso`
- **対象プラットフォーム**: Android
- **技術スタック**: Flutter + Rust
- **デザイン**: TeuxDeux風のシンプルなUI

---

## Phase 1: 完了内容

### ✅ 実装完了項目

#### 1. プロジェクトセットアップ
- Flutter 3.x プロジェクト作成
- 依存関係の追加:
  - `flutter_riverpod` ^2.6.1 (状態管理)
  - `freezed_annotation` ^2.4.4 (イミュータブルモデル)
  - `json_annotation` ^4.9.0 (JSON変換)
  - `uuid` ^4.5.1 (UUID生成)
  - `intl` ^0.19.0 (日付フォーマット)
  - `hive` ^2.2.3 (ローカルストレージ)
  - `shared_preferences` ^2.3.3

#### 2. ディレクトリ構造
```
lib/
├── main.dart
├── app_theme.dart
├── models/
│   └── todo.dart
├── providers/
│   ├── todos_provider.dart
│   └── date_provider.dart
├── presentation/
│   └── home/
│       └── home_screen.dart
└── widgets/
    ├── add_todo_field.dart
    ├── bottom_navigation.dart
    ├── date_tab_bar.dart
    ├── day_page.dart
    └── todo_item.dart
```

#### 3. データモデル (Nostr準拠設計)
- **Todoモデル**: Freezedでイミュータブル実装
- **Nostrイベント構造を意識**:
  - Kind: 30078 (Application-specific data)
  - Content: NIP-44で暗号化予定
  - Tags: `["d", "todo-{uuid}"]`

```dart
class Todo {
  String id;           // UUID
  String title;        // タスク名
  bool completed;      // 完了状態
  DateTime? date;      // null = Someday
  int order;           // 並び順
  DateTime createdAt;  // 作成日時
  DateTime updatedAt;  // 更新日時
  String? eventId;     // NostrイベントID
}
```

#### 4. UI実装 (TeuxDeux風)

##### レイアウト
- **PageViewベース**: 1日分を全画面表示
- **横スワイプ**: 日付間の移動
- **日付ヘッダー**: 左寄せ表示 + 右端に設定アイコン
- **日付タブバー**: 紫グラデーション、5日分表示
- **底部ナビゲーション**: TODAY / + / SOMEDAY

##### 機能
- タスクの作成・削除
- タスクの完了/未完了切り替え
- ドラッグ&ドロップで並び替え
- スワイプで削除
- 日付タブタップで直接移動
- TODAYボタンで今日にジャンプ
- SOMEDAYボタンで日付未定タスク表示

#### 5. 状態管理
- **Riverpod 2.x** を使用
- **ルール**: ConsumerWidget禁止、StatelessWidget + Consumer推奨
- **Provider構成**:
  - `todosProvider`: 日付ごとのTodoマップ管理
  - `todosForDateProvider`: 特定日付のTodo取得
  - `currentDateProvider`: 現在表示中の日付
  - `dateListProvider`: 表示日付リスト生成

#### 6. テーマ設定
- `app_theme.dart` でカラー/フォント/スタイルを一元管理
- TeuxDeux風の落ち着いた配色
- シンプルで読みやすいタイポグラフィ

---

## 技術仕様

### Nostrプロトコル設計

#### イベント構造
```
Kind: 30078 (Application-specific data)
Content: {暗号化されたTodo JSONデータ}
Tags: [["d", "todo-{uuid}"]]
```

#### 暗号化方式
- **NIP-44**: XChaCha20-Poly1305 + HMAC-SHA256
- 自分の公開鍵で暗号化（自分だけが復号可能）

#### 認証方式
1. **Amber統合** (外部署名アプリ)
   - Android Intent経由で署名
   - 公開鍵のみアプリが保持
2. **アプリ内生成**
   - Rust側で秘密鍵生成
   - ローカル暗号化保存（Biometric推奨）

#### リレー設定
- デフォルトリレーリスト内蔵
- ユーザーによるカスタムリレー追加可能
```
wss://relay.damus.io
wss://nos.lol
wss://relay.nostr.band
wss://nostr.wine
```

---

## Phase 2: 次のステップ

### 🚀 ネクストアクション

#### Step 1: Rust環境セットアップ
1. **flutter_rust_bridge の導入**
   ```bash
   cargo install flutter_rust_bridge_codegen
   flutter pub add flutter_rust_bridge
   flutter pub add ffi
   ```

2. **Rustプロジェクト作成**
   ```bash
   cd ~/work/meiso
   cargo new --lib rust
   ```

3. **Cargo.toml 設定**
   ```toml
   [dependencies]
   flutter_rust_bridge = "2.0"
   nostr-sdk = "0.31"  # rust-nostr
   ```

#### Step 2: Nostr機能実装

1. **基本構造**
   ```rust
   pub struct MeisoNostrClient {
       keys: Keys,
       client: Client,
   }
   
   pub async fn create_todo_event(todo: TodoData) -> Result<EventId>
   pub async fn update_todo_event(todo: TodoData) -> Result<EventId>
   pub async fn delete_todo_event(id: String) -> Result<()>
   pub async fn sync_todos() -> Result<Vec<TodoData>>
   ```

2. **NIP-44暗号化**
   ```rust
   use nostr_sdk::nips::nip44;
   
   let encrypted = nip44::encrypt(
       &secret_key,
       &public_key,
       &todo_json,
   )?;
   ```

3. **イベント作成**
   ```rust
   let event = EventBuilder::new(
       Kind::Custom(30078),
       encrypted_content,
       &[Tag::Identifier(format!("todo-{}", uuid))]
   ).to_event(&keys)?;
   ```

4. **リレー接続**
   ```rust
   client.add_relay("wss://relay.damus.io").await?;
   client.connect().await;
   client.send_event(event).await?;
   ```

#### Step 3: Amber統合

1. **Intent設定** (`android/app/src/main/AndroidManifest.xml`)
   ```xml
   <queries>
       <package android:name="com.greenart7c3.nostrsigner" />
   </queries>
   ```

2. **署名フロー実装**
   ```dart
   // Flutter側
   Future<NostrEvent> signWithAmber(UnsignedEvent event) async {
     final intent = AndroidIntent(
       package: 'com.greenart7c3.nostrsigner',
       action: 'sign_event',
       arguments: {'event': jsonEncode(event)},
     );
     await intent.launch();
     // 結果を受け取る...
   }
   ```

3. **Rust側での分岐**
   ```rust
   pub enum SignerType {
       Local(Keys),
       Amber(PublicKey),
   }
   ```

#### Step 4: データ同期実装

1. **初回同期**
   - アプリ起動時にリレーから全イベント取得
   - Hiveにローカルキャッシュ

2. **リアルタイム同期**
   - Subscription でリレーを監視
   - 新規イベント受信時にローカル更新

3. **オフライン対応**
   - ローカル変更をキューイング
   - オンライン復帰時に送信

#### Step 5: 追加機能

1. **カレンダービュー**
   - `table_calendar` パッケージ導入
   - 日付選択ダイアログ

2. **リカーリングタスク**
   - Todoモデルに `recurrence` フィールド追加
   - cron式での繰り返し設定

3. **設定画面**
   - リレー管理
   - アカウント切り替え
   - テーマ設定（ダーク/ライト）

---

## 開発ルール

### コーディングポリシー
- **状態管理**: Riverpod 2.x、ConsumerWidget禁止
- **UI**: 原則StatelessWidget
- **データモデル**: Freezedでイミュータブル
- **MVP優先**: Repository層は後で切り出し

### ファイル命名規則
- UI: `○○_screen.dart`, `○○_page.dart`
- Provider: `○○_provider.dart`
- Model: `○○.dart` (パスカルケース)
- Widget: `○○_widget.dart` または `○○.dart`

### コミットルール
- Phase単位でブランチ分ける
- 小まめなコミット
- PRベースでのレビュー

---

## 参考リソース

### Nostr関連
- [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md): Basic protocol
- [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md): Encrypted Payloads
- [rust-nostr](https://github.com/rust-nostr/nostr): Rust implementation

### Flutter関連
- [Riverpod公式](https://riverpod.dev/)
- [Freezed](https://pub.dev/packages/freezed)
- [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)

### デザイン参考
- [TeuxDeux](https://teuxdeux.com/): UIデザインの参考元

---

## トラブルシューティング

### よくある問題

1. **build_runner実行時のエラー**
   ```bash
   fvm flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. **Riverpod関連のエラー**
   - ConsumerWidgetを使用していないか確認
   - Consumer(builder: ...) を使用する

3. **日付フォーマットエラー**
   ```dart
   await initializeDateFormatting('en_US');
   ```

---

## まとめ

Phase 1では、Meisoアプリの基本的なUI/UX と状態管理を完成させました。
ダミーデータで完全に動作する状態です。

**Phase 2では、Nostr統合により真の分散型タスク管理アプリになります！**

次は `Step 1: Rust環境セットアップ` から始めましょう 🚀

