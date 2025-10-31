# Nostr自動再接続機能の実装

## 問題

Amberでログインした後、しばらくスマホを操作してmeisoに戻ってくると、Nostr未接続状態になり、ログアウトして再ログインが必要になる問題が発生していました。

### 根本原因

- Nostr接続の状態（`nostrInitializedProvider`、`publicKeyProvider`）がメモリ内のみで管理されている
- アプリがバックグラウンドに移行してシステムがメモリを解放すると、状態がリセットされる
- ローカルストレージには`isUsingAmber`フラグがあるものの、アプリ復帰時に自動的に接続を復元する仕組みがなかった

## 解決策

### 1. アプリライフサイクル監視の追加

`main.dart`の`_MeisoAppState`に`WidgetsBindingObserver` mixinを追加：

```dart
class _MeisoAppState extends ConsumerState<MeisoApp> with WidgetsBindingObserver {
  // ...
}
```

### 2. ライフサイクルイベントの監視

```dart
@override
void initState() {
  super.initState();
  
  // アプリのライフサイクル監視を開始
  WidgetsBinding.instance.addObserver(this);
  
  // アプリ起動時にNostr接続を復元
  _restoreNostrConnection();
  
  // ...
}

@override
void dispose() {
  // アプリのライフサイクル監視を終了
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  
  // アプリがフォアグラウンドに復帰した時
  if (state == AppLifecycleState.resumed) {
    print('🔄 アプリがフォアグラウンドに復帰しました');
    _restoreNostrConnection();
  }
}
```

### 3. Nostr接続の自動復元ロジック

`_restoreNostrConnection()`メソッドを実装：

**動作フロー:**

1. **初期化済みチェック**: 既に接続済みの場合はスキップ
2. **認証モード判定**: ローカルストレージから`isUsingAmber`フラグを読み込み
3. **Amberモードの場合**:
   - Rust側から保存された公開鍵を取得
   - 公開鍵が存在する場合、アプリ設定からリレーリスト・プロキシURLを取得
   - `initializeNostrWithPubkey()`を呼び出して接続を復元
4. **秘密鍵モードの場合**:
   - 暗号化された秘密鍵の存在をチェック
   - パスワード入力が必要なため、自動復元はスキップ
   - ユーザーが手動でログインする必要がある

## 実装の詳細

### Amberモードの自動復元

```dart
if (isUsingAmber) {
  // Amberモード: Rust側から公開鍵を取得
  final publicKey = await nostrService.getPublicKey();
  
  if (publicKey != null) {
    // アプリ設定からリレーリストとプロキシURLを取得
    final appSettingsAsync = ref.read(appSettingsProvider);
    final relays = appSettingsAsync.value?.relays.isNotEmpty == true
        ? appSettingsAsync.value!.relays
        : null;
    final proxyUrl = appSettingsAsync.value?.torEnabled == true
        ? 'socks5://127.0.0.1:9050'
        : null;
    
    // Nostrクライアントを初期化（Amberモード）
    await nostrService.initializeNostrWithPubkey(
      publicKeyHex: publicKey,
      relays: relays,
      proxyUrl: proxyUrl,
    );
    
    print('✅ Amberモードで接続を復元しました');
  }
}
```

### 秘密鍵モードの場合

秘密鍵モードでは、パスワード入力が必要なため、自動復元は行いません。ユーザーが手動でログインする必要があります。

```dart
else {
  // 秘密鍵モード: 暗号化された秘密鍵が存在するかチェック
  final hasKey = await nostrService.hasEncryptedKey();
  
  if (hasKey) {
    print('🔐 秘密鍵モードで暗号化された秘密鍵が見つかりました');
    print('⚠️ パスワード入力が必要なため、自動復元をスキップします');
    // ユーザーが手動でログインする必要がある
  }
}
```

## テスト手順

1. **Amberでログイン**
   - アプリを起動
   - Amberを使ってログイン
   - TODOが同期されることを確認

2. **バックグラウンド移行テスト**
   - アプリをバックグラウンドに移動（ホームボタンを押す）
   - 他のアプリを開いてしばらく操作（1〜2分）
   - meisoに戻る
   - **期待結果**: Nostr接続が自動的に復元され、「Nostr未接続」にならない

3. **メモリ解放テスト**
   - 開発者オプションでバックグラウンドプロセスの制限を設定
   - アプリをバックグラウンドに移動
   - 複数の重いアプリを起動してメモリを消費
   - meisoに戻る
   - **期待結果**: Nostr接続が自動的に復元される

4. **アプリ完全終了からの再起動**
   - アプリを完全に終了（タスクマネージャーからスワイプ）
   - アプリを再起動
   - **期待結果**: アプリ起動時にNostr接続が自動的に復元される

## 変更されたファイル

- `lib/main.dart`
  - `WidgetsBindingObserver` mixinを追加
  - `didChangeAppLifecycleState()`メソッドを追加
  - `_restoreNostrConnection()`メソッドを追加
  - `dispose()`メソッドにオブザーバーの削除を追加

## メリット

1. **ユーザー体験の向上**: アプリに戻るたびにログインし直す必要がなくなる
2. **シームレスな再接続**: バックグラウンドから戻っても自動的に接続が復元される
3. **セキュリティ維持**: 秘密鍵モードではパスワードが必要なので自動復元しない（セキュリティを優先）

## 注意事項

- Amberモードのみ自動復元が有効
- 秘密鍵モードはパスワード入力が必要なため、ユーザーが手動でログインする必要がある
- エラーが発生した場合は無視され、ユーザーは手動でログインできる

## デバッグログ

接続復元時に以下のログが出力されます：

```
🔄 アプリがフォアグラウンドに復帰しました
🔄 Nostr接続を復元しています...
🔍 Amber使用モード: true
🔐 Amberモードで公開鍵を復元しました
✅ Amberモードで接続を復元しました
```

## 今後の改善案

1. **秘密鍵モードの自動復元**: Biometric認証（指紋・顔認証）を使って、パスワードなしで自動復元できるようにする
2. **接続状態の可視化**: UI上で接続が復元中であることを表示する
3. **リトライ機能**: 復元に失敗した場合、自動的にリトライする

---

**実装日**: 2025-10-31  
**バージョン**: 1.0.0  
**担当**: Claude (Cursor AI Assistant)

