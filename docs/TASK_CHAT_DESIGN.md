# Task Chat (per-task comments) — Design

Target release: **1.5.0**

Adds a chat/comment thread to each task, shown below the SUBTASKS section of
the task detail screen. Works for both personal tasks and shared-v1
collaborative lists while preserving meiso's E2E encryption principles.

## Protocol design

### Why not plain NIP-22 (kind 1111)?

NIP-22 has the right *semantics* (comments on addressable events) but the
wrong *privacy model* for meiso:

1. Content is plaintext by convention — meiso encrypts everything.
2. The `a`/`A` tags expose which task each comment belongs to, leaking the
   task↔comment graph to relays even when content is encrypted.
3. kind 1111 is a regular event, so edit/delete needs NIP-09 on top —
   a second consistency model next to our addressable LWW.

Interop with other Nostr clients is moot once content is encrypted, so we
borrow NIP-22's root/parent semantics *inside the encrypted payload* and keep
the event shape consistent with shared-v1.

Also rejected: NIP-17/59 gift wrap (per-member fan-out + new members cannot
read history — contradicts the shared-key decision documented in
`SHARED_LIST_STRATEGY.md`), NIP-28 / kind-9 chat (plaintext), NIP-29
(requires relay-side group support; meiso targets generic open relays).

### Event shape

- **One comment = one addressable event, `kind:35002`**
  (`TASK_COMMENT_KIND`), following 35000 (task) / 35001 (meta).
- Tags: `[["d", "<comment_id>"]]` only. **No task reference tags** — the
  task association lives inside the encrypted payload, so relays cannot see
  which task a comment belongs to (nor how many comments a task has).
- Signing / encryption:
  - **Shared list**: signed by the list group key `G`, content NIP-44 v2
    self-encrypted to `G` — identical path to kind:35000 tasks.
  - **Personal task**: signed by the user's own key, content NIP-44 v2
    self-encrypted — identical path to kind:30078 settings. The payload's
    `task_id` references the task inside the existing kind:30001 list model,
    so personal comments do not depend on a per-task event migration.
- Sync: extend the existing shared-v1 subscription kinds from
  `[35000, 35001]` to `[35000, 35001, 35002]` (author = `npub_G`); personal
  comments subscribe `kind:35002, author = self`.
- Consistency: same LWW rule as tasks — apply in `created_at` ascending
  order with `event_id` tiebreak. Editing republishes the same `d`;
  deleting republishes a tombstone (`deleted: true`, `body: ""`), which also
  removes the content from relays via addressable replacement.

### Encrypted payload (JSON, inside `content`)

```json
{
  "v": 1,
  "comment_id": "8f14e45f-…",
  "task_id": "c9f0f895-…",
  "author_pubkey": "<64-char hex>",
  "body": "looks done to me 🐝",
  "created_at": 1787900000,
  "edited_at": null,
  "deleted": false,
  "parent_comment_id": null
}
```

- `author_pubkey` — display attribution, same trust model as shared-v1's
  `editor_pubkey` (self-asserted inside the `G`-signed envelope).
- `body` — clamped to `MAX_COMMENT_BODY_CHARS` (2000) on both write and
  read paths (read-side clamp guards against oversized hostile payloads).
- `parent_comment_id` — reserved for threaded replies (NIP-22's parent
  concept); unused by the 1.5.0 UI.
- `deleted: true` tombstones keep `comment_id`/`task_id` so ordering and
  counts stay stable across devices.

## Contract surface (Phase 0)

- Rust: `rust/src/task_comments.rs` — `TASK_COMMENT_KIND`, payload struct
  `TaskCommentPayload` (serde), validation. Event build/decrypt functions
  land in Phase 1a mirroring `build_signed_task_event` /
  `decrypt_task_event`.
- Dart: `lib/features/task_comments/domain/` — `TaskComment` entity,
  `TaskCommentRepository` interface (dartz `Either<Failure, _>`), reusing
  `core/common/failure.dart`.

## Rollout phases

| Phase | Scope |
|---|---|
| 0 | Contract (this document + types) |
| 1a | Rust core: build/decrypt + LWW + unit tests + FRB codegen |
| 1b | Infra: repository impl, local persistence, subscription kinds |
| 1c | Personal path via session-key FFI, backlog fetch kinds, logout wipe, id caps |
| 2 | UI: comment section under SUBTASKS (bubbles, input, edit/delete) |
| 3 | Background worker polling + notifications for kind:35002 |
| 4 | E2E (personal / shared, two devices, Amber mode) → v1.5.0 |

## Key paths per mode (as of Phase 1c)

- **Shared list**: group key `G` (hex) loaded from
  `SharedGroupKeyLocalDataSource`, passed to
  `shared_build_signed_comment_event` / `shared_decrypt_comment_event`.
- **Personal task, secret-key mode**: the user's `Keys` live only inside
  the Rust session client and are never exposed to Dart. Comments use
  `client_build_signed_comment_event` / `client_decrypt_comment_event`
  (same session-key pattern as `client_nip44_encrypt`).
- **Personal task, Amber mode**: **fail-closed** (`AuthFailure`). The
  session client has no keys, and Amber holds the nsec. A working Amber
  path needs: build unsigned kind:35002 with Amber
  `encryptNip44WithContentProvider` (self), sign via Amber, plus a Rust
  verify-only helper so receive-side signature/d-tag checks keep parity
  with the secret-key path. Planned as its own leaf before Phase 4;
  shared-list comments already work in Amber mode because they use `G`.
