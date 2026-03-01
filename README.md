# BarSnap

A World of Warcraft addon that saves and restores action bar presets — switch between farming, fighting, fishing bars instantly.

## Features

- **Preset Saving** — Capture all action bars into a named preset with one click
- **One-Click Restore** — Apply any saved preset to instantly swap your entire action bar configuration
- **Global & Character Scopes** — Save presets globally (shared across characters) or per-character. Toggle scope with one click
- **Smart Icons** — Each preset shows the icon from its first populated slot, or customize with the built-in icon picker
- **Category Filters** — Toggle which action types restore (Spells, Macros, Items, Mounts, Toys, Pets)
- **Per-Bar Filters** — Enable or disable restoration for each individual action bar
- **Layout Preservation** — Option to keep unlisted slots unchanged, or clear them when applying a preset
- **Preset Management** — Edit names, change icons, delete presets, and view action counts
- **Draggable Window** — Floating, draggable UI window with ESC-to-close support
- **Combat Safe** — Cannot save or apply presets while in combat (WoW combat lockdown restriction)

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

Toggle which bars are included when restoring. Disable a bar to leave all its slots untouched.

### Options

- **Keep unlisted slots** — When enabled, slots that aren't in the preset stay as-is instead of being cleared

### Delete Preset

Click the trash icon to permanently delete a preset (cannot be undone).

## Tech Stack

- **Language:** Lua (WoW addon API)
- **WoW Interface:** 120000 (Midnight)
- **UI Framework:** Raw WoW frame API (no AceGUI)
- **Templates Used:**
  - BasicFrameTemplateWithInset (floating windows)
  - WowScrollBoxList + MinimalScrollBar (scrollable preset list)
  - UIPanelButtonTemplate (action buttons)

## Project Structure

```
BarSnap/
├── BarSnap.toc              # Addon manifest and load order
├── Constants.lua            # UI constants, textures, colors, categories
├── Core.lua                 # Main namespace, SavedVariables, slash commands
├── Engine/
│   ├── Scanner.lua          # Action bar scanning and action parsing
│   ├── Validator.lua        # Combat guards, action validation
│   └── Restore.lua          # Preset restoration with retry logic
├── UI/
│   ├── PresetRow.lua        # Individual preset list row component
│   ├── EditorFrame.lua      # Preset editor frame (icon, name, filters, delete)
│   ├── MainFrame.lua        # Main window and preset list display
│   └── Settings.lua         # Blizzard addon settings panel
├── Assets/                  # Custom addon icon
└── build.sh                 # CurseForge build script
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

### Restoration with Validation

When you apply a preset, the addon:
1. Checks per-bar filters — disabled bars are skipped entirely
2. Validates each action still exists (spell learned, item in bags, macro exists, mount known, toy owned, equipment set exists, battle pet known)
3. Picks up the action from the appropriate UI system
4. Places it into the target slot with retry logic (up to 5 attempts over 0.5 seconds)
5. Respects category filters — skipped actions don't fill the slot
6. Respects preserve layout option — unlisted slots stay unchanged
7. Reports the result (X placed, Y skipped, Z unavailable)

### Combat Safety

WoW's `InCombatLockdown()` API prevents modifying action bars during combat. BarSnap guards save and restore operations with this check to prevent errors.

## Troubleshooting

### "Leave combat first" error

- You cannot save or apply presets while in combat. Exit combat and try again.

### Actions don't restore / appear as skipped

1. The action requirements aren't met (spell not learned, item not in bags, macro deleted, mount not known, toy not owned, equipment set deleted, battle pet not known)
2. The action category is disabled in the editor filters
3. The bar filter for that bar is disabled
4. You enabled "Keep unlisted slots" and the preset doesn't include those slots

To debug: Edit the preset and check which categories are enabled.

### Macro doesn't show after restore

Macros are identified by name. If the macro no longer exists in your macro list, it cannot be restored. Recreate the macro and save a new preset.

### Items won't place in slots

Items must be in your inventory (bags or bank doesn't count). Only items currently in bags or toys you own can restore. Check item location and try again.

## Saving Data

BarSnap saves presets to two SavedVariables that persist across WoW sessions:
- `BarSnapDB` — Global (account-wide) presets shared across all characters
- `BarSnapCharDB` — Per-character presets and the last-selected scope preference

## Version

**Current Version:** 1.0.0
**Author:** justLuther
**License:** MIT

## Contributing

Found a bug or have a feature request? Open an issue or submit a pull request on the project repository.

## License

BarSnap is provided as-is. Feel free to modify and redistribute under the MIT license.
