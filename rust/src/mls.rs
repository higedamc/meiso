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

use kc::group_context_extension::NostrGroupDataExtension;
use kc::user::MlsUser;
use nostr_sdk::prelude::*;
use openmls::prelude::tls_codec::{Deserialize as TlsDeserialize, Serialize as TlsSerialize};
use openmls::prelude::*;

/// MLS Store: Manages MLS state for each user
pub struct MlsStore {
    pub users: HashMap<String, User>,
}

/// User wrapper - Simplified version for PoC (Option B)
/// Full implementation (Option A) will be ported from Keychat later
pub struct User {
    pub mls_user: MlsUser,
}

// Ciphersuite for MLS (same as Keychat)
const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
const UNKNOWN_EXTENSION_TYPE: u16 = 0xF233;

impl User {
    /// Load user from storage
    pub async fn load(provider: OpenMlsRustPersistentCrypto, nostr_id: String) -> Result<MlsUser> {
        Ok(MlsUser::load(provider, nostr_id).await?)
    }

    /// Create MLS group (simplified - no members initially)
    pub fn create_mls_group(
        &mut self,
        group_id: String,
        description: String,
        group_name: String,
        admin_pubkeys_hex: Vec<String>,
        group_relays: Vec<String>,
        status: String,
    ) -> Result<Vec<u8>> {
        let identity = self
            .mls_user
            .identity
            .read()
            .map_err(|_| anyhow::anyhow!("Failed to acquire read lock"))?;

        // Create group extension
        let group_data = NostrGroupDataExtension::new(
            group_name.clone(),
            description,
            admin_pubkeys_hex,
            group_relays,
            status,
        );
        let serialized_group_data = group_data.tls_serialize_detached()?;

        // Setup extensions
        let required_extension_types = &[ExtensionType::Unknown(UNKNOWN_EXTENSION_TYPE)];
        let required_capabilities = Extension::RequiredCapabilities(
            RequiredCapabilitiesExtension::new(required_extension_types, &[], &[]),
        );
        let extensions = vec![
            Extension::Unknown(
                UNKNOWN_EXTENSION_TYPE,
                UnknownExtension(serialized_group_data),
            ),
            required_capabilities,
        ];

        // Get capabilities
        let capabilities: Capabilities = identity.create_capabilities()?;

        // Create group config
        let group_create_config = MlsGroupCreateConfig::builder()
            .capabilities(capabilities)
            .use_ratchet_tree_extension(true)
            .with_group_context_extensions(
                Extensions::from_vec(extensions)
                    .map_err(|e| anyhow::anyhow!("Failed to convert extensions: {:?}", e))?,
            )
            .map_err(|e| anyhow::anyhow!("Failed to create group config: {:?}", e))?
            .build();

        // Create MLS group
        let group_id_bytes = group_id.as_bytes();
        let mls_group = MlsGroup::new_with_group_id(
            &self.mls_user.provider,
            &identity.signer,
            &group_create_config,
            GroupId::from_slice(group_id_bytes),
            identity.credential_with_key.clone(),
        )
        .map_err(|e| anyhow::anyhow!("Failed to create MLS group: {:?}", e))?;

        // Store group
        drop(identity);
        let mut groups = self
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        groups.insert(group_id.clone(), kc::user::Group { mls_group });

        Ok(vec![]) // No welcome message for single-member group
    }

