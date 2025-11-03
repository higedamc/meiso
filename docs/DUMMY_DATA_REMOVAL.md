# デフォルトダミーデータの削除

## 重大な問題の修正

初回起動時に自動作成されていたダミーデータにより、**既存のリレーサーバー上のデータが空のリストで上書きされる**という深刻な問題が発生していました。

## 問題の詳細

### 発生していた問題

1. **初回起動時のダミーデータ作成**
   ```dart
   final initialTodos = [
     Todo(title: 'Nostr統合を完了する', ...),
     Todo(title: 'UI/UXを改善する', ...),
     Todo(title: 'Amber統合をテストする', ...),
     Todo(title: 'リカーリングタスクを実装する', ...),
   ];
   ```

2. **自動同期による上書き**
   - ダミーデータがローカルに保存される
   - バックグラウンド同期が実行される
   - ダミーデータがリレーサーバーに送信される
   - **既存のデータが4件のダミーデータで上書きされる**

3. **データ損失**
   - ユーザーの過去のタスクがすべて消失
   - リレーサーバー上のデータも空のリストに上書き

### なぜこの問題が発生したか

**シナリオ1: 新規デバイスでログイン**
```
1. 新しいデバイスでアプリをインストール
2. 既存のNostrアカウントでログイン
3. ローカルストレージは空 → ダミーデータ作成
4. バックグラウンド同期 → ダミーデータをリレーに送信
5. リレー上の既存データが上書きされる
```

**シナリオ2: アプリ再インストール**
```
1. アプリをアンインストール
2. 再インストール
3. 同じアカウントでログイン
4. ローカルストレージは空 → ダミーデータ作成
5. バックグラウンド同期 → リレーのデータが上書きされる
```

**シナリオ3: アプリデータクリア**
```
1. Android設定からアプリデータをクリア
2. アプリを起動
3. ログイン
4. ダミーデータ作成 → リレー上書き
```

## 修正内容

### 1. ダミーデータ作成の完全削除

**修正前:**
```dart
Future<void> _initialize() async {
  final localTodos = await localStorageService.loadTodos();
  
  if (localTodos.isEmpty) {
    // 初回起動時のみダミーデータを作成
    await _createInitialDummyData();
  } else {
    // ローカルデータを表示
    state = AsyncValue.data(grouped);
  }
}
```

**修正後:**
```dart
Future<void> _initialize() async {
  final localTodos = await localStorageService.loadTodos();
  
  if (localTodos.isEmpty) {
    // 初回起動時は空のリストから始める
    // （リレーサーバーからデータを同期する）
    print('🆕 初回起動: 空のリストで開始');
    state = AsyncValue.data({});
  } else {
    // ローカルデータを表示
    print('📦 ローカルから${localTodos.length}件のタスクを読み込み');
    state = AsyncValue.data(grouped);
  }
  
  // Nostr同期は非同期で実行
  _backgroundSync();
}
```

### 2. エラーハンドリングの改善

**修正前:**
```dart
catch (e) {
  // エラー時でもダミーデータで初期化
  try {
    await _createInitialDummyData();
  } catch (e2) {
    state = AsyncValue.data({});
  }
}
```

**修正後:**
```dart
catch (e) {
  print('⚠️ Todo初期化エラー: $e');
  // エラー時は空のマップで初期化
  print('⚠️ エラー発生のため空のリストで開始');
  state = AsyncValue.data({});
}
```

### 3. メソッドの削除

`_createInitialDummyData()`メソッドを完全に削除し、代わりに説明コメントを追加：

```dart
// 初回起動時のダミーデータは作成しない
// （削除済み: _createInitialDummyData メソッド）
// 
// 以前は「Nostr統合を完了する」などのダミーデータを作成していましたが、
// これによりリレーサーバー上の既存データが空のリストで上書きされる問題がありました。
// 現在は初回起動時は空のリストから始まり、リレーサーバーからデータを同期します。
```

## 修正後の動作

### 新規ユーザー（初回起動）

```
1. アプリをインストール
2. Nostrアカウントでログイン
3. 空のリストが表示される
4. リレーサーバーからデータを同期
   - リレーにデータがある → 取得して表示
   - リレーが空 → 空のまま
5. ユーザーが新しいタスクを追加
6. リレーに送信される
```

### 既存ユーザー（他デバイスでログイン）

