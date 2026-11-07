# BarSnap

## North star

A World of Warcraft addon that saves the player's action bars into named presets and restores one
with a click, without wiping bars the player did not ask it to touch. Presets are account-wide or
per-character, and filter what they restore by action category and by bar. Retail only.

## Commands

- `./check.sh` — must pass before a commit. It runs `luacheck .` (config in `.luacheckrc`: a new
  WoW API the addon reads goes in `read_globals`, a global it writes goes in `globals`), the
  no-comments rule (`ast-grep scan`, rule in `lint-rules/`) and the 1000-line cap per Lua file.
  Needs `brew install luacheck ast-grep`.
- `./build.sh` — versioned zip in `build/`.
- `./deploy-local.sh` — build and install into the local AddOns folder (`WOW_ADDONS_DIR` in the
  gitignored `.env`, template `.env.example`).
- In game: `/bs` or `/barsnap` toggles the window; `/bs debug` prints every non-empty slot (type,
  id, macro pool), with a per-bar summary first. There is no automated test suite; changes are
  checked in game after `/reload`.

## Feature map

Load order is the file list in `BarSnap.toc`. `Constants.lua` loads first, and `UI/WindowFactory.lua`
before any frame that calls `NS.CreateWindow`.

| Feature | Where |
| --- | --- |
| Slot model, bar labels and tooltips, categories, `NS.TYPE_MAP`, sizes, textures, colors | `Constants.lua` |
| SavedVariables init, preset validation and migration, scope accessors, slash commands, `NS.HashMacroBody` | `Core.lua` |
| Reading the bars into a preset, `/bs debug` | `Engine/Scanner.lua` |
| Combat guard, preset name validation and de-duplication | `Engine/Validator.lua` |
| Applying a preset: per-apply caches, macro lookup, retries, special-bar detection | `Engine/Restore.lua` |
| Floating or docked window builder used by every frame | `UI/WindowFactory.lua` |
| Preset list rows (pooled) | `UI/PresetRow.lua` |
| Preset editor, icon picker, delete and special-bar popups, `NS.RequestApplyPreset` | `UI/EditorFrame.lua` |
| Main window: preset list, save button, scope toggle | `UI/MainFrame.lua` |
| Blizzard settings panel | `UI/Settings.lua` |
| Packaging and upload | `.github/workflows/release.yml`, `.pkgmeta` |

## Architecture

All files share one namespace: `local _, NS = ...` (`AddonName` in place of `_` where a file uses
it), exposed as `_G.BarSnap` for debugging.

**Core** initializes `BarSnapDB` (account) and `BarSnapCharDB` (character) on `PLAYER_LOGIN`,
merging defaults and validating the presets in both. It provides `NS.DeepCopy()`, `NS.Print()`,
`NS.Warn()`, `NS.SetupTooltip()` and the scope accessors (`NS.GetActiveScope()`,
`NS.SetActiveScope()`, `NS.GetActivePresets()`) that every module uses instead of the preset arrays.

**Scanner** reads every slot with `GetActionInfo()` and classifies it as
spell/item/macro/mount/toy/flyout/equipmentset/summonpet. Spells are stored as their base spell ID
(`FindBaseSpellByID`), so presets survive talent and spec changes. Items that are toys are
reclassified; legacy `companion` types resolve to toy or summonpet. Macro entries store
`isCharacter` and a `bodyHash`, which together let restore survive renames and pool moves. A slot
whose macro reference is broken (WoW returns id 0 or nil) is reported with slot and bar instead of
dropped, as ActionBarSaverReloaded does. One summary at the end warns when captured macros share a
name across pools. `NS.ScanBars()` returns a sparse table: only non-empty slots.

**Validator** guards bar changes: `NS.CanModifyBars()` refuses during `InCombatLockdown()` with a
warning, `NS.ValidateName(name)` trims and validates, and `NS.UniqueName(name, excludeIndex)`
appends " (2)", " (3)" within the active scope.

**Restore** applies presets. `NS.ApplyPreset(preset)` walks every slot: bar filter first, then
category filter, then place the action with its type's pickup API, or clear the slot unless
`preserveLayout` is on. `ApplyPreset` is unconditional; the special-bar confirmation lives in the
UI (`NS.RequestApplyPreset`).

- A disabled bar returns `LEAVE_SLOT_UNTOUCHED` from `SlotAction`: its slots are neither placed nor
  cleared, even with `preserveLayout` off. The legacy-preset migration relies on this.
- Mount and flyout caches are built once per apply and cleared at the end, so a preset with many
  mounts does not rescan the mount journal per slot, and the journal can refilter afterwards. The
  macro caches (name and body hash, per pool) are built lazily, so `NS.FindMacroIndex` also works
  outside an apply, as in `/bs debug`.
- Placement runs inside `pcall` (`PlaceActionByType`), so one WoW API error does not stop the
  apply loop.
- A mount hidden by the journal filter is placed through its spell ID. Random Favourite Mount uses
  a sentinel ID.