    /// Add members to group
    pub fn add_members(
        &mut self,
        group_id: String,
        key_packages: Vec<String>,
    ) -> Result<(String, Vec<u8>)> {
        let mut groups = self
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;

        // Parse key packages
        let mut kp_vec = Vec::new();
        for kp_hex in key_packages {
            let kp_bytes = hex::decode(&kp_hex)?;
            let key_package_in = KeyPackageIn::tls_deserialize(&mut kp_bytes.as_slice())
                .map_err(|e| anyhow::anyhow!("Failed to deserialize key package: {:?}", e))?;
            let key_package = key_package_in
                .validate(self.mls_user.provider.crypto(), ProtocolVersion::Mls10)
                .map_err(|e| anyhow::anyhow!("Failed to validate key package: {:?}", e))?;
            kp_vec.push(key_package);
        }

        // Add members
        let (queued_msg, welcome, _group_info) = group
            .mls_group
            .add_members(
                &self.mls_user.provider,
                &self.mls_user.identity.read().unwrap().signer,
                &kp_vec,
            )
            .map_err(|e| anyhow::anyhow!("Failed to add members: {:?}", e))?;

        // Serialize
        let queued_msg_bytes = queued_msg.tls_serialize_detached()?;
        let welcome_bytes = welcome.tls_serialize_detached()?;

        Ok((hex::encode(queued_msg_bytes), welcome_bytes))
    }

    /// Self commit (finalize pending proposals)
    ///
    /// Note: If add_members() was called, it already created a commit.
    /// In that case, we only need to merge the pending commit.
    pub fn self_commit(&mut self, group_id: String) -> Result<()> {
        let mut groups = self
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;

        // Check if there's already a pending commit (from add_members, etc.)
        if group.mls_group.pending_commit().is_some() {
            dev_println!(
                "📝 [MLS] Merging existing pending commit for group {}",
                group_id
            );
            // Only merge if commit already exists
            group
                .mls_group
                .merge_pending_commit(&self.mls_user.provider)
                .map_err(|e| anyhow::anyhow!("Failed to merge commit: {:?}", e))?;
        } else {
            dev_println!(
                "📝 [MLS] Creating and merging new commit for group {}",
                group_id
            );
            // Create new commit if none exists
            group
                .mls_group
                .commit_to_pending_proposals(
                    &self.mls_user.provider,
                    &self.mls_user.identity.read().unwrap().signer,
                )
                .map_err(|e| anyhow::anyhow!("Failed to commit: {:?}", e))?;

            group
                .mls_group
                .merge_pending_commit(&self.mls_user.provider)
                .map_err(|e| anyhow::anyhow!("Failed to merge commit: {:?}", e))?;
        }

        Ok(())
    }

    /// Create encrypted message
    pub fn create_message(&mut self, group_id: String, msg: String) -> Result<(String, String)> {
        let mut groups = self
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;

        // Encrypt message
        let encrypted = group
            .mls_group
            .create_message(
                &self.mls_user.provider,
                &self.mls_user.identity.read().unwrap().signer,
                msg.as_bytes(),
            )
            .map_err(|e| anyhow::anyhow!("Failed to encrypt message: {:?}", e))?;

        let encrypted_bytes = encrypted.tls_serialize_detached()?;

        // Get listen key from export secret
        let export_secret = group
            .mls_group
            // NIP-EE: exporter_secret MUST be 32 bytes labeled "nostr"
            // See: nips/EE.md (Group Events)
            .export_secret(&self.mls_user.provider, "nostr", b"", 32)?;
        let keypair = nostr_keys_from_export_secret(&export_secret)?;
        let listen_key = keypair.public_key().to_hex();

        Ok((hex::encode(encrypted_bytes), listen_key))
    }

