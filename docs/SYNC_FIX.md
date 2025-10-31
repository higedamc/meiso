# 同期周りの修正（Sync Fix）

## 📅 修正日
2025年10月31日

## 🐛 報告された問題

ユーザーから以下3つの同期関連の問題が報告されました：

1. **タスク作成時にタスクが同期されない**
2. **タスク完了後、完了ステータスが同期されない**
3. **登録リレーサーバーの更新後、リレーサーバーが自動的に同期されない**

## 🔍 問題の原因

### 問題1 & 2: タスク同期が不完全

**原因**: `lib/providers/todos_provider.dart`の各Todo操作メソッド（`addTodo()`, `toggleTodo()`, `updateTodo()`など）で、`_syncToNostr()`を`await`せずに呼び出していました。

```dart
// ❌ 修正前
state.whenData((todos) async {
  // ... state更新 ...
  
  // awaitしていない！
  _syncToNostr(() async {
    await _syncAllTodosToNostr();
  });
});
```

これにより：
- 同期処理がfire-and-forgetで実行される
- エラーが発生しても気づかない
- 同期完了を待たずに処理が終了する

### 問題3: リレー更新時に再接続しない

**原因**: `lib/presentation/settings/relay_management_screen.dart`の実装で、リレーリストをNostrに同期していましたが、Nostrクライアント自体が新しいリレーに再接続する処理が不完全でした。

また、Rust側のNostr-SDKでは、既存のクライアントに動的にリレーを追加するAPIが提供されていないため、リレー変更後は**アプリの再起動が必要**です。

---

## ✅ 修正内容

### 修正1: Todo操作メソッドでの同期処理を`await`

すべてのTodo操作メソッドで、`_syncToNostr()`を適切に`await`し、同期完了を保証しました。

#### 修正したメソッド

1. ✅ `addTodo()` - Todo追加
2. ✅ `updateTodo()` - Todo更新
3. ✅ `updateTodoTitle()` - タイトル更新
4. ✅ `toggleTodo()` - 完了状態トグル
5. ✅ `reorderTodo()` - 並び替え
6. ✅ `moveTodo()` - 日付移動
7. ✅ `deleteTodo()` - 削除

#### 修正後のコード例

```dart
// ✅ 修正後
Future<void> addTodo(String title, DateTime? date) async {
  if (title.trim().isEmpty) return;

  await state.whenData((todos) async {
    // ... state更新 ...
    
    // ローカル保存
    await _saveAllTodosToLocal();
    
    // Nostr同期（awaitを追加）
    await _syncToNostr(() async {
      await _syncAllTodosToNostr();
    });
    print('✅ Nostr sync completed');
  }).value;
}
```

#### 変更のポイント

1. `state.whenData()`の前に`await`を追加
2. `_syncToNostr()`の前に`await`を追加
3. `.value`でFutureを取得して完了を待機

### 修正2: リレー変更時の処理を改善

`lib/presentation/settings/relay_management_screen.dart`で、リレー追加・削除時の処理を改善しました。

#### 変更内容

動的なリレー追加・削除は現在のRust APIではサポートされていないため、**次回起動時に反映される**ことを明示するメッセージを表示するように変更しました。

```dart
/// リレー変更を通知（次回起動時に反映）
void _notifyRelayChange() {
  setState(() {
    _successMessage = 'リレーリストを保存しました。次回起動時に反映されます。';
    _errorMessage = null;
  });
}
```

#### 今後の改善案

Rust側に以下のAPIを追加することで、動的なリレー追加・削除をサポート可能：

```rust
// 提案: Rust側に追加するAPI
pub fn add_relay_to_client(relay_url: String) -> Result<()> {
    // 既存のクライアントにリレーを追加
}

pub fn remove_relay_from_client(relay_url: String) -> Result<()> {
    // 既存のクライアントからリレーを削除
}
```

---

## 🎯 期待される効果

### 修正1の効果

- ✅ タスク作成時に確実にNostrへ同期される
- ✅ タスク完了時に完了ステータスが確実に同期される
- ✅ 同期エラーが適切にキャッチされる
- ✅ 同期完了後にログが出力される

### 修正2の効果

- ✅ リレー変更時に適切なメッセージが表示される
- ✅ ユーザーは次回起動時に変更が反映されることを理解できる
- ✅ リレーリストはNostr（Kind 10002）に正しく同期される

---

## 📝 テスト項目

### テスト1: タスク作成の同期

1. アプリを起動し、ログイン
2. 新しいタスクを作成
3. コンソールログで以下を確認：
   ```
   🆕 addTodo called: "テストタスク" for date: null
   💾 Saving to local storage...
   ✅ Local save complete
   📤 Starting Nostr sync...
   🔄 _syncAllTodosToNostr called
   ✅ Nostr sync completed
   ```
4. 別のデバイスでアプリを開き、タスクが同期されていることを確認

### テスト2: タスク完了の同期

1. タスクを完了状態にトグル
2. コンソールログで同期プロセスを確認
3. 別のデバイスで完了ステータスが反映されていることを確認

### テスト3: リレー変更

1. 設定 → リレーサーバー管理
2. 新しいリレーを追加
3. 「次回起動時に反映されます」メッセージを確認
4. アプリを再起動
5. 新しいリレーに接続されていることを確認

---

## 🔧 関連ファイル

- `lib/providers/todos_provider.dart` - Todo操作の同期処理を修正
- `lib/presentation/settings/relay_management_screen.dart` - リレー変更時の処理を改善

---

## 📚 参考資料

- [Nostr NIP-65: Relay List Metadata](https://github.com/nostr-protocol/nips/blob/master/65.md)
- [Nostr NIP-51: Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [Flutter Riverpod: AsyncValue](https://riverpod.dev/docs/concepts/async_value)

---

## ⚠️ 既知の制限事項

1. **リレー変更の即時反映不可**
   - 現在のRust API実装では、リレーの動的な追加・削除がサポートされていません
   - リレー変更後は**アプリの再起動が必要**です
   - 将来的には`add_relay_to_client()`などのAPIを追加する予定

2. **Amberモードの制約**
   - Amberモードでは、各操作でユーザーの承認が必要な場合があります
   - ContentProvider経由のバックグラウンド処理が失敗した場合、UI経由のフォールバックが発生します

---

## 🎉 まとめ

今回の修正により、Todo操作時の同期処理が確実に実行されるようになりました。また、リレー変更時のユーザー体験も改善されました。

ただし、リレーの動的な追加・削除については、Rust側のAPI拡張が必要なため、現時点では**アプリの再起動**が必要です。これは今後の改善課題として記録されています。

