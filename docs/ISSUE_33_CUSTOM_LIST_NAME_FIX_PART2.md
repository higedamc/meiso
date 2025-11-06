# Issue #33 Part 2: 同期問題の修正

## 問題2の解決策: Nostr同期の優先

### アプローチ

1. `CustomListsProvider._initialize()` で、ローカルにリストがない場合は**デフォルトリストを作成しない**
2. まず空の状態にし、**Nostrからの同期を優先**
3. Nostr同期後、**まだ空の場合のみ**デフォルトリストを作成

### 実装内容

#### 1. `_initialize()` の修正

**変更前**:
```dart
Future<void> _initialize() async {
  final localLists = await localStorageService.loadCustomLists();
  
  if (localLists.isEmpty) {
    // 初回起動時のみダミーデータを作成
    await _createInitialLists();
  } else {
    state = AsyncValue.data(sortedLists);
  }
}
```

**変更後**:
```dart
Future<void> _initialize() async {
  final localLists = await localStorageService.loadCustomLists();
  
  if (localLists.isEmpty) {
    // ローカルにリストがない場合は、まず空の状態にする
    // Nostrからの同期を待ってから、必要に応じてデフォルトリストを作成
    AppLogger.info(' [CustomLists] No local lists found. Waiting for Nostr sync...');
    state = AsyncValue.data([]);
  } else {
    state = AsyncValue.data(sortedLists);
  }
}
```

#### 2. `createDefaultListsIfEmpty()` メソッドの追加

```dart
/// 初回起動時のデフォルトリストを作成（Nostr同期後にリストが空の場合のみ）
Future<void> createDefaultListsIfEmpty() async {
  await state.whenData((lists) async {
    // 既にリストがある場合は何もしない
    if (lists.isNotEmpty) {
      AppLogger.debug(' [CustomLists] Lists already exist, skipping default creation');
      return;
    }
    
    AppLogger.info(' [CustomLists] Creating default lists (no lists found after Nostr sync)');
    
    final initialListNames = [
      'BRAIN DUMP',
      'GROCERY',
      'WISHLIST',
      'NOSTR',
      'WORK',
    ];
    
    // デフォルトリストを作成...
  }).value;
}
```

#### 3. `syncListsFromNostr()` の修正

Nostr同期後に `createDefaultListsIfEmpty()` を呼び出す：

```dart
Future<void> syncListsFromNostr(List<String> nostrListNames) async {
  // Nostrからのリストを同期...
  
  // Nostr同期後、リストが空の場合はデフォルトリストを作成
  await createDefaultListsIfEmpty();
}
```

#### 4. `todosProvider.syncFromNostr()` の修正

**Amberモード**と**通常モード**の両方で、`nostrListNames`が空の場合でも `syncListsFromNostr()` を呼び出すように修正：

**変更前（Amberモード）**:
```dart
if (nostrListNames.isNotEmpty) {
  await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
}
```

**変更後（Amberモード）**:
```dart
// カスタムリストを同期（名前ベース）
// nostrListNamesが空の場合でも呼び出し、デフォルトリストを作成
await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
```

**変更前（通常モード）**:
```dart
if (nostrListNames.isNotEmpty) {
  AppLogger.info(' ${nostrListNames.length}件のカスタムリストを同期します');
  await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
} else {
  AppLogger.debug(' カスタムリストが見つかりませんでした');
}
```

**変更後（通常モード）**:
```dart
// カスタムリストを同期（名前ベース）
// nostrListNamesが空の場合でも呼び出し、デフォルトリストを作成
if (nostrListNames.isNotEmpty) {
  AppLogger.info(' ${nostrListNames.length}件のカスタムリストを同期します');
} else {
  AppLogger.debug(' カスタムリストが見つかりませんでした');
}
await _ref.read(customListsProvider.notifier).syncListsFromNostr(nostrListNames);
```

## 動作フロー

### 正常系（既存のカスタムリストがある場合）

```
デバイスA:
  - カスタムリスト "SHOPPING" を作成
  - Nostrに送信: d="meiso-list-shopping", title="SHOPPING"

デバイスB（初回ログイン）:
  1. CustomListsProvider._initialize() 実行
     - ローカルストレージが空
     - 空の状態に設定（デフォルトリストは作成しない）
  
  2. todosProvider.syncFromNostr() 実行
     - Nostrから取得: ["SHOPPING"]
     - syncListsFromNostr(["SHOPPING"]) 呼び出し
  
  3. syncListsFromNostr() 内:
     - "SHOPPING" リストを追加
     - createDefaultListsIfEmpty() 呼び出し
     - リストが既に存在するため、デフォルトリストは作成しない
  
  4. 結果: "SHOPPING" リストが表示される ✅
```

