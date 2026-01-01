# Changelog

All notable changes to Meiso will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