    /// Decrypt message
    pub fn decrypt_msg(
        &mut self,
        group_id: String,
        msg: String,
    ) -> Result<(String, String, String)> {
        let msg_bytes = hex::decode(&msg)?;

        let mut groups = self
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;

        // Deserialize
        let mls_message_in = MlsMessageIn::tls_deserialize(&mut msg_bytes.as_slice())
            .map_err(|e| anyhow::anyhow!("Failed to deserialize message: {:?}", e))?;

        // Extract message body
        let protocol_message = match mls_message_in.extract() {
            MlsMessageBodyIn::PrivateMessage(pm) => pm,
            _ => return Err(anyhow::anyhow!("Not a private message")),
        };

        // Decrypt
        let (processed, _pending_proposals) = group
            .mls_group
            .process_message(&self.mls_user.provider, protocol_message)
            .map_err(|e| anyhow::anyhow!("Failed to process message: {:?}", e))?;

        // Extract content
        let (plaintext, sender) = match processed.into_content() {
            ProcessedMessageContent::ApplicationMessage(app_msg) => {
                let plaintext = String::from_utf8(app_msg.into_bytes())?;
                let sender = "unknown".to_string(); // Simplified
                (plaintext, sender)
            }
            _ => return Err(anyhow::anyhow!("Unexpected message type")),
        };

        // Get listen key
        let export_secret = group
            .mls_group
            // NIP-EE: exporter_secret MUST be 32 bytes labeled "nostr"
            .export_secret(&self.mls_user.provider, "nostr", b"", 32)?;
        let keypair = nostr_keys_from_export_secret(&export_secret)?;
        let listen_key = keypair.public_key().to_hex();

        Ok((plaintext, sender, listen_key))
    }

    /// Join MLS group
    pub fn join_mls_group(&mut self, group_id: String, welcome: Vec<u8>) -> Result<()> {
        dev_println!("🚀 [MLS] Starting join_mls_group for: {}", group_id);
        dev_println!("🔍 [MLS] Welcome message size: {} bytes", welcome.len());

        // Phase D.6: 既にグループに参加済みかチェック
        {
            let groups = self
                .mls_user
                .groups
                .read()
                .map_err(|_| anyhow::anyhow!("Failed to acquire read lock on groups"))?;

            dev_println!("🔍 [MLS] Current groups in storage: {}", groups.len());

            if groups.contains_key(&group_id) {
                dev_println!(
                    "ℹ️ [MLS] Already joined group: {}, skipping Welcome Message processing",
                    group_id
                );
                return Ok(());
            }
        }

        // Deserialize welcome
        dev_println!("📦 [MLS] Deserializing Welcome Message...");
        let welcome_in = MlsMessageIn::tls_deserialize(&mut welcome.as_slice()).map_err(|e| {
            dev_println!("❌ [MLS] Failed to deserialize Welcome Message: {:?}", e);
            anyhow::anyhow!("Failed to deserialize welcome: {:?}", e)
        })?;

        dev_println!("✅ [MLS] Welcome Message deserialized");

        let welcome_msg = match welcome_in.extract() {
            MlsMessageBodyIn::Welcome(w) => {
                dev_println!("✅ [MLS] Extracted Welcome body");
                w
            }
            _ => {
                dev_println!("❌ [MLS] Message is not a Welcome type");
                return Err(anyhow::anyhow!("Not a welcome message"));
            }
        };

        // Join group
        dev_println!("🔐 [MLS] Staging Welcome...");
        let staged_welcome = StagedWelcome::new_from_welcome(
            &self.mls_user.provider,
            &MlsGroupJoinConfig::default(),
            welcome_msg,
            None,
        )
        .map_err(|e| {
            dev_println!("❌ [MLS] Failed to stage welcome: {:?}", e);
            anyhow::anyhow!("Failed to stage welcome: {:?}", e)
        })?;

        dev_println!("✅ [MLS] Welcome staged successfully");

        dev_println!("👥 [MLS] Converting staged welcome into group...");
        let mls_group = staged_welcome
            .into_group(&self.mls_user.provider)
            .map_err(|e| {
                dev_println!("❌ [MLS] Failed to convert into group: {:?}", e);
                anyhow::anyhow!("Failed to join group: {:?}", e)
            })?;

        dev_println!("✅ [MLS] Group created from welcome");

        // Store group
        dev_println!("💾 [MLS] Storing group in memory...");
        let mut groups = self.mls_user.groups.write().map_err(|_| {
            dev_println!("❌ [MLS] Failed to acquire write lock");
            anyhow::anyhow!("Failed to acquire write lock on groups")
        })?;

        groups.insert(group_id.clone(), kc::user::Group { mls_group });

        dev_println!("✅ [MLS] Group stored successfully");
        dev_println!("✅ [MLS] Successfully joined group: {}", group_id);
        dev_println!("📊 [MLS] Total groups after join: {}", groups.len());

        Ok(())
    }

