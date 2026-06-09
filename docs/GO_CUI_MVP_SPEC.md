# Go CUI MVP Spec (macOS)

## Goal

Provide a macOS-friendly supplemental client without Apple ID dependency, using a Go CUI first and keeping a future TUI path open.

## MVP Scope

### Commands

- `login`: start browser-based NIP-07-like authorization flow.
- `status`: show login/session validity and relay target.
- `logout`: clear local session.
- `task list`: list local tasks.
- `task add --title ... --due today|tomorrow|someday`: create task.
- `task done --id ...`: complete task.
- `sync`: push dirty tasks to relay through signer.

### Non-functional Requirements

- **Offline-first**: task add/done is local-first and marks entries as dirty.
- **Reconnection**: `sync` retries by command invocation; dirty tasks remain until publish success.
- **Session persistence**: encrypted local session file, keyed by macOS Keychain secret.
- **No Flutter/Rust coupling**: CUI is isolated under `cui/` and does not change app runtime.

## Auth Model

- NIP-07 equivalent for CLI is implemented as a browser authorization broker:
  1. CUI opens browser with callback URL and CSRF state.
  2. Browser signer returns `token`, `pubkey`, `sign_endpoint`.
  3. CUI persists session and uses endpoint for signing.

## Known Constraints

- Browser signer backend must expose a compatible callback/sign API.
- `sync` currently publishes task events only; pull/merge from relays is out-of-scope for MVP.

## Future TUI Compatibility

- Command handlers call `internal/app.Service`.
- TUI can reuse the same service methods without reworking auth, session, and sync layers.
