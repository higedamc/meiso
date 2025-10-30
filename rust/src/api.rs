use anyhow::{Context, Result};
use nostr_sdk::prelude::*;
use nostr_sdk::nips::nip44; // NIP-44暗号化を明示的にインポート
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::NOSTR_CLIENT;

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
    /// 最終更新日時
    pub updated_at: String,
}

/// デフォルトのプロキシURL
fn default_proxy_url() -> String {
    "socks5://127.0.0.1:9050".to_string()
}

/// Nostrクライアントのラッパー
pub struct MeisoNostrClient {
    pub(crate) keys: Keys,
    pub(crate) client: Client,
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

        Ok(Self { keys, client })
    }

    /// 公開鍵を取得（hex形式）
    pub fn public_key_hex(&self) -> String {
        self.keys.public_key().to_hex()
    }

    /// 公開鍵を取得（npub形式）
    pub fn public_key_npub(&self) -> String {
        self.keys.public_key().to_bech32().unwrap_or_else(|_| self.keys.public_key().to_hex())
    }

    /// TodoリストをNostrイベントとして作成（Kind 30001 - NIP-51 Bookmark List）
    /// 全TODOを1つのイベントとして管理
    pub async fn create_todo_list(&self, todos: Vec<TodoData>) -> Result<String> {
        let todos_json = serde_json::to_string(&todos)?;

        // NIP-44で自己暗号化
        let public_key = self.keys.public_key();
        let encrypted_content = nip44::encrypt(
            self.keys.secret_key(),
            &public_key,
            &todos_json,
            nip44::Version::V2,
        )?;

        // イベント作成（Kind 30001 - Bookmark List）
        let d_tag = Tag::custom(
            TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
            vec!["meiso-todos".to_string()],
        );
        
        let title_tag = Tag::custom(
            TagKind::Custom(std::borrow::Cow::Borrowed("title")),
            vec!["My TODO List".to_string()],
        );

        let event = EventBuilder::new(Kind::Custom(30001), encrypted_content)
            .tags(vec![d_tag, title_tag])
            .sign(&self.keys)
            .await?;

        // リレーに送信するイベントをJSONとしてログ出力
        match serde_json::to_string_pretty(&event.as_json()) {
            Ok(event_json) => {
                println!("📤 Nostr TODO list event (Kind 30001) to relay:");
                println!("{}", event_json);
            }
            Err(e) => {
                eprintln!("⚠️ Failed to serialize event to JSON: {}", e);
            }
        }

        // リレーに送信（タイムアウト付き、エラーを無視して続行）
        match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(event.clone())).await {
            Ok(Ok(event_id)) => {
                println!("✅ TODO list event sent successfully: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                // 送信エラーでもイベントIDは返す（ローカルで保存済み）
                eprintln!("⚠️ 一部のリレーへの送信に失敗: {}", e);
                Ok(event.id.to_hex())
            }
            Err(_) => {
                // タイムアウトでもイベントIDは返す
                eprintln!("⚠️ イベント送信タイムアウト");
                Ok(event.id.to_hex())
            }
        }
    }

    /// TodoをNostrイベントとして作成（旧実装 - 後方互換性のため残す）
    pub async fn create_todo(&self, todo: TodoData) -> Result<String> {
        let todo_json = serde_json::to_string(&todo)?;

        // NIP-44で自己暗号化
        let public_key = self.keys.public_key();
        let encrypted_content = nip44::encrypt(
            self.keys.secret_key(),
            &public_key,
            &todo_json,
            nip44::Version::V2,
        )?;

        // イベント作成（dタグを追加）
        let tag = Tag::custom(
            TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::D)),
            vec![format!("todo-{}", todo.id)],
        );

        let event = EventBuilder::new(Kind::Custom(30078), encrypted_content)
            .tags(vec![tag])
            .sign(&self.keys)
            .await?;

        // リレーに送信するイベントをJSONとしてログ出力
        match serde_json::to_string_pretty(&event.as_json()) {
            Ok(event_json) => {
                println!("📤 Nostr event to relay:");
                println!("{}", event_json);
            }
            Err(e) => {
                eprintln!("⚠️ Failed to serialize event to JSON: {}", e);
            }
        }

        // リレーに送信（タイムアウト付き、エラーを無視して続行）
        match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(event.clone())).await {
            Ok(Ok(event_id)) => {
                println!("✅ Event sent successfully: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                // 送信エラーでもイベントIDは返す（ローカルで保存済み）
                eprintln!("⚠️ 一部のリレーへの送信に失敗: {}", e);
                Ok(event.id.to_hex())
            }
            Err(_) => {
                // タイムアウトでもイベントIDは返す
                eprintln!("⚠️ イベント送信タイムアウト");
                Ok(event.id.to_hex())
            }
        }
    }

    /// Todoを更新（既存イベントを置き換え）
    pub async fn update_todo(&self, todo: TodoData) -> Result<String> {
        // 作成と同じ処理（Kind 30078は同じdタグで上書き）
        self.create_todo(todo).await
    }

    /// Todoを削除（削除イベント送信）
    pub async fn delete_todo(&self, todo_id: &str) -> Result<()> {
        // まず該当イベントを取得
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(self.keys.public_key())
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::D),
                vec![format!("todo-{}", todo_id)],
            );

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(5)))
            .await?;

        if let Some(event) = events.first() {
            // 削除イベント (Kind 5) を送信
            let delete_event = EventBuilder::delete([event.id])
                .sign(&self.keys)
                .await?;

            // リレーに送信する削除イベントをJSONとしてログ出力
            match serde_json::to_string_pretty(&delete_event.as_json()) {
                Ok(event_json) => {
                    println!("🗑️ Nostr delete event to relay:");
                    println!("{}", event_json);
                }
                Err(e) => {
                    eprintln!("⚠️ Failed to serialize delete event to JSON: {}", e);
                }
            }

            // タイムアウト付き送信
            match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(delete_event.clone())).await {
                Ok(Ok(event_id)) => {
                    println!("✅ Delete event sent successfully: {}", event_id.to_hex());
                }
                Ok(Err(e)) => {
                    eprintln!("⚠️ Failed to send delete event: {}", e);
                }
                Err(_) => {
                    eprintln!("⚠️ Delete event send timeout");
                }
            }
        }

        Ok(())
    }

    /// TodoリストをNostrから同期（Kind 30001）
    pub async fn sync_todo_list(&self) -> Result<Vec<TodoData>> {
        let filter = Filter::new()
            .kind(Kind::Custom(30001))
            .author(self.keys.public_key())
            .custom_tag(
                SingleLetterTag::lowercase(Alphabet::D),
                vec!["meiso-todos".to_string()],
            );

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        // 最新のイベントを取得（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            // NIP-44で復号化
            if let Ok(decrypted) = nip44::decrypt(
                self.keys.secret_key(),
                &self.keys.public_key(),
                &event.content,
            ) {
                if let Ok(todos) = serde_json::from_str::<Vec<TodoData>>(&decrypted) {
                    println!("✅ TODO list synced: {} todos", todos.len());
                    return Ok(todos);
                }
            }
        }

        println!("⚠️ No TODO list found");
        Ok(Vec::new())
    }

    /// 全てのTodoを同期（リレーから取得）- 旧実装（Kind 30078）
    /// 
    /// ⚠️ 注意: `d`タグが`todo-`で始まるイベントは除外されます
    /// これは設定イベント（`meiso-settings`など）を除外するためです
    pub async fn sync_todos(&self) -> Result<Vec<TodoData>> {
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(self.keys.public_key());

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        let mut todos = Vec::new();

        for event in events {
            // dタグをチェック：`todo-`で始まる場合はスキップ
            let should_skip = event.tags.iter().any(|tag| {
                let tag_kind = tag.kind();
                if tag_kind.to_string() == "d" {
                    if let Some(value) = tag.content() {
                        return value.starts_with("todo-");
                    }
                }
                false
            });

            if should_skip {
                println!("⏭️  Skipping Kind 30078 event with d tag starting with 'todo-': {}", event.id.to_hex());
                continue;
            }

            // NIP-44で復号化
            if let Ok(decrypted) = nip44::decrypt(
                self.keys.secret_key(),
                &self.keys.public_key(),
                &event.content,
            ) {
                if let Ok(mut todo) = serde_json::from_str::<TodoData>(&decrypted) {
                    todo.event_id = Some(event.id.to_hex());
                    todos.push(todo);
                }
            }
        }

        Ok(todos)
    }

    // ========================================
    // アプリ設定管理（NIP-78 Application-specific data）
    // ========================================

    /// アプリ設定をNostrイベントとして作成（Kind 30078 - NIP-78）
    pub async fn create_app_settings(&self, settings: AppSettings) -> Result<String> {
        let settings_json = serde_json::to_string(&settings)?;

        // NIP-44で自己暗号化
        let public_key = self.keys.public_key();
        let encrypted_content = nip44::encrypt(
            self.keys.secret_key(),
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
            .sign(&self.keys)
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

        // リレーに送信（タイムアウト付き）
        match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(event.clone())).await {
            Ok(Ok(event_id)) => {
                println!("✅ App settings event sent successfully: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                eprintln!("⚠️ 一部のリレーへの送信に失敗: {}", e);
                Ok(event.id.to_hex())
            }
            Err(_) => {
                eprintln!("⚠️ イベント送信タイムアウト");
                Ok(event.id.to_hex())
            }
        }
    }

    /// アプリ設定をNostrから同期（Kind 30078）
    pub async fn sync_app_settings(&self) -> Result<Option<AppSettings>> {
        let filter = Filter::new()
            .kind(Kind::Custom(30078))
            .author(self.keys.public_key())
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
                self.keys.secret_key(),
                &self.keys.public_key(),
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
    pub async fn save_relay_list(&self, relays: Vec<String>) -> Result<String> {
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
            .sign(&self.keys)
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
        
        // リレーに送信（タイムアウト付き）
        match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(event.clone())).await {
            Ok(Ok(event_id)) => {
                println!("✅ Relay list event sent successfully: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                eprintln!("⚠️ 一部のリレーへの送信に失敗: {}", e);
                Ok(event.id.to_hex())
            }
            Err(_) => {
                eprintln!("⚠️ イベント送信タイムアウト");
                Ok(event.id.to_hex())
            }
        }
    }

    /// リレーリストをNostrから同期（NIP-65 Kind 10002）
    pub async fn sync_relay_list(&self) -> Result<Vec<String>> {
        println!("🔄 Syncing relay list from Nostr (Kind 10002)...");
        
        let filter = Filter::new()
            .kind(Kind::RelayList)
            .author(self.keys.public_key());

        let events = self
            .client
            .fetch_events(vec![filter], Some(Duration::from_secs(10)))
            .await?;

        // 最新のイベントを取得（Replaceable eventなので1つだけのはず）
        if let Some(event) = events.first() {
            let mut relays = Vec::new();
            
            // "r" タグからリレーURLを抽出
            for tag in event.tags.iter() {
                // TagKind::Relayをチェックし、contentからURLを取得
                if tag.kind() == TagKind::Relay {
                    if let Some(relay_url) = tag.content() {
                        relays.push(relay_url.to_string());
                    }
                }
            }
            
            println!("✅ Relay list synced: {} relays", relays.len());
            return Ok(relays);
        }

        println!("⚠️ No relay list found");
        Ok(Vec::new())
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
pub fn init_nostr_client(secret_key_hex: String, relays: Vec<String>) -> Result<String> {
    init_nostr_client_with_proxy(secret_key_hex, relays, None)
}

/// Nostrクライアントを初期化（プロキシオプション付き）
pub fn init_nostr_client_with_proxy(
    secret_key_hex: String, 
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    println!("🔧 Initializing Nostr client{}...", 
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
                println!("✅ Nostr client initialized. Public key: {}", &public_key[..16]);

                let mut global_client = NOSTR_CLIENT.lock().await;
                *global_client = Some(client);

                Ok(public_key)
            }
            Err(e) => {
                eprintln!("❌ Failed to initialize Nostr client: {}", e);
                Err(e)
            }
        }
    })
}

