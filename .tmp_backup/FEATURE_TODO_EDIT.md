# Todo編集機能の実装

## 実装した機能

### 1. 完了済みタスクを一番下に表示

**実装箇所**: `lib/providers/todos_provider.dart`

```dart
final todosForDateProvider = Provider.family<List<Todo>, DateTime?>((ref, date) {
  final todosAsync = ref.watch(todosProvider);
  return todosAsync.when(
    data: (todos) {
      final list = todos[date] ?? [];
      
      // 未完了タスクと完了済みタスクに分ける
      final incomplete = list.where((t) => !t.completed).toList();
      final completed = list.where((t) => t.completed).toList();
      
      // それぞれをorder順にソート
      incomplete.sort((a, b) => a.order.compareTo(b.order));
      completed.sort((a, b) => a.order.compareTo(b.order));
      
      // 未完了 + 完了済みの順で結合
      return [...incomplete, ...completed];
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
```

**動作**:
- タスクをチェックすると、自動的に一番下に移動
- TeuxDeuxと同じ動作

### 2. タスクをタップして編集

**実装箇所**: `lib/widgets/todo_item.dart`

**UI要素**:
- タップでダイアログが開く
- 日付表示（例: "WEDNESDAY, OCTOBER 29"）
- テキストフィールド（下線付き）
- MOVE TO ボタン（Phase2で実装予定）
- ✕ ボタン（閉じる）
- SAVE ボタン（青色）

**操作**:
- タスクをタップ → 編集ダイアログ表示
- テキストを編集
- Enterキーまたは「SAVE」ボタンで保存
- 長押しでJSON情報を表示（開発用）

### 3. Nostr仕様への準拠

**NIP-33準拠**:
- Kind 30078（Application-specific data）を使用
- Replaceable Event として実装
- 編集時は同じ`d` tagで新しいイベントを作成
- `updatedAt`を更新して変更を追跡

**実装メソッド**:
```dart
// タイトル更新専用メソッド
Future<void> updateTodoTitle(String id, DateTime? date, String newTitle)

// 内部で以下を実行:
// 1. ローカル状態を更新
// 2. updatedAtを現在時刻に設定
// 3. ローカルストレージに保存
// 4. Nostr側に同期（updateTodoOnNostr）
```

## テスト項目

### 基本機能
- [ ] タスクをタップして編集ダイアログが表示される
- [ ] タイトルを編集してSAVEで保存できる
- [ ] Enterキーでも保存できる
- [ ] ✕ボタンで編集をキャンセルできる

### 完了タスクの動作
- [ ] タスクをチェックすると一番下に移動
- [ ] チェックを外すと元の位置（未完了タスクの下）に戻る
- [ ] 複数のタスクをチェックしても順序が保持される

### Nostr同期
- [ ] 編集後、Nostrにイベントが送信される（クラウドアイコン表示）
- [ ] updatedAtが更新される
- [ ] 他のデバイスで編集が反映される（Phase2で完全実装）

### UI/UX
- [ ] ダイアログの日付表示が正しい形式（"WEDNESDAY, OCTOBER 29"）
- [ ] テキストフィールドに下線が表示される
- [ ] SAVEボタンが青色で目立つ
- [ ] 空のタイトルでは保存できない

## Phase2で実装予定

- **MOVE TO機能**: タスクを別の日付に移動
- **日付選択ダイアログ**: カレンダービューでの日付指定
- **マルチデバイス同期**: Nostrからの完全な同期

## Nostrイベント構造（参考）

```json
{
  "kind": 30078,
  "content": "{NIP-44で暗号化されたTodoのJSON}",
  "tags": [
    ["d", "todo-{uuid}"]
  ],
  "created_at": 1698581040,
  "pubkey": "...",
  "id": "...",
  "sig": "..."
}
```

復号化後のcontent:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "タスクのタイトル",
  "completed": false,
  "date": "2025-10-29T00:00:00.000Z",
  "order": 0,
  "createdAt": "2025-10-29T05:04:00.000Z",
  "updatedAt": "2025-10-29T05:10:00.000Z",
  "eventId": "abc123..."
}
```

## 参考

- NIP-33: Parameterized Replaceable Events
- NIP-44: Encrypted Direct Message
- TeuxDeux: https://www.teuxdeux.com/

