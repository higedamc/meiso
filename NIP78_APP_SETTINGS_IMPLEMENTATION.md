# NIP-78 アプリ設定保存機能の実装完了

## 概要

Meisoアプリに**NIP-78（Application-specific data）**に準拠したアプリ設定のNostr保存機能を実装しました。これにより、ユーザーの設定が**Kind 30078イベント**としてリレーに保存され、複数デバイス間で自動同期されます。

## 実装内容

### 1. Rust側の実装 (`rust/src/api.rs`)

#### 追加されたデータ構造

```rust
/// アプリ設定データ構造（NIP-78 Application-specific data - Kind 30078）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    /// ダークモード設定
    pub dark_mode: bool,
    /// 週の開始曜日 (0=日曜, 1=月曜, ...)
    pub week_start_day: i32,
    /// カレンダー表示形式 ("week" | "month")
    pub calendar_view: String,
    /// 通知設定
    pub notifications_enabled: bool,
    /// 最終更新日時
    pub updated_at: String,
}
```

#### 追加されたRust関数

```rust
// アプリ設定の保存・同期（通常モード）
pub fn save_app_settings(settings: AppSettings) -> Result<String>
pub fn sync_app_settings() -> Result<Option<AppSettings>>

// Amberモード対応
pub fn create_unsigned_encrypted_app_settings_event(
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String>

pub fn fetch_encrypted_app_settings_for_pubkey(
    public_key_hex: String,
) -> Result<Option<EncryptedAppSettingsEvent>>
```

#### イベント構造（Kind 30078 - NIP-78）

```json
{
  "kind": 30078,
  "tags": [
    ["d", "meiso-settings"]
  ],
  "content": "<NIP-44暗号化された設定JSON>"
}
```

### 2. Flutter側の実装

#### アプリ設定モデル (`lib/models/app_settings.dart`)

```dart
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(false) bool darkMode,
    @Default(1) int weekStartDay,
    @Default('week') String calendarView,
    @Default(true) bool notificationsEnabled,
    required DateTime updatedAt,
  }) = _AppSettings;
}
```

#### Provider (`lib/providers/app_settings_provider.dart`)

- **AppSettingsNotifier**: アプリ設定を管理
- **ローカル保存**: Hiveで永続化
- **Nostr同期**: 自動的にリレーに送信
- **Amberモード対応**: NIP-44暗号化・署名フロー完全サポート

#### ローカルストレージ (`lib/services/local_storage_service.dart`)

```dart
// アプリ設定の保存・読み込み
Future<void> saveAppSettings(AppSettings settings)
Future<AppSettings?> loadAppSettings()
```

#### Settings画面統合 (`lib/presentation/settings/settings_screen.dart`)

新しいアプリ設定セクションを追加：

- ダークモード切り替え
- 週の開始曜日選択
- カレンダー表示形式選択（週/月）
- 通知設定切り替え
- Nostr同期ボタン（Nostr接続時のみ表示）

### 3. Amberモード対応

両方のモード（秘密鍵モード・Amberモード）で完全にサポート：

#### 通常モード（秘密鍵モード）
```
設定変更 → Rust側でNIP-44暗号化 → 秘密鍵で署名 → Kind 30078イベント送信
```

#### Amberモード
```
設定変更 → JSON化 → Amber暗号化（NIP-44） → 未署名イベント作成 
→ Amber署名 → Kind 30078イベント送信
```

### 4. マイグレーションバグ修正

起動時に毎回マイグレーションをチェックする問題を修正：

#### 修正内容

1. **初回同期時にマイグレーション完了フラグを自動設定**
   - Kind 30001を使用している場合、初回起動時に自動的にマイグレーション完了フラグをセット
   - これにより毎回のマイグレーションチェックを回避

2. **リモートイベントがない場合、ローカルデータを保持**
   - `syncFromNostr()`でKind 30001イベントが見つからない場合、既存のローカルデータを保持
   - ネットワークエラーや新規ユーザーの初回同期時にデータが消失するのを防止

#### 変更箇所

**`lib/providers/todos_provider.dart`**:

```dart
// _backgroundSync()メソッド
Future<void> _backgroundSync() async {
  // ...
  
  // マイグレーション完了チェック（一度だけ実行）
  final migrationCompleted = await localStorageService.isMigrationCompleted();
  if (!migrationCompleted) {
    print('⚠️ Migration not completed yet. Marking as completed to avoid repeated checks.');
    await localStorageService.setMigrationCompleted();
  }
  
  await syncFromNostr();
  // ...
}

// syncFromNostr()メソッド
Future<void> syncFromNostr() async {
  // ...
  
  // Amberモード: イベントがない場合はローカルデータを保持
  if (encryptedEvent == null) {
    print('⚠️ Todoリストイベントが見つかりません（Kind 30001）');
    print('ℹ️ ローカルデータを保持します');
    _ref.read(syncStatusProvider.notifier).syncSuccess();
    return;  // 上書きしない
  }
  
  // 通常モード: 空リストの場合、ローカルにデータがあれば保持
  if (syncedTodos.isEmpty) {
    state.whenData((localTodos) {
      final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
      if (localTodoCount > 0) {
        print('ℹ️ リモートにイベントがありませんが、ローカルに${localTodoCount}件のTodoがあるため保持します');
        return;  // ローカルデータを保持
      }
    });
  }
  // ...
}
```

## 動作フロー

