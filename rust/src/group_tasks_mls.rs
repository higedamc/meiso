use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::time::{SystemTime, UNIX_EPOCH};
use crate::mls::{RUNTIME, STORE};

/// Result type for adding members to MLS group
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddMembersResult {
    pub queued_msg: String,
    pub welcome: Vec<u8>,
}

/// Result type for key package creation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyPackageResult {
    pub key_package: String,
    pub mls_protocol_version: String,
    pub ciphersuite: String,
    pub extensions: String,
}

/// Result type for MLS group info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MlsGroupInfo {
    pub group_id: String,
    pub group_name: String,
    pub member_pubkeys: Vec<String>,
    pub epoch: u64,
}

/// Phase D.8: Create an unsigned Nostr event (NIP-EE compliant)
/// 
/// # Arguments
/// * `sender_pubkey` - The sender's Nostr public key (hex)
/// * `todo_json` - JSON string of the TODO item
/// * `action` - The action type (add | update | delete | toggle | reorder | move)
/// * `todo_id` - Unique identifier for the TODO
/// * `list_id` - The group/list ID
/// 
/// # Returns
/// * JSON string of the unsigned Nostr event
fn create_unsigned_event(
    sender_pubkey: &str,
    todo_json: &str,
    action: &str,
    todo_id: &str,
    list_id: &str,
) -> Result<String> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)?
        .as_secs();
    
    let mut tag_rows: Vec<Vec<String>> = vec![
        vec!["d".to_string(), todo_id.to_string()],
        vec!["list_id".to_string(), list_id.to_string()],
        vec!["action".to_string(), action.to_string()],
    ];
    crate::nostr_client_meta::append_nip89_json_tag_rows(&mut tag_rows);
    let tags_value: Vec<serde_json::Value> =
        tag_rows.into_iter().map(|r| json!(r)).collect();

    let event = json!({
        "kind": 30078,
        "pubkey": sender_pubkey,
        "created_at": now,
        "tags": tags_value,
        "content": todo_json
        // NO "sig" field - unsigned event as per NIP-EE
    });
    
    dev_println!("📝 [Phase D.8] Created unsigned Nostr event:");
    dev_println!("   Kind: 30078");
    dev_println!("   Action: {}", action);
    dev_println!("   TODO ID: {}", todo_id);
    dev_println!("   List ID: {}", list_id);
    
    Ok(serde_json::to_string(&event)?)
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
        let _group_config = user.create_mls_group(
            group_id.clone(),
            "Meiso TODO Group".to_string(), // description
            group_name,
            vec![nostr_id.clone()], // admin pubkeys
            vec![], // relays (not used for TODO lists)
            "enabled".to_string(),
        )?;
        
        // Phase D.9.1: Key Packagesが空の場合は警告を出すが、テスト目的で許容
        if key_packages.is_empty() {
            dev_println!("⚠️ [MLS] Creating 1-person group (no other members)");
            dev_println!("⚠️ [MLS] Note: 1-person groups are only for testing purposes");
            dev_println!("⚠️ [MLS] In production, group lists require at least 2 people (self + 1 other member)");
            
            // 1人グループの場合はWelcome Messageは空（メンバー追加なし）
            dev_println!("✅ [MLS] Welcome message generated: 0 bytes (1-person group)");
            return Ok(vec![]); // 空のWelcome Message
        }
        
        // Add members (2人以上のグループ)
        let (_queued_msg, welcome) = user.add_members(group_id.clone(), key_packages)?;
        
        // Commit the changes
        user.self_commit(group_id)?;
        
        dev_println!("✅ [MLS] Welcome message generated: {} bytes", welcome.len());
        
        Ok(welcome)
    })
}

