# BarSnap Release Notes

## Version 1.0.0 - Initial Release

### New Features

- **Action Bar Presets** — Save your entire action bar configuration into named presets with one click.

- **One-Click Restore** — Apply any saved preset to instantly swap your entire action bar setup. Perfect for switching between farming, fighting, and fishing bars.

- **Global & Character Scopes** — Save presets globally (shared across all characters) or per-character. Each character remembers its last-selected scope.

- **Smart Icons** — Each preset automatically displays the icon from its first populated slot. Use the built-in icon picker to customize icons for easy visual identification.

- **Category Filters** — Toggle which action types restore independently: Spells, Macros, Items, Mounts, Toys, and Pets.

- **Per-Bar Filters** — Enable or disable restoration for each individual bar (1-8).

- **Layout Preservation** — Option to keep unlisted slots unchanged when applying a preset. Swap out some actions while keeping others in place.

- **Preset Editor** — Edit preset names (max 40 characters), change icons, manage category and bar filters, and delete presets.

- **Floating Window** — Draggable UI window with ESC-to-close support.

- **Combat Safe** — Cannot save or apply presets while in combat (WoW API restriction). Prevents accidental action bar changes during raids and dungeons.

- **Action Count Display** — See how many actions each preset contains for quick overview.

- **Persistent Storage** — All presets saved across WoW sessions in SavedVariables (global and per-character).

- **Unique Name Auto-Suffix** — Duplicate preset names are automatically suffixed with " (2)", " (3)", etc. to maintain uniqueness.

- **Macro Support** — Presets save and restore macro actions by name, so your custom macros integrate seamlessly.

- **Item & Toy Support** — Items and toys in presets validate against your current inventory and toy collection.

- **Mount Support** — Mount actions from your mount journal restore correctly.

- **Flyout Support** — Spell flyouts (like portal lists) are supported.

- **Equipment Set Support** — Equipment sets are saved by name and restore correctly.

- **Battle Pet Support** — Battle pets from your pet journal are captured and restored.

- **Retry Logic** — Action placement automatically retries (up to 5 times) if it fails, handling timing issues gracefully.

- **Blizzard Settings Panel** — Integrated addon settings panel accessible from WoW's addon options.

### Keyboard Commands

- `/bs` or `/barsnap` — Open/close the main window