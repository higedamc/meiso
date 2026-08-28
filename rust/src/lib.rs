#[macro_use]
mod dev_log;

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

pub mod api;
pub mod group_tasks;
pub mod group_tasks_mls;
pub mod group_tasks_shared;
pub mod key_store;
pub mod mls;
pub mod nostr_client_meta;

/// 複数のNostrクライアントを管理（client_id -> MeisoNostrClient）
pub static NOSTR_CLIENTS: once_cell::sync::Lazy<
    Arc<Mutex<HashMap<String, api::MeisoNostrClient>>>,
> = once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(HashMap::new())));

/// デフォルトクライアントのID（後方互換性のため）
pub const DEFAULT_CLIENT_ID: &str = "default";
