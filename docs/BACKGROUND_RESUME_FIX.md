# バックグラウンド復帰時の同期エラー修正

## Issue #19: バックグラウンド復帰時に同期エラー（赤インジケーター）が発生する問題

### 問題の概要

アプリをバックグラウンドに移した後、フォアグラウンドに復帰すると必ず同期インジケーターが赤色（エラー状態）になる問題が発生していました。

**症状:**
- 初回起動時は正常動作（青/緑のインジケーター）
- バックグラウンドから復帰すると必ず赤（エラー）になる
- リレーサーバーとの接続が切断されたまま再接続されていない

### 原因

Flutterアプリがバックグラウンドに移行した際に、NostrリレーサーバーとのWebSocket接続が切断され、フォアグラウンド復帰時に自動的に再接続されていませんでした。

### 解決策

アプリのライフサイクル（フォアグラウンド/バックグラウンド）を監視し、フォアグラウンド復帰時に自動的にリレー再接続と同期を実行する機能を実装しました。

## 実装内容

### 1. AppLifecycleProvider の作成

**ファイル:** `lib/providers/app_lifecycle_provider.dart`

アプリのライフサイクルを監視し、フォアグラウンド復帰時に以下の処理を自動実行します：

- **リレー再接続:** Rust側の`reconnect_to_relays()` APIを呼び出し
- **データ同期:** TodosProviderの`syncFromNostr()`を呼び出し
- **重複実行防止:** 5秒以内の連続復帰は無視
- **エラーハンドリング:** 再接続失敗時も適切なエラー表示

```dart
/// アプリのライフサイクル状態を管理するProvider
final appLifecycleProvider = StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState>((ref) {
  return AppLifecycleNotifier(ref);
});
```

**主な機能:**
- `_onAppResumed()`: フォアグラウンド復帰時の処理
- `_reconnectAndSync()`: リレー再接続→同期の実行
- 連続復帰防止（5秒間のクールダウン）
- 再接続中フラグで重複実行を防止

### 2. NostrService に再接続メソッドを追加

**ファイル:** `lib/providers/nostr_provider.dart`

Flutter側からRust側の再接続APIを呼び出すメソッドを追加：

```dart
/// リレーサーバーへ再接続
/// バックグラウンドから復帰時などに使用
Future<void> reconnectRelays() async {
  print('🔄 Reconnecting to relays...');
  try {
    await rust_api.reconnectToRelays();
    print('✅ Successfully reconnected to relays');
  } catch (e) {
    print('❌ Failed to reconnect to relays: $e');
    rethrow;
  }
}
```

### 3. main.dart の修正

**ファイル:** `lib/main.dart`

既存の重複したライフサイクル監視コードを削除し、AppLifecycleProviderに一元化：

**変更前:**
- `WidgetsBindingObserver` を実装
- `didChangeAppLifecycleState()` で独自処理
- フォアグラウンド復帰時に `_restoreNostrConnection()` を呼び出し（初期化チェックのみ）

**変更後:**
- AppLifecycleProviderを初期化するだけ
- フォアグラウンド復帰時の処理はすべてAppLifecycleProviderに委譲
- コードの重複を排除

```dart
@override
void initState() {
  super.initState();
  
  // AppLifecycleProviderを初期化（アプリのライフサイクル監視を開始）
  // これによりフォアグラウンド復帰時の自動再接続・同期が有効になります
  ref.read(appLifecycleProvider);
  
  // アプリ起動時にNostr接続を復元
  _restoreNostrConnection();
  
  // ... GoRouterの初期化 ...
}
```

### 4. Rust側の既存API活用

**ファイル:** `rust/src/api.rs`

既に実装されていた`reconnect_to_relays()` APIを活用：

```rust
pub(crate) async fn reconnect(&self) -> Result<()> {
    println!("🔄 Reconnecting to relays...");
    
    // Disconnect first
    self.client.disconnect().await?;
    
    // Then reconnect
    match tokio::time::timeout(Duration::from_secs(10), self.client.connect()).await {
        Ok(_) => {
            println!("✅ Reconnected to relays");
            Ok(())
        }
        Err(_) => {
            eprintln!("⚠️ Reconnection timeout");
            Err(anyhow::anyhow!("Reconnection timeout"))
        }
    }
}
```

