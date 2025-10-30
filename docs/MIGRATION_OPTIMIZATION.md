# マイグレーション最適化の実装完了

## 問題点

従来の実装では、初回起動時に以下の問題がありました：

### シナリオ: 既にマイグレーション済みのユーザー

```
状況: 別デバイスで既にKind 30001にマイグレーション済み
↓
初回起動時、ローカルにマイグレーション完了フラグがない
↓
Kind 30078（旧形式）を検索 → 40個のTODOイベント発見
↓
マイグレーション実行
↓
Amberで40回復号化 ⚠️ 不要な処理！
↓
Kind 30001に集約（既に存在するのに...）
```

**問題**: 既にマイグレーション済みなのに、40回Amberを起動してしまう

---

## 解決策

### 実装方針

**Kind 30001を優先チェック** → 存在すればマイグレーション不要

```
初回起動
↓
1. Kind 30001（新形式）をチェック
   ├─ データあり → マイグレーション済み ✅
   │  └─ Kind 30001から読み込み（1回で完了）
   └─ データなし → Kind 30078をチェック
      ├─ 旧データあり → マイグレーション実行
      │  └─ 40回Amber起動（初回のみ、避けられない）
      └─ 旧データなし → 新規ユーザー
         └─ マイグレーション不要
```

---

## 実装内容

### 1. 新規関数: `checkKind30001Exists()`

**場所**: `lib/providers/todos_provider.dart`

```dart
/// Kind 30001（新形式）にデータが存在するかチェック
/// 
/// Kind 30001にデータがある = マイグレーション済み（別デバイスで実行済みなど）
Future<bool> checkKind30001Exists() async {
  try {
    final nostrService = _ref.read(nostrServiceProvider);
    final isAmberMode = _ref.read(isAmberModeProvider);
    
    if (isAmberMode) {
      // Amberモード: 暗号化されたTodoリストイベントを取得
      final encryptedEvent = await nostrService.fetchEncryptedTodoList();
      
      if (encryptedEvent != null) {
        print('✅ Found Kind 30001 event (Amber mode)');
        return true;
      }
    } else {
      // 通常モード: Rust側で復号化済みのTodoリストを取得
      final todos = await nostrService.syncTodoListFromNostr();
      
      if (todos.isNotEmpty) {
        print('✅ Found Kind 30001 with ${todos.length} todos (normal mode)');
        return true;
      }
    }
    
    print('ℹ️ No Kind 30001 found');
    return false;
  } catch (e) {
    print('⚠️ Failed to check Kind 30001: $e');
    return false;
  }
}
```

### 2. `_backgroundSync()`の改善

**変更点**:

```dart
// マイグレーション完了チェック（一度だけ実行）
final migrationCompleted = await localStorageService.isMigrationCompleted();
if (!migrationCompleted) {
  print('🔍 Checking data status...');
  
  // ⭐ まずKind 30001（新形式）をチェック
  _ref.read(syncStatusProvider.notifier).updateMessage('データ読み込み中...');
  final hasNewData = await checkKind30001Exists();
  
  if (hasNewData) {
    // ✅ Kind 30001にデータがある = マイグレーション済み
    print('✅ Found Kind 30001 data. Migration already completed on another device.');
    print('📥 Loading data from Kind 30001...');
    
    // マイグレーション完了フラグをセット（マイグレーション不要）
    await localStorageService.setMigrationCompleted();
  } else {
    // Kind 30001がない → Kind 30078をチェック
    print('🔍 No Kind 30001 found. Checking for old Kind 30078 events...');
    final needsMigration = await checkMigrationNeeded();
    
    if (needsMigration) {
      print('📦 Found old Kind 30078 TODO events. Starting migration...');
      _ref.read(syncStatusProvider.notifier).updateMessage('データ移行中...');
      
      // マイグレーション実行（Kind 30078 → Kind 30001）
      await migrateFromKind30078ToKind30001();
      print('✅ Migration completed successfully');
    } else {
      print('✅ No old events found. Marking migration as completed.');
      await localStorageService.setMigrationCompleted();
    }
  }
}
```

### 3. ステータスメッセージの改善

**追加したメッセージ**:

| 状況 | メッセージ |
|------|-----------|
| Kind 30001チェック中 | `データ読み込み中...` |
| マイグレーション準備 | `データ移行準備中...` |
| 旧データ取得中 | `旧データ取得中...` |
| 新形式に変換中 | `新形式に変換中...` |
| 旧データ削除中 | `旧データ削除中...` |
| 移行完了 | `データ移行完了` |
| 通常同期 | `データ同期中...` |

**実装**: `lib/providers/sync_status_provider.dart`

