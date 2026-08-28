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
}
