//! Task Chat (per-task comments)
//!
//! タスク単位のコメントを 1 コメント = 1 addressable event(kind:35002)で表現する。
//! 外形・暗号経路は shared-v1(`group_tasks_shared.rs`)に揃える:
//!
//! - 共有リスト: グループ鍵 `G` で署名し、content は NIP-44 v2 で `G` 宛に自己暗号化。
//! - 個人タスク: 利用者自身の鍵で署名し、self NIP-44(kind:30078 設定と同経路)。
//! - タグは `["d", comment_id]` のみ。タスクとの紐付けは暗号化ペイロード内の
//!   `task_id` で持ち、リレーにコメント↔タスクのグラフを露出させない。
//! - 同一 `(kind, author, d)` の replaceable 性で LWW が成立し、編集は同一 `d` の
//!   再発行、削除は tombstone(`deleted: true` + `body` 空文字)の再発行で行う。
//!
//! 設計詳細は `docs/TASK_CHAT_DESIGN.md` を参照。

use anyhow::{bail, Context, Result};
use nostr_sdk::nips::nip44;
use nostr_sdk::prelude::*;
use serde::{Deserialize, Serialize};

/// タスクコメントイベントの kind(addressable)
pub const TASK_COMMENT_KIND: u16 = 35002;
/// ペイロードのスキーマバージョン
pub const TASK_COMMENT_SCHEMA_VERSION: u32 = 1;
/// `body` の最大文字数(書き込み・読み出し両側でクランプ)
pub const MAX_COMMENT_BODY_CHARS: usize = 2000;

/// コメント payload(NIP-44 で封緘される平文)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskCommentPayload {
    /// スキーマバージョン(現行 1)
    pub v: u32,
    /// コメント ID(UUID)。addressable の `d` タグ値。
    pub comment_id: String,
    /// 紐付くタスクの ID。リレーには出さずペイロード内でのみ保持する。
    pub task_id: String,
    /// 表示用の投稿者公開鍵(hex)。shared-v1 の editor_pubkey と同じ自己申告モデル。
    pub author_pubkey: String,
    /// 本文。tombstone では空文字。
    pub body: String,
    /// 投稿時刻(unix 秒)。LWW の順序判定はイベントの created_at 側で行う。
    pub created_at: u64,
    /// 最終編集時刻(未編集なら None)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub edited_at: Option<u64>,
    /// 削除 tombstone フラグ
    #[serde(default)]
    pub deleted: bool,
    /// 返信先コメント ID(将来のスレッド用予約。1.5.0 UI では未使用)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parent_comment_id: Option<String>,
}

/// payload JSON を検証してパースする。受信側(復号直後)にも必ず通すこと。
pub fn parse_comment_payload(payload_json: &str) -> Result<TaskCommentPayload> {
    let payload: TaskCommentPayload =
        serde_json::from_str(payload_json).context("comment payload is not valid JSON")?;
    validate_comment_payload(&payload)?;
    Ok(payload)
}

/// payload の不変条件を検証する。
pub fn validate_comment_payload(payload: &TaskCommentPayload) -> Result<()> {
    if payload.v != TASK_COMMENT_SCHEMA_VERSION {
        bail!("unsupported comment schema version: {}", payload.v);
    }
    if payload.comment_id.is_empty() {
        bail!("comment_id must not be empty");
    }
    if payload.task_id.is_empty() {
        bail!("task_id must not be empty");
    }
    if payload.author_pubkey.len() != 64
        || !payload.author_pubkey.chars().all(|c| c.is_ascii_hexdigit())
    {
        bail!("author_pubkey must be 64-char hex");
    }
    if payload.body.chars().count() > MAX_COMMENT_BODY_CHARS {
        bail!("body exceeds {} chars", MAX_COMMENT_BODY_CHARS);
    }
    if payload.deleted && !payload.body.is_empty() {
        bail!("tombstone must have an empty body");
    }
    Ok(())
}

