# Amber連携実装完了

## 概要

Amberとの連携機能を完全に実装しました（NIP-55準拠）。これにより、ユーザーはAmberアプリを使用してNostr公開鍵の取得とイベントへの署名が可能になります。

## 実装完了日

2025-10-29

## 最終更新日

2025-10-29 - NIP-55完全準拠版に修正

## 実装内容

### 1. AndroidManifest.xmlの更新 ✅

#### 追加内容

**queries タグの追加** (`android/app/src/main/AndroidManifest.xml`):
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
    <!-- Amber (Nostr Signer) パッケージへのクエリ -->
    <package android:name="com.greenart7c3.nostrsigner" />
</queries>
```

**Intent Filter の追加**:
```xml
<!-- Amberからのレスポンスを受け取るIntent Filter (アプリ専用スキーム) -->
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="meiso"/>
</intent-filter>
```

**重要**: NIP-55仕様に従い、アプリ専用のカスタムスキーム (`meiso://`) を使用します。これにより、Amberからのレスポンスを正しく受け取ることができます。

### 2. MainActivity.ktの完全実装 ✅

#### Method Channelの設定

- チャンネル名: `jp.godzhigella.meiso/amber`
- Flutter側とKotlin側の通信ブリッジを確立

#### 実装メソッド

1. **getPublicKeyFromAmber**
   - Amberを起動して公開鍵を取得
   - Intent URIスキーム (NIP-55準拠): 
     ```
     nostrsigner:?compressionType=none&returnType=signature&type=get_public_key&callbackUrl=meiso://result&package={packageName}
     ```

2. **signEventWithAmber** 
   - Amberを起動してイベントに署名
   - Intent URIスキーム (NIP-55準拠):
     ```
     nostrsigner:{encodedEventJson}?compressionType=none&returnType=signature&type=sign_event&callbackUrl=meiso://result&package={packageName}
     ```
   - パラメータ: URLエンコードされたイベントJSON

3. **launchAmber**
   - Amberアプリを直接起動
   - パッケージマネージャー経由で起動

4. **openAmberInStore**
   - Google PlayでAmberのページを開く
   - Play StoreのURL経由

#### Intentレスポンス処理

- `onNewIntent()`: 新しいIntentを処理
- `onResume()`: アプリ再開時にIntentを処理
- `handleAmberResponse()`: Amberからのレスポンスをパース

レスポンススキーム: `meiso://result?{params}`

レスポンスパラメータ (NIP-55準拠):
- `pubkey`: 公開鍵 (get_public_keyの場合)
- `id`: イベントID (sign_eventの場合)
- `signature`: 署名 (sign_eventの場合)
- `event`: 署名済みイベントJSON (sign_eventの場合)
- `error`: エラーメッセージ

### 3. AmberServiceの完全実装 ✅

#### Method Channelベースの実装

従来の`android_intent_plus`から`MethodChannel`ベースに完全移行。

#### 主要メソッド

1. **getPublicKey()**
   ```dart
   Future<String?> getPublicKey() async
   ```
   - Method Channel経由でAmberから公開鍵を取得
   - エラーハンドリング完備（PlatformException対応）
   - ユーザーキャンセル時の適切なエラーメッセージ

2. **signEvent()**
   ```dart
   Future<String?> signEvent(String eventJson) async
   ```
   - Method Channel経由でイベント署名を要求
   - イベントJSONをパラメータとして送信
   - エラーハンドリング完備

3. **openAmber()** / **openAmberInStore()**
   - Method Channel経由でAmberアプリを起動
   - エラー時のフォールバック処理

#### エラーハンドリング

- `AMBER_USER_REJECTED`: ユーザーがキャンセルした場合
- `AMBER_ERROR`: Amber側でエラーが発生した場合
- `NOT_INSTALLED`: Amberがインストールされていない場合
- `LAUNCH_ERROR`: アプリ起動に失敗した場合

### 4. 動作フロー

#### 公開鍵取得フロー (NIP-55準拠)

1. Flutter: `AmberService.getPublicKey()` 呼び出し
2. Dart → Kotlin: Method Channel経由で`getPublicKeyFromAmber`メソッド呼び出し
3. Kotlin: Amberアプリを`nostrsigner:?type=get_public_key&callbackUrl=meiso://result&...` Intentで起動
4. Amber: ユーザーに承認を求める
5. Amber → Kotlin: `meiso://result?pubkey={hex}`スキームで結果を返す
6. Kotlin: `onNewIntent()`/`onResume()`で結果を受信
7. Kotlin → Dart: Method Channel経由で公開鍵を返す
8. Flutter: 公開鍵を受け取り、保存処理を実行

#### イベント署名フロー (NIP-55準拠)

1. Flutter: `AmberService.signEvent(eventJson)` 呼び出し
2. Dart → Kotlin: Method Channel経由で`signEventWithAmber`メソッド呼び出し
3. Kotlin: Amberアプリを`nostrsigner:{encodedJson}?type=sign_event&callbackUrl=meiso://result&...` Intentで起動
4. Amber: イベント内容を表示、ユーザーに署名を求める
5. Amber → Kotlin: `meiso://result?event={signedJson}` または `meiso://result?id={id}&signature={sig}`で結果を返す
6. Kotlin → Dart: Method Channel経由で結果を返す
7. Flutter: 署名済みイベントを処理

## 技術的な改善点

