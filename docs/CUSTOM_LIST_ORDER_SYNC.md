# カスタムリストの順番保存機能の実装完了

## 📋 概要

SOMEDAYページ内のカスタムリストの並び順を **Kind 30078（アプリ設定）** に自動保存し、アプリ起動時やNostr同期時に復元する機能を実装しました。

---

## 🎯 実装内容

### 1. データ構造（既存）

`AppSettings` モデルに既に `customListOrder` フィールドが存在：

```dart
class AppSettings {
  // ... 他のフィールド
  
  /// カスタムリストの順番（リストIDの配列）
  @Default([]) List<String> customListOrder;
}
```

**保存先**: Kind 30078（NIP-78 Application-specific Data）  
**暗号化**: NIP-44で暗号化されてNostrリレーに保存

---

## ✅ 実装済み機能

### 1. リスト並び替え時の保存 ✅
**トリガー**: ドラッグ&ドロップでリストを並び替え  
**処理フロー**:
```
ユーザーがリストをドラッグ&ドロップ
  ↓
CustomListsProvider.reorderLists()
  ↓
_updateCustomListOrderInSettings()
  ↓
AppSettingsProvider.updateSettings()
  ↓
Kind 30078 に自動同期
```

**コード**: `lib/providers/custom_lists_provider.dart` (Line 155-183)

---

### 2. リスト追加時の保存 🆕
**トリガー**: 新しいカスタムリストを追加  
**処理**:
- リストを追加後、`customListOrder` を更新
- Kind 30078 に自動同期

**コード**: `lib/providers/custom_lists_provider.dart` (Line 89-125)

---

### 3. リスト削除時の保存 🆕
**トリガー**: カスタムリストを削除  
**処理**:
- 削除されたリストIDを `customListOrder` から除外
- Kind 30078 に自動同期

**コード**: `lib/providers/custom_lists_provider.dart` (Line 145-157)

---

### 4. リスト更新時の保存 🆕
**トリガー**: リスト名を変更  
**処理**:
- リスト更新後、`customListOrder` を更新
- 現在はIDが不変なので実質影響なし（将来対応）

**コード**: `lib/providers/custom_lists_provider.dart` (Line 127-146)

---

### 5. デフォルトリスト作成時の保存 🆕
**トリガー**: 初回起動時にデフォルトリストを作成  
**処理**:
- デフォルトリスト作成後、`customListOrder` を初期化
- Kind 30078 に自動同期

**コード**: `lib/providers/custom_lists_provider.dart` (Line 43-90)

---

### 6. アプリ起動時の復元 🆕
**トリガー**: アプリ起動時  
**処理フロー**:
```
アプリ起動
  ↓
CustomListsProvider._initialize()
  ↓
ローカルストレージから読み込み
  ↓
_applySavedListOrder()
  ↓
AppSettings.customListOrder から順番を復元
  ↓
リストを表示
```

**コード**: `lib/providers/custom_lists_provider.dart` (Line 20-41)

---

### 7. Nostr同期時の復元 ✅
**トリガー**: Nostrからリストを同期  
**処理**:
- Nostrから取得したリストを `customListOrder` の順番で並び替え
- 保存された順番にないリストは末尾に追加

**コード**: `lib/providers/custom_lists_provider.dart` (Line 212-260, Line 262-309)

---

## 🔄 データフロー全体像

### パターン1: ユーザーがリストを並び替え
```
[UI] ドラッグ&ドロップ
  ↓
[Provider] CustomListsProvider.reorderLists()
  ↓
[Local] ローカルストレージに保存
  ↓
[Provider] _updateCustomListOrderInSettings()
  ↓
[Provider] AppSettingsProvider.updateSettings()
  ↓
[Nostr] Kind 30078に同期（NIP-44暗号化）
```

### パターン2: アプリ起動時
```
[App] アプリ起動
  ↓
[Provider] CustomListsProvider._initialize()
  ↓
[Local] ローカルストレージから読み込み
  ↓
[Provider] _applySavedListOrder()
  ↓
[Provider] AppSettings.customListOrder を参照
  ↓
[UI] 保存された順番で表示
```

### パターン3: 別デバイスでリスト順を変更した場合
```
[別デバイス] リスト順を変更
  ↓
[Nostr] Kind 30078に同期
  ↓
[本デバイス] Nostr同期実行
  ↓
[Provider] AppSettingsProvider.syncFromNostr()
  ↓
[Provider] AppSettings.customListOrder が更新
  ↓
[Provider] CustomListsProvider.syncListsFromNostr()
  ↓
[Provider] _applySavedListOrder()
  ↓
[UI] 別デバイスの順番が反映
```

---

## 📝 実装の詳細

### `_updateCustomListOrderInSettings()` メソッド

```dart
/// AppSettingsのcustomListOrderを更新
Future<void> _updateCustomListOrderInSettings(List<CustomList> lists) async {
  try {
    // リストIDの配列を生成
    final listOrder = lists.map((list) => list.id).toList();
    final settingsAsync = _ref.read(appSettingsProvider);
    
    await settingsAsync.whenData((currentSettings) async {
      final updatedSettings = currentSettings.copyWith(
        customListOrder: listOrder,
        updatedAt: DateTime.now(),
      );
      
      // AppSettings更新 → 自動的にKind 30078に同期される
      await _ref.read(appSettingsProvider.notifier).updateSettings(updatedSettings);
      AppLogger.info(' [CustomLists] リスト順をAppSettingsに同期しました');
    }).value;
  } catch (e) {
    AppLogger.warning(' [CustomLists] AppSettings更新エラー: $e');
  }
}
```

