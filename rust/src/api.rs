use anyhow::{Context, Result};
use nostr_sdk::prelude::*;
use nostr_sdk::nips::nip44; // NIP-44暗号化を明示的にインポート
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::{NOSTR_CLIENTS, DEFAULT_CLIENT_ID};
use crate::group_tasks;

/// クライアントモード
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ClientMode {
    /// 秘密鍵モード（暗号化/署名可能）
    SecretKey,
    /// Amberモード（署名はAmber経由、暗号化/復号化もAmber経由）
    Amber { public_key_hex: String },
}

/// イベント送信結果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventSendResult {
    /// イベントID
    pub event_id: String,
    /// 送信成功したか
    pub success: bool,
    /// 成功したリレー数
    pub successful_relays: usize,
    /// 失敗したリレー数
    pub failed_relays: usize,
    /// タイムアウトしたか
    pub timed_out: bool,
    /// エラーメッセージ（失敗時）
    pub error_message: Option<String>,
}

/// Todoデータ構造（Flutter側と同期）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodoData {
    pub id: String,
    pub title: String,
    pub completed: bool,
    pub date: Option<String>, // ISO 8601形式 (null = Someday)
    pub order: i32,
    pub created_at: String,
    pub updated_at: String,
    pub event_id: Option<String>,
    /// リンクプレビュー（JSON文字列形式で保存）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub link_preview: Option<String>,
    /// リカーリングタスクの繰り返しパターン（JSON文字列形式で保存）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub recurrence: Option<String>,
    /// 親リカーリングタスクのID
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_recurring_id: Option<String>,
    /// カスタムリストID（SOMEDAYページのリストに属する場合）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub custom_list_id: Option<String>,
}

/// アプリ設定データ構造（NIP-78 Application-specific data - Kind 30078）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    /// ダークモード設定
    pub dark_mode: bool,
    /// 週の開始曜日 (0=日曜, 1=月曜, ...)
    pub week_start_day: i32,
    /// カレンダー表示形式 ("week" | "month")
    pub calendar_view: String,
    /// 通知設定
    pub notifications_enabled: bool,
    /// リレーリスト（NIP-65 kind 10002から同期）
    pub relays: Vec<String>,
    /// Tor有効/無効（Orbot経由での接続）
    #[serde(default)]
    pub tor_enabled: bool,
    /// プロキシURL（通常は socks5://127.0.0.1:9050）
    #[serde(default = "default_proxy_url")]
    pub proxy_url: String,
    /// カスタムリストの順番（リストIDの配列）
    #[serde(default)]
    pub custom_list_order: Vec<String>,
    /// 最終更新日時
    pub updated_at: String,
}

/// デフォルトのプロキシURL
fn default_proxy_url() -> String {
    "socks5://127.0.0.1:9050".to_string()
}

/// キャッシュされたイベント情報（Hive保存用）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CachedEventInfo {
    /// イベントID
    pub event_id: String,
    /// イベントの種類
    pub kind: u64,
    /// イベント作成日時（UNIX timestamp）
    pub created_at: i64,
    /// イベント内容（JSON文字列）
    pub event_json: String,
    /// キャッシュされた日時（UNIX timestamp）
    pub cached_at: i64,
    /// TTL（秒）
    pub ttl_seconds: u64,
    /// d-tag（Replaceable eventの場合）
    pub d_tag: Option<String>,
}

impl CachedEventInfo {
    /// キャッシュが有効かチェック
    pub fn is_valid(&self) -> bool {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        
        now - self.cached_at < self.ttl_seconds as i64
    }
}

/// Subscription情報
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionInfo {
    /// Subscription ID
    pub subscription_id: String,
    /// フィルター（JSON形式）
    pub filters_json: String,
    /// 作成日時
    pub created_at: i64,
}

/// Subscription経由で受信したイベント
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceivedEvent {
    /// イベントID
    pub event_id: String,
    /// イベントの種類
    pub kind: u64,
    /// イベント作成日時
    pub created_at: i64,
    /// イベント内容（JSON文字列）
    pub event_json: String,
    /// 受信日時
    pub received_at: i64,
    /// Subscription ID
    pub subscription_id: String,
}

/// Nostrクライアントのラッパー
#[derive(Clone)]
pub struct MeisoNostrClient {
    /// 秘密鍵（Amberモードの場合はNone）
    pub(crate) keys: Option<Keys>,
    pub(crate) client: Client,
    /// クライアントモード
    pub(crate) mode: ClientMode,
}

impl MeisoNostrClient {
    /// 新しいクライアントを作成（秘密鍵から）
    pub async fn new(secret_key_hex: &str, relays: Vec<String>) -> Result<Self> {
        Self::new_with_proxy(secret_key_hex, relays, None).await
    }

    /// 新しいクライアントを作成（秘密鍵 + プロキシオプション）
    pub async fn new_with_proxy(
        secret_key_hex: &str, 
        relays: Vec<String>,
        proxy_url: Option<String>,
    ) -> Result<Self> {
        println!("Parsing secret key (format: {})", 
            if secret_key_hex.starts_with("nsec") { "nsec" } else { "hex" });
        
        let keys = Keys::parse(secret_key_hex)
            .map_err(|e| anyhow::anyhow!("秘密鍵のパースに失敗 ({}): {}. フォーマットを確認してください (hex or nsec1...)", 
                if secret_key_hex.starts_with("nsec") { "nsec形式" } else { "hex形式" }, e))?;

        // プロキシ設定（環境変数経由）
        if let Some(ref proxy) = proxy_url {
            println!("🔐 Tor/Proxy経由で接続します: {}", proxy);
            
            // SOCKS5プロキシを環境変数に設定
            // nostr-sdkは内部でこれらの環境変数を使用する可能性がある
            std::env::set_var("all_proxy", proxy);
            std::env::set_var("ALL_PROXY", proxy);
            std::env::set_var("socks_proxy", proxy);
            std::env::set_var("SOCKS_PROXY", proxy);
            
            println!("✅ プロキシ環境変数を設定: {}", proxy);
        }

        let client = Client::new(keys.clone());

        // リレー追加
        for relay_url in &relays {
            println!("Adding relay: {}", relay_url);
            match client.add_relay(relay_url).await {
                Ok(_) => println!("✅ Relay added: {}", relay_url),
                Err(e) => {
                    eprintln!("⚠️ Failed to add relay {}: {}", relay_url, e);
                    // リレー追加失敗は続行（他のリレーで接続を試みる）
                }
            }
        }

        // リレーに接続（タイムアウト付きで待機）
        let timeout_sec = if proxy_url.is_some() { 15 } else { 5 }; // Tor経由は時間がかかる
        println!("Connecting to relays{}...", 
            if proxy_url.is_some() { " (via proxy)" } else { "" });
        
        match tokio::time::timeout(
            std::time::Duration::from_secs(timeout_sec), 
            client.connect()
        ).await {
            Ok(_) => println!("✅ Connected to relays"),
            Err(_) => {
                eprintln!("⚠️ Relay connection timeout ({}s) - continuing offline mode", timeout_sec);
                // タイムアウトしても続行（オフライン対応）
            }
        }

        Ok(Self { 
            keys: Some(keys), 
            client,
            mode: ClientMode::SecretKey,
        })
    }
    
    /// 新しいクライアントを作成（Amberモード - 公開鍵のみ）
    pub async fn new_amber_mode(
        public_key_hex: String,
        relays: Vec<String>,
        proxy_url: Option<String>,
    ) -> Result<Self> {
        println!("🟡 Creating Amber mode client (no secret key)");
        
        // プロキシ設定（環境変数経由）
        if let Some(ref proxy) = proxy_url {
            println!("🔐 Tor/Proxy経由で接続します (Amber mode): {}", proxy);
            
            std::env::set_var("all_proxy", proxy);
            std::env::set_var("ALL_PROXY", proxy);
            std::env::set_var("socks_proxy", proxy);
            std::env::set_var("SOCKS_PROXY", proxy);
            
            println!("✅ プロキシ環境変数を設定 (Amber mode): {}", proxy);
        }
        
        // Amberモードでは秘密鍵なしでクライアントを作成
        // nostr-sdk 0.30以降はPublicKeyだけでClientを作成可能
        let _public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        // Keysをpublic keyだけから作成する方法がないため、
        // ダミーの秘密鍵を生成するが、使わないことを明示
        let dummy_keys = Keys::generate();
        let client = Client::new(dummy_keys);
        
        // リレー追加
        for relay_url in &relays {
            println!("Adding relay: {}", relay_url);
            match client.add_relay(relay_url).await {
                Ok(_) => println!("✅ Relay added: {}", relay_url),
                Err(e) => {
                    eprintln!("⚠️ Failed to add relay {}: {}", relay_url, e);
                }
            }
        }
        
        // リレーに接続（タイムアウト付き）
        let timeout_sec = if proxy_url.is_some() { 20 } else { 10 };
        println!("🔌 Connecting to relays (Amber mode){}...",
            if proxy_url.is_some() { " (via proxy)" } else { "" });
        
        match tokio::time::timeout(
            std::time::Duration::from_secs(timeout_sec), 
            client.connect()
        ).await {
            Ok(_) => println!("✅ Connected to relays (Amber mode)"),
            Err(_) => {
                eprintln!("⚠️ Relay connection timeout ({}s) in Amber mode - continuing anyway", timeout_sec);
            }
        }
        
        Ok(Self {
            keys: None, // Amberモードでは秘密鍵なし
            client,
            mode: ClientMode::Amber { public_key_hex },
        })
    }

    /// 公開鍵を取得（hex形式）
    pub fn public_key_hex(&self) -> String {
        match &self.mode {
            ClientMode::SecretKey => {
                self.keys.as_ref()
                    .expect("SecretKey mode must have keys")
                    .public_key()
                    .to_hex()
            }
            ClientMode::Amber { public_key_hex } => public_key_hex.clone(),
        }
    }

    /// 公開鍵を取得（npub形式）
    pub fn public_key_npub(&self) -> String {
        match &self.mode {
            ClientMode::SecretKey => {
                let pubkey = self.keys.as_ref()
                    .expect("SecretKey mode must have keys")
                    .public_key();
                pubkey.to_bech32().unwrap_or_else(|_| pubkey.to_hex())
            }
            ClientMode::Amber { public_key_hex } => {
                // hex → npub変換
                PublicKey::from_hex(public_key_hex)
                    .ok()
                    .and_then(|pk| pk.to_bech32().ok())
                    .unwrap_or_else(|| public_key_hex.clone())
            }
        }
    }
    
    /// クライアントモードを取得
    pub fn mode(&self) -> &ClientMode {
        &self.mode
    }
    
    /// 秘密鍵が利用可能かチェック
    pub fn has_secret_key(&self) -> bool {
        self.keys.is_some()
    }

