# BarSnap

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A World of Warcraft addon that saves and restores action bar presets — switch between farming, fighting, fishing bars instantly.

## Features

- **Preset Saving** — Capture all 180 action bar slots (bars 1-15) into a named preset with one click
- **One-Click Restore** — Apply any saved preset to instantly swap your entire action bar configuration
- **Global & Character Scopes** — Save presets globally (shared across characters) or per-character. Toggle scope with one click
- **Smart Icons** — Each preset shows the icon from its first populated slot, or customize with the built-in icon picker
- **Category Filters** — Toggle which action types restore (Spells, Macros, Items, Mounts, Toys, Pets)
- **Per-Bar Filters** — Enable or disable restoration for each individual action bar (1-15); hover tooltips explain which bars overlap with class form/stance pages and the modern Action Bar 6-8 frames
- **Special-Bar Confirmation** — Optional popup warns before applying a preset that would modify Druid form / Rogue stealth / Warrior stance / Dragonriding slots, so you never overwrite a bar you can't see
- **Robust Macro Handling** — Macros are tracked by name, pool (account vs character), and body hash, so renamed or re-pooled macros still restore correctly
- **Layout Preservation** — Option to keep unlisted slots unchanged, or clear them when applying a preset
- **Preset Management** — Edit names, change icons, delete presets, and view action counts
- **Draggable Window** — Floating, draggable UI window with ESC-to-close support
- **Combat Safe** — Cannot save or apply presets while in combat (WoW combat lockdown restriction)
- **Diagnostic Output** — `/bs debug` dumps every non-empty slot to chat with bar labels and slot ranges, for troubleshooting

## Quick Start