### 正常系（カスタムリストがない場合）

```
デバイスA（新規アカウント）:
  1. CustomListsProvider._initialize() 実行
     - ローカルストレージが空
     - 空の状態に設定
  
  2. todosProvider.syncFromNostr() 実行
     - Nostrから取得: [] （空）
     - syncListsFromNostr([]) 呼び出し
  
  3. syncListsFromNostr() 内:
     - Nostrからのリストなし
     - createDefaultListsIfEmpty() 呼び出し
     - リストが空のため、デフォルトリストを作成
  
  4. 結果: デフォルトリスト（BRAIN DUMP, GROCERY等）が表示される ✅
```

## 変更されたファイル

### 問題2の修正

- `lib/providers/custom_lists_provider.dart`
  - `_initialize()` - デフォルトリスト作成を削除
  - `_createInitialLists()` → `createDefaultListsIfEmpty()` に名前変更
  - `syncListsFromNostr()` - 最後に `createDefaultListsIfEmpty()` を呼び出し
  - `customListsInitializedProvider` - 初期化完了フラグを追加

- `lib/providers/todos_provider.dart`
  - Amberモードと通常モードの両方で、`nostrListNames`が空でも `syncListsFromNostr()` を呼び出すように修正

## テストシナリオ

### シナリオ1: 既存のカスタムリストがある状態で新デバイスログイン

**前提条件**:
- デバイスAで "SHOPPING", "WORK" カスタムリストを作成済み
- リレーサーバーに保存されている

**手順**:
1. デバイスB（新規）でログイン
2. ホーム画面が表示されるまで待つ
3. SOMEDAYページを開く

**期待される結果**:
- ✅ "SHOPPING" リストが表示される
- ✅ "WORK" リストが表示される
- ❌ デフォルトリスト（BRAIN DUMP等）は表示されない

### シナリオ2: カスタムリストがない状態で新規アカウント作成

**前提条件**:
- 完全に新規のアカウント

**手順**:
1. 新規アカウントを作成
2. ホーム画面が表示されるまで待つ
3. SOMEDAYページを開く

**期待される結果**:
- ✅ デフォルトリスト（BRAIN DUMP, GROCERY, WISHLIST, NOSTR, WORK）が表示される

### シナリオ3: デバイスAで作成したカスタムリストが、デバイスBでも同期される

**前提条件**:
- デバイスAとデバイスBで同じアカウントを使用

**手順**:
1. デバイスAで新しいカスタムリスト "TODO 2025" を作成
2. デバイスBでPull to Refresh（同期）
3. SOMEDAYページを確認

**期待される結果**:
- ✅ デバイスBに "TODO 2025" リストが表示される

## 影響範囲

### 変更されたファイル（問題2）

- `lib/providers/custom_lists_provider.dart` - 初期化ロジック変更
- `lib/providers/todos_provider.dart` - 同期フロー修正

### 変更されなかったファイル

- `lib/models/custom_list.dart` - 変更なし（問題1で修正済み）
- `lib/widgets/add_list_screen.dart` - 変更なし（問題1で修正済み）
- `rust/src/api.rs` - 変更なし

### 既存データへの影響

- **既存のローカルリスト**: 影響なし（ローカルに既にリストがある場合は、そのまま使用）
- **Nostrのリスト**: 影響なし（Nostrのデータは変更されない）
- **マイグレーション**: 不要

## まとめ

Issue #33の**両方の問題**を修正しました：

1. ✅ **2byte文字問題**: 日本語入力をバリデーションでブロック + 空文字列フォールバック
2. ✅ **同期問題**: Nostr同期を優先し、同期後にリストが空の場合のみデフォルトリストを作成

これにより、新しいデバイスで初回ログイン時に、既存のカスタムリストが正しく同期されるようになりました。

## 関連ドキュメント

- [ISSUE_33_CUSTOM_LIST_NAME_FIX.md](./ISSUE_33_CUSTOM_LIST_NAME_FIX.md) - 問題1の修正詳細
- [NIP_51_LIST_ID_STRATEGY.md](./NIP_51_LIST_ID_STRATEGY.md) - リストID戦略
- [ISSUE_21_CUSTOM_LIST_SEPARATION.md](./ISSUE_21_CUSTOM_LIST_SEPARATION.md) - カスタムリストの分離実装

