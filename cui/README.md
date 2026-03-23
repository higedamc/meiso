# Meiso Go CUI

Supplemental macOS-first CUI for Meiso, designed for no-Apple-ID workflows and future TUI reuse.

## Install

```bash
cd cui
make install
```

`~/go/bin` が PATH に含まれていれば、以下のように直接実行可能:

```bash
meiso status
meiso list
meiso add --title "Buy coffee" --due today
```

PATH が未設定の場合は `~/.zshrc` に追記:

```bash
export PATH="$HOME/go/bin:$PATH"
```

## Uninstall

```bash
cd cui
make uninstall
```

バイナリ (`$GOPATH/bin/meiso`) とローカルデータ (`~/Library/Application Support/meiso-cui/`) を削除する。

## Quick start (dev)

```bash
cd cui
go mod tidy
go run ./cmd/meiso status
```

## Environment variables

- `MEISO_CUI_AUTH_URL` (default: `auto`; uses local NIP-07 bridge page)
- `MEISO_CUI_RELAY_URL` (default: `wss://relay.damus.io`, supports comma-separated values)
- `MEISO_CUI_MASTER_KEY` (optional; required outside macOS if Keychain is unavailable)

## Commands

```bash
meiso login
meiso status
meiso add --title "Buy coffee" --due today
meiso list
meiso done --id <task-id>
meiso sync
meiso logout
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
