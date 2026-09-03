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
/// `comment_id` / `task_id` / `parent_comment_id` の最大文字数。
/// 実運用は UUID(36 文字)だが、敵対 payload の巨大 id で Hive キーや
/// ログが肥大するのを防ぐ多層防御として上限を設ける。
pub const MAX_COMMENT_ID_CHARS: usize = 256;

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
    if payload.comment_id.chars().count() > MAX_COMMENT_ID_CHARS {
        bail!("comment_id exceeds {} chars", MAX_COMMENT_ID_CHARS);
    }
    if payload.task_id.is_empty() {
        bail!("task_id must not be empty");
    }
    if payload.task_id.chars().count() > MAX_COMMENT_ID_CHARS {
        bail!("task_id exceeds {} chars", MAX_COMMENT_ID_CHARS);
    }
    if let Some(parent) = &payload.parent_comment_id {
        if parent.is_empty() || parent.chars().count() > MAX_COMMENT_ID_CHARS {
            bail!(
                "parent_comment_id must be 1..={} chars",
                MAX_COMMENT_ID_CHARS
            );
        }
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
    build_signed_comment_event_with_keys(&keys, &comment_json)
}

/// `build_signed_comment_event` の `Keys` 版。
///
/// セッションクライアントの鍵(個人タスク経路)のように nsec hex を
/// 経由せず既に `Keys` を持っている呼び出し元用。秘密鍵の hex 文字列
/// コピーを増やさないため、hex 版はこちらへ委譲する。
pub fn build_signed_comment_event_with_keys(keys: &Keys, comment_json: &str) -> Result<String> {
    let payload = parse_comment_payload_clamped(comment_json)?;
    let plaintext =
        serde_json::to_string(&payload).context("Failed to serialize comment payload")?;
    let ciphertext = encrypt_for_self(keys, &plaintext)?;

    let event = EventBuilder::new(Kind::Custom(TASK_COMMENT_KIND), ciphertext)
        .tags([Tag::identifier(payload.comment_id.clone())])
        .sign_with_keys(keys)
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
    decrypt_comment_event_with_keys(&keys, &event_json)
}

/// `decrypt_comment_event` の `Keys` 版(検証内容は同一)。
pub fn decrypt_comment_event_with_keys(keys: &Keys, event_json: &str) -> Result<String> {
    let event = Event::from_json(event_json).context("Failed to parse comment event JSON")?;

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

    let plaintext = decrypt_for_self(keys, &event.content)?;
    let payload = parse_comment_payload_clamped(&plaintext)?;

    if event.tags.identifier() != Some(payload.comment_id.as_str()) {
        bail!("comment event d tag does not match payload comment_id");
    }

    serde_json::to_string(&payload).context("Failed to serialize comment payload")
}

/// 暗号化済み content を載せた kind:35002 の未署名イベント JSON を返す(Amber 経路)。
///
/// 署名は外部署名者(Amber / NIP-55)が行うため `id` / `sig` は含めない
/// (`create_unsigned_shared_invitation_event` と同形)。タグは
/// `["d", comment_id]` のみで、署名済みビルダーと同じくタスク紐付けタグは
/// 一切付けない(task↔comment グラフをリレーに露出させないため)。
///
/// `encrypted_content` は Amber の NIP-44 で **自分の公開鍵宛に** 自己暗号化
/// した暗号文を渡すこと(`encrypt_for_self` と同じ conversation key になる)。
pub fn build_unsigned_comment_event(
    author_pubkey_hex: String,
    comment_id: String,
    encrypted_content: String,
    created_at: i64,
) -> Result<String> {
    let author =
        PublicKey::from_hex(&author_pubkey_hex).context("Failed to parse author public key")?;
    if comment_id.is_empty() || comment_id.chars().count() > MAX_COMMENT_ID_CHARS {
        bail!("comment_id must be 1..={} chars", MAX_COMMENT_ID_CHARS);
    }
    if created_at <= 0 {
        bail!("created_at must be positive");
    }

    let unsigned_event = serde_json::json!({
        "pubkey": author.to_hex(),
        "created_at": created_at,
        "kind": TASK_COMMENT_KIND,
        "tags": [["d", comment_id]],
        "content": encrypted_content,
    });
    serde_json::to_string(&unsigned_event).context("Failed to serialize unsigned comment event")
}