    /// イベントをリレーに送信（改善されたエラーハンドリング）
    async fn send_event_with_result(&self, event: Event) -> Result<EventSendResult> {
        let event_id = event.id.to_hex();
        
        match tokio::time::timeout(Duration::from_secs(10), self.client.send_event(event)).await {
            Ok(Ok(send_output)) => {
                // 成功: nostr-sdkのSendEventOutputから情報を取得
                let successful = send_output.success.len();
                let failed = send_output.failed.len();
                
                println!("✅ Event sent: {} successful, {} failed", successful, failed);
                
                Ok(EventSendResult {
                    event_id,
                    success: successful > 0, // 少なくとも1つ成功したら成功扱い
                    successful_relays: successful,
                    failed_relays: failed,
                    timed_out: false,
                    error_message: if failed > 0 {
                        Some(format!("{} relays failed to receive the event", failed))
                    } else {
                        None
                    },
                })
            }
            Ok(Err(e)) => {
                // 送信エラー（全リレー失敗）
                eprintln!("❌ Failed to send event: {}", e);
                Ok(EventSendResult {
                    event_id,
                    success: false,
                    successful_relays: 0,
                    failed_relays: 0, // 不明
                    timed_out: false,
                    error_message: Some(format!("Send failed: {}", e)),
                })
            }
            Err(_) => {
                // タイムアウト
                eprintln!("⏱️ Event send timeout (10s)");
                Ok(EventSendResult {
                    event_id,
                    success: false,
                    successful_relays: 0,
                    failed_relays: 0,
                    timed_out: true,
                    error_message: Some("Timeout after 10 seconds".to_string()),
                })
            }
        }
    }

    /// TodoリストをNostrイベントとして作成（Kind 30001 - NIP-51 Bookmark List）
    /// リストごとに個別のイベントを作成
    pub async fn create_todo_list(&self, todos: Vec<TodoData>) -> Result<EventSendResult> {
        // Amberモードでは暗号化/署名ができないのでエラー
        if let ClientMode::Amber { .. } = self.mode {
            return Err(anyhow::anyhow!(
                "Cannot create TODO list in Amber mode. Use create_unsigned_encrypted_todo_list_event + Amber signing instead."
            ));
        }
        
        let keys = self.keys.as_ref()
            .context("Secret key required for TODO list creation")?;
        
        // Todoをリストごとにグループ化
        let grouped_todos = self.group_todos_by_list(&todos);
        
        println!("📦 Grouped todos into {} lists", grouped_todos.len());
        for (list_id, list_todos) in &grouped_todos {
            println!("  - List '{}': {} todos", list_id, list_todos.len());
        }
        
        let mut last_result: Option<EventSendResult> = None;
        
        // 各リストごとにイベントを作成・送信
        for (list_id, list_todos) in grouped_todos {
            let todos_json = serde_json::to_string(&list_todos)?;

            // NIP-44で自己暗号化
            let public_key = keys.public_key();
            let encrypted_content = nip44::encrypt(
                keys.secret_key(),
                &public_key,
                &todos_json,
                nip44::Version::V2,
            )?;

            // d tag（リスト識別子）
            let d_tag_value = if list_id == "default" {
                "meiso-todos".to_string()
            } else {
                format!("meiso-list-{}", list_id)
            };
            
            // title tag（リスト名）
            let title_value = if list_id == "default" {
                "My TODO List".to_string()
            } else {
                format!("Custom List {}", list_id)
            };
            
            let d_tag = Tag::custom(
                TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
                vec![d_tag_value.clone()],
            );
            
            let title_tag = Tag::custom(
                TagKind::Custom(std::borrow::Cow::Borrowed("title")),
                vec![title_value],
            );

            let event = EventBuilder::new(Kind::Custom(30001), encrypted_content)
                .tags(vec![d_tag, title_tag])
                .sign(keys)
                .await?;

            println!("📤 Sending TODO list event (d='{}', {} todos)", d_tag_value, list_todos.len());
            
            // リレーに送信
            let result = self.send_event_with_result(event).await?;
            last_result = Some(result);
        }
        
        // 最後のイベントの結果を返す（複数リストの場合）
        last_result.ok_or_else(|| anyhow::anyhow!("No lists to send"))
    }
    
    /// Todoをリストごとにグループ化
    fn group_todos_by_list(&self, todos: &[TodoData]) -> std::collections::HashMap<String, Vec<TodoData>> {
        use std::collections::HashMap;
        
        let mut grouped: HashMap<String, Vec<TodoData>> = HashMap::new();
        
        for todo in todos {
            let list_key = todo.custom_list_id.as_deref().unwrap_or("default").to_string();
            grouped.entry(list_key).or_insert_with(Vec::new).push(todo.clone());
        }
        
        grouped
    }


    /// TodoリストをNostrから同期（Kind 30001）
    /// すべてのリスト（デフォルト + カスタムリスト）から取得
    pub async fn sync_todo_list(&self) -> Result<Vec<TodoData>> {
        if let ClientMode::Amber { .. } = self.mode {
            return Err(anyhow::anyhow!(
                "Cannot sync TODO list in Amber mode. Use fetch_encrypted_todo_list_for_pubkey + Amber decryption instead."
            ));
        }
        
        let keys = self.keys.as_ref()
            .context("Secret key required for syncing")?;
        
        // すべてのリスト（meiso-todos および meiso-list-*）を取得
        let filter = Filter::new()
            .kind(Kind::Custom(30001))
            .author(keys.public_key());

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        // EventsをVec<Event>に変換
        let events_vec: Vec<_> = events.into_iter().collect();

        if events_vec.is_empty() {
            println!("⚠️ No TODO lists found");
            return Ok(Vec::new());
        }

        println!("📥 Found {} TODO list events", events_vec.len());
        
        // 同じd tagを持つイベントが複数ある場合、最新のもの（created_atが最大）のみを保持
        use std::collections::HashMap;
        let mut latest_events: HashMap<String, Event> = HashMap::new();
        
        for event in events_vec {
            // d タグを取得してリスト名を確認
            let d_tag = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            println!("🔍 Found event: d_tag={:?}, event_id={}, created_at={}", 
                d_tag, event.id.to_hex(), event.created_at.as_u64());
            
            // meiso-todos または meiso-list-* のみを処理（meiso-settings等は除外）
            if let Some(ref d_value) = d_tag {
                if d_value.starts_with("meiso-todos") || d_value.starts_with("meiso-list-") {
                    // 既存のイベントと比較して、新しい方を保持
                    if let Some(existing_event) = latest_events.get(d_value) {
                        if event.created_at > existing_event.created_at {
                            println!("🔄 Replacing older event for d='{}' (old: {}, new: {})", 
                                d_value, existing_event.created_at.as_u64(), event.created_at.as_u64());
                            latest_events.insert(d_value.clone(), event);
                        } else {
                            println!("⏭️  Skipping older event for d='{}' (keeping: {})", 
                                d_value, existing_event.created_at.as_u64());
                        }
                    } else {
                        println!("✅ Adding TODO list event: d='{}', event_id={}, created_at={}", 
                            d_value, event.id.to_hex(), event.created_at.as_u64());
                        latest_events.insert(d_value.clone(), event);
                    }
                } else {
                    println!("⏭️  Skipping event with d='{}' (not a TODO list)", d_value);
                }
            } else {
                println!("⏭️  Skipping event with no d tag");
            }
        }
        
        println!("📋 After deduplication: {} unique TODO lists", latest_events.len());
        
        let mut all_todos = Vec::new();
        
        // 各リストイベントを復号化してTodoを取得
        for (d_tag, event) in latest_events {
            println!("✅ Processing TODO list event: d='{}', event_id={}, created_at={}", 
                d_tag, event.id.to_hex(), event.created_at.as_u64());

            // NIP-44で復号化
            match nip44::decrypt(
                keys.secret_key(),
                &keys.public_key(),
                &event.content,
            ) {
                Ok(decrypted) => {
                    match serde_json::from_str::<Vec<TodoData>>(&decrypted) {
                        Ok(todos) => {
                            println!("✅ Decrypted {} todos from list {:?}", todos.len(), d_tag);
                            all_todos.extend(todos);
                        }
                        Err(e) => {
                            eprintln!("❌ Failed to parse TODO list JSON from {:?}: {}", d_tag, e);
                            // エラーは無視して次のリストを処理
                        }
                    }
                }
                Err(e) => {
                    eprintln!("❌ Failed to decrypt TODO list {:?}: {}", d_tag, e);
                    // エラーは無視して次のリストを処理
                }
            }
        }
        
        println!("✅ Total todos synced from all lists: {}", all_todos.len());
        Ok(all_todos)
    }


    // ========================================
    // アプリ設定管理（NIP-78 Application-specific data）
    // ========================================

    /// アプリ設定をNostrイベントとして作成（Kind 30078 - NIP-78）
    pub async fn create_app_settings(&self, settings: AppSettings) -> Result<EventSendResult> {
        if let ClientMode::Amber { .. } = self.mode {
            return Err(anyhow::anyhow!("Cannot create app settings in Amber mode"));
        }
        
        let keys = self.keys.as_ref()
            .context("Secret key required")?;
        
        let settings_json = serde_json::to_string(&settings)?;

        // NIP-44で自己暗号化
        let public_key = keys.public_key();
        let encrypted_content = nip44::encrypt(
            keys.secret_key(),
            &public_key,
            &settings_json,
            nip44::Version::V2,
        )?;

        // イベント作成（Kind 30078 - Application-specific data）
        let d_tag = Tag::custom(
            TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
            vec!["meiso-settings".to_string()],
        );

        let event = EventBuilder::new(Kind::Custom(30078), encrypted_content)
            .tags(vec![d_tag])
            .sign(keys)
            .await?;

        // リレーに送信するイベントをJSONとしてログ出力
        match serde_json::to_string_pretty(&event.as_json()) {
            Ok(event_json) => {
                println!("📤 Nostr app settings event (Kind 30078) to relay:");
                println!("{}", event_json);
            }
            Err(e) => {
                eprintln!("⚠️ Failed to serialize event to JSON: {}", e);
            }
        }

        // リレーに送信（改善されたエラーハンドリング）
        self.send_event_with_result(event).await
    }

