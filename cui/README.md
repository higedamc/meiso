# Meiso Go CUI

Supplemental macOS-first CUI for Meiso, designed for no-Apple-ID workflows and future TUI reuse.

## Quick start

```bash
cd cui
go mod tidy
go run ./cmd/meiso-cui status
```

## Environment variables

- `MEISO_CUI_AUTH_URL` (default: `auto`; uses local NIP-07 bridge page)
- `MEISO_CUI_RELAY_URL` (default: `wss://relay.damus.io`, supports comma-separated values)
- `MEISO_CUI_MASTER_KEY` (optional; required outside macOS if Keychain is unavailable)

## Commands

```bash
go run ./cmd/meiso-cui login
go run ./cmd/meiso-cui status
go run ./cmd/meiso-cui task add --title "Buy coffee" --due today
go run ./cmd/meiso-cui task list
go run ./cmd/meiso-cui task done --id <task-id>
go run ./cmd/meiso-cui sync
go run ./cmd/meiso-cui logout
```

## NIP-07-like flow

`login` in default `auto` mode uses NIP-07 extension directly:

1. Terminal starts a local callback server.
2. Browser opens local auth bridge page.
3. Page calls `window.nostr.getPublicKey()` from installed extension.
4. Session is encrypted and stored in `~/Library/Application Support/meiso-cui/session.enc`.

Optional remote signer mode is still available by setting `MEISO_CUI_AUTH_URL` to your signer login endpoint.

After login, CUI tries to resolve NIP-65 relay list (`kind:10002`). If found, write relays from NIP-65 are used for sync.

## Notes

- Offline command execution remains available for local task operations.
- `sync` pushes dirty tasks to relay and clears dirty flag only on successful publish.
