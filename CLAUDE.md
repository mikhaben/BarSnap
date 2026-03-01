# BarSnap

World of Warcraft addon that saves and restores action bar presets. Players capture their current bar configuration (all 96 slots across bars 1-8) into named presets, then swap between them with one click. Features global and per-character preset scoping, category-based filtering, per-bar filtering, custom icons, layout preservation, and a draggable UI with preset editor.

## Commands

- `/bs` or `/barsnap` — Toggle main window

## Project Structure

```
BarSnap/
├── BarSnap.toc            # TOC metadata, load order, SavedVariables declaration
├── Constants.lua          # All shared constants: dimensions, textures, colors, categories, type mappings
├── Core.lua               # Namespace init, SavedVariables management, events, slash commands
├── Engine/
│   ├── Scanner.lua        # Bar scanning and sparse action table construction
│   ├── Validator.lua      # Combat guards, name validation, uniqueness, action availability checks
│   └── Restore.lua        # Action placement with retry logic, category filtering, layout preservation
├── UI/
│   ├── PresetRow.lua      # Preset list row component (icon, name, apply/edit buttons, row pooling)
│   ├── EditorFrame.lua    # Preset editor (icon picker, name edit, category filters, delete confirmation)
│   ├── MainFrame.lua      # Main floating window (preset list, save button, scroll, drag, ESC close)
│   └── Settings.lua       # Blizzard addon settings panel
├── Assets/
│   └── logo.tga           # Addon icon
└── build.sh               # CurseForge build script (versioned zip)
```

**Load order:** Constants → Core → Engine (Scanner, Validator, Restore) → UI (PresetRow, EditorFrame, MainFrame). Constants must load first so shared values are available everywhere.

## Architecture

All modules share a single namespace: `local AddonName, NS = ...` passed via the TOC addon system. The namespace is exposed globally as `_G.BarSnap` for debugging.

**Core** (`Core.lua`) initializes both `BarSnapDB` (global) and `BarSnapCharDB` (per-character) SavedVariables on `PLAYER_LOGIN`, merging with defaults and validating presets in both stores. Provides `NS.DeepCopy()`, `NS.Print()` (blue prefix), `NS.Warn()` (red prefix), `NS.SetupTooltip()` helpers, and scope accessor functions (`NS.GetActiveScope()`, `NS.SetActiveScope()`, `NS.GetActivePresets()`) that all modules use instead of accessing preset arrays directly.

**Constants** (`Constants.lua`) centralizes all UI dimensions, texture paths, color tuples, action categories, and the `NS.TYPE_MAP` that maps WoW API action types to category keys (e.g., `summonmount` → `"mounts"`, `flyout` → `"spells"`).

**Scanner** (`Engine/Scanner.lua`) reads all 96 slots (8 bars × 12 slots) via `GetActionInfo()`, classifying each as spell/item/macro/mount/toy/flyout/equipmentset/summonpet. Items that are toys are auto-reclassified; legacy `companion` types are resolved to toy or summonpet. `NS.ScanBars()` returns a sparse actions table (only non-empty slots stored). `NS.CountActions()` counts entries for display.

**Validator** (`Engine/Validator.lua`) provides guards called before any bar modification:
- `NS.CanModifyBars()` — blocks during `InCombatLockdown()`
- `NS.ValidateName(name)` — trims and validates preset names
- `NS.UniqueName(name, excludeIndex)` — auto-appends " (2)", " (3)" etc. for duplicates within the active scope
- `NS.ValidateAction(action)` — checks availability per type (spell learned, item in bags, macro exists, mount known, toy owned, equipment set exists, battle pet known)
- `NS.FindMacroIndex(action)` — resolves macro name to index

**Restore** (`Engine/Restore.lua`) applies presets to bars. `NS.ApplyPreset(preset)` iterates all 96 slots — first checks per-bar filters (`barFilters`), then checks per-category filters, clears empty ones (unless `preserveLayout` is on), and places actions using type-specific pickup APIs. Failed placements retry up to `NS.RETRY_MAX` (5) times at `NS.RETRY_INTERVAL` (0.1s) intervals using `C_Timer.After()`. An async sentinel counter delays the summary chat message until all retries complete.

