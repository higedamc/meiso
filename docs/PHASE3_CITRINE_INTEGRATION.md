# Phase 3: Citrine連携実装計画

## 概要

**Citrine**はAndroid向けのローカルNostrリレーアプリです。Meisoと連携することで、以下のメリットが得られます：

### メリット
- ✅ **オフライン対応**: インターネット接続なしでもタスク管理可能
- ✅ **高速化**: ローカル接続により、イベント取得/送信が爆速に
- ✅ **プライバシー強化**: データをローカルに保持、必要時のみリモート同期
- ✅ **バッテリー効率**: リモートリレーへの頻繁な接続を削減
- ✅ **コスト削減**: リモートリレーの負荷軽減

---

## Citrineの仕様

### 基本情報
- **パッケージ名**: `com.greenart7c3.citrine`
- **ローカルリレーURL（canonical）**: `ws://localhost:4869`
- **通信方式**: WebSocket（標準Nostrプロトコル）
- **対応NIP**: NIP-01, NIP-02, NIP-04, NIP-44, NIP-50 等

### Citrineの機能
1. **ローカルリレー**: デバイス上でNostrリレーを実行
2. **自動同期**: 設定したリモートリレーと定期的に同期
3. **選択的同期**: Kind・著者・タグによるフィルタリング
4. **通知**: 新規イベント受信時の通知

### 実装メモ（現行コード）
- relay role が未設定のURLは、`localhost/127.0.0.1/プライベートIP` を local として扱う
- Amber送信は local relay を先に送信し、global relay への送信はバックグラウンドキューで処理する

---

## 実装計画

### Step 1: Citrine検出機能

#### 1.1 パッケージインストール確認
```dart
// lib/services/citrine_service.dart
import 'package:device_apps/device_apps.dart';

class CitrineService {
  static const String citrinePackage = 'com.greenart7c3.citrine';
  
  Future<bool> isCitrineInstalled() async {
    final app = await DeviceApps.getApp(citrinePackage);
    return app != null;
  }
  
  Future<bool> isCitrineRunning() async {
    // Citrineリレーへの接続テスト
    try {
      final response = await http.get(Uri.parse('http://localhost:4869'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

#### 1.2 Citrine起動促進UI
```dart
// 設定画面に追加
Widget buildCitrineSection(BuildContext context, WidgetRef ref) {
  return Consumer(
    builder: (context, ref, child) {
      final isInstalled = ref.watch(citrineInstalledProvider);
      final isRunning = ref.watch(citrineRunningProvider);
      
      return Column(
        children: [
          ListTile(
            title: Text('Citrine (ローカルリレー)'),
            subtitle: Text(
              isRunning ? '接続中' : 
              isInstalled ? 'インストール済み（起動してください）' :
              '未インストール'
            ),
            trailing: isRunning ? Icon(Icons.check_circle, color: Colors.green) : null,
          ),
          if (!isInstalled)
            ElevatedButton(
              onPressed: () => _openPlayStore('com.greenart7c3.citrine'),
              child: Text('Citrineをインストール'),
            ),
          if (isInstalled && !isRunning)
            ElevatedButton(
              onPressed: () => _launchCitrine(),
              child: Text('Citrineを起動'),
            ),
        ],
      );
    },
  );
}
```

### Step 2: リレー管理の拡張

#### 2.1 リレーリスト管理
```dart
// lib/models/relay_config.dart
@freezed
class RelayConfig with _$RelayConfig {
  const factory RelayConfig({
    required String url,
    required RelayType type,
    required bool enabled,
    @Default(true) bool read,
    @Default(true) bool write,
  }) = _RelayConfig;
}

enum RelayType {
  local,    // Citrine
  remote,   // 通常のリモートリレー
}
```

#### 2.2 リレー優先順位
```rust
// rust/src/relay_manager.rs
pub struct RelayManager {
    local_relay: Option<String>,  // ws://localhost:4869
    remote_relays: Vec<String>,
    preferences: RelayPreferences,
}

pub enum RelayStrategy {
    LocalFirst,      // Citrineを最優先
    LocalOnly,       // Citrineのみ使用（プライバシー重視）
    RemoteFirst,     // リモート優先（通常モード）
    Balanced,        // バランス型（自動選択）
}

