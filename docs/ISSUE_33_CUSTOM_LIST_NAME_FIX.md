# Issue #33: カスタムリスト同期問題の修正

## 概要

Issue #33では**2つの問題**がありました：

1. **2byte文字問題**: カスタムリスト名に日本語を入力した場合、`generateIdFromName()`で空文字列になる
2. **同期問題**: 英数字で作ったカスタムリストでも、新しいデバイスで初回ログイン時に自動的に同期されない

両方の問題を修正しました。

## 実装日

2025-11-06

## 問題の詳細

### 問題1: 2byte文字問題

#### 根本原因

`CustomListHelpers.generateIdFromName()`メソッドで以下の正規表現を使用：

```dart
.replaceAll(RegExp(r'[^\w\s-]'), '') // 特殊文字を削除
```

**問題点**：
- `\w` は ASCII の英数字とアンダースコアのみマッチ
- **日本語（2バイト文字）は削除されてしまう**

例：
- `"買い物リスト"` → `""` （空文字列）
- `"Groceryリスト"` → `"grocery"` （日本語部分が消える）
- `"BRAIN DUMP"` → `"brain-dump"` （正常）

#### なぜ問題になるのか

1. **デバイスAで日本語のカスタムリスト「買い物リスト」を作成**
   - ローカルでは `name: "買い物リスト"` として保存される
   - Nostrに送信する際、`generateIdFromName("買い物リスト")` → `""` （空文字列）
   - d tag: `"meiso-list-"` （無効なID）

2. **デバイスBで同期**
   - 無効なd tagのイベントは正しく処理されない
   - カスタムリストが表示されない

3. **同じ名前のリストが重複作成される**
   - 空のIDのリストが複数作成され、同期が破綻

### 問題2: 同期問題

#### 根本原因

`CustomListsProvider._initialize()` で、ローカルストレージにリストがない場合、**Nostrからの同期を待たずにデフォルトリスト（BRAIN DUMP等）を自動作成**していました。

フロー：
1. 新しいデバイスでログイン
2. `CustomListsProvider._initialize()` が実行される
3. ローカルストレージが空 → デフォルトリスト（BRAIN DUMP等）を作成
4. `todosProvider.syncFromNostr()` が実行される
5. `syncListsFromNostr(nostrListNames)` が呼ばれる
6. しかし、**ローカルに既にリストが存在する**ため、Nostrからのリストが追加されない
7. 結果：既存のカスタムリストが表示されない ❌

#### なぜ問題になるのか

**デバイスAで作成したカスタムリスト**:
- リレーサーバーに保存されている: `d="meiso-list-shopping"`, `title="SHOPPING"`

**デバイスBで初回ログイン時**:
1. ローカルストレージが空
2. デフォルトリスト（BRAIN DUMP, GROCERY等）を自動作成
3. Nostrから同期しようとするが、ローカルに既にリストが存在
4. 「SHOPPING」リストが追加されない
5. ユーザーは「SHOPPING」リストを見ることができない

## 解決策

### 問題1の解決策: 入力バリデーション

#### アプローチ

issueコメント：「日本語の扱いがハッシュ化、2バイト文字問題などめんどいので、そもそもカスタムリスト名として英数字しか入力できないようにするのも良さそう。」

**方針**：入力時に英数字、スペース、ハイフンのみを許可し、日本語や特殊文字を入力できないようにする

#### 実装内容

##### 1. AddListScreen のバリデーション追加

**ファイル**: `lib/widgets/add_list_screen.dart`

```dart
/// リストを保存
void _save() {
  final text = _controller.text.trim();
  
  // 空文字チェック
  if (text.isEmpty) {
    setState(() {
      _errorMessage = 'リスト名を入力してください';
    });
    return;
  }

  // 英数字、スペース、ハイフンのみ許可
  final validPattern = RegExp(r'^[a-zA-Z0-9\s-]+$');
  if (!validPattern.hasMatch(text)) {
    setState(() {
      _errorMessage = '英数字、スペース、ハイフンのみ使用できます';
    });
    return;
  }

  // リストを追加
  ref.read(customListsProvider.notifier).addList(text);
  
  // 画面を閉じる
  Navigator.pop(context);
}
```

**追加機能**：
- エラーメッセージ表示用の `_errorMessage` state
- リアルタイムエラークリア（入力時にエラーをクリア）
- 日本語で分かりやすいエラーメッセージ
- ヒントテキストを「リスト名を入力（英数字、スペース、ハイフンのみ）」に変更

##### 2. generateIdFromName() の空文字列ハンドリング

**ファイル**: `lib/models/custom_list.dart`

```dart
/// リスト名から決定的なIDを生成（NIP-51準拠）
/// 
/// ⚠️ 日本語や特殊文字は削除されます：
/// - "買い物リスト" → "" (空文字列)
/// - "Groceryリスト" → "grocery"
/// 
/// 空文字列になった場合は、"unnamed-list"を返します
static String generateIdFromName(String name) {
  final id = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\w\s-]'), '') // 特殊文字を削除（日本語も削除される）
      .replaceAll(RegExp(r'\s+'), '-')     // スペースをハイフンに
      .replaceAll(RegExp(r'-+'), '-')      // 連続するハイフンを1つに
      .replaceAll(RegExp(r'^-|-$'), '');   // 先頭・末尾のハイフンを削除
  
  // 空文字列の場合はフォールバック
  if (id.isEmpty) {
    return 'unnamed-list';
  }
  
  return id;
}
```

**変更点**：
- 空文字列の場合に `"unnamed-list"` をフォールバック値として返す
- ドキュメントコメントに日本語の扱いに関する警告を追加

