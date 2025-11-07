/// グループタスク管理（マルチパーティ暗号化）
/// 
/// fiatjaf's NIP-72 proposal に基づいた実装:
/// 1. ランダムなAES-256鍵でタスクリストを暗号化
/// 2. 各メンバーの公開鍵でAES鍵をNIP-44暗号化
/// 3. メンバー追加時は新メンバー用に鍵を暗号化
/// 4. メンバー削除時は新しいAES鍵で再暗号化（Forward Secrecy）

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use anyhow::{Context, Result};
use ::base64::{engine::general_purpose, Engine as _};
use nostr_sdk::prelude::*;
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};

/// グループタスクデータ（暗号化前）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupTodoData {
    pub id: String,
    pub title: String,
    pub completed: bool,
    pub date: Option<String>,
    pub order: i32,
    pub created_at: String,
    pub updated_at: String,
}

/// 暗号化されたグループタスクリスト
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupTodoList {
    pub group_id: String,
    pub group_name: String,
    pub encrypted_data: String,         // base64エンコードされた暗号化タスクデータ
    pub members: Vec<String>,           // メンバーの公開鍵リスト（hex）
    pub encrypted_keys: Vec<EncryptedKey>, // 各メンバー用に暗号化されたAES鍵
}

/// メンバー用に暗号化されたAES鍵
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedKey {
    pub member_pubkey: String,          // メンバーの公開鍵（hex）
    pub encrypted_aes_key: String,      // NIP-44で暗号化されたAES鍵（base64）
}

/// グループタスクを暗号化
/// 
/// 1. ランダムなAES-256鍵を生成
/// 2. タスクデータをAES-256-GCMで暗号化
/// 3. 各メンバーの公開鍵でAES鍵をNIP-44暗号化
pub fn encrypt_group_tasks(
    tasks: Vec<GroupTodoData>,
    group_id: String,
    group_name: String,
    member_pubkeys: Vec<String>,
    my_keys: &Keys,
) -> Result<GroupTodoList> {
    // 1. タスクデータをJSONに変換
    let tasks_json = serde_json::to_string(&tasks)?;

    // 2. ランダムなAES-256鍵を生成
    let mut aes_key_bytes = [0u8; 32];
    OsRng.fill_bytes(&mut aes_key_bytes);

    // 3. タスクデータをAES-256-GCMで暗号化
    let cipher = Aes256Gcm::new(&aes_key_bytes.into());

    // ノンスを生成（12バイト）
    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from(nonce_bytes);

    // 暗号化
    let ciphertext = cipher
        .encrypt(&nonce, tasks_json.as_bytes())
        .map_err(|e| anyhow::anyhow!("AES encryption failed: {}", e))?;

    // ノンス + 暗号文を結合してbase64エンコード
    let mut encrypted_data_bytes = nonce_bytes.to_vec();
    encrypted_data_bytes.extend_from_slice(&ciphertext);
    let encrypted_data = general_purpose::STANDARD.encode(&encrypted_data_bytes);

    // 4. 各メンバーの公開鍵でAES鍵をNIP-44暗号化
    let mut encrypted_keys = Vec::new();

    for member_pubkey_hex in &member_pubkeys {
        let member_pubkey = PublicKey::from_hex(member_pubkey_hex)?;

        // NIP-44でAES鍵を暗号化
        let encrypted_aes_key = nip44::encrypt(
            my_keys.secret_key(),
            &member_pubkey,
            &general_purpose::STANDARD.encode(&aes_key_bytes),
            nip44::Version::V2,
        )?;

        encrypted_keys.push(EncryptedKey {
            member_pubkey: member_pubkey_hex.clone(),
            encrypted_aes_key,
        });
    }

    Ok(GroupTodoList {
        group_id,
        group_name,
        encrypted_data,
        members: member_pubkeys,
        encrypted_keys,
    })
}