impl RelayManager {
    pub async fn connect(&mut self) -> Result<()> {
        match self.preferences.strategy {
            RelayStrategy::LocalFirst => {
                if let Some(local) = &self.local_relay {
                    if self.try_connect_local(local).await.is_ok() {
                        return Ok(());
                    }
                }
                self.connect_remote_relays().await
            }
            RelayStrategy::LocalOnly => {
                self.connect_local_only().await
            }
            _ => {
                // 他の戦略...
            }
        }
    }
}
```

### Step 3: 同期戦略の実装

#### 3.1 ハイブリッド同期
```rust
// rust/src/sync_strategy.rs
pub struct SyncStrategy {
    client: Client,
}

impl SyncStrategy {
    /// Citrine経由で同期（高速）
    pub async fn sync_via_citrine(&self) -> Result<Vec<Event>> {
        let local_relay = "ws://localhost:4869";
        
        // 1. ローカルから取得
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(self.public_key);
            
        let events = self.client
            .get_events_of(vec![local_relay.to_string()], vec![filter], None)
            .await?;
            
        Ok(events.into_iter().collect())
    }
    
    /// リモートリレーから同期（フォールバック）
    pub async fn sync_via_remote(&self) -> Result<Vec<Event>> {
        let remote_relays = vec![
            "wss://relay.damus.io",
            "wss://nos.lol",
        ];
        
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(self.public_key);
            
        let events = self.client
            .get_events_of(remote_relays, vec![filter], None)
            .await?;
            
        Ok(events.into_iter().collect())
    }
    