    /// アプリ設定をNostrから同期（Kind 30078）
    pub async fn sync_app_settings(&self) -> Result<Option<AppSettings>> {
        if let ClientMode::Amber { .. } = self.mode {
            return Err(anyhow::anyhow!("Cannot sync app settings in Amber mode"));
        }
        
        let keys = self.keys.as_ref()
            .context("Secret key required")?;
        
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(keys.public_key())
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::D),
                vec!["meiso-settings".to_string()],
            );

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        // 最新のイベントを取得（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            // NIP-44で復号化
            if let Ok(decrypted) = nip44::decrypt(
                keys.secret_key(),
                &keys.public_key(),
                &event.content,
            ) {
                if let Ok(settings) = serde_json::from_str::<AppSettings>(&decrypted) {
                    println!("✅ App settings synced from Nostr");
                    return Ok(Some(settings));
                }
            }
        }

        println!("⚠️ No app settings found");
        Ok(None)
    }

    /// リレーリストをNostrに保存（NIP-65 Kind 10002 - Relay List Metadata）
    pub async fn save_relay_list(&self, relays: Vec<String>) -> Result<EventSendResult> {
        if let ClientMode::Amber { .. } = self.mode {
            return Err(anyhow::anyhow!("Cannot save relay list in Amber mode"));
        }
        
        let keys = self.keys.as_ref()
            .context("Secret key required")?;
        
        println!("💾 Saving relay list to Nostr (Kind 10002)...");
        
        // NIP-65: リレーをタグとして追加
        let mut tags = Vec::new();
        for relay_url in &relays {
            // "r" タグで各リレーを追加（read/writeの指定も可能だが、今回は両方）
            tags.push(Tag::custom(
                TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::R)),
                vec![relay_url.clone()],
            ));
        }
        
        // Kind 10002イベント作成（contentは空）
        let event = EventBuilder::new(Kind::RelayList, String::new())
            .tags(tags)
            .sign(keys)
            .await?;
        
        // リレーに送信するイベントをJSONとしてログ出力
        match serde_json::to_string_pretty(&event.as_json()) {
            Ok(event_json) => {
                println!("📤 Nostr relay list event (Kind 10002) to relay:");
                println!("{}", event_json);
            }
            Err(e) => {
                eprintln!("⚠️ Failed to serialize event to JSON: {}", e);
            }
        }
        
        // リレーに送信（改善されたエラーハンドリング）
        self.send_event_with_result(event).await
    }

    /// リレーリストをNostrから同期（NIP-65 Kind 10002）
    pub async fn sync_relay_list(&self) -> Result<Vec<String>> {
        println!("🔄 Syncing relay list from Nostr (Kind 10002)...");
        
        // 公開鍵を取得（モードに応じて）
        let pubkey_hex = self.public_key_hex();
        println!("📋 Looking for relay list from pubkey: {}", &pubkey_hex[..16]);
        let pubkey = PublicKey::from_hex(&pubkey_hex)
            .context("Failed to parse public key")?;
        
        let filter = Filter::new()
            .kind(Kind::RelayList)
            .author(pubkey);

        println!("🔍 Fetching Kind 10002 events from relays...");
        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        println!("📥 Received {} Kind 10002 events", events.len());

        // 最新のイベントを取得（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            println!("📝 Processing relay list event ID: {}", event.id.to_hex());
            println!("📋 Event has {} tags", event.tags.len());
            
            let mut relays = Vec::new();
            
            // "r" タグからリレーURLを抽出
            for (i, tag) in event.tags.iter().enumerate() {
                println!("  Tag {}: kind={:?}, content={:?}", i, tag.kind(), tag.content());
                
                // 複数の方法でタグをチェック
                // 方法1: 標準化されたタグとして解析（以前の実装）
                if let Some(tag_std) = tag.as_standardized() {
                    use nostr_sdk::prelude::TagStandard;
                    if matches!(tag_std, TagStandard::Relay(_)) {
                        if let Some(relay_url) = tag.content() {
                            println!("    ✅ Found relay (standardized): {}", relay_url);
                            relays.push(relay_url.to_string());
                            continue;
                        }
                    }
                }
                
                // 方法2: SingleLetterタグとして解析（"r"タグ）
                use nostr_sdk::prelude::{SingleLetterTag, Alphabet};
                if tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::R)) {
                    if let Some(relay_url) = tag.content() {
                        println!("    ✅ Found relay (single letter): {}", relay_url);
                        relays.push(relay_url.to_string());
                    }
                }
            }
            
            println!("✅ Relay list synced: {} relays", relays.len());
            return Ok(relays);
        }

        println!("⚠️ No relay list found (no Kind 10002 events)");
        Ok(Vec::new())
    }

    /// リレーリストを動的に更新（既存の接続を維持しつつ追加・削除）
    pub async fn update_relay_list(&self, new_relays: Vec<String>) -> Result<()> {
        println!("🔄 Updating relay list dynamically...");
        
        // 現在のリレーリストを取得
        let current_relays: Vec<String> = self.client
            .relays()
            .await
            .keys()
            .map(|url| url.to_string())
            .collect();
        
        println!("📋 Current relays: {:?}", current_relays);
        println!("📋 New relays: {:?}", new_relays);
        
        // 削除するリレー（現在のリレーで新しいリストに含まれないもの）
        for relay_url in &current_relays {
            if !new_relays.contains(relay_url) {
                println!("➖ Removing relay: {}", relay_url);
                match self.client.remove_relay(relay_url).await {
                    Ok(_) => println!("✅ Relay removed: {}", relay_url),
                    Err(e) => eprintln!("⚠️ Failed to remove relay {}: {}", relay_url, e),
                }
            }
        }
        
        // 追加するリレー（新しいリストで現在のリレーに含まれないもの）
        for relay_url in &new_relays {
            if !current_relays.contains(relay_url) {
                println!("➕ Adding relay: {}", relay_url);
                match self.client.add_relay(relay_url).await {
                    Ok(_) => {
                        println!("✅ Relay added: {}", relay_url);
                        // 新しいリレーに接続を試みる
                        if let Err(e) = self.client.connect_relay(relay_url).await {
                            eprintln!("⚠️ Failed to connect to relay {}: {}", relay_url, e);
                        }
                    },
                    Err(e) => eprintln!("⚠️ Failed to add relay {}: {}", relay_url, e),
                }
            }
        }
        
        println!("✅ Relay list updated successfully");
        Ok(())
    }
    
    // ========================================
    // Subscription管理機能
    // ========================================
    
    /// Subscriptionを開始（リアルタイム更新を受信）
    pub(crate) async fn subscribe(&self, filters: Vec<Filter>) -> Result<SubscriptionInfo> {
        println!("📡 Starting subscription with {} filters", filters.len());
        
        // Subscriptionを開始
        let subscription_id = self.client.subscribe(filters.clone(), None).await?;
        
        let filters_json = serde_json::to_string(&filters)?;
        let created_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        
        println!("✅ Subscription started: {}", subscription_id.to_string());
        
        Ok(SubscriptionInfo {
            subscription_id: subscription_id.to_string(),
            filters_json,
            created_at,
        })
    }
    
    /// Subscriptionを停止
    pub(crate) async fn unsubscribe(&self, subscription_id: String) -> Result<()> {
        println!("🛑 Stopping subscription: {}", subscription_id);
        
        let sub_id = SubscriptionId::new(subscription_id);
        self.client.unsubscribe(sub_id).await;
        
        println!("✅ Subscription stopped");
        Ok(())
    }
    
    /// すべてのSubscriptionを停止
    pub(crate) async fn unsubscribe_all(&self) -> Result<()> {
        println!("🛑 Stopping all subscriptions");
        self.client.unsubscribe_all().await;
        println!("✅ All subscriptions stopped");
        Ok(())
    }
    
    /// Subscription経由でイベントを受信（1回のポーリング）
    /// タイムアウト付きで新しいイベントを取得
    pub(crate) async fn receive_subscription_events(&self, timeout_ms: u64) -> Result<Vec<ReceivedEvent>> {
        let timeout = Duration::from_millis(timeout_ms);
        
        // Notification channelから受信
        let mut events = Vec::new();
        let mut notifications = self.client.notifications();
        let deadline = tokio::time::Instant::now() + timeout;
        
        loop {
            let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
            if remaining.is_zero() {
                break;
            }
            
            // 通知を受信（タイムアウト付き）
            match tokio::time::timeout(remaining, notifications.recv()).await {
                Ok(Ok(notification)) => {
                    // イベント通知のみ処理
                    if let RelayPoolNotification::Event { event, subscription_id, .. } = notification {
                        let received_at = std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap()
                            .as_secs() as i64;
                        
                        let event_json = serde_json::to_string(&event.as_json())?;
                        
                        events.push(ReceivedEvent {
                            event_id: event.id.to_hex(),
                            kind: event.kind.as_u16() as u64,
                            created_at: event.created_at.as_u64() as i64,
                            event_json,
                            received_at,
                            subscription_id: subscription_id.to_string(),
                        });
                        
                        // イベントを1つ受信したら即座に返す
                        break;
                    }
                    // 他の通知タイプは無視して次を待つ
                }
                Ok(Err(_)) => {
                    // チャンネルエラー
                    break;
                }
                Err(_) => {
                    // タイムアウト
                    break;
                }
            }
        }
        
        if !events.is_empty() {
            println!("📥 Received {} events via subscription", events.len());
        }
        
        Ok(events)
    }
    
    /// リレー接続状態をチェック
    pub(crate) async fn check_connection_status(&self) -> Result<bool> {
        // 接続されているリレー数を確認
        let relays = self.client.relays().await;
        let connected_count = relays.len();
        
        println!("🔌 Connected relays: {}", connected_count);
        Ok(connected_count > 0)
    }
    
    /// リレーに再接続
    pub(crate) async fn reconnect(&self) -> Result<()> {
        println!("🔄 Reconnecting to relays...");
        
        // 一度切断
        self.client.disconnect().await?;
        
        // 再接続（タイムアウト付き）
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
}

// ========================================
// Flutter Rust Bridge API
// ========================================

/// グローバルTokioランタイム（一度だけ作成）
static TOKIO_RUNTIME: once_cell::sync::Lazy<tokio::runtime::Runtime> =
    once_cell::sync::Lazy::new(|| {
        tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime")
    });

/// Nostrクライアントを初期化（hex公開鍵を返す）
/// client_id を指定しない場合はデフォルトクライアントとして保存
pub fn init_nostr_client(secret_key_hex: String, relays: Vec<String>) -> Result<String> {
    init_nostr_client_with_id(DEFAULT_CLIENT_ID.to_string(), secret_key_hex, relays, None)
}

/// Nostrクライアントを初期化（プロキシオプション付き）
pub fn init_nostr_client_with_proxy(
    secret_key_hex: String, 
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    init_nostr_client_with_id(DEFAULT_CLIENT_ID.to_string(), secret_key_hex, relays, proxy_url)
}

/// Nostrクライアントを初期化（client_id指定可能）
pub fn init_nostr_client_with_id(
    client_id: String,
    secret_key_hex: String, 
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    println!("🔧 Initializing Nostr client [{}]{}...", 
        client_id,
        if proxy_url.is_some() { " with proxy" } else { "" });
    println!("Secret key (first 10 chars): {}...", &secret_key_hex[..10.min(secret_key_hex.len())]);
    println!("Relays: {:?}", relays);
    if let Some(ref proxy) = proxy_url {
        println!("Proxy: {}", proxy);
    }

    TOKIO_RUNTIME.block_on(async {
        match MeisoNostrClient::new_with_proxy(&secret_key_hex, relays, proxy_url).await {
            Ok(client) => {
                let public_key = client.public_key_hex();
                println!("✅ Nostr client [{}] initialized. Public key: {}", client_id, &public_key[..16]);

                let mut clients = NOSTR_CLIENTS.lock().await;
                clients.insert(client_id, client);

                Ok(public_key)
            }
            Err(e) => {
                eprintln!("❌ Failed to initialize Nostr client [{}]: {}", client_id, e);
                Err(e)
            }
        }
    })
}

/// クライアントを取得（ヘルパー関数）
async fn get_client(client_id: Option<String>) -> Result<MeisoNostrClient> {
    let id = client_id.unwrap_or_else(|| DEFAULT_CLIENT_ID.to_string());
    let clients = NOSTR_CLIENTS.lock().await;
    clients
        .get(&id)
        .cloned()
        .with_context(|| format!("Nostrクライアント [{}] が初期化されていません", id))
}

/// 公開鍵をnpub形式で取得
pub fn get_public_key_npub() -> Result<String> {
    get_public_key_npub_with_client_id(None)
}

/// 公開鍵をnpub形式で取得（client_id指定可能）
pub fn get_public_key_npub_with_client_id(client_id: Option<String>) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        Ok(client.public_key_npub())
    })
}

/// 新しい秘密鍵を生成（hex形式）
pub fn generate_secret_key() -> String {
    Keys::generate().secret_key().to_secret_hex()
}

/// 鍵ペアを生成（nsec/npub形式で返す）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyPair {
    pub private_key_nsec: String,
    pub public_key_npub: String,
    pub private_key_hex: String,
    pub public_key_hex: String,
}

pub fn generate_keypair() -> Result<KeyPair> {
    let keys = Keys::generate();
    
    let private_key_hex = keys.secret_key().to_secret_hex();
    let public_key_hex = keys.public_key().to_hex();
    
    // nsec形式
    let private_key_nsec = keys.secret_key().to_bech32()
        .map_err(|e| anyhow::anyhow!("Failed to convert private key to nsec format: {}", e))?;
    
    // npub形式
    let public_key_npub = keys.public_key().to_bech32()
        .map_err(|e| anyhow::anyhow!("Failed to convert public key to npub format: {}", e))?;
    
    println!("🔑 Generated new keypair:");
    println!("  Private (nsec): {}...", &private_key_nsec[..20]);
    println!("  Public (npub): {}", &public_key_npub);
    
    Ok(KeyPair {
        private_key_nsec,
        public_key_npub,
        private_key_hex,
        public_key_hex,
    })
}


