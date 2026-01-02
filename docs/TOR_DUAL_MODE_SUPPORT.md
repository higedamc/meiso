# Tor/Orbot Support - Dual Mode Implementation

## 概要

Meiso アプリは、**2つの Tor 接続方式**をサポートしています：

1. **Internal (Embedded Tor)**: アプリ内蔵の Tor クライアントを使用（Orbot 不要）
2. **Orbot (SOCKS5 Proxy)**: 外部の Orbot アプリ経由で接続（より軽量）

ユーザーは Settings 画面で、`Disabled` / `Internal` / `Orbot` の3つのモードを選択できます。

---

## 実装内容

### 1. Rust側の実装（Dual Tor Support）

#### `rust/Cargo.toml` - `tor` feature 追加

```toml
[dependencies]
nostr-sdk = { version = "0.37", features = ["nip44", "tor"] }
```

`tor` feature を有効化することで、`nostr-sdk` が embedded Tor クライアント (Arti) をサポートします。

#### `rust/src/api.rs` - `TorMode` enum

```rust
/// Tor接続モード
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TorMode {
    /// Tor無効（直接接続）
    Disabled,
    /// 内蔵Tor (Embedded Tor)
    Internal,
    /// Orbot経由 (SOCKS5 Proxy)
    Orbot,
}
```

#### `rust/src/api.rs` - `new_with_tor_mode()`

```rust
pub async fn new_with_tor_mode(
    secret_key_hex: &str,
    relays: Vec<String>,
    tor_mode: TorMode,
    proxy_url: Option<String>,
) -> Result<Self> {
    let keys = Keys::parse(secret_key_hex)?;

    // Torモードに応じてクライアントを作成
    let client = match tor_mode {
        TorMode::Disabled => {
            println!("🔓 Direct connection (no Tor)");
            Client::new(keys.clone())
        }
        TorMode::Internal => {
            #[cfg(feature = "tor")]
            {
                println!("🧅 Using embedded Tor");
                Client::new(keys.clone())
                // .onion リレーへの接続時に自動的に embedded Tor を使用
            }
            #[cfg(not(feature = "tor"))]
            {
                return Err(anyhow::anyhow!("Embedded Tor is not enabled."));
            }
        }
        TorMode::Orbot => {
            // Orbotモード: SOCKS5プロキシ経由
            let proxy = proxy_url.as_ref()
                .ok_or_else(|| anyhow::anyhow!("Proxy URL is required for Orbot mode"))?;
                
            println!("🔐 Using Orbot proxy: {}", proxy);
            
            // SOCKS5プロキシを環境変数に設定
            std::env::set_var("all_proxy", proxy);
            std::env::set_var("ALL_PROXY", proxy);
            std::env::set_var("socks_proxy", proxy);
            std::env::set_var("SOCKS_PROXY", proxy);
            
            Client::new(keys.clone())
        }
    };
    // ...
}
```

### 2. Flutter側の実装

#### `lib/models/app_settings.dart` - データモデル

```dart
/// Tor接続モード
enum TorMode {
  /// Tor無効（直接接続）
  disabled,
  
  /// 内蔵Tor (Embedded Tor)
  internal,
  
  /// Orbot経由 (SOCKS5 Proxy)
  orbot,
}

class AppSettings {
  // ...
  /// Tor接続モード
  @Default(TorMode.disabled) TorMode torMode,
  
  /// プロキシURL（Orbotモード使用時、通常は socks5://127.0.0.1:9050）
  @Default('socks5://127.0.0.1:9050') String proxyUrl,
  // ...
}
```

#### `lib/providers/nostr_provider.dart` - 初期化時に TorMode 対応

```dart
Future<String> initializeNostr({
  required String secretKey,
  List<String>? relays,
  TorMode? torMode,
  String? proxyUrl,
}) async {
  final relayList = relays ?? defaultRelays;
  final effectiveTorMode = torMode ?? TorMode.disabled;
  
  // TorMode に応じて接続方法を選択
  final String publicKey;
  
  switch (effectiveTorMode) {
    case TorMode.disabled:
      // 直接接続（Torなし）
      publicKey = await rust_api.initNostrClient(
        secretKeyHex: secretKey,
        relays: relayList,
      );
      break;
      
    case TorMode.internal:
      // 内蔵Tor (Embedded Tor)
      publicKey = await rust_api.initNostrClientWithTorMode(
        secretKeyHex: secretKey,
        relays: relayList,
        torMode: rust_api.TorMode.internal,
        proxyUrl: null,
      );
      break;
      
    case TorMode.orbot:
      // Orbot経由 (SOCKS5 Proxy)
      final effectiveProxyUrl = proxyUrl ?? 'socks5://127.0.0.1:9050';
      publicKey = await rust_api.initNostrClientWithTorMode(
        secretKeyHex: secretKey,
        relays: relayList,
        torMode: rust_api.TorMode.orbot,
        proxyUrl: effectiveProxyUrl,
      );
      break;
  }
  // ...
}
```

