# 手動同期機能の復活

## 概要

Kind 30001（全Todoが1つのリストイベント）実装に移行後、「自動同期中」の表示のみとなっていた長押しメニューに、同期状態の判定と手動再送信機能を復活させました。

## 背景

以前のKind 30078実装では、個別のTodoごとに`eventId`を持ち、同期済み/未同期を判定して手動送信ボタンを表示していました。Kind 30001への移行後、この機能がコメントアウトされ、すべてのタスクが「自動同期中」と表示されるようになっていました。

しかし、以下の理由から手動同期機能が必要です：

1. **バックアップ手段:** 自動同期が失敗した場合の復旧手段
2. **ユーザーの安心感:** 同期状態が明示的に確認できる
3. **ネットワークエラー対応:** オフライン時の変更を手動で再送信

## 実装内容

### 1. Todoモデルの`needsSync`フラグを活用

**既存の実装:**
```dart
/// Nostrへの同期が必要かどうか（楽観的UI更新用）
@Default(true) bool needsSync,
```

このフラグを使って同期状態を判定します：
- `needsSync = true`: 未同期（変更あり、リレーへの送信が必要）
- `needsSync = false`: 同期済み（リレーと一致）

### 2. 長押しメニューの実装変更

**ファイル:** `lib/widgets/todo_item.dart`

**変更前:**
```dart
TextButton.icon(
  onPressed: () {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('全Todoは自動的にリレーと同期されています'),
        duration: Duration(seconds: 2),
      ),
    );
  },
  icon: const Icon(Icons.cloud_done, size: 16),
  label: const Text('自動同期中'),
),
```

**変更後:**
```dart
// needsSyncフラグで判定
if (!todo.needsSync)
  // 同期済み
  TextButton.icon(
    onPressed: () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(todo.eventId != null 
            ? '同期済み (Event ID: ${todo.eventId!.substring(0, 8)}...)'
            : '同期済み'),
          duration: const Duration(seconds: 2),
        ),
      );
    },
    icon: const Icon(Icons.cloud_done, size: 16),
    label: const Text('同期済み'),
  )
else
  // 未同期 - 手動送信ボタン
  TextButton.icon(
    onPressed: () async {
      // 全Todoリストをリレーに送信（Kind 30001）
      await ref.read(todosProvider.notifier).manualSyncToNostr();
    },
    icon: const Icon(Icons.cloud_upload, size: 16),
    label: const Text('リレーに送信する'),
    style: TextButton.styleFrom(
      foregroundColor: Colors.orange.shade700,
    ),
  ),
```

### 3. TodosProviderに手動同期メソッドを追加

**ファイル:** `lib/providers/todos_provider.dart`

```dart
/// 手動で全Todoリストをリレーに送信（バックアップ手段）
/// UIから呼び出される公開メソッド
Future<void> manualSyncToNostr() async {
  print('🔄 Manual sync to Nostr triggered');
  _ref.read(syncStatusProvider.notifier).startSync();
  
  try {
    await _syncAllTodosToNostr();
    
    // 同期成功後、needsSyncフラグをクリア
    await _clearNeedsSyncFlags();
    
    _ref.read(syncStatusProvider.notifier).syncSuccess();
    print('✅ Manual sync completed successfully');
  } catch (e, stackTrace) {
    print('❌ Manual sync failed: $e');
    _ref.read(syncStatusProvider.notifier).syncError(
      '手動同期エラー: ${e.toString()}',
      shouldRetry: false,
    );
    rethrow; // UIにエラーを伝播
  }
}
```

**主な機能:**
- 既存の`_syncAllTodosToNostr()`を呼び出し
- 同期成功後、全Todoの`needsSync`フラグをクリア
- SyncStatusProviderと連携してUIに状態を反映
- エラー発生時は適切なエラーメッセージを表示

## 動作フロー

### 同期済みの場合

1. ユーザーがタスクを長押し
2. 長押しメニューが表示される
3. **クラウドマーク（緑）と「同期済み」ボタン**が表示される
4. ボタンをタップすると「同期済み」または「Event ID: xxx...」が表示される

### 未同期の場合

1. ユーザーがタスクを長押し
2. 長押しメニューが表示される
3. **クラウドアップロードマーク（オレンジ）と「リレーに送信する」ボタン**が表示される
4. ボタンをタップすると：
   - 「リレーに送信中...」メッセージ表示
   - 全Todoリスト（Kind 30001）がリレーに送信される
   - 成功: 「✅ リレーに送信しました」
   - 失敗: 「❌ 送信エラー: [エラー内容]」

## needsSyncフラグの管理

### フラグがtrueになるタイミング

すべてのTodo操作で`needsSync = true`が設定されます：

```dart
// 例: Todoを追加
final newTodo = Todo(
  // ... other fields ...
  needsSync: true, // 同期が必要
);
```