/// 公開鍵をnpub形式で取得
pub fn get_public_key_npub() -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
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

/// Todoを作成
pub fn create_todo(todo: TodoData) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.create_todo(todo).await
    })
}

/// Todoを更新
pub fn update_todo(todo: TodoData) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.update_todo(todo).await
    })
}

/// Todoを削除
pub fn delete_todo(todo_id: String) -> Result<()> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.delete_todo(&todo_id).await
    })
}

/// 全Todoを同期（Kind 30001 - 新実装）
pub fn sync_todo_list() -> Result<Vec<TodoData>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.sync_todo_list().await
    })
}

/// Todoリストを作成（Kind 30001）
pub fn create_todo_list(todos: Vec<TodoData>) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.create_todo_list(todos).await
    })
}

/// 全Todoを同期（旧実装 - Kind 30078）
pub fn sync_todos() -> Result<Vec<TodoData>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.sync_todos().await
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
    init_nostr_client_with_pubkey_and_proxy(public_key_hex, relays, None)
}

/// Amberモードで初期化（プロキシオプション付き）
pub fn init_nostr_client_with_pubkey_and_proxy(
    public_key_hex: String,
    relays: Vec<String>,
    proxy_url: Option<String>,
) -> Result<String> {
    println!("🔧 Initializing Nostr client with public key only (Amber mode){}...",
        if proxy_url.is_some() { " with proxy" } else { "" });
    println!("Public key: {}...", &public_key_hex[..16.min(public_key_hex.len())]);
    println!("Relays: {:?}", relays);
    if let Some(ref proxy) = proxy_url {
        println!("Proxy: {}", proxy);
    }
    
    TOKIO_RUNTIME.block_on(async {
        // Amber使用時はダミーの秘密鍵でクライアントを作成
        // 実際の署名操作はAmber経由で行うため、この秘密鍵は使用されない
        let dummy_keys = Keys::generate();
        
        // プロキシ設定（環境変数経由）
        if let Some(ref proxy) = proxy_url {
            println!("🔐 Tor/Proxy経由で接続します (Amber mode): {}", proxy);
            
            // SOCKS5プロキシを環境変数に設定
            std::env::set_var("all_proxy", proxy);
            std::env::set_var("ALL_PROXY", proxy);
            std::env::set_var("socks_proxy", proxy);
            std::env::set_var("SOCKS_PROXY", proxy);
            
            println!("✅ プロキシ環境変数を設定 (Amber mode): {}", proxy);
        }
        
        let client = Client::new(dummy_keys.clone());
        
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
        let timeout_sec = if proxy_url.is_some() { 20 } else { 10 }; // Tor経由は時間がかかる
        println!("🔌 Connecting to relays in Amber mode{}...",
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
        
        // グローバルクライアントに保存
        let nostr_client = MeisoNostrClient { keys: dummy_keys, client };
        let mut global_client = NOSTR_CLIENT.lock().await;
        *global_client = Some(nostr_client);
        
        println!("✅ Nostr client initialized in Amber mode");
        Ok(public_key_hex)
    })
}

/// 未署名Todoイベントを作成（Amber署名用）
/// Amberに送信するイベントJSON文字列を返す
pub fn create_unsigned_todo_event(
    todo: TodoData,
    public_key_hex: String,
) -> Result<String> {
    use serde_json::json;
    
    let todo_json = serde_json::to_string(&todo)?;
    
    // 公開鍵をパース
    let public_key = PublicKey::from_hex(&public_key_hex)
        .context("Failed to parse public key")?;
    
    // Amber用の未署名イベントを作成
    // NIP-01形式: id, pubkey, created_at, kind, tags, contentを含み、sigは空
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    // dタグを追加
    let tags = vec![
        vec!["d".to_string(), format!("todo-{}", todo.id)]
    ];
    
    // 未署名イベントJSON（Amber用）
    let unsigned_event = json!({
        "pubkey": public_key.to_hex(),
        "created_at": created_at,
        "kind": 30078,
        "tags": tags,
        "content": todo_json,
    });
    
    let event_json = serde_json::to_string(&unsigned_event)?;
    
    println!("📝 Created unsigned event for Amber signing");
    Ok(event_json)
}

/// 署名済みイベントをリレーに送信
pub fn send_signed_event(event_json: String) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
        
        // イベントをパース
        let event: Event = serde_json::from_str(&event_json)
            .context("Failed to parse signed event JSON")?;
        
        // 署名を検証
        event.verify().context("Invalid event signature")?;
        
        println!("📤 Sending signed event to relays...");
        println!("🔍 Event kind: {}", event.kind);
        println!("🔍 Event ID: {}", event.id.to_hex());
        println!("🔍 Event pubkey: {}...", &event.pubkey.to_hex()[..16]);
        
        // リレーに送信（タイムアウトを10秒に延長）
        match tokio::time::timeout(
            Duration::from_secs(10),
            client.client.send_event(event.clone())
        ).await {
            Ok(Ok(event_id)) => {
                println!("✅✅✅ Event sent successfully to relays!");
                println!("✅ Event ID: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                eprintln!("❌❌❌ Failed to send event to relays: {}", e);
                Err(anyhow::anyhow!("Failed to send event: {}", e))
            }
            Err(_) => {
                eprintln!("❌❌❌ Event send timeout (10s)");
                Err(anyhow::anyhow!("Event send timeout"))
            }
        }
    })
}