- Failed placements retry through `C_Timer.After()` up to `NS.RETRY_MAX`, under a hard ceiling that
  holds even if that constant is corrupted, and stop if combat starts. A pending counter, plus one
  sentinel call after the loop, holds the summary message until every retry resolves.

**UI.** `WindowFactory` builds floating (draggable, ESC-closeable) or docked windows from one
`BasicFrameTemplateWithInset` constructor. `PresetRow` pools rows for the `WowScrollBoxList`.
`MainFrame` lets `ScrollUtil` manage the scroll bar's visibility and anchors; setting them by hand
races its callbacks. The main window sizes its height to the list and registers in
`UISpecialFrames` for ESC.

## Data model

Two SavedVariables stores:

- `BarSnapDB` (account-wide): `presets`.
- `BarSnapCharDB` (per character): `presets`, and `scope` (`"global"` or `"character"`), the last
  scope this character selected.

Each preset holds:

- `name`, `icon` (texture ID), `timestamp` (unix), `specID` (0 if none).
- `preserveLayout`: when true, slots the preset does not list are left alone instead of cleared.
- `filters`: per category (`spells`, `macros`, `items`, `mounts`, `toys`, `pets`).
- `barFilters`: per bar, keyed 1-15. See the slot layout below.
- `actions`: sparse, keyed by slot. Values are `{type, id}`, `{type="macro", name, isCharacter,
  bodyHash}` or `{type="equipmentset", name}`.

New presets deep-copy `NS.DEFAULT_FILTERS` and `NS.DEFAULT_BAR_FILTERS`, so presets never share a
table. All modules read presets through `NS.GetActivePresets()`; only Core's initialization touches
`NS.db.presets` or `NS.charDb.presets`.

### Slot layout (retail)

Bar N covers slots `(N-1)*12+1` to `N*12`.

| Slots | Bar | What it is |
| --- | --- | --- |
| 1-12 | 1 | Main bar (Action Bar 1) |
| 13-24 | 2 | Main bar page 2, usually unused |
| 25-72 | 3-6 | MultiBar1-4, shown as Action Bar 2-5 in the options; Blizzard's labels do not map 1:1 to the internal MultiBar order |
| 73-120 | 7-10 | Class form and stance pages (Druid forms, Rogue stealth, Warrior stances, Evoker), paged onto Bar 1 in that form, not separate bars |
| 121-132 | 11 | Dragonriding/Skyriding override, vehicle, possess |
| 133-144 | 12 | Reserved, usually empty |
| 145-180 | 13-15 | MultiBar5-7, shown as Action Bar 6-8 |

The UI labels bars 7-12 generically, because which form uses which page varies by class, spec and
version; `/bs debug` shows the real mapping.

## Key design decisions

**Bar filters.** New presets restore bars 1-6 and 13-15 (everything visible in Blizzard's Action
Bars options) and skip bars 7-12. Legacy presets are stricter: during migration any missing bar
entry above 6 defaults to off, because pre-1.2 presets never scanned slots 97-180 and their data
for those bars is unknown.

**Category filters.** `NS.TYPE_MAP` maps both WoW's type names and the stored ones to a category
(WoW returns `"summonmount"`, BarSnap stores `"mount"`, both map to `"mounts"`).

**Macro pools.** WoW keeps account macros and character macros in separate index ranges
(`MAX_ACCOUNT_MACROS`, `MAX_CHARACTER_MACROS`), and names can repeat across them. Restore resolves
a macro by: its name in the saved pool, then its body hash in the saved pool (survives a rename),
then its body hash in the other pool (survives a move between pools). When all three miss it calls
`PickupMacro(action.name)` and lets WoW choose, which beats leaving the slot blank. Legacy presets
without `isCharacter` search both pools, account first, by name and then hash.
`NS.HashMacroBody` is DJB2 over the whitespace-normalized body, matching ActionBarProfiles'
PackMacro, so formatting changes keep the hash; an empty body hashes to `nil`.

**Special bar confirmation.** Applying a preset that changes bars 7-12 can rewrite content the
player cannot see, so `NS.RequestApplyPreset()` asks first when `GetAffectedSpecialBars()` reports
a bar. A bar counts only when its filter is on and the apply would really place an action or clear
a non-empty slot; no-op changes do not trigger the popup, so players do not learn to click through
it. Bars 13-15 are ordinary visible bars and never trigger it. The popup keeps a reference to the
preset and, on accept, checks it is still in the active scope's list, which rejects a deleted
preset or a scope switch while the popup was open. The delete popup does the same.

**Scope isolation.** `NS.SetActiveScope()` closes the editor (no stale index) and hides an open
special-bar popup before switching. The same name may exist in both scopes.

## Releasing

The flow is in the header of `.github/workflows/release.yml`. A GitHub ruleset on `main` requires
a pull request (work lands on `develop`, then a `develop` → `main` PR) and restricts `v*` tags to
admins. Pushing a `v*` tag publishes to CurseForge, Wago and GitHub Releases, so never push one
unless asked. Deploy needs both `CF_API_KEY` and `WAGO_API_KEY`; with one missing the workflow
skips the upload rather than publish to one platform.