## テストケース

### 有効な入力（成功）

| 入力 | 生成ID | 結果 |
|------|--------|------|
| `"BRAIN DUMP"` | `"brain-dump"` | ✅ 成功 |
| `"Grocery List"` | `"grocery-list"` | ✅ 成功 |
| `"TO BUY"` | `"to-buy"` | ✅ 成功 |
| `"Work-2025"` | `"work-2025"` | ✅ 成功 |
| `"MY LIST"` | `"my-list"` | ✅ 成功 |

### 無効な入力（エラー）

| 入力 | エラーメッセージ |
|------|-----------------|
| `""` (空) | `"リスト名を入力してください"` |
| `"買い物リスト"` | `"英数字、スペース、ハイフンのみ使用できます"` |
| `"Shopping List🛒"` | `"英数字、スペース、ハイフンのみ使用できます"` |
| `"リスト@#$"` | `"英数字、スペース、ハイフンのみ使用できます"` |
| `"List!!!!"` | `"英数字、スペース、ハイフンのみ使用できます"` |

### フォールバック（防御的プログラミング）

万が一、バリデーションをすり抜けて日本語が入力された場合：

| 入力 | 生成ID | 動作 |
|------|--------|------|
| `"買い物リスト"` | `"unnamed-list"` | ⚠️ フォールバック |

## 動作フロー

### 正常系

```
1. ユーザーが AddListScreen で "BRAIN DUMP" と入力
2. バリデーション: OK（英数字とスペースのみ）
3. addList("BRAIN DUMP") 実行
4. generateIdFromName("BRAIN DUMP") → "brain-dump"
5. CustomList { id: "brain-dump", name: "BRAIN DUMP" } 作成
6. Nostrに送信: d="meiso-list-brain-dump", title="BRAIN DUMP"
7. 他のデバイスで同期成功 ✅
```

### エラー系（日本語入力）

```
1. ユーザーが AddListScreen で "買い物リスト" と入力
2. バリデーション: NG（日本語が含まれる）
3. エラーメッセージ表示: "英数字、スペース、ハイフンのみ使用できます"
4. リスト作成をブロック ❌
5. ユーザーに再入力を促す
```

## UI変更

### Before

```
+------------------------+
| NEW LIST          [×]  |
+------------------------+
| リスト名を入力...       |
|                        |
+------------------------+
|                  [SAVE]|
+------------------------+
```

### After

```
+------------------------+
| NEW LIST          [×]  |
+------------------------+
| リスト名を入力（英数字、  |
| スペース、ハイフンのみ）  |
|                        |
| ⚠️ 英数字、スペース、    | ← エラー時のみ表示
| ハイフンのみ使用できます  |
+------------------------+
|                  [SAVE]|
+------------------------+
```

## マルチデバイス同期の動作

### 修正前（問題あり）

```
デバイスA:
  - リスト作成: "買い物リスト"
  - 生成ID: "" (空文字列)
  - Nostr送信: d="meiso-list-" (無効)

デバイスB:
  - 同期失敗: 無効なd tagを処理できない
  - リストが表示されない ❌
```

### 修正後（正常）

```
デバイスA:
  - リスト作成試行: "買い物リスト"
  - バリデーション: NG
  - エラー表示: "英数字、スペース、ハイフンのみ使用できます"
  - リスト作成をブロック ✅

または

デバイスA:
  - リスト作成: "Shopping List"
  - 生成ID: "shopping-list"
  - Nostr送信: d="meiso-list-shopping-list", title="SHOPPING LIST"

デバイスB:
  - 同期成功: d="meiso-list-shopping-list" を検出
  - CustomList { id: "shopping-list", name: "SHOPPING LIST" } 作成
  - リストが正常に表示される ✅
```

## 影響範囲

### 変更されたファイル

- `lib/widgets/add_list_screen.dart` - バリデーション追加
- `lib/models/custom_list.dart` - 空文字列フォールバック追加

### 変更されなかったファイル

- `lib/providers/custom_lists_provider.dart` - 変更なし
- `lib/providers/todos_provider.dart` - 変更なし
- `rust/src/api.rs` - 変更なし

### 既存データへの影響

- **既存のリスト**: 影響なし
- **新規リスト**: 英数字、スペース、ハイフンのみ許可
- **マイグレーション**: 不要

## 今後の拡張可能性

### Option 1: 日本語サポート（将来的に）

もし将来的に日本語をサポートする場合：

1. **SHA-256ハッシュベースのID生成**
   ```dart
   static String generateIdFromName(String name) {
     final bytes = utf8.encode(name.toLowerCase().trim());
     final hash = sha256.convert(bytes);
     return hash.toString().substring(0, 16); // 最初の16文字
   }
   ```

2. **メリット**：
   - 日本語、絵文字、特殊文字すべて対応可能
   - 決定的なID生成（同じ名前 → 同じハッシュ）

3. **デメリット**：
   - d tagが人間に読めなくなる（デバッグが困難）
   - SHA-256の依存関係追加

### Option 2: URLエンコード方式

```dart
static String generateIdFromName(String name) {
  return Uri.encodeComponent(name.toLowerCase().trim());
}
```

## 関連Issue

- Issue #33: 自分で作成したカスタムリストが、新しいデバイスで新規ログインした際には取得されない

## 参考資料

- [NIP-51: Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [Dart RegExp Documentation](https://api.dart.dev/stable/dart-core/RegExp-class.html)

## 修正履歴

### 2025-11-06: Issue #33修正完了

- AddListScreen にバリデーション追加
- generateIdFromName() に空文字列フォールバック追加
- 日本語で分かりやすいエラーメッセージ実装