/// hex 秘密鍵から `Keys` を構築する(`group_tasks_shared` と同形)。
fn keys_from_nsec_hex(nsec_hex: &str) -> Result<Keys> {
    let secret_key = SecretKey::from_hex(nsec_hex).context("Invalid secret key (hex expected)")?;
    Ok(Keys::new(secret_key))
}

/// content を NIP-44 v2 で署名鍵の公開鍵宛に自己暗号化する。
fn encrypt_for_self(keys: &Keys, plaintext: &str) -> Result<String> {
    nip44::encrypt(
        keys.secret_key(),
        &keys.public_key(),
        plaintext,
        nip44::Version::V2,
    )
    .context("NIP-44 encryption failed")
}

/// 自己暗号化された content を復号する。
fn decrypt_for_self(keys: &Keys, ciphertext: &str) -> Result<String> {
    nip44::decrypt(keys.secret_key(), &keys.public_key(), ciphertext)
        .context("NIP-44 decryption failed")
}

/// `body` を `MAX_COMMENT_BODY_CHARS` 文字にクランプする(書き込み・読み出し両側)。
fn clamp_body(payload: &mut TaskCommentPayload) {
    if payload.body.chars().count() > MAX_COMMENT_BODY_CHARS {
        payload.body = payload.body.chars().take(MAX_COMMENT_BODY_CHARS).collect();
    }
}

/// 署名済みのコメントイベント(kind:35002)JSON を構築する。
///
/// - `comment_json` を `TaskCommentPayload` として検証し(`body` はクランプ)、
///   NIP-44 v2 で署名鍵の公開鍵宛に自己暗号化して content に載せる。
/// - タグは `["d", comment_id]` のみ。タスクとの紐付けタグは一切付けない
///   (task↔comment グラフをリレーに露出させないため)。
/// - 返り値は `send_signed_event` にそのまま渡せる署名済みイベント JSON。
///
/// 鍵は非依存(key-agnostic): 共有リストではグループ鍵 `G` の nsec hex を、
/// 個人タスクでは利用者自身の鍵の nsec hex を渡す。どちらも
/// kind:30078 設定と同じ「自鍵で署名 + 自公開鍵宛 NIP-44 自己暗号化」経路になる。
pub fn build_signed_comment_event(group_nsec_hex: String, comment_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    let payload = parse_comment_payload_clamped(&comment_json)?;
    let plaintext =
        serde_json::to_string(&payload).context("Failed to serialize comment payload")?;
    let ciphertext = encrypt_for_self(&keys, &plaintext)?;

    let event = EventBuilder::new(Kind::Custom(TASK_COMMENT_KIND), ciphertext)
        .tags([Tag::identifier(payload.comment_id.clone())])
        .sign_with_keys(&keys)
        .context("Failed to sign task comment event")?;

    Ok(event.as_json())
}

/// コメントイベント(kind:35002)JSON を検証・復号し、平文の payload JSON を返す。
///
/// 検証内容(shared-v1 の `decrypt_task_event` の鍵運用に、受信側チェックを追加):
/// - kind が `TASK_COMMENT_KIND` であること
/// - author が渡した鍵の公開鍵と一致すること
/// - 署名が正しいこと(`Event::verify`)
/// - 復号後の payload が `validate_comment_payload` を通ること(`body` はクランプ)
/// - `d` タグが payload の `comment_id` と一致すること
///
/// `build_signed_comment_event` と同様に鍵非依存で、個人タスクでは利用者自身の
/// nsec hex を渡す。
pub fn decrypt_comment_event(group_nsec_hex: String, event_json: String) -> Result<String> {
    let keys = keys_from_nsec_hex(&group_nsec_hex)?;
    let event = Event::from_json(&event_json).context("Failed to parse comment event JSON")?;

    if event.kind != Kind::Custom(TASK_COMMENT_KIND) {
        bail!(
            "unexpected event kind: expected {}, got {}",
            TASK_COMMENT_KIND,
            event.kind.as_u16()
        );
    }
    if event.pubkey != keys.public_key() {
        bail!("comment event author does not match the provided key");
    }
    event
        .verify()
        .context("comment event signature verification failed")?;

    let plaintext = decrypt_for_self(&keys, &event.content)?;
    let payload = parse_comment_payload_clamped(&plaintext)?;

    if event.tags.identifier() != Some(payload.comment_id.as_str()) {
        bail!("comment event d tag does not match payload comment_id");
    }

    serde_json::to_string(&payload).context("Failed to serialize comment payload")
}

