# Amber フォアグラウンド復帰時の公開鍵エラー修正

## 問題

Amberでログインした場合、しばらくアプリを触らずにフォアグラウンドで再びアプリを触ると、以下のエラーが発生していました：

```
送信エラー Exception: 公開鍵が設定されていません
```

## 原因

アプリがフォアグラウンドに復帰した際に、以下の問題が発生していました：

1. **Providerの状態が失われる**: `publicKeyProvider`の状態がリセットされる可能性がある
2. **公開鍵の復元処理がない**: フォアグラウンド復帰時に公開鍵を自動的に復元する仕組みがなかった

アプリ起動時には`main.dart`の`_restoreNostrConnection()`で公開鍵を復元していましたが、フォアグラウンド復帰時には対応していませんでした。

## 修正内容

### 1. app_lifecycle_provider.dart の修正

フォアグラウンド復帰時に公開鍵を自動復元する処理を追加しました：

#### 変更点

- **公開鍵のチェックと復元**: `_onAppResumed()`メソッドで、公開鍵が`null`の場合に`_restorePublicKey()`を呼び出す
- **_restorePublicKey()メソッドの追加**: 
  - Amberモードかチェック
  - Rust側から公開鍵を取得
  - `publicKeyProvider`に設定

```dart
/// 公開鍵を復元する（Amberモード対応）
Future<void> _restorePublicKey() async {
  try {
    print('🔑 Attempting to restore public key...');
    
    // Amberモードかチェック
    final isUsingAmber = localStorageService.isUsingAmber();
    if (!isUsingAmber) {
      print('ℹ️ Not in Amber mode, skipping public key restoration');
      return;
    }
    
    print('🔐 Amber mode detected, restoring public key from storage...');
    
    final nostrService = _ref.read(nostrServiceProvider);
    final publicKey = await nostrService.getPublicKey();
    
    if (publicKey != null) {
      print('✅ Public key restored: ${publicKey.substring(0, 16)}...');
      
      // publicKeyProviderに設定
      _ref.read(publicKeyProvider.notifier).state = publicKey;
      
      // nostrInitializedProviderもtrueにする（念のため）
      _ref.read(nostrInitializedProvider.notifier).state = true;
    } else {
      print('⚠️ No public key found in storage (Amber mode)');
    }
  } catch (e, stackTrace) {
    print('❌ Failed to restore public key: $e');
    print('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
  }
}
```

### 2. todos_provider.dart の修正

同期処理でも公開鍵が`null`の場合に自動復元する処理を追加しました：

#### 変更点

- **_syncAllTodosToNostr()メソッド**: 公開鍵取得時に`null`チェックを追加し、Rust側から復元を試みる
- **syncFromNostr()メソッド**: 同様に公開鍵の復元処理を追加

```dart
// 公開鍵がnullの場合、Rust側から復元を試みる
if (publicKey == null) {
  print('⚠️ Public key is null, attempting to restore from storage...');
  try {
    publicKey = await nostrService.getPublicKey();
    if (publicKey != null) {
      print('✅ Public key restored from storage');
      _ref.read(publicKeyProvider.notifier).state = publicKey;
    } else {
      print('❌ Failed to restore public key - no key found in storage');
      throw Exception('公開鍵が設定されていません（ストレージにも見つかりませんでした）');
    }
  } catch (e) {
    print('❌ Failed to restore public key: $e');
    throw Exception('公開鍵が設定されていません');
  }
}
```

## 動作フロー

### フォアグラウンド復帰時

1. `AppLifecycleNotifier.didChangeAppLifecycleState()` が `AppLifecycleState.resumed` を検知
2. `_onAppResumed()` が呼び出される
3. `publicKeyProvider` が `null` かチェック
4. `null` の場合、`_restorePublicKey()` を呼び出す
5. Amberモードかチェック
6. Rust側から公開鍵を取得
7. `publicKeyProvider` に設定
8. リレー再接続と同期を実行

### Todo同期時（フォールバック）

1. `_syncAllTodosToNostr()` または `syncFromNostr()` が呼び出される
2. `publicKeyProvider` が `null` かチェック
3. `null` の場合、Rust側から公開鍵を取得
4. `publicKeyProvider` に設定
5. 同期処理を続行

## テスト方法

1. Amberでログイン
2. アプリをバックグラウンドに移動
3. しばらく待つ（数分）
4. アプリをフォアグラウンドに戻す
5. Todoを追加・編集する
6. エラーが発生せず、正常に同期されることを確認

## 関連ファイル

- `lib/providers/app_lifecycle_provider.dart`: フォアグラウンド復帰時の公開鍵復元処理
- `lib/providers/todos_provider.dart`: 同期時の公開鍵復元処理（フォールバック）
- `lib/providers/nostr_provider.dart`: 公開鍵の保存・取得API
- `lib/services/local_storage_service.dart`: Amberモードフラグの管理

## 今後の改善案

1. **Providerの永続化**: `publicKeyProvider`の状態を自動的に永続化する仕組みを検討
2. **エラーハンドリング**: 公開鍵の復元に失敗した場合の、より詳細なエラーメッセージとリカバリー手段
3. **他のProviderへの対応**: 他のProviderでも同様の問題が発生する可能性があるため、汎用的な復元メカニズムを検討

## 参考

- Amber統合ドキュメント: `docs/PHASE4_AMBER_INTEGRATION_COMPLETE.md`
- Amberパーミッション修正: `docs/PHASE5_AMBER_PERMISSIONS_FIX.md`