### Before (旧実装)

- ❌ `android_intent_plus`を使用してIntentを送信するだけ
- ❌ Amberからのレスポンスを受け取る仕組みがない
- ❌ 常に`null`を返していた
- ❌ ユーザーフィードバックが不十分
- ❌ NIP-55仕様に準拠していないURI形式

### After (新実装 - NIP-55完全準拠)

- ✅ Method Channelを使用してネイティブとFlutter間の双方向通信を確立
- ✅ `onNewIntent()`/`onResume()`でAmberからのレスポンスを適切に処理
- ✅ 実際の公開鍵・署名済みイベントを返す
- ✅ 詳細なエラーハンドリングとログ出力
- ✅ PlatformExceptionによる適切なエラー分類
- ✅ **NIP-55仕様に完全準拠したURI形式**
- ✅ **アプリ専用スキーム (`meiso://`) を使用**

## 使用方法

### 1. Amberから公開鍵を取得

```dart
final amberService = AmberService();

try {
  final publicKey = await amberService.getPublicKey();
  if (publicKey != null) {
    print('公開鍵: $publicKey');
    // セキュアストレージに保存
    await secureStorageService.saveNostrPublicKey(publicKey);
  }
} on PlatformException catch (e) {
  if (e.code == 'AMBER_USER_REJECTED') {
    // ユーザーがキャンセル
    print('ユーザーが認証をキャンセルしました');
  } else {
    // その他のエラー
    print('エラー: ${e.message}');
  }
}
```

### 2. Amberでイベントに署名

```dart
final eventJson = jsonEncode({
  'kind': 1,
  'content': 'Hello Nostr!',
  'tags': [],
  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
});

try {
  final signedEvent = await amberService.signEvent(eventJson);
  if (signedEvent != null) {
    print('署名済みイベント: $signedEvent');
    // Nostrリレーに送信
  }
} catch (e) {
  print('署名エラー: $e');
}
```

## テスト方法

### 前提条件

1. Androidエミュレーターまたは実機
2. Amberアプリがインストールされていること
   - [Google Play](https://play.google.com/store/apps/details?id=com.greenart7c3.nostrsigner)
   - または [F-Droid](https://f-droid.org/)

### テスト手順

1. **アプリをビルドして実行**
   ```bash
   cd /Users/apple/work/meiso
   fvm flutter run
   ```

2. **オンボーディング画面で「Amberでログイン」をタップ**

3. **期待される動作**
   - Amberアプリが起動する
   - Amberで「公開鍵の共有を許可しますか？」と表示される
   - 承認すると、Meisoアプリに戻り公開鍵が保存される
   - ホーム画面に遷移する

4. **エラーケースのテスト**
   - Amberで「拒否」を選択 → エラーダイアログが表示される
   - Amberがインストールされていない → インストールを促すダイアログが表示される

## トラブルシューティング

### 問題: Amberが起動しない

**原因**: Amberがインストールされていない、またはパッケージ名が正しくない

**解決策**:
1. Amberがインストールされているか確認
2. パッケージ名が`com.greenart7c3.nostrsigner`であることを確認

### 問題: レスポンスが受け取れない

**原因**: Intent Filterが正しく設定されていない、またはスキームが間違っている

**解決策**:
1. AndroidManifest.xmlの`meiso`スキームのIntent Filterを確認（`nostrsigner`ではなく`meiso`）
2. アプリを再ビルド (`flutter clean && flutter run`)
3. logcatでAmberからのレスポンスURIを確認

### 問題: PlatformExceptionが発生する

**原因**: Method Channelの設定が正しくない

**解決策**:
1. チャンネル名が一致しているか確認（Dart: `jp.godzhigella.meiso/amber`, Kotlin: `jp.godzhigella.meiso/amber`）
2. MainActivityで`configureFlutterEngine()`が正しく呼ばれているか確認

## 今後の改善案

### 優先度: 高

1. **インストール確認の実装**
   - `isAmberInstalled()`メソッドを実際に実装する
   - `device_apps`パッケージまたはMethod Channel経由でパッケージ存在確認

2. **タイムアウト処理**
   - Amberからのレスポンス待機にタイムアウトを設定（例: 60秒）
   - タイムアウト時に適切なエラーメッセージを表示

3. **複数アカウント対応**
   - Amberで複数のNostrアカウントを管理している場合の対応
   - アカウント選択UIの実装

### 優先度: 中

4. **リトライ機能**
   - エラー時に自動または手動でリトライできる仕組み

5. **デバッグモード**
   - 開発時に詳細なログを出力するデバッグモードの追加

6. **単体テスト**
   - AmberServiceのモックを使った単体テスト
   - Method Channelのテスト

## 参考資料

- [Amber GitHub](https://github.com/greenart7c3/Amber)
- [NIP-55: Android Signer Application](https://github.com/nostr-protocol/nips/blob/master/55.md)
- [Flutter Method Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)

## 変更されたファイル

1. `android/app/src/main/AndroidManifest.xml` - Intent FilterとQueriesタグの追加
2. `android/app/src/main/kotlin/jp/godzhigella/meiso/MainActivity.kt` - Method Channelとレスポンス処理の実装
3. `lib/services/amber_service.dart` - Method Channelベースの実装に完全書き換え

---

**実装者**: AI Assistant  
**レビュー**: 必要  
**ステータス**: ✅ 実装完了、テスト待ち

