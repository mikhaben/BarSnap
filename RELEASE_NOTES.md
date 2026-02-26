# BarSnap Release Notes

## Version 1.0.0 - Initial Release

### New Features

- **Action Bar Presets** — Save your entire action bar configuration (all 72 slots across bars 1-6) into named presets with one click.

- **One-Click Restore** — Apply any saved preset to instantly swap your entire action bar setup. Perfect for switching between farming, fighting, and fishing bars.

- **Smart Icons** — Each preset automatically displays the icon from its first populated slot. Use the built-in icon picker to customize icons for easy visual identification.

- **Category Filters** — Toggle which action types restore independently: Spells, Macros, Items, Mounts, and Toys. Useful for farming bars where you want specific actions but not others.

- **Layout Preservation** — Option to keep unlisted slots unchanged when applying a preset. Swap out some actions while keeping others in place.

- **Preset Editor** — Edit preset names (max 40 characters), change icons, manage category filters, and delete presets.

- **Floating Window** — Draggable, resizable UI window that remembers your position between sessions.

- **Combat Safe** — Cannot save or apply presets while in combat (WoW API restriction). Prevents accidental action bar changes during raids and dungeons.

- **Action Count Display** — See how many actions each preset contains for quick overview.

- **Empty State Message** — Clear "No presets yet" message when you haven't created any presets.

- **Persistent Storage** — All presets and window position saved across WoW sessions in SavedVariables.

- **Unique Name Auto-Suffix** — Duplicate preset names are automatically suffixed with " (2)", " (3)", etc. to maintain uniqueness.

- **Macro Support** — Presets save and restore macro actions by name, so your custom macros integrate seamlessly.

- **Item & Toy Support** — Items and toys in presets validate against your current inventory and toy collection.

- **Mount Support** — Mount actions from your mount journal restore correctly.

- **Flyout Support** — Spell flyouts (like portal lists) are supported.

- **Retry Logic** — Action placement automatically retries (up to 3 times) if it fails, handling timing issues gracefully.

### Keyboard Commands

- `/bs` or `/barsnap` — Open/close the main window
- `/bs reset` — Reset window position to screen center