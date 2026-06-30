# Collaborative Lists — Encryption Design

This document describes the cryptographic design behind meiso's collaborative
(shared) task lists.

## Overview

Collaborative lists use a **hybrid encryption scheme**: a symmetric AES-256
key encrypts the list data, and that key is distributed to each member using
asymmetric NIP-44 encryption. This means:

- The list payload is encrypted once (cheap, regardless of member count).
- Each member can independently decrypt it using only their own Nostr keypair.
- No trusted third party or key server is required.

## Encryption Flow

```
1. Generate a random AES-256 key (32 bytes, OsRng)

2. Encrypt the task list
   tasks (JSON) ──AES-256-GCM──► ciphertext
   nonce (12 bytes, random) prepended → base64 → encrypted_data

3. For each member, wrap the AES key using NIP-44 v2
   owner_secret_key × member_pubkey ──ECDH──► shared_secret
   shared_secret ──HKDF──► encryption_key
   encryption_key wraps AES key → encrypted_aes_key (per member)

4. Publish a Nostr event containing:
   - encrypted_data        (the ciphertext)
   - members[]             (list of member pubkeys, hex)
   - encrypted_keys[]      (one { member_pubkey, encrypted_aes_key } per member)
```

## Decryption Flow

```
1. Find your entry in encrypted_keys[] by matching your pubkey

2. Recover the AES key
   your_secret_key × owner_pubkey ──ECDH──► shared_secret
   shared_secret ──HKDF──► encryption_key
   encryption_key unwraps → AES key

3. Decrypt the list
   AES key + nonce (first 12 bytes of encrypted_data) ──AES-256-GCM──► tasks (JSON)
```

## Membership Changes

### Adding a member

Generate a new `encrypted_aes_key` for the new member using the **existing**
AES key. The list data itself does not need to be re-encrypted.

### Removing a member (Forward Secrecy)

1. Generate a new random AES-256 key.
2. Re-encrypt the entire list with the new key.
3. Re-wrap the new key for all **remaining** members.
4. Publish the updated event.

The removed member's old `encrypted_aes_key` becomes useless; they cannot
decrypt any future versions of the list.

## Signing and Authenticity

The wrapping Nostr event is signed with the owner's keypair via `nostr_sdk`.
Standard Nostr event verification guarantees that only the owner (or a
delegate with the private key) can publish updates to the list.

## Primitives

| Layer | Algorithm |
|---|---|
| List encryption | AES-256-GCM |
| Key agreement | ECDH over secp256k1 (NIP-44 v2) |
| Key derivation | HKDF-SHA256 (inside NIP-44) |
| RNG | `OsRng` (OS-provided CSPRNG) |
| Event signing | Schnorr / secp256k1 (Nostr) |

## Source References

- Key encryption / decryption logic: [`rust/src/group_tasks.rs`](../rust/src/group_tasks.rs)
- NIP-44 implementation: [`nostr_sdk::nip44`](https://docs.rs/nostr-sdk)
- MLS-based alternative (experimental): [`rust/src/mls.rs`](../rust/src/mls.rs)

## Relationship to MLS

`mls.rs` contains an experimental implementation using
[MLS (RFC 9420)](https://www.rfc-editor.org/rfc/rfc9420) for group key
management. MLS provides stronger forward secrecy and post-compromise security
guarantees but adds significant complexity. The current production path uses
the NIP-44 hybrid scheme described above.