    /// Get MLS group info
    pub fn get_group_info(&self, group_id: String) -> Result<super::group_tasks_mls::MlsGroupInfo> {
        dev_println!("🔍 [MLS] Getting group info for: {}", group_id);

        let groups = self
            .mls_user
            .groups
            .read()
            .map_err(|_| anyhow::anyhow!("Failed to acquire read lock on groups"))?;

        dev_println!("🔍 [MLS] Total groups in storage: {}", groups.len());

        let group = groups.get(&group_id).ok_or_else(|| {
            dev_println!("❌ [MLS] Group {} not found in storage", group_id);
            dev_println!(
                "❌ [MLS] Available groups: {:?}",
                groups.keys().collect::<Vec<_>>()
            );
            anyhow::anyhow!("Group {} not found", group_id)
        })?;

        dev_println!("✅ [MLS] Group found, extracting info...");

        // Extract group name from extension
        let group_context_extensions = group.mls_group.export_group_context().extensions();
        let group_name = if let Some(extension) = group_context_extensions
            .iter()
            .find(|ext| matches!(ext, Extension::Unknown(UNKNOWN_EXTENSION_TYPE, _)))
        {
            if let Extension::Unknown(_, unknown) = extension {
                match NostrGroupDataExtension::tls_deserialize(&mut unknown.0.as_slice()) {
                    Ok(data) => {
                        let name = String::from_utf8(data.name)
                            .unwrap_or_else(|_| "Unknown Group".to_string());
                        dev_println!("✅ [MLS] Group name: {}", name);
                        name
                    }
                    Err(e) => {
                        dev_println!(
                            "⚠️ [MLS] Failed to deserialize group data extension: {:?}",
                            e
                        );
                        "Unknown Group".to_string()
                    }
                }
            } else {
                dev_println!("⚠️ [MLS] Extension is not Unknown type");
                "Unknown Group".to_string()
            }
        } else {
            dev_println!("⚠️ [MLS] No group data extension found");
            "Unknown Group".to_string()
        };

        // Get member public keys
        let mut member_pubkeys = Vec::new();
        let members = group.mls_group.members().collect::<Vec<_>>();
        dev_println!("🔍 [MLS] Total members: {}", members.len());

        for (idx, member) in members.iter().enumerate() {
            // Extract identity from credential
            // Phase D.6: Credential構造を詳細にログ出力して調査
            let identity_bytes = member.credential.serialized_content();
            let identity_hex = hex::encode(identity_bytes);

            dev_println!(
                "👤 [MLS] Member {}: {} bytes, hex: {}...",
                idx + 1,
                identity_bytes.len(),
                if identity_hex.len() > 32 {
                    &identity_hex[..32]
                } else {
                    &identity_hex
                }
            );

            member_pubkeys.push(identity_hex);
        }

        // Get epoch
        let epoch = group.mls_group.epoch().as_u64();
        dev_println!("📊 [MLS] Group epoch: {}", epoch);

        dev_println!("✅ [MLS] Group info retrieved successfully");

        Ok(super::group_tasks_mls::MlsGroupInfo {
            group_id: group_id.clone(),
            group_name,
            member_pubkeys,
            epoch,
        })
    }

    /// Create key package
    pub fn create_key_package(&mut self) -> Result<super::group_tasks_mls::KeyPackageResult> {
        let mut identity = self
            .mls_user
            .identity
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock"))?;

        let capabilities: Capabilities = identity.create_capabilities()?;
        let key_package =
            identity.add_key_package(CIPHERSUITE, &self.mls_user.provider, capabilities);

        let key_package_serialized = key_package.tls_serialize_detached()?;

        Ok(super::group_tasks_mls::KeyPackageResult {
            key_package: hex::encode(key_package_serialized),
            mls_protocol_version: "1.0".to_string(),
            ciphersuite: format!("{:?}", CIPHERSUITE),
            extensions: "".to_string(),
        })
    }