/// 全Todoを同期（Kind 30001 - 新実装）
pub fn sync_todo_list() -> Result<Vec<TodoData>> {
    sync_todo_list_with_client_id(None)
}

/// 全Todoを同期（client_id指定可能）
pub fn sync_todo_list_with_client_id(client_id: Option<String>) -> Result<Vec<TodoData>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.sync_todo_list().await
    })
}

/// Todoリストを作成（Kind 30001）
pub fn create_todo_list(todos: Vec<TodoData>) -> Result<EventSendResult> {
    create_todo_list_with_client_id(todos, None)
}

/// Todoリストを作成（client_id指定可能）
pub fn create_todo_list_with_client_id(todos: Vec<TodoData>, client_id: Option<String>) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.create_todo_list(todos).await
    })
}


// ========================================
// 鍵管理API (SecureKeyStore)
// ========================================

use crate::key_store::SecureKeyStore;

/// 秘密鍵を暗号化して保存（パスワードベース）
pub fn save_encrypted_secret_key(
    storage_path: String,
    secret_key: String,
    password: String,
) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.save_encrypted_key(&secret_key, &password).await
    })
}

/// 暗号化された秘密鍵を読み込み
pub fn load_encrypted_secret_key(
    storage_path: String,
    password: String,
) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.load_encrypted_key(&password).await
    })
}

/// 公開鍵を保存（Amber使用時）
pub fn save_public_key(
    storage_path: String,
    public_key: String,
) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.save_public_key(&public_key).await
    })
}

/// 公開鍵を読み込み
pub fn load_public_key(
    storage_path: String,
) -> Result<Option<String>> {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.load_public_key().await
    })
}

/// 保存された鍵を削除
pub fn delete_stored_keys(
    storage_path: String,
) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.delete_keys().await
    })
}

/// 暗号化された秘密鍵が存在するか確認
pub fn has_encrypted_key(
    storage_path: String,
) -> bool {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.has_encrypted_key().await
    })
}

/// 公開鍵が存在するか確認
pub fn has_public_key(
    storage_path: String,
) -> bool {
    TOKIO_RUNTIME.block_on(async {
        let store = SecureKeyStore::new(storage_path);
        store.has_public_key().await
    })
}

// ========================================
// Amber連携API
// ========================================

/// Amberから受け取った署名済みイベントを検証
pub fn verify_amber_signature(event_json: String) -> Result<bool> {
    let event: Event = serde_json::from_str(&event_json)
        .context("Failed to parse event JSON")?;
    
    match event.verify() {
        Ok(_) => {
            println!("✅ Amber signature verified successfully");
            Ok(true)
        }
        Err(e) => {
            eprintln!("❌ Amber signature verification failed: {}", e);
            Ok(false)
        }
    }
}

/// 公開鍵のみでNostrクライアントを初期化（Amber使用時）
/// 署名が必要な操作はAmber経由で行う
pub fn init_nostr_client_with_pubkey(
    public_key_hex: String,
    relays: Vec<String>,
) -> Result<String> {
    init_nostr_client_with_pubkey_and_id(DEFAULT_CLIENT_ID.to_string(), public_key_hex, relays, None)
}

/// Amberモードで初期化（プロキシオプション付き）
pub fn init_nostr_client_with_pubkey_and_proxy(
    public_key_hex: String,
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    init_nostr_client_with_pubkey_and_id(DEFAULT_CLIENT_ID.to_string(), public_key_hex, relays, proxy_url)
}

/// Amberモードで初期化（client_id指定可能）
pub fn init_nostr_client_with_pubkey_and_id(
    client_id: String,
    public_key_hex: String,
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    println!("🔧 Initializing Nostr client [{}] with public key only (Amber mode){}...",
        client_id,
        if proxy_url.is_some() { " with proxy" } else { "" });
    println!("Public key: {}...", &public_key_hex[..16.min(public_key_hex.len())]);
    println!("Relays: {:?}", relays);
    if let Some(ref proxy) = proxy_url {
        println!("Proxy: {}", proxy);
    }
    
    TOKIO_RUNTIME.block_on(async {
        match MeisoNostrClient::new_amber_mode(public_key_hex.clone(), relays, proxy_url).await {
            Ok(client) => {
                println!("✅ Nostr client [{}] initialized in Amber mode", client_id);
                
                let mut clients = NOSTR_CLIENTS.lock().await;
                clients.insert(client_id, client);
                
                Ok(public_key_hex)
            }
            Err(e) => {
                eprintln!("❌ Failed to initialize Nostr client [{}] in Amber mode: {}", client_id, e);
                Err(e)
            }
        }
    })
}


/// 署名済みイベントをリレーに送信
pub fn send_signed_event(event_json: String) -> Result<EventSendResult> {
    send_signed_event_with_client_id(event_json, None)
}

/// 署名済みイベントをリレーに送信（client_id指定可能）
pub fn send_signed_event_with_client_id(event_json: String, client_id: Option<String>) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // イベントをパース
        let event: Event = serde_json::from_str(&event_json)
            .context("Failed to parse signed event JSON")?;
        
        // 署名を検証
        event.verify().context("Invalid event signature")?;
        
        println!("📤 Sending signed event to relays...");
        println!("🔍 Event kind: {}", event.kind);
        println!("🔍 Event ID: {}", event.id.to_hex());
        println!("🔍 Event pubkey: {}...", &event.pubkey.to_hex()[..16]);
        
        // リレーに送信（改善されたエラーハンドリング）
        client.send_event_with_result(event).await
    })
}

/// 暗号化済みcontentで未署名Todoリストイベントを作成（Kind 30001 - Amber暗号化済み用）
/// 
/// # Parameters
/// - `encrypted_content`: Amber暗号化済みのTodoリストJSON
/// - `public_key_hex`: 公開鍵（hex形式）
/// - `list_id`: リスト識別子（None = デフォルトリスト、Some(id) = カスタムリスト）
/// - `list_title`: リストのタイトル（None = デフォルトタイトル使用）
pub fn create_unsigned_encrypted_todo_list_event_with_list_id(
    encrypted_content: String,
    public_key_hex: String,
    list_id: Option<String>,
    list_title: Option<String>,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // 現在のタイムスタンプ
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // d tag（リスト識別子）
    let d_tag_value = if let Some(id) = list_id {
        format!("meiso-list-{}", id)
    } else {
        "meiso-todos".to_string()
    };
    
    // title tag（リスト名）
    let title_value = list_title.unwrap_or_else(|| "My TODO List".to_string());
    
    // Kind 30001のタグ
    let tags = vec![
        vec!["d".to_string(), d_tag_value.clone()],
        vec!["title".to_string(), title_value],
    ];
    
    // 未署名イベントJSON（Amber用）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 30001,
        "tags": tags,
        "content": encrypted_content,
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📝 Created unsigned encrypted TODO list event (d='{}') for Amber signing", d_tag_value);
    Ok(event_json)
}

/// 暗号化済みcontentで未署名Todoリストイベントを作成（Kind 30001 - Amber暗号化済み用）
/// デフォルトリスト用の互換性関数
pub fn create_unsigned_encrypted_todo_list_event(
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String> {
    create_unsigned_encrypted_todo_list_event_with_list_id(
        encrypted_content,
        public_key_hex,
        None,  // デフォルトリスト
        None,  // デフォルトタイトル
    )
}

/// 暗号化済みcontentで未署名Todoイベントを作成（Amber暗号化済み用 - 旧実装）
pub fn create_unsigned_encrypted_todo_event(
    todo_id: String,
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // 現在のタイムスタンプ
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // dタグを追加
    let tags = vec![
        vec!["d".to_string(), format!("todo-{}", todo_id)]
    ];
    
    // 未署名イベントJSON（Amber用）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 30078,
        "tags": tags,
        "content": encrypted_content,
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📝 Created unsigned encrypted event for Amber signing");
    Ok(event_json)
}

/// 暗号化されたTodoリストイベントを取得（Amber復号化用 - Kind 30001）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedTodoListEvent {
    pub event_id: String,
    pub encrypted_content: String,
    pub created_at: i64,
    /// リスト識別子（d tag）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub list_id: Option<String>,
    /// リスト名（title tag）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
}

/// Todoリストのメタデータ（通常モード用 - Kind 30001）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodoListMetadata {
    pub event_id: String,
    pub created_at: i64,
    /// リスト識別子（d tag）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub list_id: Option<String>,
    /// リスト名（title tag）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
}

/// すべてのTodoリスト（デフォルト + カスタムリスト）を取得
pub fn fetch_all_encrypted_todo_lists_for_pubkey(
    public_key_hex: String,
) -> Result<Vec<EncryptedTodoListEvent>> {
    fetch_all_encrypted_todo_lists_for_pubkey_with_client_id(public_key_hex, None)
}

pub fn fetch_all_encrypted_todo_lists_for_pubkey_with_client_id(
    public_key_hex: String,
    client_id: Option<String>,
) -> Result<Vec<EncryptedTodoListEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 公開鍵をパース
        let public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        // すべてのKind 30001イベントを取得（meiso-todos + meiso-list-*）
        let filter = Filter::new()
            .kind(Kind::Custom(30001))
            .author(public_key);
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        if events.is_empty() {
            println!("⚠️ No encrypted TODO list events found");
            return Ok(Vec::new());
        }
        
        println!("📥 Found {} encrypted TODO list events", events.len());
        
        // 同じd tagを持つイベントが複数ある場合、最新のもの（created_atが最大）のみを保持
        use std::collections::HashMap;
        let mut latest_events: HashMap<String, Event> = HashMap::new();
        
        for event in events {
            // d タグを取得
            let d_tag = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            println!("🔍 Found event: d_tag={:?}, event_id={}, created_at={}", 
                d_tag, event.id.to_hex(), event.created_at.as_u64());
            
            // meiso-todos または meiso-list-* のみを処理（meiso-settings等は除外）
            if let Some(ref d_value) = d_tag {
                if d_value.starts_with("meiso-todos") || d_value.starts_with("meiso-list-") {
                    // 既存のイベントと比較して、新しい方を保持
                    if let Some(existing_event) = latest_events.get(d_value) {
                        if event.created_at > existing_event.created_at {
                            println!("🔄 Replacing older event for d='{}' (old: {}, new: {})", 
                                d_value, existing_event.created_at.as_u64(), event.created_at.as_u64());
                            latest_events.insert(d_value.clone(), event);
                        } else {
                            println!("⏭️  Skipping older event for d='{}' (keeping: {})", 
                                d_value, existing_event.created_at.as_u64());
                        }
                    } else {
                        println!("✅ Adding TODO list event: d='{}', event_id={}, created_at={}", 
                            d_value, event.id.to_hex(), event.created_at.as_u64());
                        latest_events.insert(d_value.clone(), event);
                    }
                } else {
                    println!("⏭️  Skipping event with d='{}' (not a TODO list)", d_value);
                }
            } else {
                println!("⏭️  Skipping event with no d tag");
            }
        }
        
        println!("📋 After deduplication: {} unique TODO lists", latest_events.len());
        
        // 最新のイベントのみを返す
        let list_events: Vec<EncryptedTodoListEvent> = latest_events.into_iter()
            .map(|(d_tag, event)| {
                // title タグを取得
                let title = event.tags.iter()
                    .find(|tag| tag.kind() == TagKind::Custom(std::borrow::Cow::Borrowed("title")))
                    .and_then(|tag| tag.content())
                    .map(|s| s.to_string());
                
                println!("📤 Final event: d='{}', title={:?}, event_id={}, created_at={}", 
                    d_tag, title, event.id.to_hex(), event.created_at.as_u64());
                    
                EncryptedTodoListEvent {
                    event_id: event.id.to_hex(),
                    encrypted_content: event.content.clone(),
                    created_at: event.created_at.as_u64() as i64,
                    list_id: Some(d_tag),
                    title,
                }
            })
            .collect();
        
        println!("✅ Fetched {} TODO list events for decryption", list_events.len());
        Ok(list_events)
    })
}