---

### `_applySavedListOrder()` メソッド

```dart
/// AppSettingsから保存された順番を適用
Future<void> _applySavedListOrder(List<CustomList> lists) async {
  try {
    final settingsAsync = _ref.read(appSettingsProvider);
    
    await settingsAsync.whenData((settings) async {
      final savedOrder = settings.customListOrder;
      
      if (savedOrder.isEmpty) {
        // 保存された順番がない場合は、現在のorder順にソート
        lists.sort((a, b) => a.order.compareTo(b.order));
        return;
      }
      
      // 保存された順番に従って並び替え
      final Map<String, CustomList> listMap = {for (var list in lists) list.id: list};
      final reorderedLists = <CustomList>[];
      
      // 保存された順番に従ってリストを追加
      for (final listId in savedOrder) {
        if (listMap.containsKey(listId)) {
          reorderedLists.add(listMap[listId]!);
          listMap.remove(listId);
        }
      }
      
      // 保存された順番にないリストを末尾に追加（新規追加されたリスト）
      reorderedLists.addAll(listMap.values);
      
      // orderフィールドを再計算
      for (var i = 0; i < reorderedLists.length; i++) {
        reorderedLists[i] = reorderedLists[i].copyWith(order: i);
      }
      
      lists.clear();
      lists.addAll(reorderedLists);
      
      AppLogger.info(' [CustomLists] リスト順を復元しました');
    }).value;
  } catch (e) {
    AppLogger.warning(' [CustomLists] 順番復元エラー: $e');
    // エラー時は現在のorder順にソート
    lists.sort((a, b) => a.order.compareTo(b.order));
  }
}
```

---

## 🧪 テストシナリオ

### シナリオ1: リスト並び替え
1. SOMEDAYページでカスタムリストをドラッグ&ドロップ
2. アプリを再起動
3. **期待結果**: 並び替えた順番が保持されている

### シナリオ2: 新規リスト追加
1. SOMEDAYページで新しいリストを追加
2. リストを並び替え
3. アプリを再起動
4. **期待結果**: 新しいリストが正しい位置に表示される

### シナリオ3: リスト削除
1. SOMEDAYページでリストを削除
2. アプリを再起動
3. **期待結果**: 削除したリストが表示されず、順番も維持される

### シナリオ4: マルチデバイス同期
1. デバイスAでリストを並び替え
2. デバイスBでNostr同期を実行
3. **期待結果**: デバイスBにデバイスAの順番が反映される

---

## 🔐 セキュリティとプライバシー

### 暗号化
- `customListOrder` は `AppSettings` の一部として **NIP-44で暗号化**
- 暗号化されたデータがKind 30078としてNostrリレーに保存
- 自分の秘密鍵でのみ復号化可能

### データ構造（暗号化前）
```json
{
  "dark_mode": true,
  "week_start_day": 1,
  "calendar_view": "week",
  "notifications_enabled": true,
  "relays": ["wss://relay.damus.io"],
  "tor_enabled": false,
  "proxy_url": "socks5://127.0.0.1:9050",
  "custom_list_order": [
    "meiso-list-brain-dump",
    "meiso-list-grocery",
    "meiso-list-wishlist",
    "meiso-list-nostr",
    "meiso-list-work"
  ],
  "updated_at": "2025-11-07T12:00:00Z"
}
```

---

## 📊 変更サマリー

### 修正ファイル
- `lib/providers/custom_lists_provider.dart`

### 変更行数
- 追加: 約30行（コメント含む）
- 修正: 5箇所

### 主な変更点
1. `_initialize()`: 初期化時に `_applySavedListOrder()` を呼ぶように修正
2. `addList()`: リスト追加後に `_updateCustomListOrderInSettings()` を呼ぶ
3. `updateList()`: リスト更新後に `_updateCustomListOrderInSettings()` を呼ぶ
4. `deleteList()`: リスト削除後に `_updateCustomListOrderInSettings()` を呼ぶ
5. `createDefaultListsIfEmpty()`: デフォルトリスト作成後に `_updateCustomListOrderInSettings()` を呼ぶ

---

## ✅ 完了項目

- ✅ リスト並び替え時に `customListOrder` を保存
- ✅ リスト追加時に `customListOrder` を更新
- ✅ リスト削除時に `customListOrder` を更新
- ✅ リスト更新時に `customListOrder` を更新
- ✅ デフォルトリスト作成時に `customListOrder` を初期化
- ✅ アプリ起動時に `customListOrder` から順番を復元
- ✅ Nostr同期時に `customListOrder` から順番を復元
- ✅ `AppSettings` 更新時に Kind 30078 へ自動同期
- ✅ マルチデバイス同期対応

---

## 🎉 結論

カスタムリストの並び順が完全に永続化され、以下のシナリオで順番が保持されるようになりました：

1. ✅ **アプリ再起動後**も順番が保持される
2. ✅ **Nostr同期後**も順番が保持される
3. ✅ **別デバイス**でも同じ順番が反映される
4. ✅ **リスト追加・削除**時も順番が適切に管理される

**実装完了日**: 2025-11-07