    /// Update storage
    pub async fn update(&mut self, _nostr_id: String, _is_identity: bool) -> Result<()> {
        // Simplified - auto-save is handled by provider
        Ok(())
    }
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
        storage
            .initialize()
            .map_err(|e| anyhow::anyhow!("Failed to initialize MLS storage: {}", e))?;

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

        // IMPORTANT:
        // Rust側のMLS Storeはプロセス内グローバルで保持している。
        // ここで毎回 `MlsUser::load()` して上書きすると、メモリ上の `groups` が失われ、
        // 招待受諾直後などに `mlsInitDb` が再度呼ばれた際にグループに入れない/復号できない不具合になる。
        //
        // そのため、同一 `nostr_id` が既に初期化済みなら再初期化をスキップする。
        if map.users.contains_key(&nostr_id) {
            dev_println!(
                "ℹ️ [MLS] init_mls_db: user already initialized, skipping reload: {}",
                nostr_id
            );
            return Ok(());
        }

        // Load or create user
        let mls_user = MlsUser::load(provider, nostr_id.clone()).await?;
        map.users.insert(nostr_id, User { mls_user });

        Ok(())
    })
}

/// Get export secret from MLS group
/// This is used to derive deterministic Nostr keypair
pub fn get_export_secret(nostr_id: String, group_id: String) -> Result<Vec<u8>> {
    get_export_secret_with_params(nostr_id, group_id, "nostr", b"")
}

/// Get listen key (Nostr pubkey) from export secret
/// This key is deterministically derived from the MLS group's export secret
pub fn get_listen_key_from_export_secret(nostr_id: String, group_id: String) -> Result<String> {
    let export_secret = get_export_secret(nostr_id, group_id)?;
    let keypair = nostr_keys_from_export_secret(&export_secret)?;
    Ok(keypair.public_key().to_hex())
}

/// Backward compatibility:
/// previous Meiso implementation used exporter_secret(label="meiso", context=b"todo").
/// We keep this for *decrypt fallback* so older events can still be recovered.
pub(crate) fn get_export_secret_legacy_meiso_todo(
    nostr_id: String,
    group_id: String,
) -> Result<Vec<u8>> {
    get_export_secret_with_params(nostr_id, group_id, "meiso", b"todo")
}

fn get_export_secret_with_params(
    nostr_id: String,
    group_id: String,
    label: &'static str,
    context: &'static [u8],
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
            .ok_or_else(|| anyhow::anyhow!("User {} not found in MLS store", nostr_id))?;

        // Get MLS group
        let mut groups = user
            .mls_user
            .groups
            .write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire write lock on groups"))?;

        let group = groups
            .get_mut(&group_id)
            .ok_or_else(|| anyhow::anyhow!("Group {} not found", group_id))?;

        let export_secret =
            group
                .mls_group
                .export_secret(&user.mls_user.provider, label, context, 32)?;

        Ok(export_secret)
    })
}

/// Derive a deterministic Nostr keypair from MLS exporter_secret.
///
/// IMPORTANT:
/// - NIP-EE specifies using the 32-byte exporter_secret (label "nostr") as a *secret key*.
/// - Do NOT use `Keys::parse(hex)` here: 64-hex strings are ambiguous (pubkey vs seckey).
///   We want an unambiguous "secret key from bytes" conversion.
pub(crate) fn nostr_keys_from_export_secret(export_secret: &[u8]) -> Result<nostr_sdk::Keys> {
    use nostr_sdk::{Keys, SecretKey};

    let secret_key = SecretKey::from_slice(export_secret).map_err(|e| {
        anyhow::anyhow!(
            "Failed to derive nostr SecretKey from exporter_secret: {:?}",
            e
        )
    })?;
    Ok(Keys::new(secret_key))
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
