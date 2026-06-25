//! Shared-Key Collaborative Lists (`shared-v1`)
//!
//! MLS を用いずに共同編集タスクを実現する軽量方式。共有リストごとに専用の
//! Nostr 鍵 `G`(group key)を 1 つ生成し、メンバー間で `nsec_G` を共有する。
//!
//! - タスクは 1 タスク = 1 addressable event(kind:35000)。`G` で署名し、
//!   content は NIP-44 v2 で `G` 宛に自己暗号化する。
//! - 同一 `(kind, author=G, d=task-id)` の replaceable 性により、relay レベルで
//!   タスク単位の Last-Write-Wins が自動成立する。
//!
//! 設計詳細は `docs/SHARED_LIST_STRATEGY.md` を参照。

use anyhow::{Context, Result};
use nostr_sdk::nips::nip44;
use nostr_sdk::prelude::*;
use serde::{Deserialize, Serialize};

/// 共有タスクイベントの kind(addressable, NIP-XXA 準拠)
pub const SHARED_TASK_KIND: u16 = 35000;
/// 共有リストメタデータイベントの kind(addressable)
pub const SHARED_META_KIND: u16 = 35001;
/// メタデータイベントの固定 `d` タグ値
pub const SHARED_META_D_TAG: &str = "meta";

/// 新規生成されたグループ鍵
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupKey {
    /// 秘密鍵(hex)。メンバー間で共有される共有秘密。ログ出力厳禁。
    pub nsec_hex: String,
    /// 公開鍵(hex)。タスクイベントの author になる。
    pub npub_hex: String,
}

/// 招待 payload(NIP-44 で封緘される平文)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvitationPayload {
    pub group_id: String,
    /// グループ秘密鍵(hex)
    pub group_nsec: String,
    /// グループ公開鍵(hex)。タスク購読の author フィルタに使用。
    pub group_npub: String,
    pub group_name: String,
    pub key_epoch: u64,
}

/// hex 秘密鍵から `Keys` を構築する。
fn keys_from_nsec_hex(group_nsec_hex: &str) -> Result<Keys> {
    let secret_key =
        SecretKey::from_hex(group_nsec_hex).context("Invalid group secret key (hex expected)")?;
    Ok(Keys::new(secret_key))
}

/// グループ秘密鍵(hex)から公開鍵(hex)を導出する。
pub fn npub_from_nsec(group_nsec_hex: &str) -> Result<String> {
    let keys = keys_from_nsec_hex(group_nsec_hex)?;
    Ok(keys.public_key().to_hex())
}

/// 新しいグループ鍵を生成する。
pub fn generate_group_key() -> GroupKey {
    let keys = Keys::generate();
    GroupKey {
        nsec_hex: keys.secret_key().to_secret_hex(),
        npub_hex: keys.public_key().to_hex(),
    }
}

/// task JSON から `id` フィールド(= addressable の `d` タグ)を取り出す。
fn extract_task_id(task_json: &str) -> Result<String> {
    let value: serde_json::Value =
        serde_json::from_str(task_json).context("task_json is not valid JSON")?;
    let id = value
        .get("id")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .context("task_json must contain a non-empty 'id' field")?;
    Ok(id.to_string())
}

/// content を NIP-44 v2 で `G` 宛に自己暗号化する。
fn encrypt_for_group(keys: &Keys, plaintext: &str) -> Result<String> {
    nip44::encrypt(
        keys.secret_key(),
        &keys.public_key(),
        plaintext,
        nip44::Version::V2,
    )
    .context("NIP-44 encryption failed")
}

/// `G` 宛に自己暗号化された content を復号する。
fn decrypt_for_group(keys: &Keys, ciphertext: &str) -> Result<String> {
    nip44::decrypt(keys.secret_key(), &keys.public_key(), ciphertext)
        .context("NIP-44 decryption failed")
}

/// 署名済みのタスクイベント(kind:35000)JSON を構築する。
///
/// 返り値は `send_signed_event` にそのまま渡せる署名済みイベント JSON。
pub fn build_signed_task_event(group_nsec_hex: String, task_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    let task_id = extract_task_id(&task_json)?;
    let ciphertext = encrypt_for_group(&keys, &task_json)?;

    let event = EventBuilder::new(Kind::Custom(SHARED_TASK_KIND), ciphertext)
        .tags([Tag::identifier(task_id)])
        .sign_with_keys(&keys)
        .context("Failed to sign shared task event")?;

    Ok(event.as_json())
}