**UI** consists of three modules: `PresetRow` uses object pooling for list rows. `EditorFrame` provides a modal editor anchored to the right of the main window, with an icon picker grid and `StaticPopupDialogs["BARSNAP_DELETE_PRESET"]` for delete confirmation. `MainFrame` creates the draggable floating window with a scope toggle button (Global/Character), manages the preset scroll list, dynamically resizes (170-500px height), and registers with `UISpecialFrames` for ESC close. `Settings` registers a Blizzard addon settings panel with an "Open BarSnap" button.

## Data Model

Persisted via WoW SavedVariables. Two separate stores:

### BarSnapDB (account-wide, `SavedVariables`)

- **presets** — Array of global preset objects (shared across all characters)

### BarSnapCharDB (per-character, `SavedVariablesPerCharacter`)

- **presets** — Array of character-specific preset objects
- **scope** — `"global"` or `"character"` — persists the last-selected scope per character

### Preset Object Schema

Each preset (in either store) contains:
- `name` (string), `icon` (texture ID), `timestamp` (unix), `specID` (int, 0 if none)
- `preserveLayout` (bool) — when true, unlisted slots are left untouched instead of cleared
- `filters` — per-category booleans: `spells`, `macros`, `items`, `mounts`, `toys`, `pets`
- `barFilters` — per-bar booleans keyed 1-8: controls whether each action bar is restored
- `actions` — sparse table keyed by slot number (1-96), values are `{type, id}` or `{type="macro", name}` for macros or `{type="equipmentset", name}` for equipment sets

Default filters (all true) are deep-copied from `NS.DEFAULT_FILTERS` and `NS.DEFAULT_BAR_FILTERS` on preset creation to avoid reference sharing.

### Scope Accessor Pattern

All modules access presets through `NS.GetActivePresets()` which returns the correct array based on the current scope. No module accesses `NS.db.presets` or `NS.charDb.presets` directly (except Core.lua initialization).

## Key Design Decisions

**Sparse storage** — Only non-empty slots are stored in the actions table. Empty slots are nil, reducing memory and SavedVariables size.

**Category filters** — Each preset has independent filter state, so you can restore spells but skip items from the same preset. Category mapping uses `NS.TYPE_MAP` to handle WoW API type names differing from stored types (e.g., WoW returns `"summonmount"`, we store `"mount"`, both map to the `"mounts"` category; `summonpet` maps to `"pets"`).

**Bar filters** — Each preset has per-bar filter state (`barFilters[1..8]`). Disabled bars skip all slots in that bar range during restoration. Bar filters are checked before category filters in the restore loop.

**Retry logic** — Action placement can fail due to race conditions with cursor state. The retry system is capped at 5 attempts with a hard ceiling of 10 to prevent infinite loops. Retries abort if combat starts mid-restoration.

**Combat safety** — All bar modifications are guarded by `InCombatLockdown()`. This is a WoW API requirement — protected actions cannot be modified during combat.

**Async completion tracking** — Restoration uses a pending counter incremented only when a retry is actually queued. The summary message fires only after all pending operations resolve, ensuring accurate placed/skipped counts.

**Name uniqueness** — Preset names auto-deduplicate with numeric suffixes within the active scope. `UniqueName()` accepts an `excludeIndex` parameter for rename operations. The same name can exist in both global and character scopes.

**Scope isolation** — Global presets live in `BarSnapDB`, character presets in `BarSnapCharDB`. A scope toggle button in the main window controls which store is active. `NS.SetActiveScope()` closes the editor before switching (prevents stale index access). Each character remembers their last-selected scope.

## Build

```bash
./build.sh
```

Creates `build/BarSnap_<version>_<date>.zip` for CurseForge upload. Reads version from the TOC file.

## WoW Interface

- **Interface:** 120000 (Midnight)
- **Version:** 1.0.0
