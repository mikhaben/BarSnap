# BarSnap Release Notes

## Version 1.1.0 - Form Bars & Macro Scope Fix

### New Features

- **Druid Form & Dragonriding Bars** — Bars 9-11 (Bear form, Moonkin/Travel form, and Dragonriding/Skyriding) are now captured and restored alongside your regular action bars. Druids and dragonriders can now snapshot their full bar configuration.

- **Form Bar Confirmation Popup** — A warning popup appears before applying a preset that would modify your form or dragonriding bars, so you never accidentally overwrite a bar you can't see. Inspired by ElvUI's special bar warnings.

- **Per-Bar Filters Extended** — The preset editor now exposes per-bar toggles for bars 9-11 with descriptive labels ("Bar 9 — Bear", "Bar 10 — Moonkin / Travel", "Bar 11 — Dragonriding").

### Bug Fixes

- **Character Macro Restoration** — Fixed a bug where character-specific macros sharing a name with an account macro could restore the wrong macro. Each preset now records which macro pool an action came from and restores it from the correct pool.

- **Disabled Bars Are Now Left Alone** — Previously, turning off a bar in the editor still cleared that bar on apply (unless "Keep unlisted slots" was on). Disabled bars are now truly left untouched, matching the more intuitive meaning of "disabled" and making the form-bar migration safety actually safe.

- **Empty-Preset Apply** — Applying a preset with no captured actions now correctly clears the enabled bars instead of bailing out with "nothing to restore" after the confirmation popup.

- **Confirmation Popup Race** — Renaming a preset and creating a new one with the old name while the form-bar popup was open could apply the wrong preset. Popups now track presets by reference and silently drop if the original preset is gone.

- **Spurious Form-Bar Popup** — The confirmation popup no longer appears when category filters would block all changes on bars 9-11.

- **Corrupt Saved Variables** — Hand-edited or corrupt preset stores now produce a clear warning and reset, instead of silently disappearing.

### Performance

- **Faster Preset Apply for Mount Collectors** — Mount and flyout lookups during restore are now cached once per apply, eliminating per-slot rescans of large mount journals and spellbooks.

### Migration Notes

- Existing presets continue to work unchanged. Bars 9-11 are disabled by default on presets saved before this update to prevent silent form bar modifications on upgrade — re-save your preset to enable the new bars.

- **Behavior change:** if you previously relied on a disabled bar being cleared on apply, re-enable that bar in the preset and turn off "Keep unlisted slots" — the empty slots will then clear as expected.

---

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