/// payload JSON をパースし、`body` クランプ後に検証する内部ヘルパー。
fn parse_comment_payload_clamped(payload_json: &str) -> Result<TaskCommentPayload> {
    let mut payload: TaskCommentPayload =
        serde_json::from_str(payload_json).context("comment payload is not valid JSON")?;
    clamp_body(&mut payload);
    validate_comment_payload(&payload)?;
    Ok(payload)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> TaskCommentPayload {
        TaskCommentPayload {
            v: TASK_COMMENT_SCHEMA_VERSION,
            comment_id: "8f14e45f-ceea-467f-a34e-3c7e00000001".to_string(),
            task_id: "c9f0f895-fb98-4b91-9e6b-3c7e00000002".to_string(),
            author_pubkey: "a".repeat(64),
            body: "looks done to me".to_string(),
            created_at: 1_787_900_000,
            edited_at: None,
            deleted: false,
            parent_comment_id: None,
        }
    }

    #[test]
    fn payload_json_roundtrip() {
        let payload = sample();
        let json = serde_json::to_string(&payload).unwrap();
        let parsed = parse_comment_payload(&json).unwrap();
        assert_eq!(parsed.comment_id, payload.comment_id);
        assert_eq!(parsed.task_id, payload.task_id);
        assert_eq!(parsed.body, payload.body);
        assert!(!parsed.deleted);
    }

    #[test]
    fn optional_fields_are_omitted_and_defaulted() {
        let json = serde_json::to_string(&sample()).unwrap();
        assert!(!json.contains("edited_at"));
        assert!(!json.contains("parent_comment_id"));
        let minimal = r#"{"v":1,"comment_id":"c1","task_id":"t1","author_pubkey":""#;
        let minimal = format!(
            "{}{}\",\"body\":\"hi\",\"created_at\":1}}",
            minimal,
            "b".repeat(64)
        );
        let parsed = parse_comment_payload(&minimal).unwrap();
        assert_eq!(parsed.edited_at, None);
        assert!(!parsed.deleted);
        assert_eq!(parsed.parent_comment_id, None);
    }

    #[test]
    fn rejects_invalid_payloads() {
        let mut p = sample();
        p.v = 2;
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.comment_id = String::new();
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.author_pubkey = "not-hex".to_string();
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.body = "x".repeat(MAX_COMMENT_BODY_CHARS + 1);
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.deleted = true;
        assert!(validate_comment_payload(&p).is_err());
        p.body = String::new();
        assert!(validate_comment_payload(&p).is_ok());
    }

    fn group_key() -> crate::group_tasks_shared::GroupKey {
        crate::group_tasks_shared::generate_group_key()
    }

    #[test]
    fn comment_event_is_signed_addressable_and_encrypted() {
        let gk = group_key();
        let payload = sample();
        let json = serde_json::to_string(&payload).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex.clone(), json).unwrap();

        let event = Event::from_json(&event_json).unwrap();
        // kind と author を検証
        assert_eq!(event.kind, Kind::Custom(TASK_COMMENT_KIND));
        assert_eq!(event.pubkey.to_hex(), gk.npub_hex);
        // 署名が正しい
        event.verify().unwrap();
        // d タグ = comment_id、かつタグはそれ 1 つだけ(タスク紐付けタグ禁止)
        assert_eq!(event.tags.identifier(), Some(payload.comment_id.as_str()));
        assert_eq!(event.tags.len(), 1);
        // content は平文ではない(暗号化されている)
        assert!(!event.content.contains("looks done to me"));
        assert!(!event.content.contains(&payload.task_id));
    }

    #[test]
    fn comment_event_roundtrips() {
        let gk = group_key();
        let payload = sample();
        let json = serde_json::to_string(&payload).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex.clone(), json).unwrap();

        let decrypted = decrypt_comment_event(gk.nsec_hex, event_json).unwrap();
        let roundtrip = parse_comment_payload(&decrypted).unwrap();
        assert_eq!(roundtrip.comment_id, payload.comment_id);
        assert_eq!(roundtrip.task_id, payload.task_id);
        assert_eq!(roundtrip.author_pubkey, payload.author_pubkey);
        assert_eq!(roundtrip.body, payload.body);
        assert_eq!(roundtrip.created_at, payload.created_at);
        assert!(!roundtrip.deleted);
    }

    #[test]
    fn tombstone_roundtrips() {
        let gk = group_key();
        let mut payload = sample();
        payload.deleted = true;
        payload.body = String::new();
        let json = serde_json::to_string(&payload).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex.clone(), json).unwrap();

        let event = Event::from_json(&event_json).unwrap();
        assert_eq!(event.tags.identifier(), Some(payload.comment_id.as_str()));

        let decrypted = decrypt_comment_event(gk.nsec_hex, event_json).unwrap();
        let roundtrip = parse_comment_payload(&decrypted).unwrap();
        assert!(roundtrip.deleted);
        assert!(roundtrip.body.is_empty());
        assert_eq!(roundtrip.comment_id, payload.comment_id);
        assert_eq!(roundtrip.task_id, payload.task_id);
    }

    #[test]
    fn wrong_key_cannot_decrypt() {
        let gk = group_key();
        let other = group_key();
        let json = serde_json::to_string(&sample()).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex, json).unwrap();

        // 別鍵では author 不一致で拒否される(復号にも失敗する)
        assert!(decrypt_comment_event(other.nsec_hex, event_json).is_err());
    }

    #[test]
    fn tampered_event_fails_signature_verification() {
        let gk = group_key();
        let json = serde_json::to_string(&sample()).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex.clone(), json).unwrap();

        // created_at を改ざん → id/署名検証で拒否される
        let mut value: serde_json::Value = serde_json::from_str(&event_json).unwrap();
        value["created_at"] = serde_json::json!(1);
        let tampered = value.to_string();
        assert!(decrypt_comment_event(gk.nsec_hex, tampered).is_err());
    }

    #[test]
    fn wrong_kind_is_rejected() {
        let gk = group_key();
        let task = serde_json::json!({ "id": "task-1", "title": "not a comment" }).to_string();
        let task_event =
            crate::group_tasks_shared::build_signed_task_event(gk.nsec_hex.clone(), task).unwrap();

        // kind:35000 のタスクイベントはコメントとして復号できない
        assert!(decrypt_comment_event(gk.nsec_hex, task_event).is_err());
    }

    #[test]
    fn oversized_body_is_clamped_on_build() {
        let gk = group_key();
        let mut payload = sample();
        payload.body = "x".repeat(MAX_COMMENT_BODY_CHARS + 100);
        let json = serde_json::to_string(&payload).unwrap();
        let event_json = build_signed_comment_event(gk.nsec_hex.clone(), json).unwrap();

        let decrypted = decrypt_comment_event(gk.nsec_hex, event_json).unwrap();
        let roundtrip = parse_comment_payload(&decrypted).unwrap();
        assert_eq!(roundtrip.body.chars().count(), MAX_COMMENT_BODY_CHARS);
    }

    #[test]
    fn personal_key_path_works_like_group_key() {
        // 個人タスク経路: 利用者自身の鍵をそのまま渡す(kind:30078 設定と同じ
        // 自己暗号化経路)。関数は鍵非依存であることを確認する。
        let user = Keys::generate();
        let nsec_hex = user.secret_key().to_secret_hex();
        let json = serde_json::to_string(&sample()).unwrap();
        let event_json = build_signed_comment_event(nsec_hex.clone(), json).unwrap();

        let event = Event::from_json(&event_json).unwrap();
        assert_eq!(event.pubkey, user.public_key());

        let decrypted = decrypt_comment_event(nsec_hex, event_json).unwrap();
        let roundtrip = parse_comment_payload(&decrypted).unwrap();
        assert_eq!(roundtrip.body, sample().body);
    }
}
