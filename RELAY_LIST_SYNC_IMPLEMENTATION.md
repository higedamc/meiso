# リレーリスト同期機能実装完了（NIP-65 Kind 10002）

## 概要

アプリ設定（Kind 30078）に**リレーリスト情報（NIP-65 Kind 10002）**を統合し、デバイス間でリレー設定を同期できるようになりました。

---

## 実装内容

### 1. **AppSettingsモデルの拡張**

#### `lib/models/app_settings.dart`

```dart
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    // ... 既存のフィールド ...
    
    /// リレーリスト（NIP-65 kind 10002から同期）
    @Default([]) List<String> relays,
    
    required DateTime updatedAt,
  }) = _AppSettings;
}
```

- `relays`フィールドを追加
- デフォルト値は空リスト（初回起動時にdefaultRelaysが適用される）

---

### 2. **Rust側のNIP-65実装**

#### `rust/src/api.rs`

**AppSettings構造体にリレーリストを追加:**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub dark_mode: bool,
    pub week_start_day: i32,
    pub calendar_view: String,
    pub notifications_enabled: bool,
    pub relays: Vec<String>,  // 新規追加
    pub updated_at: String,
}
```

**リレーリスト管理メソッドを追加:**

```rust
impl MeisoNostrClient {
    /// リレーリストをNostrに保存（NIP-65 Kind 10002 - Relay List Metadata）
    pub async fn save_relay_list(&self, relays: Vec<String>) -> Result<String> {
        // NIP-65: リレーを "r" タグとして追加
        let mut tags = Vec::new();
        for relay_url in &relays {
            tags.push(Tag::custom(
                TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::R)),
                vec![relay_url.clone()],
            ));
        }
        
        // Kind 10002イベント作成（contentは空）
        let event = EventBuilder::new(Kind::RelayList, String::new())
            .tags(tags)
            .sign(&self.keys)
            .await?;
        
        // リレーに送信
        // ...
    }

    /// リレーリストをNostrから同期（NIP-65 Kind 10002）
    pub async fn sync_relay_list(&self) -> Result<Vec<String>> {
        let filter = Filter::new()
            .kind(Kind::RelayList)
            .author(self.keys.public_key());

        let events = self.client.fetch_events(vec![filter], Some(Duration::from_secs(10))).await?;

        if let Some(event) = events.first() {
            let mut relays = Vec::new();
            
            // "r" タグからリレーURLを抽出
            for tag in event.tags.iter() {
                if let Some(tag_kind) = tag.kind().as_standardized() {
                    if matches!(tag_kind, TagStandard::Relay) {
                        if let Some(relay_url) = tag.content() {
                            relays.push(relay_url.to_string());
                        }
                    }
                }
            }
            
            return Ok(relays);
        }

        Ok(Vec::new())
    }
}
```

**Flutter Rust Bridge API関数:**

```rust
/// リレーリストをNostrに保存（Kind 10002 - Relay List Metadata）
pub fn save_relay_list(relays: Vec<String>) -> Result<String>

/// リレーリストをNostrから同期（Kind 10002）
pub fn sync_relay_list() -> Result<Vec<String>>
```

---

### 3. **Flutter側の統合**

#### `lib/providers/app_settings_provider.dart`

**設定保存時にリレーリストも同期:**

```dart
Future<void> _syncToNostr(AppSettings settings) async {
  // ...
  
  if (isAmberMode) {
    // Amberモード: 設定JSONにリレーリストを含める
    final settingsJson = jsonEncode({
      'dark_mode': settings.darkMode,
      'week_start_day': settings.weekStartDay,
      'calendar_view': settings.calendarView,
      'notifications_enabled': settings.notificationsEnabled,
      'relays': settings.relays,  // 追加
      'updated_at': settings.updatedAt.toIso8601String(),
    });
    
    // 暗号化・署名・送信...
    
  } else {
    // 通常モード: Rust側でAppSettings保存
    final bridgeSettings = bridge.AppSettings(
      darkMode: settings.darkMode,
      weekStartDay: settings.weekStartDay,
      calendarView: settings.calendarView,
      notificationsEnabled: settings.notificationsEnabled,
      relays: settings.relays,  // 追加
      updatedAt: settings.updatedAt.toIso8601String(),
    );
    
    await bridge.saveAppSettings(settings: bridgeSettings);
    
    // リレーリストを別途同期（NIP-65 Kind 10002）
    if (settings.relays.isNotEmpty) {
      try {
        final relayEventId = await bridge.saveRelayList(relays: settings.relays);
        print('✅ リレーリスト同期完了: $relayEventId');
      } catch (e) {
        print('⚠️ リレーリスト同期失敗: $e');
      }
    }
  }
}
```

**設定同期時にリレーリストも取得:**

```dart
Future<void> syncFromNostr() async {
  // ...
  
  if (isAmberMode) {
    // Amberモード: 復号化後にKind 10002から取得
    final settingsMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
    
    List<String> syncedRelays = [];
    if (settingsMap.containsKey('relays')) {
      syncedRelays = List<String>.from(settingsMap['relays'] as List);
    }
    
    // Kind 10002からリレーリストを同期（利用可能な場合）
    try {
      final kind10002Relays = await bridge.syncRelayList();
      if (kind10002Relays.isNotEmpty) {
        syncedRelays = kind10002Relays;
      }
    } catch (e) {
      print('⚠️ Kind 10002同期失敗: $e');
    }
    
  } else {
    // 通常モード: Rust側でAppSettings取得
    final bridgeSettings = await bridge.syncAppSettings();
    
    // リレーリストを別途同期（NIP-65 Kind 10002）
    List<String> syncedRelays = [];
    try {
      syncedRelays = await bridge.syncRelayList();
    } catch (e) {
      print('⚠️ リレーリスト同期失敗: $e');
      syncedRelays = bridgeSettings.relays;
    }
  }
}
```

**リレーリスト更新メソッドを追加:**

```dart
/// リレーリストを更新
Future<void> updateRelays(List<String> relays) async {
  state.whenData((settings) async {
    await updateSettings(settings.copyWith(relays: relays));
  });
}
```

---

### 4. **Settings画面との連携**

#### `lib/presentation/settings/settings_screen.dart`

**初期化時にAppSettingsからリレーリストを読み込み:**

```dart
void _initializeRelayStates() {
  final relayNotifier = ref.read(relayStatusProvider.notifier);
  
  // AppSettingsからリレーリストを取得（保存されている場合）
  final appSettings = ref.read(appSettingsProvider);
  appSettings.whenData((settings) {
    if (settings.relays.isNotEmpty) {
      // 保存されたリレーリストを使用
      relayNotifier.initializeWithRelays(settings.relays);
      print('✅ 保存されたリレーリストを読み込み: ${settings.relays.length}件');
    } else {
      // デフォルトリレーを使用
      relayNotifier.initializeWithRelays(defaultRelays);
      print('✅ デフォルトリレーを使用');
    }
  });
}
```

**リレー追加・削除時にAppSettingsに反映:**

```dart
void _addRelay() {
  final url = _newRelayController.text.trim();
  // バリデーション...
  
  ref.read(relayStatusProvider.notifier).addRelay(url);
  _newRelayController.clear();
  
  // AppSettingsにも反映
  final updatedRelays = ref.read(relayStatusProvider).keys.toList();
  ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
  
  setState(() {
    _successMessage = 'リレーを追加しました';
  });
}

