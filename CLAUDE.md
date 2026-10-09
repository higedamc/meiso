# meiso — project rules for Claude Code sessions

## Language policy

**Everything outward-facing is written in English**: GitHub issues, pull request titles and bodies, `README.md`, code comments, commit messages, and documentation (including this file). Conversation with the repository owner stays Japanese.

## Stack overview

- Flutter + Rust (flutter_rust_bridge). Rust is cross-compiled for three Android ABIs by cargokit during the build; the first build is very heavy.
- After changing any public `#[frb]` API, regenerate the bridge with `./generate.sh` (takes minutes). Not needed if you did not touch the public API.
- `cui/` is a Go CLI (module `github.com/higedamc/meiso/cui`, go 1.24.1) that speaks the same Nostr protocol as the app.
- **Flutter version: pinned to 3.41.6** in `.fvmrc` and in `FLUTTER_VERSION` of both workflows under `.github/workflows/`. The three must stay equal: `pubspec.lock` is written by this SDK and the release APK is built with it (v1.4.3's `libflutter.so` carries engine `425cfb54d0` / Dart 3.11.4). Bare `flutter` may not be on `PATH`; use `fvm flutter`, which reads `.fvmrc`.

## CI gates a pull request has to pass

- `flutter analyze --no-fatal-infos --no-fatal-warnings` — errors only. The repository carries a large pre-existing info/warning lint backlog, so gate on real breakage, not style noise.
- `flutter test --no-pub --exclude-tags golden`
- The `golden` job runs separately and is currently non-blocking. **Record goldens on the Linux runner only**, via `workflow_dispatch` with `update_goldens=true`, then commit the uploaded artifact. Never record goldens on macOS.

Report verification results at the exact commit you pushed — working trees move underneath you.

## Which branch to start from

**Branch from `origin/main`.** `release/1.4.0` is fully merged: as of 2026-10-05 `git rev-list --count origin/main..origin/release/1.4.0` is 0 while `main` is 68 commits ahead, and the shared-v1 Rust implementation (`rust/src/group_tasks_shared.rs`) is on `main`. Older notes telling you to base 1.4.0 work on `release/1.4.0` are obsolete — following them puts you three months behind.

## Installing on a device (required reading)

Build only, then install with `adb install --user 0` — do **not** use `flutter run` or `flutter install`, because the Flutter commands cannot choose the target user profile.

```bash
# 1. Build only. Always use the beta flavor for test builds on a real device.
flutter build apk --flavor beta --debug

# 2. Install with an explicit user profile.
adb install --user 0 build/app/outputs/flutter-apk/app-beta-debug.apk
```

- `adb install` **always** needs `--user 0`.

### The flavor trap

The `production` flavor shares its application id and signing key with the release build (release builds are signed with the debug keystore too, for zapstore compatibility — this cannot be changed). Installing `app-production-debug.apk` on a real device therefore **overwrites the owner's release install**. Test builds must use `--flavor beta` (application id `jp.godzhigella.meiso.beta`), which coexists as a separate app. Recovery is reinstalling the official release APK; data survives. See `docs/FLAVOR_BUILD_AND_ISSUE_128_IMPLEMENTATION.md`.

## Build environment

- **Disk**: one debug build grows `build/` past 20 GB. Check `df -h` first and `flutter clean` worktrees you are done with. When space is tight, delete `build/app/intermediates` (regenerable Gradle intermediates) first.
- **Emulator**: `-gpu host` is required (swiftshader produces constant system ANRs and is unusable). `-memory 4096` recommended.

## Nostr protocol (collaborative lists)

The current scheme is **shared-v1** (since 1.4.0). The MLS path and the NIP-72-style `rust/src/group_tasks.rs` are legacy; do not conflate them with shared-v1.

- **Task**: `kind:35000` (addressable), author = the group-only key `G`, `d=<task-uuid>`, content = NIP-44 self-encrypted. Last-write-wins comes from relay replaceable semantics.
- **Group metadata**: `kind:35001`, author `G`, `d="meta"`.
- **Invitation**: `kind:30078`, author = the inviter's real key, `d="shared-invite-<group_id>-<recipientHex>"`, `p=<recipient hex>`, content = NIP-44 (inviter→recipient) carrying `{group_id, group_nsec, group_name, key_epoch}`.
- The same `kind:30078` also carries legacy MLS-compatible `d="group-invitation-*"` events, so **always branch on the `d` prefix**.
- **Known structural gap**: the creator (inviter) has no new-device recovery path, because no self-addressed (`#p=self`) invitation is published — on a new device they see zero invitations and cannot restore the credentials. Suspect this first when someone reports "my shared list does not appear on my new device". The workaround is to have an existing member invite the creator again.

## Sync development principles

- **Do not touch the signing or permission code.** Per-event signing (Amber asking for approval each time) is intended behaviour aligned with Nostr's model, not friction to be removed. Changes that nudge the user toward broader permissions are not acceptable.
- **Keep the two login modes at parity.** Amber mode and secret-key mode must not diverge in behaviour; an optimisation such as EOSE early-exit has to be applied to both.
- **`group` / giftwrap fetches (`kind:445` / `1059`) must not use EOSE early-exit** — they need all-relay reliability. Only replaceable fetches may early-exit.
- **"First EOSE wins" makes the fastest relay authoritative.** A relay that answers first may hold an older copy of a replaceable event. Any fetch whose result feeds *deletion inference* — the `kind:30001` list fetches, where a task's absence from a newer list is read as a delete — must therefore not stop at a single EOSE. The authority for those is the highest `created_at` seen across relays.