/// 暗号化済みcontentで未署名Todoリストイベントを作成（Kind 30001 - Amber暗号化済み用）
pub fn create_unsigned_encrypted_todo_list_event(
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
    
    // Kind 30001のタグ
    let tags = vec![
        vec!["d".to_string(), "meiso-todos".to_string()],
        vec!["title".to_string(), "My TODO List".to_string()],
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
    
    println!("📝 Created unsigned encrypted TODO list event (Kind 30001) for Amber signing");
    Ok(event_json)
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
}

pub fn fetch_encrypted_todo_list_for_pubkey(
    public_key_hex: String,
) -> Result<Option<EncryptedTodoListEvent>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
        
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
            println!("📥 Fetched encrypted TODO list event");
            Ok(Some(EncryptedTodoListEvent {
                event_id: event.id.to_hex(),
                encrypted_content: event.content.clone(),
                created_at: event.created_at.as_u64() as i64,
            }))
        } else {
            println!("⚠️ No encrypted TODO list event found");
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
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
        
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
pub fn save_app_settings(settings: AppSettings) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.create_app_settings(settings).await
    })
}

/// アプリ設定を同期（Kind 30078）
pub fn sync_app_settings() -> Result<Option<AppSettings>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

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
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
        
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
pub fn save_relay_list(relays: Vec<String>) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.save_relay_list(relays).await
    })
}