```
1. 新しいデバイスでアプリをインストール
2. 既存のNostrアカウントでログイン
3. 空のリストが表示される（一時的）
4. リレーサーバーから既存データを同期
5. 既存のタスクが表示される ✅
```

### ローカルデータがある場合

```
1. アプリを起動
2. ローカルストレージからデータを読み込み
3. タスクが即座に表示される
4. バックグラウンドでリレーと同期
5. リレーのデータが新しい場合は更新
```

## データ保護の仕組み

### 1. ローカルデータ優先

```dart
if (localTodos.isEmpty) {
  // 空のリストで開始
  state = AsyncValue.data({});
} else {
  // ローカルデータを表示
  state = AsyncValue.data(grouped);
}
```

### 2. リレーが空の場合の保護

```dart
if (syncedTodos.isEmpty) {
  final hasLocalData = await state.whenData((localTodos) {
    final localTodoCount = localTodos.values.fold<int>(0, (sum, list) => sum + list.length);
    if (localTodoCount > 0) {
      print('ℹ️ リモートにイベントがありませんが、ローカルに${localTodoCount}件のTodoがあるため保持します');
      return true;
    }
    return false;
  }).value ?? false;
  
  if (hasLocalData) {
    print('✅ ローカルデータを保持（リモートは空）');
    return; // 上書きしない
  }
}
```

### 3. 同期の順序

1. ローカルデータを読み込み → UIに表示
2. リレーからデータを取得
3. リレーのデータが新しい場合のみ更新
4. ローカルが新しい場合はリレーに送信

## データ復旧方法

### もしデータが失われてしまった場合

#### 方法1: 他のデバイスから復旧

1. 別のデバイス（まだデータが残っている）でアプリを起動
2. タスクを長押し
3. 「リレーに送信する」をタップ
4. すべてのデバイスで同期される

#### 方法2: Androidバックアップから復旧

```bash
# adbコマンドでバックアップを確認
adb backup -f meiso_backup.ab com.example.meiso

# バックアップから復元
adb restore meiso_backup.ab
```

#### 方法3: 手動でデータを再入力

残念ながらリレーとローカルの両方でデータが失われた場合、手動で再入力するしかありません。

## 今後の改善案

### 1. データバックアップ機能

```dart
/// 全Todoをファイルにエクスポート
Future<void> exportTodos() async {
  final todos = getAllTodos();
  final json = jsonEncode(todos);
  // ファイルに保存
  await saveToFile(json);
}
```

### 2. データ復元確認ダイアログ

```dart
// 初回起動時、リレーにデータがある場合
if (localTodos.isEmpty && remoteTodos.isNotEmpty) {
  // ダイアログ表示: 「リレーから${remoteTodos.length}件のタスクを復元しますか？」
  final shouldRestore = await showRestoreDialog();
  if (shouldRestore) {
    // 復元実行
  }
}
```

### 3. 自動バックアップ

```dart
// 定期的にローカルバックアップを作成
Timer.periodic(Duration(hours: 24), (_) {
  createLocalBackup();
});
```

## テスト方法

### 1. 新規インストールのテスト

```
1. アプリをアンインストール
2. 再インストール
3. ログイン
4. 期待される結果:
   - 空のリストが表示される
   - リレーからデータが同期される
   - ダミーデータが作成されない ✅
```

### 2. 複数デバイスのテスト

```
デバイスA:
1. タスクを3件追加
2. リレーに送信

デバイスB（新規インストール）:
1. 同じアカウントでログイン
2. 期待される結果:
   - デバイスAの3件のタスクが同期される ✅
   - ダミーデータで上書きされない ✅
```

### 3. データクリアのテスト

```
1. Android設定 > アプリ > Meiso > ストレージ > データを削除
2. アプリを起動
3. ログイン
4. 期待される結果:
   - リレーからデータが同期される ✅
   - ダミーデータが作成されない ✅
```

## 関連ファイル

- `lib/providers/todos_provider.dart` - `_initialize()`メソッド修正、`_createInitialDummyData()`削除

## まとめ

デフォルトのダミーデータを完全に削除することで、以下の問題が解決されました：

1. ✅ 初回起動時にリレーのデータが保護される
2. ✅ 複数デバイスでの同期が正しく機能する
3. ✅ アプリ再インストール時もデータが保持される
4. ✅ ローカルデータが空でもリレーから復元できる

この修正により、ユーザーのデータが予期せず失われることがなくなります。