/// グループタスクを復号化
/// 
/// 1. 自分の秘密鍵でAES鍵をNIP-44復号化
/// 2. AES鍵でタスクデータを復号化
pub fn decrypt_group_tasks(
    group_list: &GroupTodoList,
    my_keys: &Keys,
) -> Result<Vec<GroupTodoData>> {
    let my_pubkey = my_keys.public_key().to_hex();

    // 1. 自分用に暗号化されたAES鍵を見つける
    let my_encrypted_key = group_list
        .encrypted_keys
        .iter()
        .find(|k| k.member_pubkey == my_pubkey)
        .context("No encrypted key found for current user")?;

    // 2. NIP-44でAES鍵を復号化
    let aes_key_base64 = nip44::decrypt(
        my_keys.secret_key(),
        &my_keys.public_key(),
        &my_encrypted_key.encrypted_aes_key,
    )?;

    let aes_key_bytes = general_purpose::STANDARD
        .decode(&aes_key_base64)
        .context("Failed to decode AES key from base64")?;

    if aes_key_bytes.len() != 32 {
        return Err(anyhow::anyhow!(
            "Invalid AES key length: {}",
            aes_key_bytes.len()
        ));
    }

    // 3. 暗号化データをbase64デコード
    let encrypted_data_bytes = general_purpose::STANDARD
        .decode(&group_list.encrypted_data)
        .context("Failed to decode encrypted data from base64")?;

    // ノンス（最初の12バイト）と暗号文を分離
    if encrypted_data_bytes.len() < 12 {
        return Err(anyhow::anyhow!("Encrypted data too short"));
    }

    let (nonce_bytes, ciphertext) = encrypted_data_bytes.split_at(12);
    let mut nonce_array = [0u8; 12];
    nonce_array.copy_from_slice(nonce_bytes);
    let nonce = Nonce::from(nonce_array);

    // 4. AES-256-GCMで復号化
    let mut aes_key_array = [0u8; 32];
    aes_key_array.copy_from_slice(&aes_key_bytes);

    let cipher = Aes256Gcm::new(&aes_key_array.into());
    let plaintext_bytes = cipher
        .decrypt(&nonce, ciphertext)
        .map_err(|e| anyhow::anyhow!("AES decryption failed: {}", e))?;

    // 5. JSONからタスクデータをパース
    let plaintext = String::from_utf8(plaintext_bytes)?;
    let tasks: Vec<GroupTodoData> = serde_json::from_str(&plaintext)?;

    Ok(tasks)
}

/// グループにメンバーを追加
/// 
/// 新しいメンバー用にAES鍵を暗号化して追加
pub fn add_member_to_group(
    group_list: &mut GroupTodoList,
    new_member_pubkey: String,
    my_keys: &Keys,
) -> Result<()> {
    // 既に存在するメンバーかチェック
    if group_list.members.contains(&new_member_pubkey) {
        return Err(anyhow::anyhow!("Member already exists in group"));
    }

    // 1. 現在のAES鍵を復号化
    let my_pubkey = my_keys.public_key().to_hex();
    let my_encrypted_key = group_list
        .encrypted_keys
        .iter()
        .find(|k| k.member_pubkey == my_pubkey)
        .context("No encrypted key found for current user")?;

    let aes_key_base64 = nip44::decrypt(
        my_keys.secret_key(),
        &my_keys.public_key(),
        &my_encrypted_key.encrypted_aes_key,
    )?;

    let aes_key_bytes = general_purpose::STANDARD
        .decode(&aes_key_base64)
        .context("Failed to decode AES key from base64")?;

    // 2. 新しいメンバーの公開鍵でAES鍵を暗号化
    let new_member_pubkey_obj = PublicKey::from_hex(&new_member_pubkey)?;

    let encrypted_aes_key = nip44::encrypt(
        my_keys.secret_key(),
        &new_member_pubkey_obj,
        &general_purpose::STANDARD.encode(&aes_key_bytes),
        nip44::Version::V2,
    )?;

    // 3. メンバーリストと暗号化鍵リストに追加
    group_list.members.push(new_member_pubkey.clone());
    group_list.encrypted_keys.push(EncryptedKey {
        member_pubkey: new_member_pubkey,
        encrypted_aes_key,
    });

    Ok(())
}

