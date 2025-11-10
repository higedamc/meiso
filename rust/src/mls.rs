use anyhow::Result;
use lazy_static::lazy_static;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::Mutex;

pub use kc::identity::Identity;
use kc::openmls_rust_persistent_crypto::JsonCodec;
pub use kc::openmls_rust_persistent_crypto::OpenMlsRustPersistentCrypto;
pub use openmls::group::{GroupId, MlsGroup, MlsGroupCreateConfig, MlsGroupJoinConfig};
pub use openmls_sqlite_storage::{Connection, SqliteStorageProvider};
pub use openmls_traits::OpenMlsProvider;

use kc::user::MlsUser;
use nostr_sdk::prelude::*;

/// MLS Store: Manages MLS state for each user
pub struct MlsStore {
    pub users: HashMap<String, MlsUser>,
}

lazy_static! {
    pub(crate) static ref STORE: Mutex<Option<MlsStore>> = Mutex::new(None);
}

lazy_static! {
    pub(crate) static ref RUNTIME: Arc<Runtime> =
        Arc::new(Runtime::new().expect("Failed to create tokio runtime for MLS"));
}

/// Initialize MLS database for a specific user (nostr_id)
pub fn init_mls_db(db_path: String, nostr_id: String) -> Result<()> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        
        // Open SQLite connection
        let connection = Connection::open(&db_path)?;
        
        // Create storage provider
        let mut storage = SqliteStorageProvider::<JsonCodec, Connection>::new(connection);
        storage.initialize().map_err(|e| {
            anyhow::anyhow!("Failed to initialize MLS storage: {}", e)
        })?;
        
        // Create OpenMLS provider
        let provider = OpenMlsRustPersistentCrypto::new(storage).await;
        
        // Initialize store if needed
        if store.is_none() {
            *store = Some(MlsStore {
                users: HashMap::new(),
            });
        }
        
        let map = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("Failed to get MLS store"))?;
        
        // Load or create user
        let mls_user = MlsUser::load(provider, nostr_id.clone()).await?;
        map.users.insert(nostr_id, mls_user);
        
        Ok(())
    })
}

/// Get export secret from MLS group
/// This is used to derive deterministic Nostr keypair
pub fn get_export_secret(nostr_id: String, group_id: String) -> Result<Vec<u8>> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found in MLS store", nostr_id))?;
        
        // Get MLS group
        let mut groups = user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;
        
        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;
        
        // Export secret with Meiso-specific label
        let export_secret = group
            .mls_group
            .export_secret(&user.provider, "meiso", b"todo", 32)?;
        
        Ok(export_secret)
    })
}

/// Get listen key (Nostr pubkey) from export secret
/// This key is deterministically derived from the MLS group's export secret
pub fn get_listen_key_from_export_secret(nostr_id: String, group_id: String) -> Result<String> {
    let export_secret = get_export_secret(nostr_id, group_id)?;
    
    // Convert export secret to hex
    let export_secret_hex = hex::encode(&export_secret);
    
    // Parse as Nostr keypair
    let keypair = nostr::Keys::parse(&export_secret_hex)?;
    
    // Extract x-only public key (schnorr)
    let public_key = keypair.public_key();
    let listen_key = public_key.to_hex();
    
    Ok(listen_key)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    
    #[test]
    fn test_init_mls_db() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_mls.db");
        let db_path_str = db_path.to_str().unwrap().to_string();
        
        let result = init_mls_db(db_path_str, "test_user".to_string());
        assert!(result.is_ok());
    }
}

