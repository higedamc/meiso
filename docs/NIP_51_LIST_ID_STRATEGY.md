# NIP-51準拠のリストID戦略

## 問題

### 以前の実装（UUID v4ベース）

```dart
CustomList {
  id: "550e8400-e29b-41d4-a716-446655440000",  // UUID v4
  name: "BRAIN DUMP"
}

// Nostrイベント
d tag: "meiso-list-550e8400-e29b-41d4-a716-446655440000"
```

**問題点:**
- 同じ名前のリスト（例: "BRAIN DUMP"）を異なるデバイスで作成すると、異なるUUIDが生成される
- 結果として、Nostrリレーに**別々のイベント**として保存される
- リストが無限に増殖し、同期されない 🫠

### NIP-51の標準アプローチ

[NIP-51 (Lists)](https://github.com/nostr-protocol/nips/blob/master/51.md)では、リスト識別子（d tag）に**意味のある決定的な値**を使用することが推奨されています。

例:
- `bookmark-list` - ブックマークリスト
- `mute-list` - ミュートリスト
- `pin-list` - ピン留めリスト

## 解決策：名前ベースの決定的ID

### リスト名から決定的なIDを生成

```dart
/// リスト名から決定的なIDを生成（NIP-51準拠）
/// 
/// 例:
/// - "BRAIN DUMP" → "brain-dump"
/// - "Grocery List" → "grocery-list"  
/// - "TO BUY!!!" → "to-buy"
static String generateIdFromName(String name) {
  return name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\w\s-]'), '') // 特殊文字を削除
      .replaceAll(RegExp(r'\s+'), '-')     // スペースをハイフンに
      .replaceAll(RegExp(r'-+'), '-')      // 連続するハイフンを1つに
      .replaceAll(RegExp(r'^-|-$'), '');   // 先頭・末尾のハイフンを削除
}
```

### Nostrイベント構造

```json
{
  "kind": 30001,
  "content": "<NIP-44暗号化されたTodoリスト>",
  "tags": [
    ["d", "meiso-list-brain-dump"],
    ["title", "BRAIN DUMP"]
  ]
}
```

### メリット

✅ **異なるデバイスで同じ名前のリストを作成しても、同じd tagになる**
✅ **Replaceable Eventなので、最新版に自動的に統一される**
✅ **NIP-51の標準パターンに準拠**
✅ **リスト名が人間にも読みやすい**

## 実装詳細

### 1. CustomListモデル（`lib/models/custom_list.dart`）

```dart
extension CustomListHelpers on CustomList {
  static String generateIdFromName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
```

### 2. CustomListsProvider（リスト追加時）

```dart
Future<void> addList(String name) async {
  final normalizedName = name.trim().toUpperCase();
  
  // リスト名から決定的なIDを生成
  final listId = CustomListHelpers.generateIdFromName(normalizedName);
  
  // 同じIDのリストが既に存在するかチェック
  if (lists.any((list) => list.id == listId)) {
    print('⚠️ List with ID "$listId" already exists');
    return;
  }
  
  final newList = CustomList(
    id: listId, // UUID v4の代わりに名前ベースのID
    name: normalizedName,
    order: _getNextOrder(lists),
    createdAt: now,
    updatedAt: now,
  );
}
```

### 3. Nostr同期（`lib/providers/todos_provider.dart`）

#### 送信時：

```dart
// Todoをリストごとにグループ化（名前ベースIDに変換）
final Map<String, List<Todo>> groupedTodos = {};
for (final todo in allTodos) {
  String listKey;
  if (todo.customListId == null) {
    listKey = 'default';
  } else {
    // UUIDベースのIDを名前ベースIDに変換（マイグレーション）
    listKey = customListsMap[todo.customListId] ?? todo.customListId!;
  }
  
  groupedTodos.putIfAbsent(listKey, () => []);
  groupedTodos[listKey]!.add(todo);
}

// 各リストごとに暗号化・署名・送信
for (final entry in groupedTodos.entries) {
  final listId = entry.key; // 名前ベースID（例: "brain-dump"）
  final listTitle = customListNames[listId]; // "BRAIN DUMP"
  
  final unsignedEvent = await nostrService.createUnsignedEncryptedTodoListEvent(
    encryptedContent: encryptedContent,
    listId: listId == 'default' ? null : listId, // d tag
    listTitle: listTitle, // title tag
  );
}
```

#### 受信時：

```dart
// カスタムリスト名を抽出
final List<String> nostrListNames = [];
for (final event in encryptedEvents) {
  if (event.listId != null && event.title != null) {
    final listId = event.listId!;
    if (listId == 'meiso-todos') continue; // デフォルトは除外
    
    if (!nostrListNames.contains(event.title!)) {
      nostrListNames.add(event.title!);
    }
  }
}

// カスタムリストを同期（名前ベース）
await customListsProvider.notifier.syncListsFromNostr(nostrListNames);
```

`syncListsFromNostr`内部では：

```dart
for (final listName in nostrListNames) {
  // 名前から決定的なIDを生成
  final listId = CustomListHelpers.generateIdFromName(listName);
  
  // すでに存在するか確認（IDで）
  if (!updatedLists.any((list) => list.id == listId)) {
    final newList = CustomList(
      id: listId, // 名前から生成した決定的なID
      name: listName.toUpperCase(),
      ...
    );
    updatedLists.add(newList);
  }
}
```

### 4. マイグレーション（既存Todoの更新）

同期時に、UUIDベースの`customListId`を持つTodoを名前ベースIDに自動変換：

```dart
// このリストの各TodoのeventIdとcustomListIdを更新
for (final todo in listTodos) {
  await _updateTodoEventIdInState(todo.id, todo.date, sendResult.eventId);
  
  // 名前ベースIDに更新（UUIDベースの場合のマイグレーション）
  if (todo.customListId != null && todo.customListId != listId) {
    await _updateTodoCustomListIdInState(todo.id, todo.date, listId);
    print('🔄 Migrated customListId: ${todo.customListId} -> $listId');
  }
}
```

## 動作フロー例

### デバイスAで「BRAIN DUMP」リストを作成

```
1. ユーザーが "BRAIN DUMP" という名前のリストを作成
2. generateIdFromName("BRAIN DUMP") → "brain-dump"
3. CustomList { id: "brain-dump", name: "BRAIN DUMP" }
4. Todoを追加: Todo { customListId: "brain-dump", ... }
5. Nostrに送信: Kind 30001, d="meiso-list-brain-dump", title="BRAIN DUMP"
```

### デバイスBで同期

```
1. Nostrからイベントを取得
2. d="meiso-list-brain-dump", title="BRAIN DUMP" を検出
3. generateIdFromName("BRAIN DUMP") → "brain-dump"
4. CustomList { id: "brain-dump", name: "BRAIN DUMP" } を作成
5. 暗号化されたTodoを復号化: Todo { customListId: "brain-dump", ... }
```

### デバイスBでも「BRAIN DUMP」を作成しようとした場合

```
1. ユーザーが "BRAIN DUMP" という名前のリストを作成
2. generateIdFromName("BRAIN DUMP") → "brain-dump"
3. ⚠️ 同じID "brain-dump" のリストが既に存在
4. 新規作成をスキップ（重複回避）
```

## テストケース

```dart
// 正規化のテスト
generateIdFromName("BRAIN DUMP")    // → "brain-dump"
generateIdFromName("Grocery List")  // → "grocery-list"
generateIdFromName("TO BUY!!!")     // → "to-buy"
generateIdFromName("  Work  ")      // → "work"
generateIdFromName("My---List")     // → "my-list"
```

## リスト名変更時の動作

⚠️ **重要:** リスト名を変更すると、**新しいIDが生成される**ため、実質的に新しいリストとして扱われます。

将来的な改善案：
1. リスト名変更を禁止する（削除して再作成のみ）
2. リスト名変更時に古いd tagのイベントを削除し、新しいd tagで再送信
3. リスト名とは独立した永続的なUUIDを内部的に保持（複雑化）

現時点では、**リスト名は作成後に変更しない**ことを推奨します。

## 参考資料

- [NIP-51: Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [NIP-44: Encrypted Payloads](https://github.com/nostr-protocol/nips/blob/master/44.md)