/// 署名済みコメントイベントの外形だけを検証し、content(暗号文)を返す(Amber 経路)。
///
/// 検証: kind == `TASK_COMMENT_KIND` / author == `expected_author_pubkey_hex` /
/// `Event::verify()` / `d` タグ存在。復号は Amber(NIP-55)側で行うため、
/// 復号後の平文は必ず `validate_decrypted_comment_payload` に通すこと。
/// この 2 関数を合わせて `decrypt_comment_event` と同じ 5 点検証
/// (kind / author / 署名 / d タグ照合 / payload スキーマ)が成立する。
pub fn verify_signed_comment_envelope(
    event_json: String,
    expected_author_pubkey_hex: String,
) -> Result<String> {
    let expected_author = PublicKey::from_hex(&expected_author_pubkey_hex)
        .context("Failed to parse expected author public key")?;
    let event = Event::from_json(&event_json).context("Failed to parse comment event JSON")?;

    if event.kind != Kind::Custom(TASK_COMMENT_KIND) {
        bail!(
            "unexpected event kind: expected {}, got {}",
            TASK_COMMENT_KIND,
            event.kind.as_u16()
        );
    }
    if event.pubkey != expected_author {
        bail!("comment event author does not match the expected author");
    }
    event
        .verify()
        .context("comment event signature verification failed")?;
    if event.tags.identifier().is_none() {
        bail!("comment event has no d tag");
    }

    Ok(event.content.clone())
}