/// リレーリストをNostrから同期（Kind 10002）
pub fn sync_relay_list() -> Result<Vec<String>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.sync_relay_list().await
    })
}

// ========================================
// マイグレーション関連API
// ========================================

/// 指定したイベントIDのリストを削除（Kind 5削除イベントを送信）
pub fn delete_events(
    event_ids: Vec<String>,
    reason: Option<String>,
) -> Result<String> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;
        
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
        
        // Kind 5削除イベントを作成
        let content = reason.unwrap_or_default();
        
        // イベントIDを'e'タグとして追加
        let tags: Vec<Tag> = event_id_objects
            .iter()
            .map(|id| Tag::event(*id))
            .collect();
        
        let event = EventBuilder::new(Kind::EventDeletion, content)
            .tags(tags)
            .sign(&client.keys)
            .await?;
        
        println!("📤 Sending Kind 5 deletion event...");
        
        // リレーに送信
        match tokio::time::timeout(
            Duration::from_secs(10),
            client.client.send_event(event.clone())
        ).await {
            Ok(Ok(event_id)) => {
                println!("✅ Deletion event sent successfully!");
                println!("✅ Deletion Event ID: {}", event_id.to_hex());
                Ok(event_id.to_hex())
            }
            Ok(Err(e)) => {
                eprintln!("❌ Failed to send deletion event: {}", e);
                Err(anyhow::anyhow!("Failed to send deletion event: {}", e))
            }
            Err(_) => {
                eprintln!("❌ Deletion event send timeout (10s)");
                Err(anyhow::anyhow!("Deletion event send timeout"))
            }
        }
    })
}