/// すべてのTodoリストのメタデータ（d tag, title）を取得（通常モード用）
pub fn fetch_all_todo_list_metadata() -> Result<Vec<TodoListMetadata>> {
    fetch_all_todo_list_metadata_with_client_id(None)
}

pub fn fetch_all_todo_list_metadata_with_client_id(
    client_id: Option<String>,
) -> Result<Vec<TodoListMetadata>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 秘密鍵モードのみサポート（Amberモードでは使用しない）
        let keys = client.keys.as_ref()
            .context("Secret key required for fetching metadata")?;
        
        // すべてのKind 30001イベントを取得（meiso-todos + meiso-list-*）
        let filter = Filter::new()
            .kind(Kind::Custom(30001))
            .author(keys.public_key());
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        if events.is_empty() {
            println!("⚠️ No TODO list events found");
            return Ok(Vec::new());
        }
        
        println!("📥 Found {} TODO list events", events.len());
        
        // 同じd tagを持つイベントが複数ある場合、最新のもの（created_atが最大）のみを保持
        use std::collections::HashMap;
        let mut latest_events: HashMap<String, Event> = HashMap::new();
        
        for event in events {
            // d タグを取得
            let d_tag = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            println!("🔍 Found event: d_tag={:?}, event_id={}, created_at={}", 
                d_tag, event.id.to_hex(), event.created_at.as_u64());
            
            // meiso-todos または meiso-list-* のみを処理（meiso-settings等は除外）
            if let Some(ref d_value) = d_tag {
                if d_value.starts_with("meiso-todos") || d_value.starts_with("meiso-list-") {
                    // 既存のイベントと比較して、新しい方を保持
                    if let Some(existing_event) = latest_events.get(d_value) {
                        if event.created_at > existing_event.created_at {
                            println!("🔄 Replacing older event for d='{}' (old: {}, new: {})", 
                                d_value, existing_event.created_at.as_u64(), event.created_at.as_u64());
                            latest_events.insert(d_value.clone(), event);
                        } else {
                            println!("⏭️  Skipping older event for d='{}' (keeping: {})", 
                                d_value, existing_event.created_at.as_u64());
                        }
                    } else {
                        println!("✅ Adding TODO list event: d='{}', event_id={}, created_at={}", 
                            d_value, event.id.to_hex(), event.created_at.as_u64());
                        latest_events.insert(d_value.clone(), event);
                    }
                } else {
                    println!("⏭️  Skipping event with d='{}' (not a TODO list)", d_value);
                }
            } else {
                println!("⏭️  Skipping event with no d tag");
            }
        }
        
        println!("📋 After deduplication: {} unique TODO lists", latest_events.len());
        
        // メタデータのみを返す
        let metadata_list: Vec<TodoListMetadata> = latest_events.into_iter()
            .map(|(d_tag, event)| {
                // title タグを取得
                let title = event.tags.iter()
                    .find(|tag| tag.kind() == TagKind::Custom(std::borrow::Cow::Borrowed("title")))
                    .and_then(|tag| tag.content())
                    .map(|s| s.to_string());
                
                println!("📤 Metadata: d='{}', title={:?}, event_id={}, created_at={}", 
                    d_tag, title, event.id.to_hex(), event.created_at.as_u64());
                    
                TodoListMetadata {
                    event_id: event.id.to_hex(),
                    created_at: event.created_at.as_u64() as i64,
                    list_id: Some(d_tag),
                    title,
                }
            })
            .collect();
        
        println!("✅ Fetched {} TODO list metadata", metadata_list.len());
        Ok(metadata_list)
    })
}

/// デフォルトTodoリスト（meiso-todos）のみを取得（互換性のため残す）
pub fn fetch_encrypted_todo_list_for_pubkey(
    public_key_hex: String,
) -> Result<Option<EncryptedTodoListEvent>> {
    fetch_encrypted_todo_list_for_pubkey_with_client_id(public_key_hex, None)
}

pub fn fetch_encrypted_todo_list_for_pubkey_with_client_id(
    public_key_hex: String,
    client_id: Option<String>,
) -> Result<Option<EncryptedTodoListEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 公開鍵をパース
        let public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        let filter = Filter::new()
            .kind(Kind::Custom(30001))
            .author(public_key)
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::D),
                vec!["meiso-todos".to_string()],
            );
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        // 最新のイベント（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            println!("📥 Fetched encrypted TODO list event (default list only)");
            Ok(Some(EncryptedTodoListEvent {
                event_id: event.id.to_hex(),
                encrypted_content: event.content.clone(),
                created_at: event.created_at.as_u64() as i64,
                list_id: Some("meiso-todos".to_string()),
                title: Some("My TODO List".to_string()),
            }))
        } else {
            println!("⚠️ No encrypted TODO list event found (default list)");
            Ok(None)
        }
    })
}

/// 公開鍵だけで暗号化されたTodoイベントを取得（Amber復号化用 - 旧実装 Kind 30078）
/// 復号化はAmber側で行うため、暗号化されたままのイベントを返す
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedTodoEvent {
    pub event_id: String,
    pub encrypted_content: String,
    pub created_at: i64,
    pub d_tag: String,
}

pub fn fetch_encrypted_todos_for_pubkey(
    public_key_hex: String,
) -> Result<Vec<EncryptedTodoEvent>> {
    fetch_encrypted_todos_for_pubkey_with_client_id(public_key_hex, None)
}

pub fn fetch_encrypted_todos_for_pubkey_with_client_id(
    public_key_hex: String,
    client_id: Option<String>,
) -> Result<Vec<EncryptedTodoEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 公開鍵をパース
        let public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(public_key);
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        let mut encrypted_todos = Vec::new();
        
        for event in events {
            // dタグを取得
            let d_tag = event
                .tags
                .iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .unwrap_or("")
                .to_string();
            
            // `todo-`で始まるdタグのイベントはスキップ
            if d_tag.starts_with("todo-") {
                println!("⏭️  Skipping Kind 30078 event with d tag starting with 'todo-': {}", event.id.to_hex());
                continue;
            }
            
            encrypted_todos.push(EncryptedTodoEvent {
                event_id: event.id.to_hex(),
                encrypted_content: event.content.clone(),
                created_at: event.created_at.as_u64() as i64,
                d_tag,
            });
        }
        
        println!("📥 Fetched {} encrypted todo events (after filtering)", encrypted_todos.len());
        Ok(encrypted_todos)
    })
}

/// npub形式の公開鍵をhex形式に変換
pub fn npub_to_hex(npub: String) -> Result<String> {
    // npub形式でない場合（すでにhex形式の可能性）
    if !npub.starts_with("npub1") {
        // 64文字のhex文字列かチェック
        if npub.len() == 64 && npub.chars().all(|c| c.is_ascii_hexdigit()) {
            return Ok(npub); // すでにhex形式
        }
        return Err(anyhow::anyhow!("Invalid public key format: expected npub1... or 64-char hex, got: {}", &npub[..10.min(npub.len())]));
    }
    
    let public_key = PublicKey::parse(&npub)
        .context("Failed to parse npub format public key")?;
    
    Ok(public_key.to_hex())
}

/// hex形式の公開鍵をnpub形式に変換
pub fn hex_to_npub(hex: String) -> Result<String> {
    // すでにnpub形式の場合
    if hex.starts_with("npub1") {
        return Ok(hex);
    }
    
    let public_key = PublicKey::from_hex(&hex)
        .context("Failed to parse hex format public key")?;
    
    Ok(public_key.to_bech32()?)
}

// ========================================
// アプリ設定管理API（NIP-78）
// ========================================

/// アプリ設定を保存（Kind 30078 - Application-specific data）
pub fn save_app_settings(settings: AppSettings) -> Result<EventSendResult> {
    save_app_settings_with_client_id(settings, None)
}

/// アプリ設定を保存（client_id指定可能）
pub fn save_app_settings_with_client_id(settings: AppSettings, client_id: Option<String>) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.create_app_settings(settings).await
    })
}

/// アプリ設定を同期（Kind 30078）
pub fn sync_app_settings() -> Result<Option<AppSettings>> {
    sync_app_settings_with_client_id(None)
}

/// アプリ設定を同期（client_id指定可能）
pub fn sync_app_settings_with_client_id(client_id: Option<String>) -> Result<Option<AppSettings>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.sync_app_settings().await
    })
}

/// 暗号化済みcontentで未署名アプリ設定イベントを作成（Amber暗号化済み用）
pub fn create_unsigned_encrypted_app_settings_event(
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // 現在のタイムスタンプ
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // Kind 30078のタグ（アプリ設定用）
    let tags = vec![
        vec!["d".to_string(), "meiso-settings".to_string()],
    ];
    
    // 未署名イベントJSON（Amber用）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 30078,
        "tags": tags,
        "content": encrypted_content,
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📝 Created unsigned encrypted app settings event (Kind 30078) for Amber signing");
    Ok(event_json)
}

/// 未署名リレーリストイベントを作成（Amber署名用 - NIP-65 Kind 10002）
pub fn create_unsigned_relay_list_event(
    relays: Vec<String>,
    public_key_hex: String,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // 現在のタイムスタンプ
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // NIP-65: リレーをタグとして追加
    let mut tags = Vec::new();
    for relay_url in &relays {
        // "r" タグで各リレーを追加（read/writeの指定も可能だが、今回は両方）
        tags.push(vec!["r".to_string(), relay_url.clone()]);
    }
    
    // 未署名イベントJSON（Amber用）
    // contentは空文字列（NIP-65では不要）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 10002,
        "tags": tags,
        "content": "",
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📝 Created unsigned relay list event (Kind 10002) for Amber signing");
    Ok(event_json)
}

/// 暗号化されたアプリ設定イベントを取得（Amber復号化用）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedAppSettingsEvent {
    pub event_id: String,
    pub encrypted_content: String,
    pub created_at: i64,
}

pub fn fetch_encrypted_app_settings_for_pubkey(
    public_key_hex: String,
) -> Result<Option<EncryptedAppSettingsEvent>> {
    fetch_encrypted_app_settings_for_pubkey_with_client_id(public_key_hex, None)
}

pub fn fetch_encrypted_app_settings_for_pubkey_with_client_id(
    public_key_hex: String,
    client_id: Option<String>,
) -> Result<Option<EncryptedAppSettingsEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 公開鍵をパース
        let public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(public_key)
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::D),
                vec!["meiso-settings".to_string()],
            );
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        // 最新のイベント（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            println!("📥 Fetched encrypted app settings event");
            Ok(Some(EncryptedAppSettingsEvent {
                event_id: event.id.to_hex(),
                encrypted_content: event.content.clone(),
                created_at: event.created_at.as_u64() as i64,
            }))
        } else {
            println!("⚠️ No encrypted app settings event found");
            Ok(None)
        }
    })
}

// ========================================
// リレーリスト管理API（NIP-65 Kind 10002）
// ========================================

