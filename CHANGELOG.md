# Changelog

All notable changes to Meiso will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-04-07

### Added
- **Subtask Support (Issue #128)**: Reminders-first subtask mode with parent-child task relationships
  - `parentTaskId` / `depth` fields on Todo model
  - Subtask CRUD in TodosNotifier, inline UI in todo_edit_screen and todo_item
  - Task Links model (blocks, blocked_by, related_to, duplicate_of) for Asana mode
  - **Edit screen**: Promote subtask to root or attach task as subtask of another parent (with l10n)
- **Image Attachments**: Blossom / NIP-96 image upload with server picker and full-screen viewer
  - Amber-mode signing support for media uploads
- **Product Flavors**: `production` (Zapstore) / `beta` (GitHub Actions) build split
  - `BuildChannel` enum + `buildChannel` constant in `app_config.dart` (Issue #124)
  - `--dart-define=BUILD_CHANNEL` for compile-time channel detection
- **Feature Gate System**: Beta-only experimental feature toggles (Asana/Wunderlist/Kanban modes, Task Linking)
- **Hide Completed Tasks**: Toggle in App Settings to hide completed tasks (including Planning detail view)
- **CI/CD**: GitHub Actions workflow for automated beta APK builds with Telegram notifications
- **Go CUI**: Bidirectional Nostr sync, custom lists, tree view for terminal-based task management
- **Nostr relay User-Agent (Issue #130)**: WebSocket handshake sends `meiso/<version> (<os>; <os_version>)` using a vendored `async-wsocket` fork and `setRelayWebsocketUserAgent` before client init
- **NIP-89 client tag (Issue #131)**: Published events include a minimal `["client","meiso"]` tag unless disabled under Settings -> Advanced (synced in Kind 30078 as `nip89_client_tag_enabled`)

### Changed
- **Three-Tier Sync**: Refactored sync flow to Hive -> Global -> Citrine relay architecture
- **CargoKit**: Vendored cargokit to resolve CI submodule fetch failures; fixed flavor compatibility in plugin.gradle
- **Rust Bridge**: Regenerated FRB bindings with subtask/task-link fields
- **Rust**: `async-wsocket` 0.10.1 patched at `rust/vendor/async-wsocket` with `[patch.crates-io]`; direct dependency from the `rust` crate for the setter API
- **Task reorder UX**: Dedicated drag handle; subtask drag-out promotes to root; long-press on text remains JSON/debug path where applicable
- **GitHub Actions**: `actions/checkout`, `setup-java`, `cache`, `upload-artifact`, and `download-artifact` bumped to v5
- **Test Suite**: Fixed 17 broken tests, added tests for recurring instance generation and child instance removal

### Fixed
- **Community feedback ([Nostr](https://njump.me/nevent1qqsgx0r3afgwp8p7rgwcpnl4xs8j0wtvhdtv3h5djjvwe795y6y0y4gppemhxue69uhkummn9ekx7mp0qgs9dcnp82lvzhplnvrua24rq842dg9025q9g6shzkurh6r2yqj9wsgrqsqqqpzhkcx0sp))**: Tasks looked like they only synced after pull-to-refresh — fixed “Send to relay” showing for already-synced todos, stale/null `eventId` merge from encrypted payloads, cold-start retry, and batch sync window (PR #129).
- **Same thread**: Relay behaviour on cold start — Amber mode client reuse (avoid per-send client recreation / WS timeout loop), real per-relay connection checks, relay status UI updates, and Citrine/global relay management improvements (PR #129).
- Beta APK stuck on splash / white screen: `abiFilters` for ARM64, FRB version alignment, splash error diagnostics
- Relay status stuck at `0/n` connected after successful init
- `needsSync` stuck true and related sync state persistence
- `imageUrl` end-to-end through Rust, FRB, and Nostr conversion layers
- `moveTodo`: child tasks follow parent date; Amber JSON parity for subtasks / `image_url`
- Task reorder jumping back: list order vs. arranged (e.g. hidden completed) index mismatch
- Production build: `app-production-release.apk` also copied to `app-release.apk` for `flutter install`
- **Security / logging**: Rust `println!` only in debug; removed secret-key logging (defense in depth)
- CargoKit product flavor compatibility (Rust .so missing from APK)
- Removed stale prebuilt jniLibs that masked cargokit output
- CI build failures (cargokit submodule, Amber gitlink, signing config)

### Notes
- Community-reported “Today” blank bottom sheet (no dismiss) is tracked for verification in Issue #132.

## [1.1.9] - 2026-03-13

### Added
- **Bootstrap Sync Flow**: Added a blocking startup sync flow for first launch with retry and continue-with-local-cache actions.
- **Relay Sync Metadata**: Added local/global relay sync metadata fields to Todo for local-first send tracking.

### Changed
- **Local-first Sending**: Amber signed events now send to local relay first, then enqueue global relay backfill in background.
- **Startup Behavior**: App restore now uses bootstrap sync orchestration instead of ad-hoc startup sync calls.

### Fixed
- **Custom List Consistency**: Normalized `customListId` values from Nostr payloads and d-tags to avoid list mismatch.
- **Date Grouping Stability**: Normalized incoming dates to local day keys before grouping to prevent day-split inconsistencies.

## [1.1.8] - 2026-02-11

### Improved
- **Relay Connection Optimization (Phase 1 & 2)**: Major performance improvements for Nostr relay communication
  - **Phase 1 - Dynamic Polling Interval**: Implemented adaptive polling (100ms active, 1000ms idle) with exponential backoff for power efficiency
  - **Phase 2 - EOSE-based Early Termination**: Migrated from `fetch_events()` to `subscribe()` with End-of-Stored-Events detection for faster response
  - Initial TODO sync: 10s → 2-3s (70-80% reduction)
  - Delta sync on app resume: 3s → 1-1.5s (50-67% reduction)
  - Event reception speed: 1s → 0.1s (90% reduction)
  - Overall user experience: 3-5x faster
  - Based on proven optimizations from jokyo project relay analysis
  - Backwards compatible with fallback to previous implementation

### Technical
- Updated `lib/services/nostr_subscription_service.dart` with Amethyst-style dynamic polling
- Updated `rust/src/api.rs` with subscribe-based streaming reception
- Added comprehensive test coverage for Phase 1 (100%)
- Created detailed documentation:
  - `docs/RELAY_OPTIMIZATION_PHASE1_IMPLEMENTATION.md`
  - `docs/PHASE2_APPLICABILITY_ANALYSIS.md`
  - `docs/RELAY_OPTIMIZATION_PHASE2_IMPLEMENTATION.md`
- 6 files changed, 1798 insertions(+), 10 deletions(-)

## [1.1.7] - 2025-01-16

### Fixed
- **OGP Link Preview (Issue #114)**: Fixed link preview functionality
  - Resolved timeout and connection issues
  - Improved error handling for malformed URLs
  - Enhanced preview card rendering
- **Undo Delete Button (Issue #11)**: Fixed issue where "元に戻す" (Undo) button after deleting a task did not properly restore the task
  - Implemented soft delete with delayed confirmation (3 seconds)
  - Delete is only persisted/synced after SnackBar timeout
  - Undo button cancels the deletion before persistence
  - Supports both regular tasks and MLS group tasks
  - Only the last deleted task can be undone (single-item undo buffer)
- **Week Start Day Setting (Issue #38)**: Implemented week start day setting for calendar display
  - Week start day setting now properly reflects in home screen calendar
  - Supports Sunday, Monday, and Saturday as week start options
  - Setting is accessible and functional in app settings
  - Calendar widget automatically adjusts week display based on user preference

### Changed
- **Sync Status Indicator**: Simplified and improved sync status display
  - Reduced code complexity (289 lines removed)
  - Enhanced visual feedback for sync operations
- **Localization**: Comprehensive updates to translations
  - Added 162 new English strings
  - Updated Japanese and Spanish translations
  - Improved recurring task terminology across all languages
- **Timeout Durations**: Adjusted network timeout values for better reliability

### Improved
- **Todo Provider**: Major refactoring for better performance and maintainability
  - 416 lines of improvements
  - Enhanced state management
  - Better error handling

## [1.1.6] - 2025-01-10

### Fixed
- **List Rename Bug**: Fixed issue where custom list names could not be renamed
  - Resolved text editing controller disposal causing setState error
  - Added proper state management for rename operations
- **Initial Sync Dialog Bug**: Fixed sync dialog incorrectly appearing on every app launch
  - Now only shows on true first launch (when no private key exists)
  - Added proper initialization state tracking
- **Recurring Tasks Performance**: Improved rolling window optimization
  - Enhanced performance for generating recurring task instances
  - Fixed edge cases in recurring pattern calculations
  - Optimized task generation for daily, weekly, and monthly patterns

### Changed
- Updated recurring task documentation with performance improvements

## [1.1.2] - 2025-01-02

### Fixed
- hotfix for l10n

## [1.1.1] - 2025-01-02

### Added
- **Tor Connection Support (Issue #97)**
  - Orbot mode: Connect to .onion relays via SOCKS5 proxy
  - Proxy status indicator showing connection health
  - Orbot installation guide with Play Store link
  - Configurable proxy URL (default: `socks5://127.0.0.1:9050`)
  - Internal (Embedded Tor) mode marked as "under development" for future implementation

### Fixed
- Updated Rust API to properly handle `TorMode` parameter
- Enabled `tor` feature in `Cargo.toml` for future embedded Tor support

### Changed
- Settings UI now shows three Tor connection modes: Disabled, Internal (disabled), Orbot
- Added `TorMode` enum to `AppSettings` model

### Technical
- Created `docs/TOR_DUAL_MODE_SUPPORT.md` documenting Tor implementation
- Updated 16 files with 3,848 insertions

### Tested
- ✅ Orbot mode successfully connects to .onion relays
- ✅ TODOs can be created and synced via Tor connection
- ✅ Proxy connection status updates correctly

### Notes
- Internal Tor mode requires Guardian Project `tor-android` library integration (~20MB APK size increase)
- Orbot must be installed and running for Orbot mode to work
- See Amethyst repository for reference implementation

## [1.1.0] - 2025-01-01

### Added
- **MLS Group Todo Lists (Beta)**
  - Full bidirectional synchronization (Alice ↔ Bob)
  - Real-time group task sharing with instant UI updates
  - Secure group communication via MLS protocol
  - Group invitation and acceptance flow

### Fixed
- **Bug #1**: Fixed invitation mark reappearing after app restart for accepted group lists
  - Added `acceptedAt` field to track accepted invitations
  - Modified `syncGroupInvitations()` to preserve accepted state
  - Resolved race condition in `CustomListsProvider.updateList()`
- **Bug #2**: Fixed "Zombie List" problem where deleted lists immediately reappeared
  - Corrected `_filterDeletedLists()` to use `list.eventId` instead of `list.id`
  - Added Rust API fallback to find event IDs for personal lists
  - Fixed `deleteList()` to properly update `_deletedEventIds`
- **Bug #3**: Fixed UI update delay for MLS group todos
  - Changed `_syncMlsGroupTodos()`, `addTodoToGroup()`, and `updateTodoInGroup()` to update state immediately
  - Removed unnecessary `_setTodosStateAsync()` calls that delayed UI updates

### Changed
- All state update methods in `CustomListsProvider` now use `state.valueOrNull` instead of `state.whenData()` to prevent race conditions
- Improved error handling and logging for MLS group operations

### Technical
- Major refactoring of `lib/providers/custom_lists_provider.dart` (461 lines changed)
- Updated `lib/providers/todos_provider.dart` for immediate state updates

## [1.0.0] - 2025-11-21

### Added
- **Core Task Management Features**
  - Three-column layout (Today / Tomorrow / Someday)
  - Task creation, editing, and deletion
  - Task completion toggle
  - Drag and drop reordering
  - Swipe to delete with undo functionality
  - Swipe to postpone to next day

- **Calendar & Date Management**
  - Expandable calendar view with smooth animations
  - Date tab bar showing 5 days
  - Navigate to any date
  - Move tasks between dates

- **Custom Lists**
  - Create personal task lists
  - Organize tasks by categories
  - Delete lists with confirmation

- **Recurring Tasks**
  - Daily, weekly, monthly, yearly patterns
  - Every other day / Every weekday support
  - Flexible interval settings (every 2 weeks, etc.)
  - Multiple weekday selection
  - Automatic next task generation
  - Visual marker (🔄 icon)

- **Nostr Integration**
  - Full Nostr protocol support (Kind 30078)
  - NIP-44 end-to-end encryption
  - Multi-device synchronization
  - Amber signer integration
  - Custom relay management
  - Real-time sync status indicator
  - Pull to refresh

- **Privacy & Security**
  - Amber mode: External key management (recommended)
  - NIP-44 encryption for all tasks
  - Local-first architecture with Hive storage
  - Tor connection support via Orbot proxy

- **UI/UX**
  - Dark mode support
  - TeuxDeux-inspired minimal design
  - Smooth animations
  - Responsive touch interactions
  - Multi-language support (English, Japanese, Spanish)

- **Settings**
  - Secret key management
  - Relay server configuration
  - App preferences (language, theme)
  - Tor/Orbot proxy settings

### Technical Highlights
- Flutter 3.x + Riverpod 2.x state management
- Rust integration via flutter_rust_bridge
- rust-nostr for Nostr protocol implementation
- Freezed for immutable data models
- Clean Architecture foundation
- Comprehensive error handling

### Notes
- This is the initial public release
- Group lists (MLS-based) are in development and hidden in Advanced settings
- Debug logs only visible in debug mode
- Some features (calendar view options, week start day, notifications) are planned for future releases

