use anyhow::Result;
use serde::{Deserialize, Serialize};
use crate::mls::{RUNTIME, STORE};

/// Result type for adding members to MLS group
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddMembersResult {
    pub queued_msg: String,
    pub welcome: Vec<u8>,
}

/// Create a new MLS TODO group
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key (hex)
/// * `group_id` - Unique identifier for the group (e.g., custom list ID)
/// * `group_name` - Display name for the group
/// * `key_packages` - List of key packages from members to add (hex encoded)
/// 
/// # Returns
/// * Welcome message (bytes) to be sent to new members via NIP-17
pub fn create_mls_todo_group(
    nostr_id: String,
    group_id: String,
    group_name: String,
    key_packages: Vec<String>,
) -> Result<Vec<u8>> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Create MLS group with Meiso-specific extension
        let group_config = user.create_mls_group(
            group_id.clone(),
            "Meiso TODO Group".to_string(), // description
            group_name,
            vec![nostr_id.clone()], // admin pubkeys
            vec![], // relays (not used for TODO lists)
            "enabled".to_string(),
        )?;
        
        // Add members if any
        if !key_packages.is_empty() {
            let (queued_msg, welcome) = user.add_members(group_id, key_packages)?;
            
            // Commit the changes
            user.self_commit(group_id)?;
            
            return Ok(welcome);
        }
        
        Ok(vec![])
    })
}

/// Encrypt and add a TODO to an MLS group
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// * `todo_json` - JSON string of the TODO item
/// 
/// # Returns
/// * Encrypted message (hex) to be sent to the group via Nostr
pub fn add_todo_to_mls_group(
    nostr_id: String,
    group_id: String,
    todo_json: String,
) -> Result<String> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Encrypt message using MLS
        let (encrypt_msg, _listen_key) = user.create_message(group_id, todo_json)?;
        
        Ok(encrypt_msg)
    })
}

/// Decrypt a TODO from an MLS group message
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// * `encrypted_msg` - Encrypted message (hex) from Nostr event
/// 
/// # Returns
/// * Tuple of (decrypted_json, sender_pubkey, listen_key)
pub fn decrypt_todo_from_mls_group(
    nostr_id: String,
    group_id: String,
    encrypted_msg: String,
) -> Result<(String, String, String)> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Decrypt message
        let (decrypt_msg, sender, listen_key) = user.decrypt_msg(group_id, encrypted_msg)?;
        
        Ok((decrypt_msg, sender, listen_key))
    })
}

/// Add members to an existing MLS TODO group
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key (must be admin)
/// * `group_id` - The group ID
/// * `key_packages` - List of key packages from new members (hex encoded)
/// 
/// # Returns
/// * AddMembersResult containing queued_msg (for existing members) and welcome (for new members)
pub fn add_members_to_mls_group(
    nostr_id: String,
    group_id: String,
    key_packages: Vec<String>,
) -> Result<AddMembersResult> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Add members
        let (queued_msg, welcome) = user.add_members(group_id.clone(), key_packages)?;
        
        // Commit changes
        user.self_commit(group_id)?;
        
        Ok(AddMembersResult {
            queued_msg,
            welcome,
        })
    })
}

/// Join an MLS TODO group using a welcome message
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// * `welcome` - Welcome message received via NIP-17
/// 
/// # Returns
/// * Success or error
pub fn join_mls_group(
    nostr_id: String,
    group_id: String,
    welcome: Vec<u8>,
) -> Result<()> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Join group
        user.join_mls_group(group_id.clone(), welcome)?;
        
        // Update storage
        user.update(nostr_id, false).await?;
        
        Ok(())
    })
}

/// Create a key package for this user
/// Key packages are published to Nostr relays (Kind 10443) so others can add you to groups
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// 
/// # Returns
/// * Hex-encoded key package to be published
pub fn create_key_package(nostr_id: String) -> Result<String> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let mut store = STORE.lock().await;
        let store = store
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get_mut(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        // Create key package
        let key_package_result = user.create_key_package()?;
        
        // Update storage
        user.update(nostr_id, true).await?;
        
        Ok(key_package_result.key_package)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mls::init_mls_db;
    use tempfile::tempdir;
    
    #[test]
    fn test_create_key_package() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test_mls.db");
        let db_path_str = db_path.to_str().unwrap().to_string();
        
        // Initialize MLS
        init_mls_db(db_path_str, "test_user".to_string()).unwrap();
        
        // Create key package
        let result = create_key_package("test_user".to_string());
        assert!(result.is_ok());
        
        let key_package = result.unwrap();
        assert!(!key_package.is_empty());
    }
}

