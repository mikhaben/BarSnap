# BarSnap

World of Warcraft addon that saves and restores action bar presets. Players capture their current bar configuration (all 180 slots across bars 1-15) into named presets, then swap between them with one click. Features global and per-character preset scoping, category-based filtering, per-bar filtering, custom icons, layout preservation, confirmation popups for form/dragonriding/modern Edit Mode bars, and a draggable UI with preset editor.

## Commands

- `/bs` or `/barsnap` — Toggle main window
- `/bs debug` — Print every non-empty action slot to chat (diagnostic; shows type, id, macro pool)

## Project Structure

```
BarSnap/
├── BarSnap.toc            # TOC metadata, load order, SavedVariables declaration
├── Constants.lua          # All shared constants: slot model, dimensions, textures, colors, categories, type mappings, BAR_LABELS/BAR_TOOLTIPS
├── Core.lua               # Namespace init, SavedVariables management, preset validation/migration, slash command dispatch, NS.HashMacroBody
├── Engine/
│   ├── Scanner.lua        # ScanBars (sparse table over 180 slots) + DebugScan diagnostic + duplicate-name detection
│   ├── Validator.lua      # Combat guard, preset name validation, unique-name suffixing
│   └── Restore.lua        # ApplyPreset, FindMacroIndex with name+hash caches, mount/flyout caches, retry logic, GetAffectedSpecialBars
├── UI/
│   ├── WindowFactory.lua  # NS.CreateWindow — floating-vs-docked window builder reused by every frame
│   ├── PresetRow.lua      # Preset list row component (icon, name, apply/edit buttons, row pooling)
│   ├── EditorFrame.lua    # Preset editor (icon picker, name, category + per-bar checkboxes with tooltips, special-bar confirmation popup, RequestApplyPreset)
│   ├── MainFrame.lua      # Main floating window (preset list, save button, scroll, drag, scope toggle, ESC close)
│   └── Settings.lua       # Blizzard addon settings panel
├── Assets/
│   └── logo.tga           # Addon icon
├── build.sh               # CurseForge build script (versioned zip)
└── deploy.sh              # Local dev deploy: builds and copies the zip into the live WoW AddOns folder
```

**Load order:** Constants → Core → Engine (Scanner, Validator, Restore) → UI (WindowFactory, PresetRow, EditorFrame, MainFrame, Settings). Constants must load first so shared values are available everywhere; `WindowFactory` must load before any UI frame that calls `NS.CreateWindow`.

## Architecture

All modules share a single namespace: `local AddonName, NS = ...` passed via the TOC addon system. The namespace is exposed globally as `_G.BarSnap` for debugging.

**Core** (`Core.lua`) initializes both `BarSnapDB` (global) and `BarSnapCharDB` (per-character) SavedVariables on `PLAYER_LOGIN`, merging with defaults and validating presets in both stores. Provides `NS.DeepCopy()`, `NS.Print()` (blue prefix), `NS.Warn()` (red prefix), `NS.SetupTooltip()` helpers, and scope accessor functions (`NS.GetActiveScope()`, `NS.SetActiveScope()`, `NS.GetActivePresets()`) that all modules use instead of accessing preset arrays directly.

**Constants** (`Constants.lua`) centralizes all UI dimensions, texture paths, color tuples, action categories, and the `NS.TYPE_MAP` that maps WoW API action types to category keys (e.g., `summonmount` → `"mounts"`, `flyout` → `"spells"`).

**Scanner** (`Engine/Scanner.lua`) reads all 180 slots (15 bars × 12 slots) via `GetActionInfo()`, classifying each as spell/item/macro/mount/toy/flyout/equipmentset/summonpet. Slots 1-72 cover the Main bar + 4 legacy MultiBars. Slots 73-120 (pages 7-10) are class-paged "special" bars used by some classes for form/stance/bonus paging — exact bar↔form assignment varies by class/spec and is intentionally NOT promised in our UI (we label them "Special" and let users discover via `/bs debug`). Slots 121-132 (page 11) are the Dragonriding/Skyriding override bar. Slots 133-144 (page 12) are reserved and usually empty. Slots 145-180 (pages 13-15) are Blizzard's MultiBar5/6/7 frames — visible as Action Bar 6/7/8 in the Action Bars options panel. Items that are toys are auto-reclassified; legacy `companion` types are resolved to toy or summonpet. Macro entries include an `isCharacter` flag (true/false) AND a `bodyHash` (DJB2 of the whitespace-normalized body via `NS.HashMacroBody`) — together these let restore tolerate renames and pool migrations. Broken macro references (WoW returns id=0/nil) are warned with slot+bar instead of silently dropped (mirrors ActionBarSaverReloaded's pattern). At end of scan, a single summary warns if any captured macros have duplicate names across pools. `NS.ScanBars()` returns a sparse actions table (only non-empty slots stored). `NS.CountActions()` counts entries for display. `NS.DebugScan()` powers `/bs debug` — dumps every non-empty slot to chat for diagnostics.