1. Download and install BarSnap into your `World of Warcraft\_retail_\Interface\AddOns\` folder
2. Reload your UI (`/reload`) or restart WoW
3. Type `/bs` to open the main window
4. Click "Save Current Bars" to capture your current action bar configuration
5. Name your preset and customize if needed
6. Click the play button on any preset to restore it instantly

## Commands

| Command | Effect |
|---------|--------|
| `/bs` or `/barsnap` | Toggle the main window |
| `/bs debug` | Print every non-empty action slot to chat — shows BarSnap bar, slot range, action type, macro pool, etc. Useful for correlating your in-game UI to BarSnap's bar numbering. |

## Main Window

### Save Current Bars Button

Captures all action bar slots into a new preset. The addon auto-names it "Preset #1" (or next number), displays the action count, and opens the editor for customization.

### Preset List

Shows all saved presets with:
- **Icon** (left) — Visual indicator from the preset's first slot action
- **Preset Name** — Click edit button to rename
- **Apply Button** (play icon) — Restore this preset to your action bars
- **Edit Button** (gear icon) — Customize the preset's settings and filters

### Empty State

When you have no presets, displays "No presets yet" with an empty list.

## Preset Editor

### Icon Selection

Click the icon button (top-left) to open WoW's built-in icon selector. Choose any texture to represent your preset.

### Preset Name

Edit the name in the text box (max 40 characters). Names are auto-trimmed and must be unique — duplicates get " (2)", " (3)" suffixes automatically.

### Restore Categories

Toggle which action types restore when applying the preset:
- **Spells** — Spell actions (including flyouts)
- **Macros** — Macro actions
- **Items** — Item actions (including equipment sets)
- **Mounts** — Mount actions
- **Toys** — Toy actions
- **Pets** — Battle pet actions

### Bar Filters

Toggle which bars are included when restoring. Disable a bar to leave all its slots untouched. Hover any checkbox for a tooltip explaining the bar's slot range and class context (e.g. Bar 7 doubles as Druid Bear form, Bar 13 maps to Blizzard's visible Action Bar 6).

New presets default the visible action bars (1-6 and 13-15) to enabled and the class form/Dragonriding pages (7-12) to disabled — opt in to those bars per preset if you want BarSnap to manage them.

### Options

- **Keep unlisted slots** — When enabled, slots that aren't in the preset stay as-is instead of being cleared

### Delete Preset

Click the trash icon to permanently delete a preset (cannot be undone).

## Tech Stack

- **Language:** Lua (WoW addon API)
- **WoW Interface:** 120007 (Midnight)
- **UI Framework:** Raw WoW frame API (no AceGUI)
- **Templates Used:**
  - BasicFrameTemplateWithInset (floating windows)
  - WowScrollBoxList + MinimalScrollBar (scrollable preset list)
  - UIPanelButtonTemplate (action buttons)

## Project Structure

```
BarSnap/
├── BarSnap.toc              # Addon manifest and load order
├── Constants.lua            # Slot model, dimensions, textures, colors, categories, bar labels & tooltips
├── Core.lua                 # Main namespace, SavedVariables, slash commands, helpers
├── Engine/
│   ├── Scanner.lua          # Bar scanning, sparse action capture, duplicate-name detection, debug dump
│   ├── Validator.lua        # Combat guard, name validation, unique-name suffixing
│   └── Restore.lua          # Preset apply, macro/mount/flyout lookup caches, retry logic, special-bar detection
├── UI/
│   ├── WindowFactory.lua    # Floating/docked window builder shared by every frame
│   ├── PresetRow.lua        # Individual preset list row component
│   ├── EditorFrame.lua      # Preset editor (icon, name, category & per-bar filters, confirmation popups)
│   ├── MainFrame.lua        # Main window and preset list display
│   └── Settings.lua         # Blizzard addon settings panel
├── Assets/                  # Custom addon icon
├── release-notes/           # Per-version release notes (one file per version)
├── .pkgmeta                 # Packager config for the release workflow
├── .github/workflows/
│   └── release.yml          # CI: tag push → package + upload to CurseForge, Wago, GitHub
├── LICENSE                  # MIT
├── CONTRIBUTING.md          # How to build, test, and submit PRs
├── build.sh                 # CurseForge build script (versioned zip)
├── deploy-local.sh          # Local dev: build + install into your WoW AddOns folder (path from .env)
└── .env.example             # Template for .env (gitignored); set WOW_ADDONS_DIR to your AddOns path
```

## How It Works

### Action Bar Scanning

When you click "Save Current Bars", the addon scans all action bars and records:
- **Spells** — Spell ID (normalized to base spell)
- **Macros** — Macro name
- **Items** — Item ID
- **Mounts** — Mount ID
- **Toys** — Toy ID (items that are toys are auto-reclassified)
- **Flyouts** — Flyout ID
- **Equipment Sets** — Set name
- **Battle Pets** — Pet ID

Empty slots are not recorded (sparse storage).

### Restoration

When you apply a preset, the addon:
1. Checks per-bar filters — disabled bars are skipped entirely (slots left as-is)
2. Checks per-category filters — filtered-out types are skipped
3. Picks up the action through the appropriate WoW API (spell, item, macro, mount, toy, flyout, equipment set, or battle pet)
4. Places it into the target slot, retrying up to 5 attempts at 100 ms intervals if cursor state fights the place
5. For macros specifically: looks up by exact name in the saved pool, then by body hash, then in the other pool, then falls back to `PickupMacro(name)` — survives rename and pool migration
6. Respects the preserve-layout option — unlisted slots stay unchanged when on, get cleared when off
7. Reports the result in chat (X placed, Y skipped)

### Combat Safety

WoW's `InCombatLockdown()` API prevents modifying action bars during combat. BarSnap guards save and restore operations with this check to prevent errors.

## Troubleshooting

### "Leave combat first" error

- You cannot save or apply presets while in combat. Exit combat and try again.

### Actions don't restore / appear as skipped

1. The action no longer exists or isn't available to you (spell not learned, item not in bags, macro deleted, mount not known, toy not owned, equipment set deleted, battle pet not known)
2. The action category is disabled in the editor filters
3. The bar filter for that bar is disabled — common gotcha: your visual "Action Bar 6/7/8" maps to BarSnap's Bars 13/14/15, and the form-bar pages (Druid/Rogue/Warrior/Evoker) map to BarSnap bars 7-12. Hover the editor checkboxes for the slot-range hint.
4. You enabled "Keep unlisted slots" and the preset doesn't include those slots

To debug: run `/bs debug` to see exactly which BarSnap bars contain your actions, then enable those bars in the editor.

### Macro doesn't show after restore

Macros are identified by name first, then by body hash (so renamed macros still restore if the body matches), then across the other pool (account ↔ character). If none of those match, BarSnap falls back to `PickupMacro(<name>)` and lets WoW resolve. If the macro is genuinely gone — deleted with no body match anywhere — the slot is reported as skipped. Run `/bs debug` after saving to confirm the macro was captured with the expected pool.

### Items won't place in slots

Items must be in your inventory (bags or bank doesn't count). Only items currently in bags or toys you own can restore. Check item location and try again.

## Saving Data

BarSnap saves presets to two SavedVariables that persist across WoW sessions:
- `BarSnapDB` — Global (account-wide) presets shared across all characters
- `BarSnapCharDB` — Per-character presets and the last-selected scope preference

## Version

**Current Version:** 1.2.2
**Author:** justLuther
**License:** [MIT](LICENSE)

## Releasing

Releases are built and published by GitHub Actions (`.github/workflows/release.yml`)
using the [BigWigsMods packager](https://github.com/BigWigsMods/packager), triggered
when you push a **version tag**.

To cut a release:

1. Bump `## Version` in `BarSnap.toc` and create `release-notes/<version>.md` with that
   version's notes — this file becomes the changelog shown on CurseForge/Wago.
2. Commit to `main`, then tag and push the tag:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```
3. The workflow packages the addon and uploads it to CurseForge, Wago, and GitHub Releases.

**One-time setup:** add the `CF_API_KEY` and `WAGO_API_KEY` repository secrets
(Settings → Secrets and variables → Actions). Both are required — if either is missing
the workflow skips the upload (with a warning) rather than publishing to only one
platform. Project IDs already live in `BarSnap.toc` (`## X-Curse-Project-ID`,
`## X-Wago-ID`). `build.sh` remains available for manual local packaging.

## Contributing

Found a bug or have a feature request? Open an issue or submit a pull request — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to build, test, and what to expect in review.

## License

BarSnap is provided as-is. Feel free to modify and redistribute under the [MIT license](LICENSE).