/// リレーリストをNostrに保存（Kind 10002 - Relay List Metadata）
pub fn save_relay_list(relays: Vec<String>) -> Result<EventSendResult> {
    save_relay_list_with_client_id(relays, None)
}

/// リレーリストをNostrに保存（client_id指定可能）
pub fn save_relay_list_with_client_id(relays: Vec<String>, client_id: Option<String>) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.save_relay_list(relays).await
    })
}

/// リレーリストをNostrから同期（Kind 10002）
pub fn sync_relay_list() -> Result<Vec<String>> {
    sync_relay_list_with_client_id(None)
}

/// リレーリストをNostrから同期（client_id指定可能）
pub fn sync_relay_list_with_client_id(client_id: Option<String>) -> Result<Vec<String>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.sync_relay_list().await
    })
}

/// リレーリストを動的に更新（リアルタイム反映）
pub fn update_relay_list(relays: Vec<String>) -> Result<()> {
    update_relay_list_with_client_id(relays, None)
}

/// リレーリストを動的に更新（client_id指定可能）
pub fn update_relay_list_with_client_id(relays: Vec<String>, client_id: Option<String>) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.update_relay_list(relays).await
    })
}

// ========================================
// マイグレーション関連API
// ========================================

/// 指定したイベントIDのリストを削除（Kind 5削除イベントを送信）
pub fn delete_events(
    event_ids: Vec<String>,
    reason: Option<String>,
) -> Result<EventSendResult> {
    delete_events_with_client_id(event_ids, reason, None)
}

/// イベント削除（client_id指定可能）
pub fn delete_events_with_client_id(
    event_ids: Vec<String>,
    reason: Option<String>,
    client_id: Option<String>,
) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        if event_ids.is_empty() {
            return Err(anyhow::anyhow!("削除するイベントIDが指定されていません"));
        }
        
        println!("🗑️ Deleting {} events...", event_ids.len());
        
        // イベントIDをEventIdに変換
        let mut event_id_objects = Vec::new();
        for id_str in &event_ids {
            match EventId::from_hex(id_str) {
                Ok(event_id) => event_id_objects.push(event_id),
                Err(e) => {
                    eprintln!("⚠️ Invalid event ID {}: {}", id_str, e);
                    continue;
                }
            }
        }
        
        if event_id_objects.is_empty() {
            return Err(anyhow::anyhow!("有効なイベントIDがありません"));
        }
        
        if let ClientMode::Amber { .. } = client.mode {
            return Err(anyhow::anyhow!("Cannot delete events in Amber mode"));
        }
        
        let keys = client.keys.as_ref()
            .context("Secret key required for deletion")?;
        
        // Kind 5削除イベントを作成
        let content = reason.unwrap_or_default();
        
        // イベントIDを'e'タグとして追加
        let tags: Vec<Tag> = event_id_objects
            .iter()
            .map(|id| Tag::event(*id))
            .collect();
        
        let event = EventBuilder::new(Kind::EventDeletion, content)
            .tags(tags)
            .sign(keys)
            .await?;
        
        println!("📤 Sending Kind 5 deletion event...");
        
        // リレーに送信（改善されたエラーハンドリング）
        client.send_event_with_result(event).await
    })
}

// ========================================
// Subscription & キャッシュ関連API
// ========================================

/// Subscriptionを開始（Todo/設定などのリアルタイム更新）
pub fn start_subscription(filters_json: String) -> Result<SubscriptionInfo> {
    start_subscription_with_client_id(filters_json, None)
}

/// Subscriptionを開始（client_id指定可能）
pub fn start_subscription_with_client_id(
    filters_json: String,
    client_id: Option<String>,
) -> Result<SubscriptionInfo> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // JSON文字列からFilterのリストをパース
        let filters: Vec<Filter> = serde_json::from_str(&filters_json)
            .context("Failed to parse filters JSON")?;
        
        client.subscribe(filters).await
    })
}

/// Subscriptionを停止
pub fn stop_subscription(subscription_id: String) -> Result<()> {
    stop_subscription_with_client_id(subscription_id, None)
}

/// Subscriptionを停止（client_id指定可能）
pub fn stop_subscription_with_client_id(
    subscription_id: String,
    client_id: Option<String>,
) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.unsubscribe(subscription_id).await
    })
}

/// すべてのSubscriptionを停止
pub fn stop_all_subscriptions() -> Result<()> {
    stop_all_subscriptions_with_client_id(None)
}

/// すべてのSubscriptionを停止（client_id指定可能）
pub fn stop_all_subscriptions_with_client_id(client_id: Option<String>) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.unsubscribe_all().await
    })
}

/// Subscription経由でイベントを受信
/// timeout_ms: タイムアウト（ミリ秒）
pub fn receive_subscription_events(timeout_ms: u64) -> Result<Vec<ReceivedEvent>> {
    receive_subscription_events_with_client_id(timeout_ms, None)
}

/// Subscription経由でイベントを受信（client_id指定可能）
pub fn receive_subscription_events_with_client_id(
    timeout_ms: u64,
    client_id: Option<String>,
) -> Result<Vec<ReceivedEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.receive_subscription_events(timeout_ms).await
    })
}

/// リレー接続状態をチェック
pub fn check_connection_status() -> Result<bool> {
    check_connection_status_with_client_id(None)
}

/// リレー接続状態をチェック（client_id指定可能）
pub fn check_connection_status_with_client_id(client_id: Option<String>) -> Result<bool> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.check_connection_status().await
    })
}

/// リレーに再接続
pub fn reconnect_to_relays() -> Result<()> {
    reconnect_to_relays_with_client_id(None)
}

/// リレーに再接続（client_id指定可能）
pub fn reconnect_to_relays_with_client_id(client_id: Option<String>) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        client.reconnect().await
    })
}

/// イベントJSONからキャッシュ情報を作成（Event型を使わずに）
pub fn create_cache_info(
    event_json: String,
    ttl_seconds: u64,
) -> Result<CachedEventInfo> {
    // JSONからイベント情報を抽出（nostr-sdkの Event型を経由せずに）
    let json_value: serde_json::Value = serde_json::from_str(&event_json)
        .context("Failed to parse event JSON")?;
    
    let event_id = json_value["id"]
        .as_str()
        .context("Missing or invalid event id")?
        .to_string();
    
    let kind = json_value["kind"]
        .as_u64()
        .context("Missing or invalid event kind")?;
    
    let created_at = json_value["created_at"]
        .as_i64()
        .context("Missing or invalid created_at")?;
    
    // d-tagを取得（あれば）
    let d_tag = json_value["tags"]
        .as_array()
        .and_then(|tags| {
            tags.iter().find_map(|tag| {
                let tag_array = tag.as_array()?;
                if tag_array.len() >= 2 && tag_array[0].as_str()? == "d" {
                    Some(tag_array[1].as_str()?.to_string())
                } else {
                    None
                }
            })
        });
    
    let cached_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    
    Ok(CachedEventInfo {
        event_id,
        kind,
        created_at,
        event_json,
        cached_at,
        ttl_seconds,
        d_tag,
    })
}

/// キャッシュが有効かチェック
pub fn is_cache_valid(cache_info: CachedEventInfo) -> bool {
    cache_info.is_valid()
}

// ========================================
// グループタスク管理API（マルチパーティ暗号化）
// ========================================

use crate::group_tasks::{GroupTodoList, GroupTodoData};

/// グループタスクリストを暗号化（マルチパーティ暗号化）
/// 
/// # Parameters
/// - `tasks`: グループタスクのリスト
/// - `group_id`: グループID（UUID）
/// - `group_name`: グループ名
/// - `member_pubkeys`: メンバーの公開鍵リスト（hex形式）
pub fn encrypt_group_task_list(
    tasks: Vec<GroupTodoData>,
    group_id: String,
    group_name: String,
    member_pubkeys: Vec<String>,
) -> Result<GroupTodoList> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート（Amberモードでは未対応）
        let keys = client.keys.as_ref()
            .context("Secret key required for group task encryption")?;
        
        crate::group_tasks::encrypt_group_tasks(
            tasks,
            group_id,
            group_name,
            member_pubkeys,
            keys,
        )
    })
}

/// グループタスクリストを復号化
/// 
/// # Parameters
/// - `group_list`: 暗号化されたグループタスクリスト
pub fn decrypt_group_task_list(
    group_list: GroupTodoList,
) -> Result<Vec<GroupTodoData>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート（Amberモードでは未対応）
        let keys = client.keys.as_ref()
            .context("Secret key required for group task decryption")?;
        
        crate::group_tasks::decrypt_group_tasks(
            &group_list,
            keys,
        )
    })
}

/// グループにメンバーを追加
/// 
/// # Parameters
/// - `group_list`: 既存のグループタスクリスト
/// - `new_member_pubkey`: 追加するメンバーの公開鍵（hex形式）
pub fn add_member_to_group_task_list(
    mut group_list: GroupTodoList,
    new_member_pubkey: String,
) -> Result<GroupTodoList> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート
        let keys = client.keys.as_ref()
            .context("Secret key required for adding member")?;
        
        crate::group_tasks::add_member_to_group(
            &mut group_list,
            new_member_pubkey,
            keys,
        )?;
        
        Ok(group_list)
    })
}

/// グループからメンバーを削除（Forward Secrecy: 全体を再暗号化）
/// 
/// # Parameters
/// - `group_list`: 既存のグループタスクリスト
/// - `member_to_remove`: 削除するメンバーの公開鍵（hex形式）
pub fn remove_member_from_group_task_list(
    group_list: GroupTodoList,
    member_to_remove: String,
) -> Result<GroupTodoList> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート
        let keys = client.keys.as_ref()
            .context("Secret key required for removing member")?;
        
        crate::group_tasks::remove_member_from_group(
            &group_list,
            member_to_remove,
            keys,
        )
    })
}

/// グループタスクリストをNostrに保存（Kind 30001 - NIP-51）
/// 
/// # Parameters
/// - `group_list`: 暗号化されたグループタスクリスト
pub fn save_group_task_list_to_nostr(
    group_list: GroupTodoList,
) -> Result<EventSendResult> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート
        let keys = client.keys.as_ref()
            .context("Secret key required for saving group task list")?;
        
        // GroupTodoListをJSON文字列に変換
        let group_list_json = serde_json::to_string(&group_list)?;
        
        // NIP-44で自己暗号化（グループメタデータのみ）
        let public_key = keys.public_key();
        let encrypted_content = nip44::encrypt(
            keys.secret_key(),
            &public_key,
            &group_list_json,
            nip44::Version::V2,
        )?;
        
        // d tag（グループ識別子）
        let d_tag_value = format!("meiso-group-{}", group_list.group_id);
        
        let d_tag = Tag::custom(
            TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
            vec![d_tag_value.clone()],
        );
        
        let title_tag = Tag::custom(
            TagKind::Custom(std::borrow::Cow::Borrowed("title")),
            vec![group_list.group_name.clone()],
        );
        
        // メンバーをpタグで追加（検索可能にする - NIP-01標準）
        let mut tags = vec![d_tag, title_tag];
        for member_pubkey in &group_list.members {
            tags.push(Tag::public_key(
                nostr_sdk::PublicKey::from_hex(member_pubkey)
                    .map_err(|e| anyhow::anyhow!("Invalid member pubkey: {}", e))?,
            ));
        }
        
        let event = EventBuilder::new(Kind::Custom(30001), encrypted_content)
            .tags(tags)
            .sign(keys)
            .await?;
        
        println!("📤 Sending group task list event (d='{}', {} members)", d_tag_value, group_list.members.len());
        
        // リレーに送信
        client.send_event_with_result(event).await
    })
}