## 動作フロー

1. **アプリがバックグラウンドに移行**
   - `AppLifecycleNotifier._onAppPaused()` が呼ばれる
   - ログ出力: `📱 App paused`

2. **アプリがフォアグラウンドに復帰**
   - `AppLifecycleNotifier._onAppResumed()` が呼ばれる
   - ログ出力: `📱 App resumed at: [timestamp]`
   
3. **再接続チェック**
   - 前回復帰からの経過時間をチェック（5秒以上の場合のみ実行）
   - Nostr初期化済みかチェック
   - 既に再接続中でないかチェック

4. **リレー再接続**
   - `nostrService.reconnectRelays()` を呼び出し
   - Rust側で `disconnect()` → `connect()` を実行
   - ログ出力: `🔄 Reconnecting to relays...` → `✅ Successfully reconnected to relays`

5. **データ同期**
   - `todosNotifier.syncFromNostr()` を呼び出し
   - Nostrからデータを取得して状態を更新
   - ログ出力: `🔄 Starting sync after reconnect...` → `✅ Sync after reconnect completed`

6. **UIへの反映**
   - `SyncStatusIndicator` が同期状態に応じた色を表示
   - 成功: 緑色（`SyncState.success`）
   - エラー: 赤色（`SyncState.error`） - ただし3秒後に自動クリア

## ログ出力

実装には詳細なログ出力が含まれており、デバッグが容易です：

```
📱 AppLifecycleNotifier initialized
📱 App lifecycle changed: AppLifecycleState.resumed
📱 App resumed at: 2025-11-03T10:30:45.123
📱 Time since last resume: 120 seconds
🔄 Starting relay reconnection...
🔄 Reconnecting to relays...
✅ Relay reconnection completed
🔄 Starting sync after reconnect...
📥 Received X TodoData objects from Rust
✅ Sync after reconnect completed
```

## テスト方法

1. アプリを起動
2. データが正常に同期されることを確認（緑または青のインジケーター）
3. ホームボタンでアプリをバックグラウンドに移行
4. 10秒以上待機
5. アプリをフォアグラウンドに復帰
6. **期待される結果:**
   - ログに `📱 App resumed` が表示される
   - リレー再接続のログが表示される
   - データ同期が実行される
   - インジケーターが緑色（成功）になる
   - 赤色（エラー）にならない

## 注意事項

- **5秒間のクールダウン:** 連続したフォアグラウンド復帰を防ぐため、前回復帰から5秒以内の場合は再接続をスキップします
- **Nostr未初期化時:** Nostrが初期化されていない場合は再接続をスキップします（初回起動時など）
- **既に再接続中:** 再接続処理が既に実行中の場合は重複実行を防ぎます
- **エラーハンドリング:** 再接続失敗時もアプリは動作し続け、エラーは3秒後に自動クリアされます

## 関連ファイル

- `lib/providers/app_lifecycle_provider.dart` - 新規作成
- `lib/providers/nostr_provider.dart` - `reconnectRelays()` メソッド追加
- `lib/main.dart` - AppLifecycleProvider初期化、重複コード削除
- `rust/src/api.rs` - 既存の `reconnect_to_relays()` API活用

## 今後の改善案

1. **再接続リトライロジック:** 再接続失敗時の自動リトライ機能
2. **ネットワーク状態監視:** ネットワーク接続が回復した際の自動再接続
3. **オフラインモード表示:** ネットワーク未接続時の明示的なUI表示
4. **再接続タイムアウト調整:** 10秒のタイムアウトが適切かどうかの検証

## まとめ

この実装により、アプリをバックグラウンドから復帰させた際に必ず発生していた同期エラー（赤インジケーター）が解決されました。AppLifecycleProviderによる一元的なライフサイクル管理により、フォアグラウンド復帰時に自動的にリレー再接続とデータ同期が実行され、ユーザーはシームレスにアプリを使用できるようになります。

