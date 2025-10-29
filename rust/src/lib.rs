use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use nostr_sdk::prelude::*;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;

/// アプリ全体で使用するNostrクライアント
static NOSTR_CLIENT: once_cell::sync::Lazy<Arc<Mutex<Option<MeisoNostrClient>>>> =
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(None)));

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
    keys: Keys,
    client: Client,
}

impl MeisoNostrClient {
    /// 新しいクライアントを作成（秘密鍵から）
    pub async fn new(secret_key_hex: &str, relays: Vec<String>) -> Result<Self> {
        let keys = Keys::parse(secret_key_hex).context("Failed to parse secret key")?;

        let client = Client::new(keys.clone());

        // リレー追加
        for relay_url in relays {
            client.add_relay(&relay_url).await?;
        }

        // リレーに接続
        client.connect().await;

        Ok(Self { keys, client })
    }

    /// 公開鍵を取得（hex形式）
    pub fn public_key(&self) -> String {
        self.keys.public_key().to_hex()
    }

    /// TodoをNostrイベントとして作成
    pub async fn create_todo(&self, todo: TodoData) -> Result<String> {
        let todo_json = serde_json::to_string(&todo)?;

        // NIP-44で自己暗号化
        let public_key = self.keys.public_key();
        let encrypted_content = nostr::nips::nip44::encrypt(
            self.keys.secret_key(),
            &public_key,
            &todo_json,
            nostr::nips::nip44::Version::V2,
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

        // リレーに送信
        let event_id = self.client.send_event(event).await?;

        Ok(event_id.to_hex())
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
            let delete_event = EventBuilder::delete([event.id.clone()])
                .sign(&self.keys)
                .await?;

            self.client.send_event(delete_event).await?;
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
            if let Ok(decrypted) = nostr::nips::nip44::decrypt(
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

/// Nostrクライアントを初期化
#[frb(sync)]
pub fn init_nostr_client(secret_key_hex: String, relays: Vec<String>) -> Result<String> {
    // 非同期処理をブロッキング実行
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async {
        let client = MeisoNostrClient::new(&secret_key_hex, relays).await?;
        let public_key = client.public_key();

        let mut global_client = NOSTR_CLIENT.lock().await;
        *global_client = Some(client);

        Ok(public_key)
    })
}

/// 新しい秘密鍵を生成
#[frb(sync)]
pub fn generate_secret_key() -> String {
    Keys::generate().secret_key().to_secret_hex()
}

/// Todoを作成
#[frb(sync)]
pub fn create_todo(todo: TodoData) -> Result<String> {
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostr client not initialized")?;

        client.create_todo(todo).await
    })
}

/// Todoを更新
#[frb(sync)]
pub fn update_todo(todo: TodoData) -> Result<String> {
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostr client not initialized")?;

        client.update_todo(todo).await
    })
}

/// Todoを削除
#[frb(sync)]
pub fn delete_todo(todo_id: String) -> Result<()> {
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostr client not initialized")?;

        client.delete_todo(&todo_id).await
    })
}

/// 全Todoを同期
#[frb(sync)]
pub fn sync_todos() -> Result<Vec<TodoData>> {
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(async {
        let client_guard = NOSTR_CLIENT.lock().await;
        let client = client_guard
            .as_ref()
            .context("Nostr client not initialized")?;

        client.sync_todos().await
    })
}

// flutter_rust_bridge自動生成モジュール
mod frb_generated;
