mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
use std::sync::Arc;
use tokio::sync::Mutex;

pub mod api;
pub mod key_store;

/// アプリ全体で使用するNostrクライアント
pub static NOSTR_CLIENT: once_cell::sync::Lazy<Arc<Mutex<Option<api::MeisoNostrClient>>>> =
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(None)));