/// グループからメンバーを削除（Forward Secrecy）
/// 
/// メンバー削除後は新しいAES鍵で全体を再暗号化し、
/// 削除されたメンバーが今後のアップデートを復号できないようにする
pub fn remove_member_from_group(
    group_list: &GroupTodoList,
    _member_to_remove: String,
    my_keys: &Keys,
) -> Result<GroupTodoList> {
    // 1. 現在のタスクデータを復号化
    let tasks = decrypt_group_tasks(group_list, my_keys)?;

    // 2. 削除後のメンバーリストを作成
    let remaining_members: Vec<String> = group_list
        .members
        .iter()
        .filter(|m| **m != _member_to_remove)
        .cloned()
        .collect();

    if remaining_members.is_empty() {
        return Err(anyhow::anyhow!("Cannot remove all members from group"));
    }

    // 3. 新しいAES鍵で再暗号化（Forward Secrecy）
    encrypt_group_tasks(
        tasks,
        group_list.group_id.clone(),
        group_list.group_name.clone(),
        remaining_members,
        my_keys,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt_group_tasks() {
        // テスト用の鍵を生成
        let keys1 = Keys::generate();
        let keys2 = Keys::generate();

        let member_pubkeys = vec![keys1.public_key().to_hex(), keys2.public_key().to_hex()];

        // テストデータ
        let tasks = vec![
            GroupTodoData {
                id: "task1".to_string(),
                title: "Test Task 1".to_string(),
                completed: false,
                date: None,
                order: 0,
                created_at: "2024-01-01T00:00:00Z".to_string(),
                updated_at: "2024-01-01T00:00:00Z".to_string(),
            },
            GroupTodoData {
                id: "task2".to_string(),
                title: "Test Task 2".to_string(),
                completed: true,
                date: Some("2024-01-02".to_string()),
                order: 1,
                created_at: "2024-01-02T00:00:00Z".to_string(),
                updated_at: "2024-01-02T00:00:00Z".to_string(),
            },
        ];

        // 暗号化
        let encrypted_group = encrypt_group_tasks(
            tasks.clone(),
            "test-group".to_string(),
            "Test Group".to_string(),
            member_pubkeys,
            &keys1,
        )
        .unwrap();

        // メンバー1で復号化
        let decrypted_tasks1 = decrypt_group_tasks(&encrypted_group, &keys1).unwrap();
        assert_eq!(decrypted_tasks1.len(), 2);
        assert_eq!(decrypted_tasks1[0].id, "task1");
        assert_eq!(decrypted_tasks1[1].id, "task2");

        // メンバー2で復号化
        let decrypted_tasks2 = decrypt_group_tasks(&encrypted_group, &keys2).unwrap();
        assert_eq!(decrypted_tasks2.len(), 2);
        assert_eq!(decrypted_tasks2[0].title, "Test Task 1");
        assert_eq!(decrypted_tasks2[1].title, "Test Task 2");
    }

    #[test]
    fn test_add_member_to_group() {
        let keys1 = Keys::generate();
        let keys2 = Keys::generate();
        let keys3 = Keys::generate();

        let member_pubkeys = vec![keys1.public_key().to_hex(), keys2.public_key().to_hex()];

        let tasks = vec![GroupTodoData {
            id: "task1".to_string(),
            title: "Test Task".to_string(),
            completed: false,
            date: None,
            order: 0,
            created_at: "2024-01-01T00:00:00Z".to_string(),
            updated_at: "2024-01-01T00:00:00Z".to_string(),
        }];

        let mut encrypted_group = encrypt_group_tasks(
            tasks,
            "test-group".to_string(),
            "Test Group".to_string(),
            member_pubkeys,
            &keys1,
        )
        .unwrap();

        // メンバー3を追加
        add_member_to_group(&mut encrypted_group, keys3.public_key().to_hex(), &keys1).unwrap();

        // メンバー3で復号化できることを確認
        let decrypted_tasks = decrypt_group_tasks(&encrypted_group, &keys3).unwrap();
        assert_eq!(decrypted_tasks.len(), 1);
        assert_eq!(decrypted_tasks[0].title, "Test Task");
    }

    #[test]
    fn test_remove_member_from_group() {
        let keys1 = Keys::generate();
        let keys2 = Keys::generate();

        let member_pubkeys = vec![keys1.public_key().to_hex(), keys2.public_key().to_hex()];

        let tasks = vec![GroupTodoData {
            id: "task1".to_string(),
            title: "Test Task".to_string(),
            completed: false,
            date: None,
            order: 0,
            created_at: "2024-01-01T00:00:00Z".to_string(),
            updated_at: "2024-01-01T00:00:00Z".to_string(),
        }];

        let encrypted_group = encrypt_group_tasks(
            tasks,
            "test-group".to_string(),
            "Test Group".to_string(),
            member_pubkeys,
            &keys1,
        )
        .unwrap();

        // メンバー2を削除（Forward Secrecy）
        let new_encrypted_group =
            remove_member_from_group(&encrypted_group, keys2.public_key().to_hex(), &keys1)
                .unwrap();

        // メンバー1は復号化できる
        let decrypted_tasks = decrypt_group_tasks(&new_encrypted_group, &keys1).unwrap();
        assert_eq!(decrypted_tasks.len(), 1);

        // メンバー2は復号化できない（新しいAES鍵で再暗号化されているため）
        let result = decrypt_group_tasks(&new_encrypted_group, &keys2);
        assert!(result.is_err());
    }
}