#### `lib/presentation/settings/app_settings_detail_screen.dart` - UI

- **Tor接続モード選択**: `Disabled` / `Internal` / `Orbot` の3つから選択
- **Orbotモード時の設定**:
  - プロキシURL編集ダイアログ（ホストとポート入力）
  - プロキシ接続テストボタン
  - Orbot インストールガイド（Google Play / F-Droid へのリンク）
- **Internalモード時の案内**: 「内蔵Tor使用中、追加アプリ不要」メッセージ

---

## 技術仕様

### 動作環境

- **Android**: Orbot 16.6.1+ 推奨（Orbotモード使用時）
- **Embedded Tor**: Arti (Rust製 Tor クライアント)
- **Nostr SDK**: 0.37+ (`tor` feature 有効化)

### 接続フロー

#### 1. Disabled モード
- 通常の直接接続（Tor なし）

#### 2. Internal モード (Embedded Tor)
- アプリ内蔵の Arti クライアントを使用
- `.onion` リレーへの接続時に自動的に Tor 経由で接続
- Orbot のインストール不要

#### 3. Orbot モード (SOCKS5 Proxy)
- プロキシURL（デフォルト: `socks5://127.0.0.1:9050`）を設定
- Rust側で環境変数 `all_proxy`, `ALL_PROXY`, `socks_proxy`, `SOCKS_PROXY` を設定
- `nostr-sdk` が SOCKS5 プロキシ経由でリレーに接続
- Orbot が Tor ネットワークへのゲートウェイとして動作

---

## メリット

### Internal モード
1. **簡単**: Orbot のインストール不要
2. **統合**: アプリ内で完結
3. **軽量**: 追加アプリ不要

### Orbot モード
1. **軽量**: アプリサイズが小さい
2. **共有**: 他のアプリと Orbot を共有可能
3. **柔軟**: Orbot の詳細設定を利用可能

### 共通
1. **プライバシー強化**: Tor経由で接続することで、IPアドレスを隠蔽
2. **検閲回避**: ブロックされたリレーへのアクセスが可能
3. **透過的な実装**: `nostr-sdk` のネイティブサポートを活用

---

## 比較: Internal vs Orbot

| 項目 | Internal (Embedded) | Orbot (Proxy) |
|------|---------------------|---------------|
| **インストール** | 不要 | Orbot 必要 |
| **アプリサイズ** | 大きい（+数MB） | 小さい |
| **設定** | 自動 | 手動（Orbot起動必要） |
| **他アプリと共有** | 不可 | 可能 |
| **接続速度** | やや遅い（初回） | Orbot次第 |
| **推奨ユーザー** | 一般ユーザー | 上級ユーザー |

---

## 使用方法

### 1. Settings 画面で Tor モードを選択

1. アプリを開く
2. Settings（⚙️）をタップ
3. 「Tor Connection」をタップ
4. `Disabled` / `Internal` / `Orbot` から選択

### 2. Orbotモードを使用する場合

1. Orbotアプリをインストール（Google Play / F-Droid）
2. Orbotを起動し、接続を確立
3. Meisoアプリで「Orbot (Proxy)」を選択
4. 必要に応じてプロキシURLを編集（通常はデフォルトでOK）
5. 「Test」ボタンで接続確認

### 3. Internalモードを使用する場合

1. Meisoアプリで「Internal (Embedded)」を選択
2. 自動的に内蔵Torが有効化される
3. `.onion`リレーへの接続時に自動的にTor経由で接続

---

## トラブルシューティング

### Orbotモードで接続できない

1. Orbotアプリが起動しているか確認
2. Orbotが「接続済み」状態になっているか確認
3. プロキシURL（`socks5://127.0.0.1:9050`）が正しいか確認
4. 「Test」ボタンで接続状態を確認

### Internalモードで接続が遅い

- 初回接続時はTorサーキットの構築に時間がかかります（数秒〜数十秒）
- 2回目以降は高速化されます

### `.onion`リレーに接続できない

- TorモードがDisabledになっていないか確認
- InternalまたはOrbotモードを選択してください

---

## 今後の改善案

- [ ] Orbot自動起動機能（Androidインテント経由）
- [ ] `.onion`リレーへの接続テスト（両方式）
- [ ] Internal モードの接続状態表示
- [ ] Embedded Tor の設定カスタマイズ（サーキット選択等）
- [ ] Tor ブリッジ設定のサポート

---

## 参考資料

- [Orbot - Google Play](https://play.google.com/store/apps/details?id=org.torproject.android)
- [Orbot - F-Droid](https://f-droid.org/packages/org.torproject.android/)
- [nostr-sdk Documentation](https://docs.rs/nostr-sdk/)
- [Arti (Tor in Rust)](https://gitlab.torproject.org/arti)

---

**実装日**: 2026-01-02
**Issue**: #97 - Tor connection support confirmation and improvement