/// Phase D.8: Encrypt and add a TODO to an MLS group (NIP-EE compliant)
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// * `todo_json` - JSON string of the TODO item
/// * `action` - The action type (add | update | delete | toggle | reorder | move)
/// * `todo_id` - Unique identifier for the TODO
/// 
/// # Returns
/// * Encrypted message (hex) to be sent to the group via Nostr
pub fn add_todo_to_mls_group(
    nostr_id: String,
    group_id: String,
    todo_json: String,
    action: String,
    todo_id: String,
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
        
        // Phase D.8: Wrap TODO in unsigned Nostr event (NIP-EE compliant)
        let unsigned_event = create_unsigned_event(
            &nostr_id,
            &todo_json,
            &action,
            &todo_id,
            &group_id,
        )?;
        
        // Encrypt message using MLS
        let (encrypt_msg, _listen_key) = user.create_message(group_id, unsigned_event)?;
        
        Ok(encrypt_msg)
    })
}

/// Phase D.8: Decrypt a TODO from an MLS group message (NIP-EE compliant)
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// * `encrypted_msg` - Encrypted message (hex) from Nostr event
/// 
/// # Returns
/// * Tuple of (todo_content, action, todo_id, sender_pubkey, listen_key)
pub fn decrypt_todo_from_mls_group(
    nostr_id: String,
    group_id: String,
    encrypted_msg: String,
) -> Result<(String, String, String, String, String)> {
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
        
        // Phase D.8: Parse unsigned Nostr event
        let event: serde_json::Value = serde_json::from_str(&decrypt_msg)?;
        
        // Extract metadata from tags
        let tags = event["tags"]
            .as_array()
            .ok_or_else(|| anyhow::anyhow!("tags not found in event"))?;
        
        let action = tags
            .iter()
            .find(|tag| tag[0].as_str() == Some("action"))
            .and_then(|tag| tag[1].as_str())
            .unwrap_or("");
        
        let todo_id = tags
            .iter()
            .find(|tag| tag[0].as_str() == Some("d"))
            .and_then(|tag| tag[1].as_str())
            .unwrap_or("");
        
        let sender_pubkey = event["pubkey"]
            .as_str()
            .unwrap_or("");
        
        let todo_content = event["content"]
            .as_str()
            .unwrap_or("{}");
        
        dev_println!("📥 [Phase D.8] Decrypted unsigned Nostr event:");
        dev_println!("   Kind: {}", event["kind"]);
        dev_println!("   Action: {}", action);
        dev_println!("   TODO ID: {}", todo_id);
        dev_println!("   Sender: {}...", &sender_pubkey[..16.min(sender_pubkey.len())]);
        
        // Phase D.8: Backward compatibility - detect old format
        // If action is empty, it's Phase 9.1 format (direct TODO JSON)
        if action.is_empty() {
            dev_println!("ℹ️  [Phase D.8] Detected Phase 9.1 format (direct TODO JSON)");
            // Return original decrypted message as todo_content
            Ok((decrypt_msg, String::new(), String::new(), sender, listen_key))
        } else {
            // Phase D.8 format (unsigned Nostr event)
            Ok((
                todo_content.to_string(),
                action.to_string(),
                todo_id.to_string(),
                sender_pubkey.to_string(),
                listen_key,
            ))
        }
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

/// Get MLS group info
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// * `group_id` - The group ID
/// 
/// # Returns
/// * MlsGroupInfo containing group name, member pubkeys, and epoch
pub fn get_mls_group_info(nostr_id: String, group_id: String) -> Result<MlsGroupInfo> {
    let rt = RUNTIME.as_ref();
    rt.block_on(async {
        let store = STORE.lock().await;
        let store = store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("MLS store not initialized"))?;
        
        let user = store
            .users
            .get(&nostr_id)
            .ok_or_else(|| anyhow::anyhow!("User {} not found", nostr_id))?;
        
        user.get_group_info(group_id)
    })
}

/// Create a key package for this user
/// Key packages are published to Nostr relays (Kind 10443) so others can add you to groups
/// 
/// # Arguments
/// * `nostr_id` - The user's Nostr public key
/// 
/// # Returns
/// * KeyPackageResult containing hex-encoded key package and metadata
pub fn create_key_package(nostr_id: String) -> Result<KeyPackageResult> {
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
        
        Ok(key_package_result)
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

