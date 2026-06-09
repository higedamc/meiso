use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use anyhow::{Context, Result};
use rand::RngCore;

/// セキュアな鍵ストレージ
/// Argon2id + AES-256-GCMで秘密鍵を暗号化保存
pub struct SecureKeyStore {
    storage_path: String,
}

impl SecureKeyStore {
    /// 新しいSecureKeyStoreインスタンスを作成
    pub fn new(storage_path: String) -> Self {
        dev_println!("🔐 SecureKeyStore initialized at: {}", storage_path);
        Self { storage_path }
    }

    /// パスワードから暗号化鍵を導出
    /// Argon2idを使用（メモリハード、サイドチャネル攻撃耐性）
    fn derive_key_from_password(password: &str, salt: &[u8]) -> Result<[u8; 32]> {
        use argon2::{Algorithm, Argon2, Params, Version};

        // Argon2idの設定
        let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, Params::default());

        // 32バイトの鍵を直接導出
        let mut key = [0u8; 32];
        argon2
            .hash_password_into(password.as_bytes(), salt, &mut key)
            .context("Failed to derive key with Argon2")?;

        Ok(key)
    }

    /// 秘密鍵を暗号化して保存
    ///
    /// フォーマット: [salt(16B)] + [nonce(12B)] + [ciphertext]
    pub async fn save_encrypted_key(&self, secret_key: &str, password: &str) -> Result<()> {
        dev_println!("🔐 Encrypting and saving secret key...");

        // 1. ランダムなsaltを生成（16バイト）
        let mut salt = [0u8; 16];
        OsRng.fill_bytes(&mut salt);

        // 2. パスワードから暗号化鍵を導出
        let key = Self::derive_key_from_password(password, &salt)?;

        // 3. ランダムなnonceを生成（12バイト）
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from(nonce_bytes);

        // 4. AES-256-GCMで暗号化
        let cipher = Aes256Gcm::new(&key.into());
        let ciphertext = cipher.encrypt(&nonce, secret_key.as_bytes()).map_err(|e| {
            anyhow::anyhow!("Failed to encrypt secret key with AES-256-GCM: {:?}", e)
        })?;

        // 5. ファイルに保存: salt + nonce + ciphertext
        let mut data = Vec::new();
        data.extend_from_slice(&salt);
        data.extend_from_slice(&nonce_bytes);
        data.extend_from_slice(&ciphertext);

        tokio::fs::write(&self.storage_path, data)
            .await
            .context("Failed to write encrypted key to file")?;

        dev_println!("✅ Secret key encrypted and saved successfully");
        Ok(())
    }

    /// 暗号化された秘密鍵をファイルから読み込んで復号化
    pub async fn load_encrypted_key(&self, password: &str) -> Result<String> {
        dev_println!("🔐 Loading and decrypting secret key...");

        // 1. ファイルから読み込み
        let data = tokio::fs::read(&self.storage_path)
            .await
            .context("Failed to read encrypted key file")?;

        // 2. データを分離: salt(16B) + nonce(12B) + ciphertext
        if data.len() < 28 {
            anyhow::bail!("Encrypted key file is too short (corrupted?)");
        }

        let salt = &data[0..16];
        let nonce_bytes = &data[16..28];
        let ciphertext = &data[28..];

        // 3. パスワードから復号化鍵を導出
        let key = Self::derive_key_from_password(password, salt)?;

        // 4. 復号化
        let cipher = Aes256Gcm::new(&key.into());
        let nonce =
            Nonce::from(*<&[u8; 12]>::try_from(nonce_bytes).context("Invalid nonce length")?);

        let plaintext = cipher
            .decrypt(&nonce, ciphertext)
            .map_err(|_| anyhow::anyhow!("Failed to decrypt secret key (wrong password?)"))?;

        let secret_key =
            String::from_utf8(plaintext).context("Decrypted data is not valid UTF-8")?;

        dev_println!("✅ Secret key decrypted successfully");
        Ok(secret_key)
    }

    /// Amber使用時: 公開鍵のみ保存（平文でOK）
    pub async fn save_public_key(&self, public_key: &str) -> Result<()> {
        let pub_path = format!("{}.pub", self.storage_path);
        dev_println!("🔐 Saving public key to: {}", pub_path);

        tokio::fs::write(&pub_path, public_key)
            .await
            .context("Failed to write public key to file")?;

        dev_println!("✅ Public key saved successfully");
        Ok(())
    }

    /// 公開鍵を読み込み（Amber使用時）
    pub async fn load_public_key(&self) -> Result<Option<String>> {
        let pub_path = format!("{}.pub", self.storage_path);

        match tokio::fs::read_to_string(&pub_path).await {
            Ok(key) => {
                dev_println!("✅ Public key loaded from: {}", pub_path);
                Ok(Some(key))
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                dev_println!("ℹ️ Public key file not found");
                Ok(None)
            }
            Err(e) => Err(e).context("Failed to read public key file"),
        }
    }

    /// 保存された鍵を全て削除
    pub async fn delete_keys(&self) -> Result<()> {
        dev_println!("🗑️ Deleting stored keys...");

        let mut deleted_count = 0;

        // 暗号化された秘密鍵を削除
        if tokio::fs::remove_file(&self.storage_path).await.is_ok() {
            dev_println!("✅ Deleted encrypted secret key");
            deleted_count += 1;
        }

        // 公開鍵を削除
        let pub_path = format!("{}.pub", self.storage_path);
        if tokio::fs::remove_file(&pub_path).await.is_ok() {
            dev_println!("✅ Deleted public key");
            deleted_count += 1;
        }

        if deleted_count > 0 {
            dev_println!("✅ Deleted {} key file(s)", deleted_count);
        } else {
            dev_println!("ℹ️ No key files found to delete");
        }

        Ok(())
    }

    /// 鍵ファイルが存在するか確認
    pub async fn has_encrypted_key(&self) -> bool {
        tokio::fs::metadata(&self.storage_path).await.is_ok()
    }

    /// 公開鍵ファイルが存在するか確認
    pub async fn has_public_key(&self) -> bool {
        let pub_path = format!("{}.pub", self.storage_path);
        tokio::fs::metadata(&pub_path).await.is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// テスト用の一時ディレクトリとパスを作成
    fn setup_test_storage() -> (TempDir, String) {
        let temp_dir = TempDir::new().unwrap();
        let storage_path = temp_dir
            .path()
            .join("test_key.enc")
            .to_str()
            .unwrap()
            .to_string();
        (temp_dir, storage_path)
    }

    #[tokio::test]
    async fn test_encrypt_and_decrypt() {
        let (_temp_dir, storage_path) = setup_test_storage();
        let store = SecureKeyStore::new(storage_path);

        let secret_key = "nsec1test1234567890abcdefghijklmnopqrstuvwxyz";
        let password = "my_secure_password_123";

        // 保存
        store
            .save_encrypted_key(secret_key, password)
            .await
            .unwrap();

        // 読み込み
        let loaded_key = store.load_encrypted_key(password).await.unwrap();

        assert_eq!(secret_key, loaded_key);
    }

    #[tokio::test]
    async fn test_wrong_password() {
        let (_temp_dir, storage_path) = setup_test_storage();
        let store = SecureKeyStore::new(storage_path);

        let secret_key = "nsec1test1234567890abcdefghijklmnopqrstuvwxyz";
        let password = "correct_password";
        let wrong_password = "wrong_password";

        // 保存
        store
            .save_encrypted_key(secret_key, password)
            .await
            .unwrap();

        // 間違ったパスワードで読み込み（失敗するはず）
        let result = store.load_encrypted_key(wrong_password).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_public_key_storage() {
        let (_temp_dir, storage_path) = setup_test_storage();
        let store = SecureKeyStore::new(storage_path);

        let public_key = "npub1test1234567890abcdefghijklmnopqrstuvwxyz";

        // 保存
        store.save_public_key(public_key).await.unwrap();

        // 読み込み
        let loaded_key = store.load_public_key().await.unwrap();
        assert_eq!(Some(public_key.to_string()), loaded_key);
    }

    #[tokio::test]
    async fn test_delete_keys() {
        let (_temp_dir, storage_path) = setup_test_storage();
        let store = SecureKeyStore::new(storage_path.clone());

        let secret_key = "nsec1test";
        let public_key = "npub1test";
        let password = "password";

        // 保存
        store
            .save_encrypted_key(secret_key, password)
            .await
            .unwrap();
        store.save_public_key(public_key).await.unwrap();

        // 存在確認
        assert!(store.has_encrypted_key().await);
        assert!(store.has_public_key().await);

        // 削除
        store.delete_keys().await.unwrap();

        // 削除確認
        assert!(!store.has_encrypted_key().await);
        assert!(!store.has_public_key().await);
    }

    #[tokio::test]
    async fn test_has_methods() {
        let (_temp_dir, storage_path) = setup_test_storage();
        let store = SecureKeyStore::new(storage_path);

        // 初期状態：何もない
        assert!(!store.has_encrypted_key().await);
        assert!(!store.has_public_key().await);

        // 秘密鍵を保存
        store
            .save_encrypted_key("nsec1test", "password")
            .await
            .unwrap();
        assert!(store.has_encrypted_key().await);
        assert!(!store.has_public_key().await);

        // 公開鍵を保存
        store.save_public_key("npub1test").await.unwrap();
        assert!(store.has_encrypted_key().await);
        assert!(store.has_public_key().await);
    }
}