/// グループタスクリストの未署名イベントを作成（Amberモード用）
/// 
/// GroupTodoListを受け取り、暗号化済みcontentで未署名イベントJSONを作成
/// 
/// # Arguments
/// * `group_list_json` - GroupTodoListのJSON文字列（暗号化前）
/// * `encrypted_content` - Amberで暗号化済みのcontent
/// * `public_key_hex` - 作成者の公開鍵（hex）
/// 
/// # Returns
/// 未署名イベントのJSON文字列
pub fn create_unsigned_group_task_list_event(
    group_list_json: String,
    encrypted_content: String,
    public_key_hex: String,
) -> Result<String> {
    // GroupTodoListをパース
    let group_list: GroupTodoList = serde_json::from_str(&group_list_json)
        .context("Failed to parse GroupTodoList JSON")?;
    
    // d tag（グループ識別子）
    let d_tag_value = format!("meiso-group-{}", group_list.group_id);
    
    let d_tag = Tag::custom(
        TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
        vec![d_tag_value.clone()],
    );
    
    let title_tag = Tag::custom(
        TagKind::Custom(std::borrow::Cow::Borrowed("title")),
        vec![group_list.group_name.clone()],
    );
    
    // メンバーをpタグで追加（検索可能にする）
    let mut tags = vec![d_tag, title_tag];
    for member_pubkey in &group_list.members {
        tags.push(Tag::public_key(
            nostr_sdk::PublicKey::from_hex(member_pubkey)
                .map_err(|e| anyhow::anyhow!("Invalid member pubkey: {}", e))?,
        ));
    }
    
    // 未署名イベントを手動構築
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    
    // タグをJSON配列に変換
    let tags_json: Vec<Vec<String>> = tags.iter().map(|tag| {
        tag.clone().to_vec().iter().map(|s| s.to_string()).collect()
    }).collect();
    
    // 未署名イベントのJSON構造を作成
    let unsigned_event = serde_json::json!({
        "pubkey": public_key_hex,
        "created_at": now,
        "kind": 30001,
        "tags": tags_json,
        "content": encrypted_content,
    });
    
    // JSON文字列に変換
    let unsigned_event_json = serde_json::to_string(&unsigned_event)
        .context("Failed to serialize unsigned event")?;
    
    println!("📝 Created unsigned group task list event (d='{}', {} members)", 
        d_tag_value, group_list.members.len());
    
    Ok(unsigned_event_json)
}

/// 暗号化されたグループタスクイベント（Amber復号化用）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedGroupTodoListEvent {
    pub event_id: String,
    pub encrypted_content: String,  // イベント全体のcontent（JSON文字列）
    pub created_at: i64,
    pub list_id: String,          // d tag (例: "meiso-group-family")
    pub group_name: Option<String>,  // title tag (オプション)
    pub encrypted_data: String,    // 暗号化されたタスクデータ（base64）
    pub members: Vec<String>,      // メンバーの公開鍵リスト（hex）
    pub encrypted_keys: Vec<EncryptedKeyData>, // 各メンバー用の暗号化AES鍵
}

/// メンバー用に暗号化されたAES鍵（Flutter互換）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedKeyData {
    pub member_pubkey: String,     // メンバーの公開鍵（hex）
    pub encrypted_aes_key: String, // NIP-44で暗号化されたAES鍵（base64）
}

/// 公開鍵だけで暗号化されたグループタスクイベントを取得（Amber復号化用）
/// 復号化はAmber側で行うため、暗号化されたままのイベントを返す
pub fn fetch_encrypted_group_task_lists_for_pubkey(
    public_key_hex: String,
) -> Result<Vec<EncryptedGroupTodoListEvent>> {
    fetch_encrypted_group_task_lists_for_pubkey_with_client_id(public_key_hex, None)
}

pub fn fetch_encrypted_group_task_lists_for_pubkey_with_client_id(
    public_key_hex: String,
    client_id: Option<String>,
) -> Result<Vec<EncryptedGroupTodoListEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // 公開鍵をパース
        let public_key = PublicKey::from_hex(&public_key_hex)
            .context("Failed to parse public key")?;
        
        // pタグで自分がメンバーとして含まれるKind 30001イベントを検索
        let filter_p = Filter::new()
            .kind(Kind::Custom(30001))
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::P),
                vec![public_key_hex.clone()]
            );
        
        // 全てのKind 30001を取得（旧形式のmemberタグ対応）
        let filter_all = Filter::new()
            .kind(Kind::Custom(30001))
            .author(public_key);
        
        let events = client
            .client
            .fetch_events(vec![filter_p, filter_all], Some(Duration::from_secs(10)))
            .await?;
        
        if events.is_empty() {
            println!("⚠️ No encrypted group task list events found");
            return Ok(Vec::new());
        }
        
        println!("📥 Found {} encrypted group task list events", events.len());
        
        // 同じd tagを持つイベントが複数ある場合、最新のもの（created_atが最大）のみを保持
        use std::collections::HashMap;
        let mut latest_events: HashMap<String, Event> = HashMap::new();
        
        for event in events {
            // d タグを取得
            let d_tag = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            if let Some(d_value) = d_tag {
                // meiso-group-* のみを処理
                if d_value.starts_with("meiso-group-") {
                    // 既存のイベントと比較して、より新しい場合のみ保持
                    if let Some(existing_event) = latest_events.get(&d_value) {
                        if event.created_at.as_u64() > existing_event.created_at.as_u64() {
                            println!("🔄 Updating latest event for d='{}' (newer timestamp)", d_value);
                            latest_events.insert(d_value, event);
                        } else {
                            println!("⏭️  Skipping older event for d='{}'", d_value);
                        }
                    } else {
                        latest_events.insert(d_value, event);
                    }
                }
            }
        }
        
        println!("📋 After deduplication: {} unique group task lists", latest_events.len());
        
        let mut encrypted_lists = Vec::new();
        
        for (d_tag, event) in latest_events {
            // title タグを取得（オプション）
            let group_name = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::Title)
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            // p タグからメンバー一覧を取得
            // 注意: contentは暗号化されているため、pタグから取得する必要がある
            let members: Vec<String> = event.tags.iter()
                .filter_map(|tag| {
                    if tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::P)) {
                        tag.content().map(|s| s.to_string())
                    } else {
                        None
                    }
                })
                .collect();
            
            let members_count = members.len();
            println!("📋 Group '{}' has {} members from p tags", d_tag, members_count);
            
            // encrypted_content をそのまま保存（後でFlutter側でAmber復号化）
            encrypted_lists.push(EncryptedGroupTodoListEvent {
                event_id: event.id.to_hex(),
                encrypted_content: event.content.clone(),
                created_at: event.created_at.as_u64() as i64,
                list_id: d_tag.clone(),
                group_name,
                encrypted_data: String::new(), // 後でcontentを復号化してから取得
                members,
                encrypted_keys: Vec::new(), // 後でcontentを復号化してから取得
            });
            
            println!("📦 Added encrypted group event: d='{}', event_id={}, members={}", 
                d_tag, event.id.to_hex(), members_count);
        }
        
        println!("✅ Total encrypted group task lists: {}", encrypted_lists.len());
        Ok(encrypted_lists)
    })
}

/// タスクデータをAES-256-GCMで暗号化（Amberモード用）
/// 
/// # Arguments
/// * `tasks_json` - タスクデータのJSON文字列
/// * `aes_key_base64` - base64エンコードされたAES-256鍵（32バイト）
/// 
/// # Returns
/// base64エンコードされた暗号化データ（ノンス12バイト + 暗号文）
pub fn encrypt_group_data_with_aes_key(
    tasks_json: String,
    aes_key_base64: String,
) -> Result<String> {
    group_tasks::encrypt_data_with_aes_key(tasks_json, aes_key_base64)
}

/// AES鍵を使ってグループタスクデータを復号化（Amberモード用）
/// 
/// Amberで復号化済みのAES鍵を使ってデータを復号化する
/// 
/// # Arguments
/// * `encrypted_data_base64` - base64エンコードされた暗号化データ
/// * `aes_key_base64` - base64エンコードされたAES鍵（すでに復号化済み）
/// 
/// # Returns
/// 復号化されたJSON文字列
pub fn decrypt_group_data_with_aes_key(
    encrypted_data_base64: String,
    aes_key_base64: String,
) -> Result<String> {
    group_tasks::decrypt_data_with_aes_key(encrypted_data_base64, aes_key_base64)
}

/// 自分がメンバーになっているグループタスクリストを取得（非推奨 - Amberモードでは動作しない）
/// 代わりに fetch_encrypted_group_task_lists_for_pubkey を使用してください
#[deprecated(note = "Use fetch_encrypted_group_task_lists_for_pubkey for Amber mode compatibility")]
pub fn fetch_my_group_task_lists() -> Result<Vec<GroupTodoList>> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(None).await?;
        
        // 秘密鍵モードのみサポート
        let keys = client.keys.as_ref()
            .context("Secret key required for fetching group task lists")?;
        
        // 自分がメンバーとして含まれるKind 30001イベントを検索
        // 戦略: pタグで検索できない場合、全てのKind 30001を取得してフィルタリング
        let my_pubkey = keys.public_key().to_hex();
        
        // まずpタグで検索（新形式）
        let filter_p = Filter::new()
            .kind(Kind::Custom(30001))
            .custom_tag(
                nostr_sdk::SingleLetterTag::lowercase(nostr_sdk::Alphabet::P),
                vec![my_pubkey.clone()]
            );
        
        // 次に全てのKind 30001を取得（旧形式のmemberタグ対応）
        let filter_all = Filter::new()
            .kind(Kind::Custom(30001));
        
        let events = client
            .client
            .fetch_events(vec![filter_p, filter_all], Some(Duration::from_secs(10)))
            .await?;
        
        if events.is_empty() {
            println!("⚠️ No group task lists found");
            return Ok(Vec::new());
        }
        
        println!("📥 Found {} group task list events", events.len());
        
        let mut group_lists = Vec::new();
        
        for event in events {
            // d タグを取得してグループリストか確認
            let d_tag = event.tags.iter()
                .find(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)))
                .and_then(|tag| tag.content())
                .map(|s| s.to_string());
            
            // meiso-group-* のみを処理
            if let Some(ref d_value) = d_tag {
                if d_value.starts_with("meiso-group-") {
                    // NIP-44で復号化
                    match nip44::decrypt(
                        keys.secret_key(),
                        &keys.public_key(),
                        &event.content,
                    ) {
                        Ok(decrypted) => {
                            match serde_json::from_str::<GroupTodoList>(&decrypted) {
                                Ok(group_list) => {
                                    // 自分がメンバーに含まれているか確認
                                    if group_list.members.contains(&my_pubkey) {
                                        println!("✅ Decrypted group: {} (member check: ✓)", group_list.group_name);
                                        group_lists.push(group_list);
                                    } else {
                                        println!("⚠️ Skipping group {} (not a member)", group_list.group_name);
                                    }
                                }
                                Err(e) => {
                                    eprintln!("❌ Failed to parse group task list JSON from {:?}: {}", d_tag, e);
                                }
                            }
                        }
                        Err(_) => {
                            // 復号化失敗 = 自分宛てではない or 壊れたデータ
                            // 全てのKind 30001を取得しているため、これは正常
                        }
                    }
                }
            }
        }
        
        println!("✅ Total group task lists fetched: {}", group_lists.len());
        Ok(group_lists)
    })
}

// ========================================
// MLS API (Option B PoC)
// ========================================