/// Amber が復号した平文 payload を検証し、正規化済み payload JSON を返す(Amber 経路)。
///
/// 検証: `validate_comment_payload`(`body` クランプ込み)/
/// `comment_id` == `expected_comment_id`(イベントの `d` タグ値を渡す)/
/// `author_pubkey` == `expected_author_pubkey_hex`。
///
/// 個人タスク経路専用のため payload の author は必ず利用者自身になる
/// (共有リスト経路の editor 自己申告モデルとは異なり、ここでは照合する)。
/// 書き込み側でも暗号化前の payload 正規化(検証 + `body` クランプ)として
/// 使うことで、`build_signed_comment_event` と同じ書き込み側検証を保つ。
pub fn validate_decrypted_comment_payload(
    plaintext_json: String,
    expected_comment_id: String,
    expected_author_pubkey_hex: String,
) -> Result<String> {
    let expected_author = PublicKey::from_hex(&expected_author_pubkey_hex)
        .context("Failed to parse expected author public key")?;
    let payload = parse_comment_payload_clamped(&plaintext_json)?;

    if payload.comment_id != expected_comment_id {
        bail!("comment payload comment_id does not match the event d tag");
    }
    let payload_author = PublicKey::from_hex(&payload.author_pubkey)
        .context("comment payload author_pubkey is not a valid public key")?;
    if payload_author != expected_author {
        bail!("comment payload author does not match the expected author");
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

        // id 長キャップ(敵対 payload の巨大 id 防御)
        let mut p = sample();
        p.comment_id = "x".repeat(MAX_COMMENT_ID_CHARS + 1);
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.task_id = "x".repeat(MAX_COMMENT_ID_CHARS + 1);
        assert!(validate_comment_payload(&p).is_err());

        let mut p = sample();
        p.parent_comment_id = Some("x".repeat(MAX_COMMENT_ID_CHARS + 1));
        assert!(validate_comment_payload(&p).is_err());
        p.parent_comment_id = Some(String::new());
        assert!(validate_comment_payload(&p).is_err());
        p.parent_comment_id = Some("x".repeat(MAX_COMMENT_ID_CHARS));
        assert!(validate_comment_payload(&p).is_ok());

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
    fn keys_variants_roundtrip_with_hex_variants() {
        // hex 版と Keys 版は相互運用できる(委譲実装の確認)
        let user = Keys::generate();
        let nsec_hex = user.secret_key().to_secret_hex();
        let json = serde_json::to_string(&sample()).unwrap();

        let by_keys = build_signed_comment_event_with_keys(&user, &json).unwrap();
        let via_hex = decrypt_comment_event(nsec_hex.clone(), by_keys).unwrap();
        assert_eq!(parse_comment_payload(&via_hex).unwrap().body, sample().body);

        let by_hex = build_signed_comment_event(nsec_hex, json).unwrap();
        let via_keys = decrypt_comment_event_with_keys(&user, &by_hex).unwrap();
        assert_eq!(
            parse_comment_payload(&via_keys).unwrap().body,
            sample().body
        );
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

    /// 利用者鍵の payload(author = 自鍵)を作るヘルパー(Amber 経路テスト用)。
    fn sample_for(keys: &Keys) -> TaskCommentPayload {
        let mut payload = sample();
        payload.author_pubkey = keys.public_key().to_hex();
        payload
    }

    /// Amber の署名を模す: 未署名イベント JSON のフィールドから id を計算して
    /// 署名する(NIP-55 署名者が行う処理と同じ)。
    fn amber_like_sign(keys: &Keys, unsigned_json: &str) -> String {
        let value: serde_json::Value = serde_json::from_str(unsigned_json).unwrap();
        assert!(value.get("id").is_none());
        assert!(value.get("sig").is_none());
        let tags: Vec<Tag> = value["tags"]
            .as_array()
            .unwrap()
            .iter()
            .map(|t| {
                Tag::parse(
                    &t.as_array()
                        .unwrap()
                        .iter()
                        .map(|s| s.as_str().unwrap().to_string())
                        .collect::<Vec<_>>(),
                )
                .unwrap()
            })
            .collect();
        let event = EventBuilder::new(
            Kind::Custom(value["kind"].as_u64().unwrap() as u16),
            value["content"].as_str().unwrap(),
        )
        .tags(tags)
        .custom_created_at(Timestamp::from(value["created_at"].as_u64().unwrap()))
        .sign_with_keys(keys)
        .unwrap();
        assert_eq!(event.pubkey.to_hex(), value["pubkey"].as_str().unwrap());
        event.as_json()
    }

    /// Amber の NIP-44 を模す: 自鍵 + 自公開鍵で conversation key を作る
    /// (`encrypt_for_self` と同じ相手先指定)。
    fn amber_like_encrypt(keys: &Keys, plaintext: &str) -> String {
        nip44::encrypt(
            keys.secret_key(),
            &keys.public_key(),
            plaintext,
            nip44::Version::V2,
        )
        .unwrap()
    }

    #[test]
    fn unsigned_comment_event_has_expected_shape() {
        let user = Keys::generate();
        let unsigned = build_unsigned_comment_event(
            user.public_key().to_hex(),
            "comment-1".to_string(),
            "ciphertext".to_string(),
            1_787_900_000,
        )
        .unwrap();

        let value: serde_json::Value = serde_json::from_str(&unsigned).unwrap();
        assert_eq!(value["kind"], TASK_COMMENT_KIND);
        assert_eq!(value["pubkey"], user.public_key().to_hex());
        assert_eq!(value["created_at"], 1_787_900_000);
        assert_eq!(value["content"], "ciphertext");
        // d タグ 1 つだけ(タスク紐付けタグ禁止)、id / sig は外部署名者が付ける
        assert_eq!(value["tags"], serde_json::json!([["d", "comment-1"]]));
        assert!(value.get("id").is_none());
        assert!(value.get("sig").is_none());
    }

    #[test]
    fn build_unsigned_comment_event_rejects_bad_inputs() {
        let pk = Keys::generate().public_key().to_hex();
        let ok = |p: &str, c: &str, t: i64| {
            build_unsigned_comment_event(p.to_string(), c.to_string(), "x".to_string(), t)
        };
        assert!(ok("not-a-pubkey", "c-1", 1).is_err());
        assert!(ok(&pk, "", 1).is_err());
        assert!(ok(&pk, &"x".repeat(MAX_COMMENT_ID_CHARS + 1), 1).is_err());
        assert!(ok(&pk, "c-1", 0).is_err());
        assert!(ok(&pk, "c-1", 1).is_ok());
    }

    #[test]
    fn amber_written_event_is_readable_by_secret_key_mode() {
        // Amber 経路(3 関数 + Amber 模擬の NIP-44/署名)で書いたイベントが、
        // 秘密鍵モードの decrypt_comment_event でそのまま読めること
        // (モード切替でコメントが読めなくなる事故の防止)。
        let user = Keys::generate();
        let payload = sample_for(&user);
        let payload_json = serde_json::to_string(&payload).unwrap();

        let normalized = validate_decrypted_comment_payload(
            payload_json,
            payload.comment_id.clone(),
            user.public_key().to_hex(),
        )
        .unwrap();
        let ciphertext = amber_like_encrypt(&user, &normalized);
        let unsigned = build_unsigned_comment_event(
            user.public_key().to_hex(),
            payload.comment_id.clone(),
            ciphertext,
            1_787_900_123,
        )
        .unwrap();
        let signed = amber_like_sign(&user, &unsigned);

        let decrypted =
            decrypt_comment_event(user.secret_key().to_secret_hex(), signed).unwrap();
        let roundtrip = parse_comment_payload(&decrypted).unwrap();
        assert_eq!(roundtrip.comment_id, payload.comment_id);
        assert_eq!(roundtrip.task_id, payload.task_id);
        assert_eq!(roundtrip.author_pubkey, payload.author_pubkey);
        assert_eq!(roundtrip.body, payload.body);
    }

    #[test]
    fn secret_key_written_event_is_readable_via_amber_path() {
        // 逆方向: 秘密鍵モードで書いたイベントを Amber 経路
        // (envelope 検証 → NIP-44 復号 → payload 検証)で読めること。
        let user = Keys::generate();
        let payload = sample_for(&user);
        let payload_json = serde_json::to_string(&payload).unwrap();
        let event_json =
            build_signed_comment_event(user.secret_key().to_secret_hex(), payload_json).unwrap();

        let ciphertext = verify_signed_comment_envelope(
            event_json.clone(),
            user.public_key().to_hex(),
        )
        .unwrap();
        let plaintext = nip44::decrypt(user.secret_key(), &user.public_key(), &ciphertext).unwrap();
        let event = Event::from_json(&event_json).unwrap();
        let normalized = validate_decrypted_comment_payload(
            plaintext,
            event.tags.identifier().unwrap().to_string(),
            user.public_key().to_hex(),
        )
        .unwrap();

        let roundtrip = parse_comment_payload(&normalized).unwrap();
        assert_eq!(roundtrip.comment_id, payload.comment_id);
        assert_eq!(roundtrip.body, payload.body);
    }

    #[test]
    fn envelope_rejects_wrong_author() {
        let user = Keys::generate();
        let other = Keys::generate();
        let payload_json = serde_json::to_string(&sample_for(&user)).unwrap();
        let event_json =
            build_signed_comment_event(user.secret_key().to_secret_hex(), payload_json).unwrap();

        assert!(
            verify_signed_comment_envelope(event_json, other.public_key().to_hex()).is_err()
        );
    }

    #[test]
    fn envelope_rejects_tampered_events() {
        let user = Keys::generate();
        let payload_json = serde_json::to_string(&sample_for(&user)).unwrap();
        let event_json =
            build_signed_comment_event(user.secret_key().to_secret_hex(), payload_json).unwrap();
        let pubkey_hex = user.public_key().to_hex();

        // content 改ざん(id が合わなくなる)
        let mut value: serde_json::Value = serde_json::from_str(&event_json).unwrap();
        value["content"] = serde_json::json!("attacker-ciphertext");
        assert!(verify_signed_comment_envelope(value.to_string(), pubkey_hex.clone()).is_err());

        // created_at 改ざん
        let mut value: serde_json::Value = serde_json::from_str(&event_json).unwrap();
        value["created_at"] = serde_json::json!(1);
        assert!(verify_signed_comment_envelope(value.to_string(), pubkey_hex.clone()).is_err());

        // d タグ改ざん(id/署名検証で拒否される)
        let mut value: serde_json::Value = serde_json::from_str(&event_json).unwrap();
        value["tags"] = serde_json::json!([["d", "attacker-comment-id"]]);
        assert!(verify_signed_comment_envelope(value.to_string(), pubkey_hex.clone()).is_err());

        // 未署名イベントはパース段階で拒否される
        let unsigned = build_unsigned_comment_event(
            pubkey_hex.clone(),
            "c-1".to_string(),
            "x".to_string(),
            1_787_900_000,
        )
        .unwrap();
        assert!(verify_signed_comment_envelope(unsigned, pubkey_hex).is_err());
    }

    #[test]
    fn envelope_rejects_wrong_kind_and_missing_d_tag() {
        let user = Keys::generate();
        let pubkey_hex = user.public_key().to_hex();

        // kind:35000(共有タスク)はコメント envelope として通らない
        let task = serde_json::json!({ "id": "task-1", "title": "not a comment" }).to_string();
        let task_event = crate::group_tasks_shared::build_signed_task_event(
            user.secret_key().to_secret_hex(),
            task,
        )
        .unwrap();
        assert!(verify_signed_comment_envelope(task_event, pubkey_hex.clone()).is_err());

        // 正しく署名されていても d タグが無ければ拒否
        let no_d_tag = EventBuilder::new(Kind::Custom(TASK_COMMENT_KIND), "ciphertext")
            .sign_with_keys(&user)
            .unwrap()
            .as_json();
        assert!(verify_signed_comment_envelope(no_d_tag, pubkey_hex).is_err());
    }

    #[test]
    fn nip44_self_encrypt_interops_across_implementations() {
        // Amber は独立実装の NIP-44 で「自分の公開鍵宛」に自己暗号化する。
        // その conversation key が Rust 側 `encrypt_for_self` と一致することを、
        // nostr-tools v2(独立実装)で生成した固定ベクターの復号で確認する。
        // 生成スクリプト: nip44.v2.encrypt(plaintext,
        //   getConversationKey(sk, getPublicKey(sk)))
        // 鍵はこのテスト専用の使い捨て値(実運用の鍵ではない)。
        let sk_hex = "5f4c8e348d1c76ac9c8797e75d4f7fb3e1a5c3b2a19f8d7e6c5b4a3928170605";
        let expected_plaintext = "{\"v\":1,\"comment_id\":\"cross-impl-1\",\"task_id\":\"task-cross\",\"author_pubkey\":\"c4467447470bad49c186f0394edd8a3225587543f744cdc409138053cc3e6d53\",\"body\":\"bees interop\",\"created_at\":1787900000,\"deleted\":false}";
        let ciphertext = "Aianwy5+gQoMnPjH/qhCLBKQaSYu4F3lgExhvsyX+F8XQ4WrpJJblL9QWPqidzcGTdQ69pjI3HjJufn/nPjeVQI+C2uDL0GIvuJAYoy13nYdIWVrHqZ6PLrRjnPe5/MsYIFqScr1iHNtsi0THuVtufDiA1sW+HJ0JBgBXKkJt7usO76M3W+NIyg+NrE6l9n9blbZX8X7RCE4vfQ/9ZUQtoTD/uE9xQ/74vc6CebzizU1Ntnp45dHvxplI+lmnnIeL0mHU8jXpnwQHBA2CYVWUJJrD12OzPMjufATUX0HoOh48Z5jdAzQezD0VkjtMbRE2KasKrReRRVbXIB0/2roZiyJwYxeTT46tGHR81PDXsrvXjqfZHV5h2VjB/EcmV15QKky";

        let keys = keys_from_nsec_hex(sk_hex).unwrap();
        assert_eq!(
            keys.public_key().to_hex(),
            "c4467447470bad49c186f0394edd8a3225587543f744cdc409138053cc3e6d53"
        );
        let decrypted = decrypt_for_self(&keys, ciphertext).unwrap();
        assert_eq!(decrypted, expected_plaintext);
        // 対称鍵なので逆方向(Rust encrypt → 独立実装 decrypt)も同鍵で成立する
        let roundtrip = decrypt_for_self(&keys, &encrypt_for_self(&keys, expected_plaintext).unwrap()).unwrap();
        assert_eq!(roundtrip, expected_plaintext);
    }

    #[test]
    fn decrypted_payload_validation_rejects_mismatches() {
        let user = Keys::generate();
        let other = Keys::generate();
        let payload = sample_for(&user);
        let payload_json = serde_json::to_string(&payload).unwrap();
        let pubkey_hex = user.public_key().to_hex();

        // comment_id が d タグ(期待値)と一致しない
        assert!(validate_decrypted_comment_payload(
            payload_json.clone(),
            "different-comment-id".to_string(),
            pubkey_hex.clone(),
        )
        .is_err());

        // payload の author が期待 author と一致しない
        assert!(validate_decrypted_comment_payload(
            payload_json.clone(),
            payload.comment_id.clone(),
            other.public_key().to_hex(),
        )
        .is_err());

        // payload スキーマ違反(tombstone に本文)
        let mut broken = payload.clone();
        broken.deleted = true;
        assert!(validate_decrypted_comment_payload(
            serde_json::to_string(&broken).unwrap(),
            payload.comment_id.clone(),
            pubkey_hex.clone(),
        )
        .is_err());

        // 正常系はクランプ済み正規化 JSON を返す
        let mut oversized = payload.clone();
        oversized.body = "x".repeat(MAX_COMMENT_BODY_CHARS + 100);
        let normalized = validate_decrypted_comment_payload(
            serde_json::to_string(&oversized).unwrap(),
            payload.comment_id.clone(),
            pubkey_hex,
        )
        .unwrap();
        let parsed = parse_comment_payload(&normalized).unwrap();
        assert_eq!(parsed.body.chars().count(), MAX_COMMENT_BODY_CHARS);
    }
}
