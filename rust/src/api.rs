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

/// Nostrクライアントのラッパー
pub struct MeisoNostrClient {
    pub(crate) keys: Keys,
    pub(crate) client: Client,
}

impl MeisoNostrClient {
    /// 新しいクライアントを作成（秘密鍵から）
    pub async fn new(secret_key_hex: &str, relays: Vec<String>) -> Result<Self> {
        println!("Parsing secret key (format: {})", 
            if secret_key_hex.starts_with("nsec") { "nsec" } else { "hex" });
        
        let keys = Keys::parse(secret_key_hex)
            .map_err(|e| anyhow::anyhow!("秘密鍵のパースに失敗 ({}): {}. フォーマットを確認してください (hex or nsec1...)", 
                if secret_key_hex.starts_with("nsec") { "nsec形式" } else { "hex形式" }, e))?;

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

        // リレーに接続（バックグラウンドで非同期接続）
        println!("Starting relay connection...");
        let client_clone = client.clone();
        tokio::spawn(async move {
            client_clone.connect().await;
            println!("✅ Connected to relays (background)");
        });

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

    /// TodoをNostrイベントとして作成
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

        // リレーに送信（タイムアウト付き、エラーを無視して続行）
        match tokio::time::timeout(Duration::from_secs(5), self.client.send_event(event.clone())).await {
            Ok(Ok(event_id)) => Ok(event_id.to_hex()),
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

            // タイムアウト付き送信（エラーは無視）
            let _ = tokio::time::timeout(Duration::from_secs(5), self.client.send_event(delete_event)).await;
        }

        Ok(())
    }

    /// 全てのTodoを同期（リレーから取得）
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
    println!("🔧 Initializing Nostr client...");
    println!("Secret key (first 10 chars): {}...", &secret_key_hex[..10.min(secret_key_hex.len())]);
    println!("Relays: {:?}", relays);

    TOKIO_RUNTIME.block_on(async {
        match MeisoNostrClient::new(&secret_key_hex, relays).await {
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

/// 新しい秘密鍵を生成
pub fn generate_secret_key() -> String {
    Keys::generate().secret_key().to_secret_hex()
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

/// 全Todoを同期
pub fn sync_todos() -> Result<Vec<TodoData>> {
    TOKIO_RUNTIME.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostrクライアントが初期化されていません")?;

        client.sync_todos().await
    })
}

