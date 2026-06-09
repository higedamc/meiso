# Go CUI Auth Broker Spec

## Objective

Provide a NIP-07-like login experience for CLI by using browser approval and callback-based session bootstrap.

## Modes

- `auto` (default): local bridge page uses `window.nostr` directly.
- remote signer URL mode: user can set `MEISO_CUI_AUTH_URL` to explicit signer endpoint.

## Login Sequence

### Auto mode (`MEISO_CUI_AUTH_URL=auto`)

1. CUI starts local bridge server on `127.0.0.1` random port.
2. CUI opens local `/auth?state=...` page.
3. Page calls `window.nostr.getPublicKey()`.
4. Page redirects to local `/callback?state=...&pubkey=...`.
5. CUI validates `state` and stores encrypted session (`signer_name=nip07`).

### Remote signer URL mode

1. CUI starts local callback server on `127.0.0.1` random port.
2. CUI opens `MEISO_CUI_AUTH_URL` with query:
   - `callback`: local callback URL (`http://127.0.0.1:<port>/callback`)
   - `state`: CSRF token
3. Browser signer redirects to callback with:
   - `state`
   - `token`
   - `pubkey`
   - `sign_endpoint`
   - `expires_in` (seconds, optional)
   - `refresh_hint` (optional)
4. CUI validates `state` and stores encrypted session.

## Sign Endpoint Contract

`POST <sign_endpoint>`

Request:

```json
{
  "token": "<access-token>",
  "event": {
    "kind": 30001,
    "content": "...",
    "tags": [["d", "..."]]
  }
}
```

Response:

```json
{
  "event": {
    "id": "...",
    "pubkey": "...",
    "sig": "...",
    "kind": 30001,
    "content": "...",
    "tags": [["d", "..."]]
  }
}
```

In `auto` mode, `sign_endpoint` is not used. Signing is done by opening a local `/sign` page and calling `window.nostr.signEvent(...)`.

## Session Persistence Fields

- `access_token`
- `pubkey`
- `signer_name` (`browser`)
- `sign_endpoint`
- `refresh_hint`
- `relay_url`
- `relay_urls`
- `expires_at`
- `last_success_at`
- `failure_count`

## Relay Source Priority

1. NIP-07 `getRelays()` result (when available in extension)
2. NIP-65 (`kind:10002`) lookup after login
3. `MEISO_CUI_RELAY_URL` defaults

## Failure Handling

- Login timeout: 2 minutes.
- State mismatch: abort session creation.
- Missing token/pubkey: reject callback.
- Sign endpoint error: keep task dirty and fail `sync`.