    /// スマート同期（状況に応じて自動選択）
    pub async fn smart_sync(&self) -> Result<Vec<Event>> {
        // 1. Citrineが利用可能か確認
        if self.is_citrine_available().await {
            // 2. Citrineから取得
            let local_events = self.sync_via_citrine().await?;
            
            // 3. 必要に応じてリモートからも取得（差分のみ）
            if self.should_sync_remote(&local_events) {
                self.sync_remote_delta(&local_events).await?;
            }
            
            return Ok(local_events);
        }
        
        // 4. Citrine不在時はリモート同期
        self.sync_via_remote().await
    }
}
```

#### 3.2 イベント送信戦略
```rust
pub async fn publish_event(&self, event: Event) -> Result<EventId> {
    let mut published_relays = Vec::new();
    
    // 1. Citrine優先送信
    if let Some(local) = &self.local_relay {
        if self.try_publish_to(local, &event).await.is_ok() {
            published_relays.push(local.clone());
        }
    }
    
    // 2. 設定に応じてリモートにも送信
    if self.preferences.sync_to_remote {
        for relay in &self.remote_relays {
            if self.try_publish_to(relay, &event).await.is_ok() {
                published_relays.push(relay.clone());
            }
        }
    }
    
    if published_relays.is_empty() {
        return Err(anyhow!("Failed to publish to any relay"));
    }
    
    Ok(event.id)
}
```

### Step 4: 設定画面の実装

#### 4.1 リレー設定UI
```dart
// lib/presentation/settings/relay_settings_screen.dart
class RelaySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('リレー設定')),
      body: Consumer(
        builder: (context, ref, child) {
          final relays = ref.watch(relayConfigProvider);
          final strategy = ref.watch(relayStrategyProvider);
          
          return ListView(
            children: [
              // Citrine設定セクション
              _buildCitrineSection(),
              
              Divider(),
              
              // 同期戦略選択
              ListTile(
                title: Text('同期戦略'),
                subtitle: Text(_strategyDescription(strategy)),
                trailing: DropdownButton<RelayStrategy>(
                  value: strategy,
                  items: RelayStrategy.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(_strategyName(s)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(relayStrategyProvider.notifier).state = value;
                    }
                  },
                ),
              ),
              
              Divider(),
              
              // リモートリレー一覧
              _buildRemoteRelaysList(relays),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRelayDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }
  
  String _strategyName(RelayStrategy strategy) {
    switch (strategy) {
      case RelayStrategy.localFirst:
        return 'ローカル優先';
      case RelayStrategy.localOnly:
        return 'ローカルのみ';
      case RelayStrategy.remoteFirst:
        return 'リモート優先';
      case RelayStrategy.balanced:
        return 'バランス型';
    }
  }
  
  String _strategyDescription(RelayStrategy strategy) {
    switch (strategy) {
      case RelayStrategy.localFirst:
        return 'Citrineを優先、不在時はリモートリレー';
      case RelayStrategy.localOnly:
        return 'Citrineのみ使用（最大プライバシー）';
      case RelayStrategy.remoteFirst:
        return 'リモートリレーを優先使用';
      case RelayStrategy.balanced:
        return '状況に応じて自動選択';
    }
  }
}
```

### Step 5: パフォーマンス最適化

#### 5.1 接続プーリング
```rust
pub struct ConnectionPool {
    local_connection: Option<Connection>,
    remote_connections: HashMap<String, Connection>,
}

impl ConnectionPool {
    pub async fn get_or_connect(&mut self, url: &str) -> Result<&Connection> {
        if url == "ws://localhost:4869" {
            if self.local_connection.is_none() {
                self.local_connection = Some(self.connect(url).await?);
            }
            Ok(self.local_connection.as_ref().unwrap())
        } else {
            if !self.remote_connections.contains_key(url) {
                let conn = self.connect(url).await?;
                self.remote_connections.insert(url.to_string(), conn);
            }
            Ok(self.remote_connections.get(url).unwrap())
        }
    }
}
```

#### 5.2 キャッシュ戦略
```dart
// lib/services/cache_service.dart
class CacheService {
  final HiveInterface _hive;
  
  /// Citrineが利用可能な場合、Hiveキャッシュは最小限に
  Future<void> optimizeCacheForCitrine(bool citrineAvailable) async {
    if (citrineAvailable) {
      // Citrineがある場合、ローカルキャッシュは最近のデータのみ
      await _cleanOldCache(days: 7);
    } else {
      // Citrine不在時は、より多くのデータをキャッシュ
      // 特に何もしない（既存のキャッシュを保持）
    }
  }
}
```

---

## Citrineの初期設定ガイド（ユーザー向け）

アプリ内に以下のガイドを表示：

### 1. Citrineのインストール
```
1. Play StoreからCitrineをインストール
2. Citrineを起動
3. リレー設定で「Start Local Relay」を有効化
```

### 2. Citrine → Meisoの自動同期設定
```
1. Citrineの設定画面を開く
2. 「Relay Settings」→「Sync Relays」
3. 以下のリレーを追加:
   - wss://relay.damus.io
   - wss://nos.lol
   - wss://relay.nostr.band
4. 「Auto Sync」を有効化
5. 「Sync Interval」を30分に設定（推奨）
```

### 3. Meiso側の設定
```
1. Meisoの設定画面を開く
2. 「リレー設定」→「Citrine連携」
3. 「Citrine検出」をタップ
4. 「同期戦略」を「ローカル優先」に設定
```

---

## テスト計画

### 機能テスト
- [ ] Citrine検出機能の動作確認
- [ ] ローカルリレー接続テスト
- [ ] リモートリレーフォールバック
- [ ] イベント送信（ローカル/リモート）
- [ ] イベント取得（ローカル/リモート）
- [ ] 同期戦略の切り替え

### パフォーマンステスト
- [ ] Citrine接続時の起動速度
- [ ] イベント送信レイテンシ（ローカル vs リモート）
- [ ] 大量イベント同期時の挙動
- [ ] バッテリー消費量測定

### エッジケーステスト
- [ ] Citrine非インストール時の挙動
- [ ] Citrine停止時のフォールバック
- [ ] ネットワーク切断時の挙動
- [ ] リレー切り替え時のデータ一貫性

---

## リリース計画

### Phase 3.1: 基本実装（2週間）
- Citrine検出機能
- ローカルリレー優先接続
- 基本的な同期戦略

### Phase 3.2: UI実装（1週間）
- 設定画面の拡張
- Citrineステータス表示
- ユーザーガイド

### Phase 3.3: 最適化（1週間）
- パフォーマンスチューニング
- バッテリー効率改善
- バグフィックス

---

## 参考リソース

- [Citrine GitHub](https://github.com/greenart7c3/Citrine)
- [Citrine使用方法](https://github.com/greenart7c3/Citrine/blob/main/README.md)
- [Nostr Protocol](https://github.com/nostr-protocol/nips)

---

**Phase 3で、Meisoは真のローカルファースト分散型タスク管理アプリになります！** 🚀

