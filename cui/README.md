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
- `MEISO_CUI_SOCKS_PROXY` (optional; route all relay traffic through Tor/Orbot — see below)

## Tor / SOCKS5 proxy

Set `MEISO_CUI_SOCKS_PROXY` to send every outbound connection (relay
WebSockets, NIP-65 resolution, remote signer calls) through a SOCKS5 proxy:

```bash
# Tor daemon
export MEISO_CUI_SOCKS_PROXY="127.0.0.1:9050"
# Orbot (Android tethering / desktop) often uses 9050 as well
meiso status        # shows the active proxy
meiso shared sync
```

Accepted forms: `host:port`, `socks5://host:port`, or `socks5h://host:port`.
The scheme is normalized to `socks5h`, so **hostnames are resolved by the proxy
(no local DNS leak)**. When unset, the CLI connects directly.

Implementation note: go-nostr v0.52 has no per-connection dialer hook, so the
proxy is applied to `http.DefaultTransport`, which the relay WebSocket dials
fall back to. This is process-wide and intentional — in Tor mode nothing should
bypass the proxy.

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

## Shared-Key Collaborative Lists (`shared-v1`)

Catches up with app 1.4.0. A shared list has its own dedicated Nostr key `G`:
tasks are addressable events (`kind:35000`, `d=task-id`) signed by `G` with
NIP-44 v2 self-encrypted content, so relays only see opaque ciphertext and
Last-Write-Wins is resolved at the relay layer. Members join by receiving
`nsec_G` through a NIP-44 envelope (`kind:30078`, addressed with `#p`).

This is wire-compatible with the Android client (`rust/src/group_tasks_shared.rs`):
events created here are read by the app and vice versa.

```bash
# create a list (generates the group key, publishes kind:35001 metadata)
meiso shared create --name "Groceries"
meiso shared groups

# invite a member (seals nsec_G for them; needs local secret-key login)
meiso shared invite --group "Groceries" --to npub1...

# on the invitee's machine: list and accept pending invitations
meiso shared invites
meiso shared accept                 # accept all (or: accept <group-id>)

# work with tasks (group can be referenced by id or name)
meiso shared add   --group "Groceries" --title "Milk" --date today
meiso shared tasks --group "Groceries"
meiso shared done  --group "Groceries" --id <task-id>
meiso shared delete --group "Groceries" --id <task-id>   # publishes a tombstone

# pull collaborators' edits and push local changes
meiso shared sync                   # all groups (or: --group "Groceries")
```

Notes:

- Invitations require a signer that can NIP-44 encrypt — use `login-local`
  (or a NIP-07 extension that exposes `nip44.encrypt`). The group key `G` itself
  signs/encrypts all task events, so collaboration works regardless of how you
  authenticate.
- Group credentials (including the shared secret `nsec_G`) are stored encrypted
  at rest in `shared_groups.enc`; shared task state lives in `shared_tasks.json`,
  separate from your personal list so group content is never published to your
  own `kind:30001` list.
- `logout` wipes group secrets and shared task state along with the session.
- For two clients to collaborate they must share at least one relay
  (`MEISO_CUI_RELAY_URL`).

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
