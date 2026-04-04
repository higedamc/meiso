//! Process-wide Nostr client metadata: NIP-89 `client` tag toggle (issue #131).

use std::sync::atomic::{AtomicBool, Ordering};

use nostr_sdk::prelude::*;

static NIP89_CLIENT_TAG_ENABLED: AtomicBool = AtomicBool::new(true);

pub fn set_nip89_client_tag_enabled(enabled: bool) {
    NIP89_CLIENT_TAG_ENABLED.store(enabled, Ordering::SeqCst);
}

pub fn nip89_client_tag_enabled() -> bool {
    NIP89_CLIENT_TAG_ENABLED.load(Ordering::SeqCst)
}

/// NIP-89 minimal `["client", "meiso"]` as SDK tags.
pub fn nip89_client_tags() -> Vec<Tag> {
    if !nip89_client_tag_enabled() {
        return Vec::new();
    }
    vec![Tag::custom(
        TagKind::Custom(std::borrow::Cow::Borrowed("client")),
        vec!["meiso".to_string()],
    )]
}

fn has_client_tag_row(tags: &[Vec<String>]) -> bool {
    tags.iter()
        .any(|row| row.first().map(|s| s.as_str()) == Some("client"))
}

/// Append NIP-89 client tag rows for Amber unsigned JSON (`tags` as string arrays).
pub fn append_nip89_json_tag_rows(tags: &mut Vec<Vec<String>>) {
    if !nip89_client_tag_enabled() || has_client_tag_row(tags) {
        return;
    }
    tags.push(vec!["client".to_string(), "meiso".to_string()]);
}

/// Merge NIP-89 tags into signed-event tag list unless a `client` tag already exists.
pub fn merge_nip89_into_tags(mut base: Vec<Tag>) -> Vec<Tag> {
    if !nip89_client_tag_enabled() {
        return base;
    }
    if base.iter().any(|t| {
        t.clone()
            .to_vec()
            .first()
            .map(|s| s.as_str() == "client")
            .unwrap_or(false)
    }) {
        return base;
    }
    base.extend(nip89_client_tags());
    base
}