/// タスクイベント(kind:35000)JSON を復号し、平文の task JSON を返す。
pub fn decrypt_task_event(group_nsec_hex: String, event_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    let event = Event::from_json(&event_json).context("Failed to parse task event JSON")?;
    decrypt_for_group(&keys, &event.content)
}

/// 署名済みのメタデータイベント(kind:35001, d="meta")JSON を構築する。
pub fn build_signed_meta_event(group_nsec_hex: String, meta_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    // meta_json の妥当性を最低限検証する。
    let _: serde_json::Value =
        serde_json::from_str(&meta_json).context("meta_json is not valid JSON")?;
    let ciphertext = encrypt_for_group(&keys, &meta_json)?;

    let event = EventBuilder::new(Kind::Custom(SHARED_META_KIND), ciphertext)
        .tags([Tag::identifier(SHARED_META_D_TAG.to_string())])
        .sign_with_keys(&keys)
        .context("Failed to sign shared meta event")?;

    Ok(event.as_json())
}

/// メタデータイベント(kind:35001)JSON を復号し、平文の meta JSON を返す。
pub fn decrypt_meta_event(group_nsec_hex: String, event_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    let event = Event::from_json(&event_json).context("Failed to parse meta event JSON")?;
    decrypt_for_group(&keys, &event.content)
}

/// 招待 payload の平文 JSON を構築する(NIP-44 封緘は呼び出し側 / Amber が行う)。
pub fn build_invitation_payload(
    group_id: String,
    group_nsec: String,
    group_npub: String,
    group_name: String,
    key_epoch: u64,
) -> Result<String> {
    let payload = InvitationPayload {
        group_id,
        group_nsec,
        group_npub,
        group_name,
        key_epoch,
    };
    serde_json::to_string(&payload).context("Failed to serialize invitation payload")
}

/// 招待 payload の平文 JSON を解析する。
pub fn parse_invitation_payload(payload_json: String) -> Result<InvitationPayload> {
    serde_json::from_str(&payload_json).context("Failed to parse invitation payload")
}

/// 秘密鍵モード用: 招待 payload を受信者宛に NIP-44 で封緘する。
///
/// Amber モードでは Flutter 側(Amber)で NIP-44 暗号化するため、本関数は用いない。
pub fn encrypt_invitation_for_recipient(
    inviter_nsec_hex: String,
    recipient_pubkey_hex: String,
    payload_json: String,
) -> Result<String> {
    let inviter_keys = keys_from_nsec_hex(&inviter_nsec_hex)?;
    let recipient =
        PublicKey::from_hex(&recipient_pubkey_hex).context("Invalid recipient public key")?;
    nip44::encrypt(
        inviter_keys.secret_key(),
        &recipient,
        &payload_json,
        nip44::Version::V2,
    )
    .context("Failed to NIP-44 encrypt invitation")
}