```dart
/// 同期ステータス情報
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    // ...
    
    /// 同期中のメッセージ（「データ読み込み中...」「データ移行中...」など）
    String? message,
    
    // ...
  }) = _SyncStatus;
}

// メソッド追加
void updateMessage(String message) {
  state = state.copyWith(message: message);
}

void clearMessage() {
  state = state.copyWith(message: null);
}
```

---

## フローチャート

### ケース1: 既にマイグレーション済み（別デバイス）

```
初回起動
↓
_backgroundSync()
├─ マイグレーション完了フラグ確認 → なし
├─ checkKind30001Exists() → ✅ 発見！
├─ マイグレーション完了フラグをセット
└─ syncFromNostr() → Kind 30001から読み込み（1回で完了）

結果: 40回Amber起動を回避 ✅
```

### ケース2: 初回マイグレーション必要

```
初回起動
↓
_backgroundSync()
├─ マイグレーション完了フラグ確認 → なし
├─ checkKind30001Exists() → なし
├─ checkMigrationNeeded() → ✅ Kind 30078が40個
├─ migrateFromKind30078ToKind30001()
│  ├─ 40個取得・復号化（40回Amber起動 - 避けられない）
│  ├─ Kind 30001に集約
│  ├─ Kind 5で削除
│  └─ マイグレーション完了フラグをセット
└─ syncFromNostr() → Kind 30001から読み込み

結果: 初回のみ40回Amber起動（必要な処理）
```

### ケース3: 新規ユーザー

```
初回起動
↓
_backgroundSync()
├─ マイグレーション完了フラグ確認 → なし
├─ checkKind30001Exists() → なし
├─ checkMigrationNeeded() → なし（Kind 30078もなし）
├─ マイグレーション完了フラグをセット
└─ syncFromNostr() → データなし

結果: マイグレーション不要 ✅
```

### ケース4: 2回目以降の起動

```
2回目以降
↓
_backgroundSync()
├─ マイグレーション完了フラグ確認 → ✅ 完了済み
└─ syncFromNostr() → Kind 30001から読み込み

結果: マイグレーションチェック自体をスキップ ✅
```

---

## メリット

### 1. 不要なマイグレーションを回避

- 既にマイグレーション済みの場合、Kind 30001を直接読み込み
- 40回Amber起動が不要に

### 2. ユーザー体験の向上

- 「データ読み込み中...」「データ移行中...」など、状況に応じたメッセージ表示
- ユーザーが今何が起きているか理解しやすい

### 3. 効率的なチェック

```
従来: Kind 30078チェック → マイグレーション → Kind 30001作成
改善: Kind 30001チェック → あれば完了（マイグレーション不要）
```

### 4. 複数デバイス対応

- デバイスAでマイグレーション実行
- デバイスBでは自動的にKind 30001を検出
- デバイスBでは不要なマイグレーションをスキップ

---

## テストシナリオ

### シナリオ1: 既にマイグレーション済み（別デバイス）

**期待動作**:
1. Kind 30001を検出
2. 「データ読み込み中...」表示
3. マイグレーション完了フラグをセット
4. 40回Amber起動なし ✅

### シナリオ2: 初回マイグレーション

**期待動作**:
1. Kind 30001なし、Kind 30078が40個
2. 「データ移行中...」表示
3. 40回Amber起動（初回のみ、必要）
4. Kind 30001に集約
5. 旧データ削除

### シナリオ3: 新規ユーザー

**期待動作**:
1. Kind 30001なし、Kind 30078なし
2. マイグレーション完了フラグをセット
3. データなし状態で起動

### シナリオ4: 2回目以降

**期待動作**:
1. マイグレーション完了フラグあり
2. マイグレーションチェック自体をスキップ
3. Kind 30001から通常同期

---

## 変更ファイル

### 変更

- `lib/providers/todos_provider.dart`
  - `checkKind30001Exists()` 追加
  - `_backgroundSync()` 改善
  - `migrateFromKind30078ToKind30001()` にメッセージ追加

- `lib/providers/sync_status_provider.dart`
  - `SyncStatus` に `message` フィールド追加
  - `updateMessage()` / `clearMessage()` メソッド追加

### 新規作成

- `MIGRATION_OPTIMIZATION.md` (このドキュメント)

---

## まとめ

マイグレーション処理を最適化し、**Kind 30001を優先チェック**することで：

- ✅ 既にマイグレーション済みの場合、40回Amber起動を回避
- ✅ ユーザーに適切なメッセージを表示
- ✅ 複数デバイス間でスムーズに動作
- ✅ 新規ユーザーは影響なし

これにより、ユーザー体験が大幅に向上しました！

