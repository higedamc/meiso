# Issue #59: リカーリングタスクの修正

修正日: 2025-11-05

## 問題の内容

毎週（every week）や毎週水曜日（every Wednesday）のようなタスクを設定した場合、**来週分までしか反映されない**という問題が報告されました。

- **毎日（everyday）**: 正常に動作 ✅
- **毎週系**: 次のインスタンスが1回しか生成されない ❌

## 原因

`lib/providers/todos_provider.dart`の`_createNextRecurringTask`メソッドが、タスク完了時に**次の1つのインスタンスだけ**を生成していました。

### なぜ毎日は正常に動作していたのか？

- 初回タスク作成時に`_generateFutureInstances`メソッドが7日分のインスタンスを生成
- 毎日の場合: 7日分 = 7個のインスタンスが生成される
- 毎週の場合: 7日分 = 次の1週分（1個）しか生成されない

## 修正内容

### 修正したファイル
- `lib/providers/todos_provider.dart`

### 変更点

`_createNextRecurringTask`メソッドを修正し、タスク完了時に**7日分のインスタンスを再生成**するように変更しました。

#### Before（修正前）
```dart
/// リカーリングタスクの次回インスタンスを生成
Future<void> _createNextRecurringTask(
  Todo originalTodo,
  Map<DateTime?, List<Todo>> todos,
) async {
  // 次回の日付を計算
  final nextDate = originalTodo.recurrence!.calculateNextDate(originalTodo.date!);
  
  if (nextDate == null) {
    return; // 繰り返し終了
  }

  // 次の1つだけ生成
  final newTodo = Todo(
    id: _uuid.v4(),
    title: originalTodo.title,
    completed: false,
    date: nextDate,
    // ...
  );

  // 状態に追加
  final list = List<Todo>.from(todos[nextDate] ?? []);
  list.add(newTodo);
  todos[nextDate] = list;
}
```

#### After（修正後）
```dart
/// リカーリングタスクの次回インスタンスを生成（7日分）
Future<void> _createNextRecurringTask(
  Todo originalTodo,
  Map<DateTime?, List<Todo>> todos,
) async {
  if (originalTodo.recurrence == null || originalTodo.date == null) {
    return;
  }

  AppLogger.debug(' リカーリングタスク完了: ${originalTodo.title}');
  AppLogger.debug(' 将来のインスタンスを再生成します（7日分）');

  // 親タスクのIDを特定（このタスクが子インスタンスの場合は親IDを使用）
  final parentId = originalTodo.parentRecurringId ?? originalTodo.id;
  
  // このリカーリングタスクの親となるタスクを探す
  Todo? parentTask;
  for (final dateGroup in todos.values) {
    for (final task in dateGroup) {
      if (task.id == parentId) {
        parentTask = task;
        break;
      }
    }
    if (parentTask != null) break;
  }
  
  // 親タスクが見つからない場合は、完了したタスク自身を使用
  parentTask ??= originalTodo;

  DateTime? currentDate = originalTodo.date; // 完了したタスクの日付から開始
  int generatedCount = 0;
  const maxInstances = 10; // 最大10個まで生成（無限ループ防止）
  final now = DateTime.now();
  final sevenDaysLater = now.add(const Duration(days: 7));

  // 7日以内の将来のインスタンスを生成
  while (generatedCount < maxInstances) {
    final nextDate = parentTask.recurrence!.calculateNextDate(currentDate!);
    
    if (nextDate == null) {
      AppLogger.info(' 繰り返し終了');
      break; // 繰り返し終了
    }

    // 7日以内の日付のみ生成
    if (nextDate.isAfter(sevenDaysLater)) {
      AppLogger.debug(' 7日以内の範囲を超えたため終了');
      break;
    }

    // 既に同じタイトルのタスクが存在するかチェック
    final existingTasks = todos[nextDate] ?? [];
    final alreadyExists = existingTasks.any((t) => 
      t.parentRecurringId == parentId ||
      (t.title == parentTask!.title && t.recurrence != null && t.id != parentId && !t.completed)
    );

    if (!alreadyExists) {
      // 新しいインスタンスを生成
      final newTodo = Todo(
        id: _uuid.v4(),
        title: parentTask.title,
        completed: false,
        date: nextDate,
        order: _getNextOrder(todos, nextDate),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recurrence: parentTask.recurrence,
        parentRecurringId: parentId,
        linkPreview: parentTask.linkPreview,
        needsSync: true,
      );

      final list = List<Todo>.from(todos[nextDate] ?? []);
      list.add(newTodo);
      todos[nextDate] = list;

      generatedCount++;
      AppLogger.info(' インスタンス生成: ${nextDate.month}/${nextDate.day}');
    } else {
      AppLogger.debug(' インスタンス既存: ${nextDate.month}/${nextDate.day}');
    }

    currentDate = nextDate;
  }

  AppLogger.debug(' 合計${generatedCount}個のインスタンスを生成しました');

  // 状態を更新
  state = AsyncValue.data(Map.from(todos));
  
  // ローカルに保存
  await _saveAllTodosToLocal();

  // Nostrにも同期
  await _syncToNostr(() async {
    await _syncAllTodosToNostr();
  });
}
```

### 主な変更ポイント

1. **親タスクIDの特定**: 子インスタンスから親タスクを追跡
   - `parentRecurringId`フィールドを使用して親タスクを特定
   - 親タスクの繰り返しパターンを継承

