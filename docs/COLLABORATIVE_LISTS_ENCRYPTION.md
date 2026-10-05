# Collaborative Lists — Encryption Design

This document describes the cryptographic design behind meiso's collaborative
(shared) task lists.

## Overview

Collaborative lists use the **shared-v1** scheme (`rust/src/group_tasks_shared.rs`):
a single Nostr keypair `G` (the "group key") is generated per shared list.
`G` is shared out-of-band to every member and is used both as the **signer**
and as the **encryption target** for that list's events:

- Each task is one addressable Nostr event (`kind:35000`), signed by `G`, with
  `content` self-encrypted to `G` via NIP-44 v2.
- The replaceable semantics of `(kind, author=G, d=task-id)` give relay-level
  last-write-wins per task, with no application-side merge logic needed.
- Any member holding `nsec_G` can read, write, and sign as the group.

See [`docs/SHARED_LIST_STRATEGY.md`](SHARED_LIST_STRATEGY.md) for the full
design rationale (including the prior MLS-based approach it replaced).

## Encryption Flow

```
1. Generate the group key G (Keys::generate(), once per list)
   nsec_G (32 bytes) / npub_G

2. Encrypt a task
   task (JSON) ──NIP-44 v2, self-encrypt to npub_G──► ciphertext

3. Sign and publish
   EventBuilder(kind: 35000, content: ciphertext)
     .tag(d = task-id)
     .sign_with_keys(G)
   ──► relays
```

Group metadata (list name, `key_epoch`, member list for display) uses the
same pattern on `kind:35001` with a fixed `d` tag of `"meta"`.

## Decryption Flow

```
1. Fetch events where author = npub_G, kind in {35000, 35001}

2. Decrypt
   ciphertext ──NIP-44 v2, decrypt as npub_G (using nsec_G)──► task (JSON)

3. Apply LWW per `d` tag (task id); `deleted: true` is a tombstone, not an
   event deletion, so it still propagates through the same replaceable slot.
```

Anyone without `nsec_G` cannot decrypt task or metadata content.

## Key Distribution (Invites)

`nsec_G` is handed to a new member via a NIP-44-wrapped invitation
(`kind:30078`, tagged `["p", recipientHex]`), encrypted from the inviter's
real keypair to the recipient's real keypair. The payload carries
`group_id`, `group_nsec`, `group_npub`, `group_name`, and `key_epoch`. See
§3.3 of `SHARED_LIST_STRATEGY.md` for the exact envelope.

## Membership Changes

### Adding a member

Send the existing `nsec_G` to the new member via the invitation flow above.
No re-encryption or re-signing of existing events is needed — the new member
can read the full history as soon as they have `nsec_G`.

### Removing a member — no forward secrecy today

**Removing a member does not revoke their access.** `nsec_G` is a shared
secret with no per-member scoping: once a member has it, they keep the
ability to decrypt every past and future event for that list until the
group key itself is rotated.

The `key_epoch` field exists in the metadata/invitation schema and is
carried through the Rust, FRB, and Dart layers (see
`rust/src/group_tasks_shared.rs`, `lib/features/shared_list/`), but **no
code path increments it or generates a replacement `G`**. There is no
`rotate_group_key`-equivalent function. The only member-removal code path
in the codebase (`removeMemberFromGroupTaskList` /
`group_tasks::remove_member_from_group`) rewraps the **legacy** AES key and
has no shared-v1 counterpart. Locally deleting a cached `nsec_G` entry
(`shared_group_key_local_datasource.dart`) only affects the device doing
the deleting; it does not stop the removed member's other devices from
continuing to decrypt the list.

`SHARED_LIST_STRATEGY.md` §5 describes a key-rotation design for this gap
(bump `key_epoch`, generate `G'`, redistribute, re-sign all tasks under
`G'`), but it is a proposal, not shipped behavior.

## Legacy Group Tasks Path (`group_tasks.rs`)

An older hybrid scheme still lives in `rust/src/group_tasks.rs` and is
reachable from `removeMemberFromGroup` / `remove_member_from_group_task_list`.
It differs from shared-v1:

- A random AES-256 key encrypts the list payload once; the AES key is then
  wrapped per-member using NIP-44 v2 (ECDH with each member's real pubkey).
- Removing a member there **does** give forward secrecy: a fresh AES key is
  generated, the list is re-encrypted, and the new key is re-wrapped only for
  the remaining members (`group_tasks::remove_member_from_group`).

This path predates shared-v1 and is not the one new shared lists are created
with. If it is still exercised by any UI flow, references to it should say
so explicitly rather than describing it as the current/default scheme.

### Legacy encryption flow (for reference)

```
1. Generate a random AES-256 key (32 bytes, OsRng)
2. Encrypt the task list: tasks (JSON) ──AES-256-GCM──► ciphertext
3. For each member: wrap the AES key via NIP-44 v2 (ECDH + HKDF)
4. Publish: encrypted_data + members[] + encrypted_keys[] (per member)
```

### Legacy primitives

| Layer | Algorithm |
|---|---|
| List encryption | AES-256-GCM |
| Key agreement | ECDH over secp256k1 (NIP-44 v2) |
| Key derivation | HKDF-SHA256 (inside NIP-44) |
| RNG | `OsRng` (OS-provided CSPRNG) |
| Event signing | Schnorr / secp256k1 (Nostr) |

## Signing and Authenticity

For shared-v1, any event signed by `npub_G` is accepted as authoritative for
that list — standard Nostr signature verification just confirms the event
came from someone holding `nsec_G`, not from a specific member. There is no
per-member attribution at the protocol level; `editor_pubkey` inside the
decrypted payload is a self-reported, unverified hint for UI display only.

## Primitives (shared-v1)

| Layer | Algorithm |
|---|---|
| Task/meta encryption | NIP-44 v2 (self-encrypt to `npub_G`) |
| Event signing | Schnorr / secp256k1 (Nostr), signed by `G` |
| Key generation | `Keys::generate()` (OS-provided CSPRNG) |
| Conflict resolution | Relay-level replaceable LWW on `(kind, author, d)` |

## Source References

- Shared-v1 implementation: [`rust/src/group_tasks_shared.rs`](../rust/src/group_tasks_shared.rs)
- Shared-v1 design rationale: [`docs/SHARED_LIST_STRATEGY.md`](SHARED_LIST_STRATEGY.md)
- Legacy AES key-wrap path: [`rust/src/group_tasks.rs`](../rust/src/group_tasks.rs)
- NIP-44 implementation: [`nostr_sdk::nip44`](https://docs.rs/nostr-sdk)
- MLS-based alternative (experimental, superseded by shared-v1): [`rust/src/mls.rs`](../rust/src/mls.rs)

## Relationship to MLS

`mls.rs` contains an experimental implementation using
[MLS (RFC 9420)](https://www.rfc-editor.org/rfc/rfc9420) for group key
management. MLS provides forward secrecy and post-compromise security
without relying on manual key rotation, but it brings significant
state-management complexity (key packages, epochs, SQLite persistence)
that motivated the move to shared-v1 — see `SHARED_LIST_STRATEGY.md` §1
and §2.1 for the tradeoff. Unlike MLS, neither shared-v1 nor the legacy
AES path gets forward secrecy for free; the legacy path only gets it when
a member is explicitly removed and the list is re-keyed, and shared-v1
currently has no removal path at all (see above).
