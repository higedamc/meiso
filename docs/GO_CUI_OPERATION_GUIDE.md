# Go CUI Operation Guide

## Build

```bash
cd cui
go mod tidy
go test ./...
```

## Local E2E (verified flow)

The following sequence was verified in this repository:

1. `task add` creates local dirty task.
2. `task list` shows dirty state.
3. `task done` updates status and keeps dirty state.
4. `login-local --secret ...` creates persistent local session.
5. `status` returns valid local session.
6. `sync` publishes dirty task and clears dirty state.

## Browser Auth E2E (NIP-07-like)

1. Keep default `MEISO_CUI_AUTH_URL=auto` (or unset it).
2. Run `go run ./cmd/meiso-cui login`.
3. Approve `window.nostr.getPublicKey()` in your NIP-07 extension.
4. Confirm terminal receives callback and saves encrypted session.
5. Run `status` to validate signer mode (`nip07`).
6. Run `sync` and approve `window.nostr.signEvent(...)` in browser.

## Troubleshooting

### Browser shows "This site can’t be reached" on login

This means the auth endpoint is not reachable from your machine.

1. If you use default `auto`, install/enable a NIP-07 extension in your default browser.
2. If you use remote signer mode, verify `MEISO_CUI_AUTH_URL` points to a running signer login endpoint.
3. Retry: `go run ./cmd/meiso-cui login`

For local-only testing without browser signer, use:

```bash
go run ./cmd/meiso-cui login-local --secret <nsec-or-hex>
```

## Re-login and Expiry Behavior

- If session is valid: commands continue without re-login.
- If session is expired and `refresh_hint` exists: CUI tries token refresh automatically.
- If refresh fails: session remains stored, `status` becomes invalid, and explicit `login` is required.

## Relay Resolution and Sync

- Initial relays come from `MEISO_CUI_RELAY_URL` (comma-separated supported).
- During login, CUI attempts NIP-65 (`kind:10002`) fetch for the account pubkey.
- If NIP-65 write relays are found, they override initial relays for sync.
- `sync` publishes to all resolved relays and succeeds when at least one relay accepts each event.
- For Android Meiso interoperability, CUI sends `kind:30001` with `d=meiso-todos` and NIP-44 encrypted todo-list JSON payload.
- NIP-07 mode requires an extension that supports `window.nostr.nip44.encrypt`.

## Persistence

- Session: encrypted file using AES-GCM (`session.enc`).
- Master key:
  - macOS: stored/retrieved via Keychain (`security` command).
  - fallback/non-macOS: `MEISO_CUI_MASTER_KEY` required.
- Tasks: local JSON (`tasks.json`) with dirty flag for offline-first sync.

## Future TUI Path

TUI should reuse `cui/internal/app.Service` methods:

- `Login`, `LoginLocal`, `SessionStatus`, `Logout`
- `AddTask`, `ListTasks`, `DoneTask`
- `Sync`

This keeps auth/session/sync logic shared between CUI and TUI frontends.