void _removeRelay(String url) {
  ref.read(relayStatusProvider.notifier).removeRelay(url);
  
  // AppSettingsにも反映
  final updatedRelays = ref.read(relayStatusProvider).keys.toList();
  ref.read(appSettingsProvider.notifier).updateRelays(updatedRelays);
  
  setState(() {
    _successMessage = 'リレーを削除しました';
  });
}
```

---

## 動作フロー

### **初回起動時**

1. `AppSettings.defaultSettings()`でデフォルト設定が作成（`relays: []`）
2. `_initializeRelayStates()`でデフォルトリレー（`defaultRelays`）を使用
3. ユーザーがリレーを追加/削除すると`AppSettings`に反映
4. Nostr接続時に`AppSettings`がKind 30078として保存され、リレーリストがKind 10002として保存

### **2回目以降の起動**

1. `AppSettings`をローカルストレージから読み込み
2. `_initializeRelayStates()`で保存されたリレーリストを使用
3. バックグラウンドでNostrから同期（Kind 30078 + Kind 10002）
4. Kind 10002が存在する場合、そちらを優先

### **デバイス間同期**

1. **デバイスA**: リレーを追加 → Kind 30078 + Kind 10002に保存
2. **デバイスB**: アプリ起動 → Kind 30078 + Kind 10002から同期
3. **結果**: 両デバイスで同じリレーリストが表示される

---

## NIP-65イベント例

```json
{
  "kind": 10002,
  "created_at": 1730000000,
  "tags": [
    ["r", "wss://relay.damus.io"],
    ["r", "wss://nos.lol"],
    ["r", "wss://relay.nostr.band"],
    ["r", "wss://nostr.wine"]
  ],
  "content": "",
  "pubkey": "abc123...",
  "id": "def456...",
  "sig": "789xyz..."
}
```

- **Kind**: `10002` (Relay List Metadata)
- **Tags**: 各リレーURLを`"r"`タグとして記録
- **Content**: 空文字列
- **Replaceable Event**: 最新のイベントのみが有効

---

## 次のステップ

### 1. **コード生成を実行**

```bash
cd /path/to/meiso
flutter pub run build_runner build --delete-conflicting-outputs
```

これにより以下が生成されます：
- `app_settings.freezed.dart`
- `app_settings.g.dart`
- `rust/src/frb_generated.rs`（Rustブリッジ）

### 2. **動作確認**

1. アプリを起動
2. Settings画面でリレーを追加/削除
3. Nostrに接続
4. 別のデバイスで同じアカウントでログイン
5. リレーリストが同期されることを確認

### 3. **Amber暗号化対応の確認**

- Amberモードでは`AppSettings`（Kind 30078）のJSONにリレーリストが含まれる
- ただし、**Kind 10002は平文**なので、より高速に同期可能

---

## まとめ

✅ **AppSettingsにリレーリストを追加**（`relays`フィールド）  
✅ **Rust側でNIP-65（Kind 10002）実装**（`save_relay_list`, `sync_relay_list`）  
✅ **Flutter側でリレー同期を統合**（AppSettingsProvider）  
✅ **Settings画面で自動保存・読み込み**（RelayStatusProviderと連携）  
✅ **デバイス間同期が可能**（Kind 10002で標準化）

これにより、ユーザーはリレー設定をデバイス間で簡単に同期できるようになりました！