/// MLS: データベース初期化
pub fn mls_init_db(db_path: String, nostr_id: String) -> Result<()> {
    crate::mls::init_mls_db(db_path, nostr_id)
}

/// MLS: Export SecretからListen Key取得
pub fn mls_get_listen_key(nostr_id: String, group_id: String) -> Result<String> {
    crate::mls::get_listen_key_from_export_secret(nostr_id, group_id)
}

/// MLS: TODOグループ作成
pub fn mls_create_todo_group(
    nostr_id: String,
    group_id: String,
    group_name: String,
    key_packages: Vec<String>,
) -> Result<Vec<u8>> {
    crate::group_tasks_mls::create_mls_todo_group(nostr_id, group_id, group_name, key_packages)
}

/// MLS: TODOをグループに追加（暗号化）
pub fn mls_add_todo(
    nostr_id: String,
    group_id: String,
    todo_json: String,
) -> Result<String> {
    crate::group_tasks_mls::add_todo_to_mls_group(nostr_id, group_id, todo_json)
}

/// MLS: TODOを復号化
pub fn mls_decrypt_todo(
    nostr_id: String,
    group_id: String,
    encrypted_msg: String,
) -> Result<(String, String, String)> {
    crate::group_tasks_mls::decrypt_todo_from_mls_group(nostr_id, group_id, encrypted_msg)
}

/// MLS: Key Package作成
pub fn mls_create_key_package(nostr_id: String) -> Result<crate::group_tasks_mls::KeyPackageResult> {
    crate::group_tasks_mls::create_key_package(nostr_id)
}

/// MLS: グループに参加（Welcome Message使用）
pub fn mls_join_group(
    nostr_id: String,
    group_id: String,
    welcome_msg: Vec<u8>,
) -> Result<()> {
    crate::group_tasks_mls::join_mls_group(nostr_id, group_id, welcome_msg)
}

/// MLS: Key Package公開イベント作成（Kind 10443 - NIP-EE）
/// 
/// Key PackageをKind 10443イベントとして公開することで、
/// 他のユーザーがnpubから自動的にKey Packageを取得できるようになる
/// 
/// # Arguments
/// * `key_package_result` - mlsCreateKeyPackageの結果
/// * `public_key_hex` - ユーザーの公開鍵（hex）
/// * `relays` - Key Packageを公開するリレーのリスト
/// 
/// # Returns
/// * 未署名イベントJSON（Amber署名用）
pub fn create_unsigned_key_package_event(
    key_package_result: crate::group_tasks_mls::KeyPackageResult,
    public_key_hex: String,
    relays: Vec<String>,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // 現在のタイムスタンプ
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // NIP-EE（Kind 10443）のタグ構成
    let mut tags = Vec::new();
    
    // MLS Protocol Version
    tags.push(vec!["mls_protocol_version".to_string(), key_package_result.mls_protocol_version]);
    
    // Ciphersuite
    tags.push(vec!["ciphersuite".to_string(), key_package_result.ciphersuite]);
    
    // Extensions (if any)
    if !key_package_result.extensions.is_empty() {
        tags.push(vec!["extensions".to_string(), key_package_result.extensions]);
    }
    
    // Client識別
    tags.push(vec!["client".to_string(), "meiso".to_string()]);
    
    // リレーリスト
    for relay_url in &relays {
        tags.push(vec!["relay".to_string(), relay_url.clone()]);
    }
    
    // 未署名イベントJSON（Amber用）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 10443,  // NIP-EE: Key Package
        "tags": tags,
        "content": key_package_result.key_package,
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📦 Created unsigned key package event (Kind 10443) for Amber signing");
    Ok(event_json)
}

/// MLS: グループ招待を同期（Kind 30078から取得）
/// 
/// 自分宛のグループ招待イベントを取得する
/// 
/// # Arguments
/// * `recipient_public_key_hex` - 受信者の公開鍵（hex）
/// * `client_id` - NostrクライアントID（オプション）
/// 
/// # Returns
/// * グループ招待のJSON配列
pub fn sync_group_invitations(
    recipient_public_key_hex: String,
    client_id: Option<String>,
) -> Result<String> {
    use serde_json::json;
    
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        let recipient_pubkey = PublicKey::from_hex(&recipient_public_key_hex)
            .context("Failed to parse recipient public key")?;
        
        println!("📥 Syncing group invitations for: {}", recipient_pubkey.to_hex());
        
        // Kind 30078イベントをフィルタ（pタグで自分宛）
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::P),
                vec![recipient_pubkey.to_hex()],
            )
            .limit(50);
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        println!("✅ Found {} group invitation events", events.len());
        
        // イベントをJSON配列に変換
        let mut invitations = Vec::new();
        
        for event in events {
            // d tagからgroup_idを抽出
            let d_tag = event
                .tags
                .iter()
                .find(|tag| {
                    let tag_vec = (*tag).clone().to_vec();
                    tag_vec.first().map(|s| s.as_str()) == Some("d")
                })
                .and_then(|tag| {
                    let tag_vec = (*tag).clone().to_vec();
                    tag_vec.get(1).cloned()
                });
            
            if let Some(d_tag_value) = d_tag {
                // d_tag形式: group-invitation-{groupId}-{recipientPubkey}
                if let Some(group_id) = d_tag_value.strip_prefix("group-invitation-") {
                    if let Some(group_id_only) = group_id.split('-').next() {
                        // contentをパース（平文のJSON）
                        // Note: 将来的にはNIP-44復号化が必要
                        if let Ok(content_json) = serde_json::from_str::<serde_json::Value>(&event.content) {
                            let invitation = json!({
                                "event_id": event.id.to_hex(),
                                "inviter_pubkey": event.pubkey.to_hex(),
                                "group_id": content_json.get("group_id").and_then(|v| v.as_str()).unwrap_or(group_id_only),
                                "group_name": content_json.get("group_name").and_then(|v| v.as_str()).unwrap_or("Unnamed Group"),
                                "welcome_msg": content_json.get("welcome_msg").and_then(|v| v.as_str()).unwrap_or(""),
                                "inviter_name": content_json.get("inviter_name").and_then(|v| v.as_str()),
                                "invited_at": content_json.get("invited_at").and_then(|v| v.as_u64()).unwrap_or(0),
                                "created_at": event.created_at.as_u64(),
                            });
                            
                            invitations.push(invitation);
                            
                            println!(
                                "  📨 Invitation: {} from {}",
                                content_json.get("group_name").and_then(|v| v.as_str()).unwrap_or("Unnamed"),
                                event.pubkey.to_hex().chars().take(16).collect::<String>()
                            );
                        }
                    }
                }
            }
        }
        
        let result = json!({
            "invitations": invitations,
            "count": invitations.len(),
        });
        
        Ok(serde_json::to_string(&result)?)
    })
}

/// MLS: グループ招待イベント作成（Kind 30078 + NIP-44）
/// 
/// グループ招待通知をKind 30078イベントとして作成（未署名）
/// 受信者の公開鍵でNIP-44暗号化される
/// 
/// # Arguments
/// * `sender_public_key_hex` - 送信者の公開鍵（hex）
/// * `recipient_npub` - 受信者のnpub
/// * `group_id` - グループID
/// * `group_name` - グループ名
/// * `welcome_msg_base64` - Welcome Message（base64エンコード済み）
/// * `inviter_name` - 招待者の名前（オプション）
/// 
/// # Returns
/// * 未署名イベントJSON（Amber署名用）
pub fn create_unsigned_group_invitation_event(
    sender_public_key_hex: String,
    recipient_npub: String,
    group_id: String,
    group_name: String,
    welcome_msg_base64: String,
    inviter_name: Option<String>,
) -> Result<String> {
    use serde_json::json;
    
    // 公開鍵をパース
    let sender_pubkey = PublicKey::from_hex(&sender_public_key_hex)
        .context("Failed to parse sender public key")?;
    let recipient_pubkey = PublicKey::from_bech32(&recipient_npub)
        .context("Failed to parse recipient npub")?;
    
    // 招待データを作成
    let invitation_data = json!({
        "type": "group_invitation",
        "group_id": group_id,
        "group_name": group_name,
        "welcome_msg": welcome_msg_base64,
        "inviter_name": inviter_name,
        "invited_at": std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs(),
    });
    
    let content_json = serde_json::to_string(&invitation_data)?;
    
    println!("📤 Creating group invitation event");
    println!("   Group: {}", group_name);
    println!("   Recipient: {}", recipient_pubkey.to_hex());
    
    // NIP-44で暗号化（注意: Amber署名前なので、ここでは暗号化できない）
    // → Amber署名版では、contentを平文で渡し、Flutter側で暗号化する必要がある
    // → または、秘密鍵モードでは署名前に暗号化する
    
    // 簡略化のため、ここでは平文をそのまま渡す（実際の実装ではFlutter側で暗号化）
    // Amber対応のため、未署名イベントとして返す
    
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // d tag: group-invitation-{groupId}-{recipientPubkey}
    let d_tag_value = format!("group-invitation-{}-{}", group_id, recipient_pubkey.to_hex());
    
    let mut tags = Vec::new();
    tags.push(vec!["d".to_string(), d_tag_value]);
    tags.push(vec!["p".to_string(), recipient_pubkey.to_hex()]);
    tags.push(vec!["client".to_string(), "meiso".to_string()]);
    
    // 未署名イベントJSON
    // Note: contentは平文で渡す。実際の暗号化はFlutter側（Amber署名時）に実装予定
    let unsigned_event = json!({
        "pubkey": sender_pubkey.to_hex(),
        "created_at": created_at,
        "kind": 30078,  // NIP-78: App Data
        "tags": tags,
        "content": content_json,  // 平文（TODO: NIP-44暗号化）
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("✅ Created unsigned group invitation event");
    Ok(event_json)
}

/// MLS: npubからKey Packageを取得（Kind 10443）
/// 
/// 指定したnpubのユーザーが公開しているKey Packageを取得する
/// 
/// # Arguments
/// * `npub` - 取得対象ユーザーのnpub（bech32形式）
/// 
/// # Returns
/// * Key Package（hex文字列）
pub fn fetch_key_package_by_npub(npub: String) -> Result<String> {
    fetch_key_package_by_npub_with_client_id(npub, None)
}

/// MLS: npubからKey Packageを取得（client_id指定可能）
pub fn fetch_key_package_by_npub_with_client_id(
    npub: String,
    client_id: Option<String>,
) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client = get_client(client_id).await?;
        
        // npubを公開鍵（hex）に変換
        let public_key = PublicKey::from_bech32(&npub)
            .context("Failed to parse npub")?;
        
        println!("🔍 Fetching Key Package for: {}", public_key.to_hex());
        
        // Kind 10443イベントをクエリ
        let filter = Filter::new()
            .kind(Kind::Custom(10443))
            .author(public_key)
            .limit(1);  // 最新のKey Packageのみ
        
        let events = client
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;
        
        // 最新のKey Packageを取得
        if let Some(event) = events.first() {
            println!("✅ Found Key Package event: {}", event.id.to_hex());
            println!("   Created at: {}", event.created_at);
            
            // タグから情報を取得（デバッグ用）
            for tag in event.tags.iter() {
                let tag_vec = tag.clone().to_vec();
                if let Some(tag_kind) = tag_vec.first() {
                    if tag_kind == "mls_protocol_version" || tag_kind == "ciphersuite" {
                        println!("   {}: {:?}", tag_kind, tag_vec.get(1));
                    }
                }
            }
            
            // contentがKey Package本体
            Ok(event.content.clone())
        } else {
            Err(anyhow::anyhow!("No Key Package found for npub: {}", npub))
        }
    })
}