- `addTodo()`: 新規作成時
- `updateTodo()`: 更新時
- `toggleTodo()`: 完了状態変更時
- `reorderTodo()`: 並び替え時
- `moveTodo()`: 日付移動時
- `deleteTodo()`: 削除時

### フラグがfalseになるタイミング

同期成功後、`_clearNeedsSyncFlags()`で一括クリアされます：

```dart
Future<void> _clearNeedsSyncFlags() async {
  state.whenData((todos) async {
    final Map<DateTime?, List<Todo>> updatedTodos = {};
    bool hasChanges = false;

    for (final entry in todos.entries) {
      final date = entry.key;
      final list = entry.value.map((todo) {
        if (todo.needsSync) {
          hasChanges = true;
          return todo.copyWith(needsSync: false);
        }
        return todo;
      }).toList();
      updatedTodos[date] = list;
    }

    if (hasChanges) {
      state = AsyncValue.data(updatedTodos);
      await _saveAllTodosToLocal();
      print('✅ Cleared needsSync flags for all todos');
    }
  });
}
```

## UI表示の違い

### 同期済み（`needsSync = false`）

- **アイコン:** `Icons.cloud_done`（緑）
- **ラベル:** 「同期済み」
- **色:** デフォルト色
- **動作:** タップすると同期状態を確認（Event IDなど）

### 未同期（`needsSync = true`）

- **アイコン:** `Icons.cloud_upload`（オレンジ）
- **ラベル:** 「リレーに送信する」
- **色:** `Colors.orange.shade700`
- **動作:** タップすると全Todoリストをリレーに送信

## 自動同期との関係

### 自動同期（バックグラウンド）

以下のタイミングで自動的に同期が実行されます：

1. **Todo操作後:** 楽観的UI更新後、バックグラウンドで同期
2. **30秒ごと:** バッチ同期タイマー
3. **アプリ起動時:** 初期化完了後
4. **フォアグラウンド復帰時:** AppLifecycleProviderによる再接続後

### 手動同期（明示的）

ユーザーが長押しメニューから「リレーに送信する」を選択した場合：

- 即座に同期を実行
- 同期ステータスインジケーターが表示される
- 成功/失敗がSnackBarで通知される

## エラーハンドリング

### Nostr未初期化の場合

```dart
if (!isInitialized) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Nostrが初期化されていません。設定画面で接続してください。'),
      duration: Duration(seconds: 3),
    ),
  );
  return;
}
```

### 送信失敗の場合

```dart
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('❌ 送信エラー: $e'),
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
    ),
  );
}
```

- エラーメッセージが赤背景のSnackBarで表示される
- SyncStatusProviderがエラー状態を記録
- 3秒後にエラー状態がクリアされる
- ローカルデータは保持される（巻き戻りなし）

## テスト方法

### 1. 同期済み状態の確認

1. アプリを起動し、いくつかのタスクを追加
2. 自動同期が完了するまで待つ（緑のインジケーター）
3. タスクを長押し
4. **期待される結果:** 「同期済み」ボタンが表示される

### 2. 未同期状態の確認

1. タスクを編集または追加
2. 即座にタスクを長押し（自動同期前）
3. **期待される結果:** 「リレーに送信する」ボタンが表示される（オレンジ）

### 3. 手動送信のテスト

1. 未同期のタスクを長押し
2. 「リレーに送信する」をタップ
3. **期待される結果:**
   - 「リレーに送信中...」が表示される
   - 同期インジケーターが表示される
   - 「✅ リレーに送信しました」が表示される
   - 再度長押しすると「同期済み」に変わっている

### 4. オフライン時のテスト

1. 機内モードをONにする
2. タスクを追加・編集
3. タスクを長押し → 「リレーに送信する」をタップ
4. **期待される結果:** 送信エラーが表示される
5. 機内モードをOFFにする
6. 再度「リレーに送信する」をタップ
7. **期待される結果:** 送信成功

## 関連ファイル

- `lib/widgets/todo_item.dart` - 長押しメニューUI実装
- `lib/providers/todos_provider.dart` - `manualSyncToNostr()`メソッド追加
- `lib/models/todo.dart` - `needsSync`フラグ定義

## 今後の改善案

1. **未同期タスク数の表示:** 設定画面などに未同期タスク数を表示
2. **一括手動同期:** すべての未同期タスクをまとめて送信するボタン
3. **同期履歴:** 最後に同期した日時を記録・表示
4. **コンフリクト解決:** ローカルとリモートで差分がある場合の処理

## まとめ

`needsSync`フラグを活用することで、Kind 30001実装でも同期状態を正確に判定できるようになりました。ユーザーは各タスクの同期状態を確認でき、必要に応じて手動でリレーに再送信できます。これにより、自動同期が失敗した場合のバックアップ手段が確保され、ユーザーの安心感が向上します。

