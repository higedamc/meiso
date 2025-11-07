# Hotfix Summary

## Date
November 6, 2025

---

## Implemented Hotfixes

### Hotfix 1: Fix TodosProvider initialization logic ✅

**Issue**:
- Local data was prioritized, and Nostr sync ran in the background with a 1-second delay
- When logging in on a new device for the first time, it took time for Todos to appear

**Fix**:
1. Modified `_initialize()`
   - When local data exists: Display immediately → Background sync
   - When no local data exists: Set to empty state and **immediately execute Nostr sync** (priority sync)

2. Added `_prioritySync()` method
   - Executes Nostr sync without delay
   - Migration check → Sync completion

**Modified files**:
- `lib/providers/todos_provider.dart`

---

### Hotfix 2: Implement custom list order synchronization ✅

**Issue**:
- Custom list order (`order`) was not included in kind: 30078 (AppSettings)
- When logging in on a new device, list order became random

**Fix**:

#### 1. Added field to Rust data structure

```rust
pub struct AppSettings {
    pub dark_mode: bool,
    pub week_start_day: i32,
    pub calendar_view: String,
    pub notifications_enabled: bool,
    pub relays: Vec<String>,
    pub tor_enabled: bool,
    pub proxy_url: String,
    pub custom_list_order: Vec<String>, // 🆕 Added
    pub updated_at: String,
}
```

#### 2. Added field to Flutter model

```dart
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(false) bool darkMode,
    // ...
    @Default([]) List<String> customListOrder, // 🆕 Added
    required DateTime updatedAt,
  }) = _AppSettings;
}
```

#### 3. Added sync logic to CustomListsProvider

**Update AppSettings when reordering**:
```dart
Future<void> reorderLists(int oldIndex, int newIndex) async {
  // ...reordering logic...
  
  // Update AppSettings customListOrder as well
  await _updateCustomListOrderInSettings(updatedLists);
}
```

**Restore order when syncing from Nostr**:
```dart
Future<void> syncListsFromNostr(List<String> nostrListNames) async {
  // ...add lists...
  
  // Apply saved order from AppSettings
  await _applySavedListOrder(updatedLists);
}
```

**Modified files**:
- `rust/src/api.rs` - AppSettings struct
- `lib/models/app_settings.dart` - AppSettings model
- `lib/providers/custom_lists_provider.dart` - Sync logic

---

### Hotfix 3: Optimize relay list initial sync ✅

**Issue**:
- Relay list (kind: 10002) sync functionality was implemented but was not automatically called during initial login
- AppSettings sync was not included in `todosProvider.syncFromNostr()`

**Fix**:

Added AppSettings sync at the **beginning** of `todosProvider.syncFromNostr()`:

```dart
Future<void> syncFromNostr() async {
  // Priority: Sync AppSettings (including relay list)
  AppLogger.info(' [Sync] 1/3: Syncing AppSettings (including relay list)...');
  try {
    await _ref.read(appSettingsProvider.notifier).syncFromNostr();
    AppLogger.info(' [Sync] AppSettings sync completed');
  } catch (e) {
    AppLogger.warning(' [Sync] AppSettings sync error (continuing): $e');
  }
  
  // 2/3: Custom list sync
  // 3/3: Todo sync
}
```

**Sync order**:
1. **AppSettings (including relay list)** ← 🆕 Highest priority
2. Custom lists
3. Todos

**Modified files**:
- `lib/providers/todos_provider.dart`

---

## Impact

### Improved initial login flow (new device)

**Before**:
```
1. Load from local storage (empty)
2. 1-second delay
3. Background Todo sync
4. Custom list sync
5. (No AppSettings/relay list sync)
```

**After** ✅:
```
1. Load from local storage (empty)
2. Immediate priority Nostr sync
   - 2.1. AppSettings sync (including relay list)
   - 2.2. Custom list sync (with order restoration)
   - 2.3. Todo sync
```

---

## Test Scenarios

### Scenario 1: Sync existing data on new device

1. **Device A**: Create custom lists + reorder + add Todos
2. **Device B**: Initial login

**Expected behavior** ✅:
- Relay list is automatically applied
- Custom lists are displayed in correct order
- Todos appear immediately (no 1-second delay)
- Dark theme setting is automatically applied

### Scenario 2: Completely new account

1. Create new account
2. Confirm default lists are displayed
3. Add custom lists + reorder
4. Log in on another device

**Expected behavior** ✅:
- Default lists are displayed
- Customized order is reproduced on new device

---

## Changed Files

### Code
1. `lib/providers/todos_provider.dart` - Hotfix 1, 3
2. `lib/providers/custom_lists_provider.dart` - Hotfix 2
3. `lib/models/app_settings.dart` - Hotfix 2
4. `rust/src/api.rs` - Hotfix 2

---

## Summary

All hotfixes are complete, and initial login data synchronization has been significantly improved:

✅ **Hotfix 1**: Todo sync executes immediately
✅ **Hotfix 2**: Custom list order is synchronized
✅ **Hotfix 3**: Relay list is synchronized with highest priority

This ensures that **all settings and data are correctly restored when logging in on a new device for the first time**.