/// 秘密鍵モード用: 受信した招待を復号して payload を取り出す。
pub fn decrypt_invitation_from_sender(
    recipient_nsec_hex: String,
    sender_pubkey_hex: String,
    ciphertext: String,
) -> Result<InvitationPayload> {
    let recipient_keys = keys_from_nsec_hex(&recipient_nsec_hex)?;
    let sender = PublicKey::from_hex(&sender_pubkey_hex).context("Invalid sender public key")?;
    let plaintext = nip44::decrypt(recipient_keys.secret_key(), &sender, &ciphertext)
        .context("Failed to NIP-44 decrypt invitation")?;
    parse_invitation_payload(plaintext)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_task(id: &str, title: &str) -> String {
        serde_json::json!({
            "id": id,
            "title": title,
            "status": "open",
            "order": "0|hzzzz",
            "list_id": "group-123",
            "deleted": false,
        })
        .to_string()
    }

    #[test]
    fn generate_group_key_roundtrips_to_keys() {
        let gk = generate_group_key();
        let keys = keys_from_nsec_hex(&gk.nsec_hex).unwrap();
        assert_eq!(keys.public_key().to_hex(), gk.npub_hex);
        assert_eq!(gk.nsec_hex.len(), 64);
        assert_eq!(gk.npub_hex.len(), 64);
    }

    #[test]
    fn task_event_is_signed_addressable_and_encrypted() {
        let gk = generate_group_key();
        let task = sample_task("task-1", "Buy groceries");
        let event_json = build_signed_task_event(gk.nsec_hex.clone(), task.clone()).unwrap();

        let event = Event::from_json(&event_json).unwrap();
        // kind と author を検証
        assert_eq!(event.kind, Kind::Custom(SHARED_TASK_KIND));
        assert_eq!(event.pubkey.to_hex(), gk.npub_hex);
        // 署名が正しい
        event.verify().unwrap();
        // d タグ = task id
        assert_eq!(event.tags.identifier(), Some("task-1"));
        // content は平文ではない(暗号化されている)
        assert!(!event.content.contains("Buy groceries"));
    }

    #[test]
    fn task_event_decrypts_back_to_plaintext() {
        let gk = generate_group_key();
        let task = sample_task("task-1", "Buy groceries");
        let event_json = build_signed_task_event(gk.nsec_hex.clone(), task.clone()).unwrap();

        let decrypted = decrypt_task_event(gk.nsec_hex.clone(), event_json).unwrap();
        let original: serde_json::Value = serde_json::from_str(&task).unwrap();
        let roundtrip: serde_json::Value = serde_json::from_str(&decrypted).unwrap();
        assert_eq!(original, roundtrip);
    }

    #[test]
    fn other_group_key_cannot_decrypt() {
        let gk = generate_group_key();
        let other = generate_group_key();
        let task = sample_task("task-1", "Secret");
        let event_json = build_signed_task_event(gk.nsec_hex.clone(), task).unwrap();

        // 別グループ鍵では復号できない
        assert!(decrypt_task_event(other.nsec_hex, event_json).is_err());
    }

    #[test]
    fn task_without_id_is_rejected() {
        let gk = generate_group_key();
        let bad = serde_json::json!({ "title": "no id" }).to_string();
        assert!(build_signed_task_event(gk.nsec_hex, bad).is_err());
    }

    #[test]
    fn meta_event_roundtrips() {
        let gk = generate_group_key();
        let meta = serde_json::json!({
            "name": "Shared Groceries",
            "key_epoch": 1,
            "members": [],
        })
        .to_string();
        let event_json = build_signed_meta_event(gk.nsec_hex.clone(), meta.clone()).unwrap();
        let event = Event::from_json(&event_json).unwrap();
        assert_eq!(event.kind, Kind::Custom(SHARED_META_KIND));
        assert_eq!(event.tags.identifier(), Some(SHARED_META_D_TAG));

        let decrypted = decrypt_meta_event(gk.nsec_hex, event_json).unwrap();
        let roundtrip: serde_json::Value = serde_json::from_str(&decrypted).unwrap();
        assert_eq!(roundtrip["name"], "Shared Groceries");
    }

    /// Alice↔Bob の full handshake + 双方向 task 同期 + tombstone を end-to-end でなぞる。
    /// リレー I/O は介在しないが、暗号操作・署名・LWW セマンティクスを総合検証する。
    #[test]
    fn alice_bob_end_to_end_collaboration() {
        // 1. Alice がグループ鍵 G を作成
        let g = generate_group_key();
        let alice = Keys::generate();
        let bob = Keys::generate();

        // 2. Alice が Bob 宛に nsec_G を NIP-44 封緘して送信
        let invite_payload = build_invitation_payload(
            "list-1".to_string(),
            g.nsec_hex.clone(),
            g.npub_hex.clone(),
            "Groceries".to_string(),
            1,
        )
        .unwrap();
        let ciphertext = encrypt_invitation_for_recipient(
            alice.secret_key().to_secret_hex(),
            bob.public_key().to_hex(),
            invite_payload,
        )
        .unwrap();

        // 3. Bob が招待を復号して nsec_G を入手
        let bob_view = decrypt_invitation_from_sender(
            bob.secret_key().to_secret_hex(),
            alice.public_key().to_hex(),
            ciphertext,
        )
        .unwrap();
        assert_eq!(bob_view.group_nsec, g.nsec_hex);
        assert_eq!(bob_view.group_npub, g.npub_hex);

        // 4. Alice が task A を発行(共有鍵 G で署名・暗号化)
        let task_a = serde_json::json!({
            "id": "task-A",
            "title": "Milk",
            "status": "open",
            "order": "0|m",
            "editor_pubkey": alice.public_key().to_hex(),
            "updated_at": "2026-01-01T00:00:00Z",
        })
        .to_string();
        let event_a = build_signed_task_event(g.nsec_hex.clone(), task_a).unwrap();

        // 5. Bob が(同じ G で)task B を発行
        let task_b = serde_json::json!({
            "id": "task-B",
            "title": "Bread",
            "status": "open",
            "order": "0|n",
            "editor_pubkey": bob.public_key().to_hex(),
            "updated_at": "2026-01-01T00:00:01Z",
        })
        .to_string();
        let event_b = build_signed_task_event(bob_view.group_nsec.clone(), task_b).unwrap();

        // 6. 双方向に復号できる(リレー越しのフェッチを擬似)
        let alice_sees_b: serde_json::Value =
            serde_json::from_str(&decrypt_task_event(g.nsec_hex.clone(), event_b.clone()).unwrap())
                .unwrap();
        assert_eq!(alice_sees_b["title"], "Bread");
        assert_eq!(alice_sees_b["editor_pubkey"], bob.public_key().to_hex());

        let bob_sees_a: serde_json::Value = serde_json::from_str(
            &decrypt_task_event(bob_view.group_nsec.clone(), event_a.clone()).unwrap(),
        )
        .unwrap();
        assert_eq!(bob_sees_a["title"], "Milk");

        // 7. 第三者(共有鍵を持たない attacker)は復号不能
        let attacker = generate_group_key();
        assert!(decrypt_task_event(attacker.nsec_hex.clone(), event_a.clone()).is_err());
        assert!(decrypt_task_event(attacker.nsec_hex, event_b.clone()).is_err());

        // 8. LWW: Alice が task-A を更新 (status: done)
        let task_a_done = serde_json::json!({
            "id": "task-A",
            "title": "Milk",
            "status": "done",
            "order": "0|m",
            "editor_pubkey": alice.public_key().to_hex(),
            "updated_at": "2026-01-01T01:00:00Z",
        })
        .to_string();
        let event_a_done = build_signed_task_event(g.nsec_hex.clone(), task_a_done).unwrap();
        let evt_done = Event::from_json(&event_a_done).unwrap();
        let evt_old = Event::from_json(&event_a).unwrap();
        // 同じ d タグ + 同じ author なので relay レベルで LWW(後勝ち)
        assert_eq!(evt_done.tags.identifier(), Some("task-A"));
        assert_eq!(evt_old.tags.identifier(), Some("task-A"));
        assert!(evt_done.created_at >= evt_old.created_at);

        // 9. Tombstone: Bob が task-B を削除(`deleted: true` を載せた addressable)
        let task_b_tombstone = serde_json::json!({
            "id": "task-B",
            "title": "Bread",
            "deleted": true,
            "editor_pubkey": bob.public_key().to_hex(),
            "updated_at": "2026-01-01T02:00:00Z",
        })
        .to_string();
        let event_b_del =
            build_signed_task_event(bob_view.group_nsec, task_b_tombstone).unwrap();
        let alice_sees_del: serde_json::Value = serde_json::from_str(
            &decrypt_task_event(g.nsec_hex.clone(), event_b_del.clone()).unwrap(),
        )
        .unwrap();
        assert_eq!(alice_sees_del["deleted"], true);
    }

    #[test]
    fn invitation_payload_roundtrips_via_nip44() {
        let gk = generate_group_key();
        let inviter = Keys::generate();
        let recipient = Keys::generate();

        let payload = build_invitation_payload(
            "group-123".to_string(),
            gk.nsec_hex.clone(),
            gk.npub_hex.clone(),
            "Shared Groceries".to_string(),
            1,
        )
        .unwrap();

        let ciphertext = encrypt_invitation_for_recipient(
            inviter.secret_key().to_secret_hex(),
            recipient.public_key().to_hex(),
            payload,
        )
        .unwrap();

        let decoded = decrypt_invitation_from_sender(
            recipient.secret_key().to_secret_hex(),
            inviter.public_key().to_hex(),
            ciphertext,
        )
        .unwrap();

        assert_eq!(decoded.group_id, "group-123");
        assert_eq!(decoded.group_nsec, gk.nsec_hex);
        assert_eq!(decoded.key_epoch, 1);
    }
}
