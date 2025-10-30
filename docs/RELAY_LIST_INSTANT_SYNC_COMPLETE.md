# リレーリスト即座同期機能の実装完了

## 概要

設定画面でリレーサーバーを追加・削除した際に、即座にNostr（NIP-65 Kind 10002）に同期する機能を実装しました。

## 問題点

以前の実装では：
- **通常モード（秘密鍵モード）**: リレーリストがKind 10002として同期されていた
- **Amberモード**: リレーリストがKind 30078（アプリ設定）の一部としてのみ保存され、個別同期されていなかった

## 実装内容

### 1. Rust側の実装 (`rust/src/api.rs`)

#### 新規関数追加

```rust
/// 未署名リレーリストイベントを作成（Amber署名用 - NIP-65 Kind 10002）
pub fn create_unsigned_relay_list_event(
    relays: Vec<String>,
    public_key_hex: String,
) -> Result<String>
```

**機能**:
- NIP-65準拠のKind 10002イベントを作成
- 各リレーURLを`r`タグとして追加
- contentは空文字列（NIP-65では不要）
- 未署名のJSON文字列を返す（Amber署名用）

**イベント構造**:
```json
{
  "pubkey": "...",
  "created_at": 1234567890,
  "kind": 10002,
  "tags": [
    ["r", "wss://relay1.example.com"],
    ["r", "wss://relay2.example.com"]
  ],
  "content": ""
}
```

### 2. Flutter側の実装

#### `app_settings_provider.dart` の修正

Amberモードで設定を同期する際、リレーリストも個別にKind 10002として送信するように修正：

```dart
// Amberモード: 設定同期後にリレーリストも個別同期
if (settings.relays.isNotEmpty) {
  // 1. 未署名リレーリストイベント作成
  final unsignedRelayEvent = await bridge.createUnsignedRelayListEvent(
    relays: settings.relays,
    publicKeyHex: publicKey,
  );
  
  // 2. Amberで署名（ContentProvider → UI）
  String signedRelayEvent = await amberService.signEventWithContentProvider(
    event: unsignedRelayEvent,
    npub: npub,
  );
  
  // 3. リレーに送信
  final relayEventId = await nostrService.sendSignedEvent(signedRelayEvent);
}
```

#### `settings_screen.dart` の修正

リレー追加・削除時に同期完了を待機し、UIフィードバックを表示：

**修正前**:
```dart
void _addRelay() {
  // 同期的に処理、待機なし
  ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
  setState(() { _successMessage = 'リレーを追加しました'; });
}
```

**修正後**:
```dart
Future<void> _addRelay() async {
  setState(() { _isLoading = true; });
  
  try {
    // 同期完了を待機
    await ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
    setState(() { _successMessage = 'リレーを追加して同期しました'; });
  } catch (e) {
    setState(() { _errorMessage = 'リレー追加エラー: $e'; });
  } finally {
    setState(() { _isLoading = false; });
  }
}
```

## 動作フロー

### 通常モード（秘密鍵モード）

```
リレー追加/削除
  ↓
AppSettingsNotifier.updateRelays()
  ↓
Kind 30078（設定）送信
  ↓
Kind 10002（リレーリスト）送信 ← Rust側で署名・送信
  ↓
UI: 「リレーを追加して同期しました」
```

### Amberモード

```
リレー追加/削除
  ↓
AppSettingsNotifier.updateRelays()
  ↓
Kind 30078（設定）
  - JSON化 → Amber暗号化 → 未署名イベント作成 → Amber署名 → 送信
  ↓
Kind 10002（リレーリスト）← 新規追加
  - 未署名イベント作成（暗号化不要）→ Amber署名 → 送信
  ↓
UI: 「リレーを追加して同期しました」
```

## メリット

### 1. NIP-65準拠

- リレーリストがKind 10002として正しく保存される
- 他のNostrクライアントとの互換性が向上

### 2. 即座同期

- リレー追加・削除時に即座にNostrに反映
- 複数デバイス間で設定が同期される

### 3. UIフィードバック

- ローディング表示で同期中であることを明示
- 成功・失敗メッセージで結果を通知

### 4. 両モード対応

- 秘密鍵モード: Rust側で暗号化・署名
- Amberモード: Amber経由で署名

## NIP-65について

**NIP-65: Relay List Metadata (Kind 10002)**

- ユーザーが使用するリレーリストを公開
- 他のクライアントがこのリストを参照可能
- 暗号化不要（公開情報）
- `r`タグで各リレーを指定

**タグの意味**:
```json
["r", "wss://relay.example.com"]           // read + write
["r", "wss://relay.example.com", "read"]   // read only
["r", "wss://relay.example.com", "write"]  // write only
```

現在の実装では、すべてのリレーを read + write として登録しています。

## テスト項目

### 基本機能
- [x] リレー追加時にKind 10002として同期（通常モード）
- [x] リレー削除時にKind 10002として同期（通常モード）
- [x] リレー追加時にKind 10002として同期（Amberモード）
- [x] リレー削除時にKind 10002として同期（Amberモード）

### UIフィードバック
- [x] 同期中のローディング表示
- [x] 成功メッセージの表示
- [x] エラーメッセージの表示

### エラーハンドリング
- [x] Amber署名失敗時のフォールバック（ContentProvider → UI）
- [x] ネットワークエラー時の適切なエラー表示
- [x] リレー送信タイムアウトの処理

## ファイル変更一覧

### 新規追加
- `RELAY_LIST_INSTANT_SYNC_COMPLETE.md` - このドキュメント

### 変更
- `rust/src/api.rs`
  - `create_unsigned_relay_list_event()` 関数追加
- `lib/providers/app_settings_provider.dart`
  - AmberモードでKind 10002を個別送信
- `lib/presentation/settings/settings_screen.dart`
  - `_addRelay()` / `_removeRelay()` を async 化
  - ローディング表示とエラーハンドリング追加

## 次のステップ

1. **リレーの種類指定**: read/write を個別に設定できるようにする
2. **リレー品質の可視化**: 応答速度やアップタイムを表示
3. **自動リレー選択**: 地理的に近いリレーを自動推薦

## 関連NIP

- **NIP-01**: Basic protocol flow description
- **NIP-65**: Relay List Metadata (Kind 10002)
- **NIP-78**: Application-specific data (Kind 30078)

## まとめ

リレーサーバーの追加・削除時に、NIP-65準拠のKind 10002イベントとして即座に同期する機能を実装しました。通常モードとAmberモードの両方で動作し、適切なUIフィードバックを提供します。