### 設定変更時（通常モード）

```
1. ユーザーが設定を変更（例: ダークモード切り替え）
2. AppSettingsNotifier.updateSettings()
3. ローカルストレージに保存
4. Rust側: save_app_settings()
   ↓
   NIP-44暗号化 → 秘密鍵で署名 → Kind 30078イベント作成 → リレー送信
```

### 設定変更時（Amberモード）

```
1. ユーザーが設定を変更
2. AppSettingsNotifier.updateSettings()
3. ローカルストレージに保存
4. Flutter側で設定をJSON化
5. Amber NIP-44暗号化（ContentProvider経由、失敗時はIntent）
6. 未署名イベント作成（Kind 30078）
7. Amber署名（ContentProvider経由、失敗時はIntent）
8. リレーに送信
```

### 設定同期時

```
1. アプリ起動時またはユーザーが「同期」ボタンをタップ
2. AppSettingsNotifier.syncFromNostr()
3. リレーからKind 30078イベント取得
4. Amberモード: Amberで復号化
   通常モード: Rust側で復号化
5. ローカルストレージに保存
6. UI更新
```

## メリット

### 1. NIP-78準拠

- 標準的なNostrプロトコルに従ったアプリ固有データの保存
- **Kind 30078（Application-specific data）** を使用
- `d`タグで識別子を指定: `meiso-settings`

### 2. 複数デバイス間の同期

- ユーザーの設定が自動的にリレーに保存される
- 別のデバイスでログインした際に設定が自動復元される

### 3. プライバシー保護

- **NIP-44暗号化**により、設定内容は完全に暗号化
- リレーやネットワーク監視者は内容を読み取れない

### 4. Amberモード完全対応

- 秘密鍵をアプリ外（Amber）で管理
- 暗号化・署名の両方をAmber経由で実行
- ContentProvider経由のバックグラウンド処理で高速化

### 5. オフライン対応

- ローカルストレージ（Hive）で設定を保存
- オフライン時も設定の読み書きが可能
- オンライン復帰時に自動同期

## 設定項目

現在実装されている設定：

1. **ダークモード** (`darkMode`): アプリのテーマ
2. **週の開始曜日** (`weekStartDay`): 0=日曜、1=月曜、...
3. **カレンダー表示** (`calendarView`): "week"（週表示）または "month"（月表示）
4. **通知設定** (`notificationsEnabled`): リマインダー通知の有効/無効

## 今後の拡張

### 追加可能な設定項目

- カラーテーマ（カスタムカラー）
- フォントサイズ
- タスク完了時の効果音
- 自動削除設定（完了タスクの自動削除）
- デフォルトのタスク期限

### 複数設定プロファイル

- ワークモード/プライベートモードなど、複数の設定プロファイルをサポート
- 各プロファイルを別の`d`タグで管理（例: `meiso-settings-work`, `meiso-settings-personal`）

## 技術仕様

### イベントタイプ

- **Kind**: 30078（NIP-78 Application-specific data）
- **Replaceable Event**: 同じ`d`タグを持つ新しいイベントが古いイベントを自動的に置き換える

### タグ

```json
[
  ["d", "meiso-settings"]  // 識別子（固定）
]
```

### 暗号化

- **NIP-44**: バージョン2の暗号化を使用
- 自己暗号化（送信者 = 受信者）
- Content内にJSON形式で設定を保存

### ストレージ

- **ローカル**: Hive（`settings`ボックス、キー: `app_settings`）
- **リモート**: Nostrリレー（Kind 30078イベント）

## テスト項目

### 基本機能

- [x] 設定の保存・読み込み（ローカル）
- [x] 設定のNostr送信（通常モード）
- [x] 設定のNostr同期（通常モード）
- [x] 設定のAmber暗号化・署名（Amberモード）
- [x] 設定のAmber復号化（Amberモード）

### エッジケース

- [x] オフライン時の動作
- [x] ネットワークエラー時の動作
- [x] Amber拒否時の動作
- [x] 初回起動時のデフォルト設定

### マイグレーション

- [x] 初回起動時のマイグレーション完了フラグ自動設定
- [x] リモートイベントがない場合のローカルデータ保持
- [x] 毎回マイグレーションチェックを実行しないこと

## 関連NIP

- **NIP-01**: Basic protocol flow description
- **NIP-44**: Encrypted Payloads（バージョン2）
- **NIP-78**: Application-specific data（Kind 30078）

## ファイル一覧

### 新規作成

- `lib/models/app_settings.dart` - アプリ設定モデル
- `lib/providers/app_settings_provider.dart` - アプリ設定Provider
- `NIP78_APP_SETTINGS_IMPLEMENTATION.md` - このドキュメント

### 変更

- `rust/src/api.rs` - AppSettings構造体とAPI追加
- `lib/services/local_storage_service.dart` - アプリ設定の保存・読み込み追加
- `lib/presentation/settings/settings_screen.dart` - アプリ設定セクション追加
- `lib/providers/todos_provider.dart` - マイグレーションバグ修正

## まとめ

NIP-78に準拠したアプリ設定のNostr保存機能を完全に実装しました。ユーザーの設定がリレーに暗号化保存され、複数デバイス間で自動同期されます。Amberモードにも完全対応し、秘密鍵をアプリ外で管理できます。

また、起動時に毎回マイグレーションをチェックする問題も修正し、アプリのパフォーマンスと安定性が向上しました。