**Validator** (`Engine/Validator.lua`) provides guards called before bar modification:
- `NS.CanModifyBars()` — blocks during `InCombatLockdown()`
- `NS.ValidateName(name)` — trims and validates preset names
- `NS.UniqueName(name, excludeIndex)` — auto-appends " (2)", " (3)" etc. for duplicates within the active scope

**Restore** (`Engine/Restore.lua`) applies presets to bars. `NS.ApplyPreset(preset)` iterates all 180 slots — first checks per-bar filters (`barFilters`), then per-category filters, clears empty ones (unless `preserveLayout` is on), and places actions using type-specific pickup APIs. Form/dragonriding confirmation is handled by the UI layer (`NS.RequestApplyPreset` in `EditorFrame.lua`) — `ApplyPreset` itself is unconditional. Per-apply caches (mount, flyout, macro name-by-pool, macro hash-by-pool) are built at start and cleared on completion. `NS.FindMacroIndex(action)` resolves a macro record through a four-step chain — name in saved pool → hash in saved pool → hash in other pool → nil — and PlaceActionImpl falls back to `PickupMacro(action.name)` when the chain misses. Failed placements retry up to `NS.RETRY_MAX` (5) times at `NS.RETRY_INTERVAL` (0.1s) intervals using `C_Timer.After()`. An async sentinel counter delays the summary chat message until all retries complete.

**UI** consists of five modules. `WindowFactory` (`NS.CreateWindow`) builds either floating (draggable, ESC-closeable, centered) or docked (anchored to a parent frame) windows from a single `BasicFrameTemplateWithInset`-based constructor — every other UI frame goes through it. `PresetRow` uses object pooling for scroll-list rows. `EditorFrame` provides the modal editor anchored to the right of the main window, with an icon picker grid, `StaticPopupDialogs[NS.POPUP_DELETE_PRESET]` for delete confirmation, `StaticPopupDialogs[NS.POPUP_CONFIRM_FORM_BARS]` for the form-bar guard, and the public `NS.RequestApplyPreset` entry point that gates `ApplyPreset` behind that popup. `MainFrame` creates the draggable floating window with a scope toggle button (Global/Character), manages the preset scroll list via `WowScrollBoxList`, dynamically resizes (170-500px height), and registers with `UISpecialFrames` for ESC close. `Settings` registers a Blizzard addon settings panel with an "Open BarSnap" button.

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
- `barFilters` — per-bar booleans keyed 1-15: controls whether each action bar is restored. Bars 1-6 are the standard visible action bars (Main + 4 MultiBars, slots 1-72). Bars 7-10, 12 (slots 73-120, 133-144) are class-paged "special" bars — paged onto Bar 1 dynamically for some classes' forms/stances/bonus pages; exact bar↔form assignment varies by class/spec and is left unlabelled in the UI. Bar 11 (slots 121-132) is the Dragonriding/Skyriding override bar — directly editable in the default Blizzard UI when on a flying mount. Bars 13-15 (slots 145-180) are Blizzard's MultiBar5/6/7 — visible as **Action Bar 6, 7, 8** in the Action Bars options panel. See `NS.BAR_TOOLTIPS` in Constants.lua for per-bar hover text.
- `actions` — sparse table keyed by slot number (1-180), values are `{type, id}`, `{type="macro", name, isCharacter, bodyHash}` for macros, or `{type="equipmentset", name}` for equipment sets

Defaults are deep-copied from `NS.DEFAULT_FILTERS` (all categories true) and `NS.DEFAULT_BAR_FILTERS` (bars 1-6 + 13-15 true, bars 7-12 false — see the **Bar filters** decision below) on preset creation to avoid reference sharing.

### Scope Accessor Pattern

All modules access presets through `NS.GetActivePresets()` which returns the correct array based on the current scope. No module accesses `NS.db.presets` or `NS.charDb.presets` directly (except Core.lua initialization).

## Key Design Decisions

**Sparse storage** — Only non-empty slots are stored in the actions table. Empty slots are nil, reducing memory and SavedVariables size.

**Category filters** — Each preset has independent filter state, so you can restore spells but skip items from the same preset. Category mapping uses `NS.TYPE_MAP` to handle WoW API type names differing from stored types (e.g., WoW returns `"summonmount"`, we store `"mount"`, both map to the `"mounts"` category; `summonpet` maps to `"pets"`).