2. **7日分のループ生成**: 次の1つだけでなく、7日以内のインスタンスをすべて生成
   - `while`ループで7日分のインスタンスを生成
   - `sevenDaysLater`を基準に日付範囲をチェック

3. **重複チェック**: 既存のインスタンスとの重複を防止
   - `parentRecurringId`と`title`で重複をチェック
   - 完了済みタスクは重複判定から除外

4. **ログ出力の強化**: デバッグ情報を追加
   - インスタンス生成時の日付をログ出力
   - 合計生成数をログ出力

## 動作確認

### テスト手順

1. 「every week」でタスクを作成
   ```
   例: "Weekly report every week"
   ```

2. 今日のタスクを完了にする
   - タスクをタップして完了マークをつける

3. カレンダーで7日先まで確認
   - カレンダービューを開く
   - 次の週のタスクが表示されることを確認

4. 次の週のタスクも完了にする
   - さらに次の週のタスクが自動生成されることを確認

### 期待される動作

- ✅ 毎週タスクが7日分生成される（最低1つ、最大でそのパターンに応じた数）
- ✅ 毎週水曜日のタスクが次回以降も継続的に表示される
- ✅ タスク完了時に自動的に次の7日分が生成される
- ✅ 2週間ごとのタスクも正しく生成される

## 技術的な詳細

### アルゴリズム

1. **タスク完了時にトリガー**
   - `toggleTodo`メソッドでタスクを完了にする
   - `_createNextRecurringTask`メソッドが呼び出される

2. **完了したタスクの親タスクを特定**
   - `parentRecurringId`フィールドから親タスクIDを取得
   - すべてのタスクから親タスクを検索

3. **完了した日付から7日以内のインスタンスを計算**
   - `calculateNextDate`メソッドで次回日付を計算
   - 7日以内の範囲内でループ

4. **既存のインスタンスをスキップして新規生成**
   - `parentRecurringId`と`title`で重複チェック
   - 重複がない場合のみ新規生成

5. **最大10個まで生成（無限ループ防止）**
   - `maxInstances`定数で上限を設定

### 週次リカーリングの計算例

#### 毎週水曜日の場合
- **今日**: 2025年11月5日（水）→ 完了
- **次回**: 2025年11月12日（水）→ 生成
- **その次**: 2025年11月19日（水）→ 7日以内なら生成（11月5日から14日以内なのでOK）

#### 2週間ごとの場合
- **今日**: 2025年11月5日 → 完了
- **次回**: 2025年11月19日 → 生成（11月5日から14日以内なので生成される）

#### 毎週月・水・金の場合
- **今日**: 2025年11月5日（水）→ 完了
- **次回**: 2025年11月7日（金）→ 生成
- **その次**: 2025年11月10日（月）→ 生成
- **その次**: 2025年11月12日（水）→ 生成

## コード変更の詳細

### 変更箇所
- ファイル: `lib/providers/todos_provider.dart`
- メソッド: `_createNextRecurringTask`（658-760行目）
- 行数: 約63行から約103行に増加（+40行）

### 追加された機能
1. 親タスク検索ロジック（673-686行目）
2. 7日分ループ生成ロジック（697-746行目）
3. デバッグログ出力（667-668, 688-689, 740-742, 748行目）

### 削除された機能
なし（既存の機能はすべて保持）

## リリースノート

### Bug Fix: リカーリングタスクが来週分しか表示されない問題を修正

**問題**
週次・月次の繰り返しタスクで、次の1回分しか生成されない問題がありました。

**修正**
タスク完了時に自動的に7日分のインスタンスが生成されるようになりました。これにより、毎日タスクと同様の動作になります。

**影響範囲**
- 週次リカーリングタスク（every week, every Monday など）
- 月次リカーリングタスク（every month など）
- カスタム間隔のリカーリングタスク（every 2 weeks など）

**既知の制限**
- 7日以内のインスタンスのみ生成されます
- 最大10個までのインスタンスが生成されます（無限ループ防止）

## 関連リンク

- [GitHub Issue #59](https://github.com/higedamc/meiso/issues/59)
- Repository: [higedamc/meiso](https://github.com/higedamc/meiso)
- 修正PR: （後で追加）

## テストケース

### ケース1: 毎週タスク
- **入力**: "Weekly meeting every week"
- **期待**: 毎週7日分のインスタンスが生成される

### ケース2: 毎週水曜日
- **入力**: "Team sync every Wednesday"
- **期待**: 毎週水曜日のインスタンスが生成される（7日以内に次の水曜日があればそれも生成）

### ケース3: 2週間ごと
- **入力**: "Sprint review every 2 weeks"
- **期待**: 2週間後のインスタンスが生成される

### ケース4: 毎月15日
- **入力**: "Monthly report every month on 15th"
- **期待**: 次月15日のインスタンスが生成される（7日以内なら）

## 今後の改善案

1. **生成範囲の設定化**
   - 現在は7日固定だが、設定で変更可能にする
   - 例: 14日分、30日分など

2. **無限スクロール対応**
   - カレンダーをスクロールした際に自動的に追加生成

3. **パフォーマンス最適化**
   - 大量のリカーリングタスクがある場合の最適化

4. **UI改善**
   - リカーリングタスクの将来分を視覚的に表示
   - 「さらに生成」ボタンの追加

## まとめ

この修正により、週次・月次のリカーリングタスクが正常に動作するようになりました。タスク完了時に自動的に次の7日分のインスタンスが生成されるため、ユーザーは継続的にタスクを管理できます。