**Bar filters** — Each preset has per-bar filter state (`barFilters[1..15]`). Disabled bars skip all slots in that bar range during restoration. Bar filters are checked before category filters in the restore loop. **New presets default bars 1-6 and 13-15 to true** (the user-visible Action Bars 1-5 + Action Bars 6-8) **and bars 7-12 to false** (class form pages and Dragonriding override — paged onto Bar 1 dynamically, not visible as separate bars). **Legacy presets are stricter**: any missing bar entry above 6 defaults to false during migration, because pre-1.2 presets never scanned slots 97-180 and we can't safely re-enable bars whose data we don't have.

**Retry logic** — Action placement can fail due to race conditions with cursor state. The retry system is capped at 5 attempts with a hard ceiling of 10 to prevent infinite loops. Retries abort if combat starts mid-restoration.

**Combat safety** — All bar modifications are guarded by `InCombatLockdown()`. This is a WoW API requirement — protected actions cannot be modified during combat.

**Async completion tracking** — Restoration uses a pending counter incremented only when a retry is actually queued. The summary message fires only after all pending operations resolve, ensuring accurate placed/skipped counts.

**Name uniqueness** — Preset names auto-deduplicate with numeric suffixes within the active scope. `UniqueName()` accepts an `excludeIndex` parameter for rename operations. The same name can exist in both global and character scopes.

**Scope isolation** — Global presets live in `BarSnapDB`, character presets in `BarSnapCharDB`. A scope toggle button in the main window controls which store is active. `NS.SetActiveScope()` closes the editor before switching (prevents stale index access) and hides any active form bar popup. Each character remembers their last-selected scope.

**Macro scope handling** — WoW allows both account-wide (indices 1-`MAX_ACCOUNT_MACROS`, currently 120 in Midnight) and character-specific (indices `MAX_ACCOUNT_MACROS+1` to `MAX_ACCOUNT_MACROS+MAX_CHARACTER_MACROS`, currently 121-150 in Midnight where `MAX_CHARACTER_MACROS=30`) macros with overlapping names. Each macro action stores `isCharacter` (true/false) AND a DJB2 `bodyHash` of the whitespace-normalized body at scan time. Restore lookup chain: (1) exact name in the saved pool — survives same-name duplicates across pools, (2) hash in the saved pool — survives rename, (3) hash in the other pool — survives pool migration (account ↔ character). If the chain misses, `PlaceActionImpl` falls back to `PickupMacro(action.name)` and lets WoW resolve — strictly additive last resort. Legacy presets (isCharacter == nil, bodyHash == nil) collapse to a name-only search across both pools, matching pre-1.1 behaviour. Hash function is whitespace-normalized (ABP-style) so trivial formatting changes don't break the match.

**Special bar confirmation** — Bars 7-12 are class-paged "special" bars (form/stance/bonus paging for various classes, plus the Dragonriding override at bar 11). Most aren't visible as separate bars in the default UI — they swap onto Bar 1 when the relevant state activates — so applying a preset that touches them can silently rewrite content the user can't see. `NS.RequestApplyPreset()` (UI layer) checks via `GetAffectedSpecialBars()` (which considers both preset data and current bar state to avoid false positives) and shows a `StaticPopupDialog` confirmation before proceeding. Bars 13-15 (Action Bar 6-8 in Blizzard's UI) are NOT in the popup — they're regular user-facing bars. The popup captures preset identity (scope, name) rather than a direct reference, allowing re-resolution at confirm time to handle deletion/rename races and scope switches mid-dialog.

## Build

```bash
./build.sh   # zips the addon into build/BarSnap_<version>_<date>.zip for CurseForge upload (reads version from TOC)
./deploy.sh  # builds and copies the zip into the local WoW _retail_/Interface/AddOns folder (path is hard-coded — edit the script for your machine)
```

Retail only — interface version, addon version, and SavedVariables names live in `BarSnap.toc`.

## Releasing

CI (`.github/workflows/release.yml`) runs the [BigWigsMods packager](https://github.com/BigWigsMods/packager) on every push to `main` and uploads to CurseForge, Wago, and GitHub Releases. Untagged pushes are alpha builds; a tagged HEAD produces a stable release. `.pkgmeta` controls the zip contents — BarSnap embeds no libs, so there are no externals; dev/tooling files are stripped via its `ignore` list.

```bash
# Stable release: bump ## Version in BarSnap.toc + add a RELEASE_NOTES.md entry, commit, then:
git tag v1.2.3
git push origin main --follow-tags   # the tag drives the published version
```

Requirements (one-time):
- Repo secrets: `CF_API_KEY` (CurseForge), `WAGO_API_KEY` (Wago). `GITHUB_TOKEN` is provided automatically. The workflow maps these to the env vars the packager expects (`WAGO_API_KEY` → `WAGO_API_TOKEN`, `GITHUB_TOKEN` → `GITHUB_OAUTH`).
- TOC directives `## X-Curse-Project-ID` and `## X-Wago-ID` — the packager reads upload destinations from these. Omit one to skip that platform.

`build.sh` / `deploy.sh` remain the manual path for local zips and in-game testing.
