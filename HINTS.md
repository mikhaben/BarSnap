# WoW Addon Development Hints

Reference document for World of Warcraft addon development patterns, APIs, and gotchas. Compiled during BarSnap development targeting Interface 120000 (Midnight).

---

## Table of Contents

- [Icon Picker / Icon Selection](#icon-picker--icon-selection)
- [WoW 12.0 (Midnight) API Notes](#wow-120-midnight-api-notes)
- [UI Templates](#ui-templates)
- [ScrollBox DataProvider Pattern](#scrollbox-dataprovider-pattern)
- [Useful Textures](#useful-textures)
- [Async Patterns](#async-patterns)
- [Combat Safety](#combat-safety)
- [Data Storage](#data-storage)
- [Blizzard Interface Code Sources](#blizzard-interface-code-sources)

---

## Icon Picker / Icon Selection

### The Blizzard Icon Picker

`IconSelectorPopup` does **NOT** exist as a standalone global. The Blizzard icon picker is `MacroPopupFrame`, which inherits from `IconSelectorPopupFrameTemplate` (defined in SharedXML). See the source: [Blizzard_MacroIconSelector.lua][macro-icon-src] and [Blizzard_MacroIconSelector.xml][macro-icon-xml].

Concrete frames like `MacroPopupFrame` and `GuildBankPopupFrame` inherit from this template. Each adds its own `OnShow`/`OkayButton_OnClick` logic via mixins (e.g., `MacroPopupFrameMixin`).

### Using Blizzard's Icon Picker in Your Addon

Load on demand, then configure and show:

```lua
C_AddOns.LoadAddOn("Blizzard_MacroUI")

MacroPopupFrame.mode = IconSelectorPopupFrameModes.Edit
MacroPopupFrame:Show()
```

### MacroPopupFrame Structure

| Path | Description |
|------|-------------|
| `MacroPopupFrame.IconSelector` | Scrollable icon grid |
| `MacroPopupFrame.BorderBox.SelectedIconArea.SelectedIconButton` | Shows currently selected icon |
| `MacroPopupFrame.BorderBox.IconSelectorEditBox` | Search/filter box |
| `MacroPopupFrame.BorderBox.OkayButton` | Confirm selection |
| `MacroPopupFrame.BorderBox.CancelButton` | Cancel (hides frame by default from template) |

### Getting the Selected Icon

```lua
local texture = MacroPopupFrame.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
```

### Hooking Buttons

```lua
MacroPopupFrame.BorderBox.OkayButton:SetScript("OnClick", function()
    local icon = MacroPopupFrame.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    -- Use icon
    MacroPopupFrame:Hide()
end)
```

### Icon Data Provider

```lua
local provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
```

`IconSelector:SetSelectedCallback(callback)` registers a callback when the user clicks an icon in the grid.

### Modes

- `IconSelectorPopupFrameModes.Edit` -- For editing an existing icon
- `IconSelectorPopupFrameModes.New` -- For selecting a new icon

### Third-Party Icon Picker Libraries

| Library | Notes |
|---------|-------|
| [LibIconPicker][lib-icon-picker] | Callback-based, load-on-demand, lazy rendering. Cleaner API than hooking MacroPopupFrame. |
| [AdvancedIconSelector][adv-icon-selector] | Provides `LibAdvancedIconSelector-1.0` for embedding |
| [BetterIconSelect][better-icon-select] | Fork of AdvancedIconSelector with improved UI |
| [LargerMacroIconSelection][larger-macro-icon] | Hooks existing icon selection frames; adds search and larger grid |

---

## WoW 12.0 (Midnight) API Notes

- **Patch 12.0.0 API overhaul:** 437 new global APIs, 6 new ScriptObjects, 28 new Widget methods, 138 older APIs deprecated (mostly BattleNet, CombatLog, SpellBook functions). Full diff: [Patch 12.0.0 API changes][patch-12-api].
- **Icon picker APIs were NOT removed** in 12.0.0. UI customization was explicitly preserved.
- **In-game API docs:** Type `/api` or `/api gui` in-game for the most current API browser (updated to Patch 12.0.1).
- **`C_AddOns.LoadAddOn()`** -- Use to lazy-load Blizzard addons on demand. Works for `Blizzard_MacroUI`, `Blizzard_GuildBankUI`, etc.
- **Full API reference:** [World of Warcraft API][wow-api] on Warcraft Wiki, and the [Widget API][widget-api] for frame/texture/fontstring methods.

---

## UI Templates

### Frames and Windows

| Template | Usage |
|----------|-------|
| `BasicFrameTemplateWithInset` | Standard Blizzard frame with title bar, close button, and inset panel. Use for floating windows. |
| `WowScrollBoxList` + `MinimalScrollBar` | Modern scroll list with DataProvider for element recycling and minimal scrollbar. Replaces deprecated `UIPanelScrollFrameTemplate`. |

### Buttons and Inputs

| Template | Usage |
|----------|-------|
| `UIPanelButtonTemplate` | Standard Blizzard button. Use for "Save", "Change Icon", etc. |
| `UICheckButtonTemplate` | Standard checkbox. 24x24 is a good size. |
| `InputBoxTemplate` | Standard edit box with border. |
| `SecureActionButtonTemplate` | For buttons that need protected actions (drag-to-action-bar, macro execution). Required for combat-safe interactions. |

### Dialogs and Special Frames

**StaticPopupDialogs** -- For confirmation dialogs. Always verify data has not shifted before acting (e.g., check name matches index before deletion):

```lua
StaticPopupDialogs["MYADDON_CONFIRM_DELETE"] = {
    text = "Delete preset '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        -- Verify data.name still matches data.index before deleting
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

**UISpecialFrames** -- Register frame name to enable ESC-to-close:

```lua
tinsert(UISpecialFrames, "MyAddonMainFrame")
```

---

## ScrollBox DataProvider Pattern

Modern WoW list UIs use `WowScrollBoxList` + `DataProvider` instead of manual pooling. The ScrollBox handles frame recycling automatically:

```lua
local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")

local view = CreateScrollBoxListLinearView()
view:SetElementExtent(ROW_HEIGHT)
view:SetElementInitializer("Frame", function(row, data)
    -- Create children on first use, configure data every time
    if not row.label then
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetAllPoints()
    end
    row.label:SetText(data.name)
end)

local dataProvider = CreateDataProvider()
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
scrollBox:SetDataProvider(dataProvider)

-- To refresh: flush and re-insert
dataProvider:Flush()
for i, item in ipairs(items) do
    dataProvider:Insert({ name = item.name, index = i })
end
```

---

## Useful Textures

Common Blizzard textures for addon UIs:

| Purpose | Texture Path / ID |
|---------|-------------------|
| Play / arrow | `Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up` |
| Gear / settings | `Interface\\WorldMap\\GEAR_64GREY` |
| Trash / delete | `Interface\\Buttons\\UI-GroupLoot-Pass-Up` |
| Trash highlight | `Interface\\Buttons\\UI-GroupLoot-Pass-Highlight` |
| Button highlight | `Interface\\Buttons\\ButtonHilight-Square` |
| Icon border / slot | `Interface\\Buttons\\UI-Quickslot2` |
| Checkmark | `Interface\\RaidFrame\\ReadyCheck-Ready` |
| X / remove | `Interface\\RaidFrame\\ReadyCheck-NotReady` |
| Plus / add | `Interface\\PaperDollInfoFrame\\Character-Plus` |
| Lock | `Interface\\LFGFrame\\UI-LFG-ICON-LOCK` |
| Fallback icon | `134400` (INV_Misc_QuestionMark) |

---

## Async Patterns

### Retry with C_Timer.After

For operations that may fail due to race conditions (e.g., cursor state during action placement):

```lua
local function DoWithRetry(attempt, maxAttempts, interval, action, callback)
    if action() then
        callback(true)
        return
    end
    if attempt < maxAttempts then
        C_Timer.After(interval, function()
            if InCombatLockdown() then callback(false); return end
            DoWithRetry(attempt + 1, maxAttempts, interval, action, callback)
        end)
    else
        callback(false)
    end
end
```

### Async Completion Sentinel

Track multiple in-flight async operations and fire a summary only after all complete. The sentinel (initializing counter to 1 before the loop, releasing after) prevents the callback from firing before the loop finishes queuing all operations:

```lua
local pending = 1  -- sentinel: prevents premature completion
local function onComplete()
    pending = pending - 1
    if pending > 0 then return end
    -- All operations finished, print summary
end

for slot = 1, 72 do
    if needsAsync(slot) then
        pending = pending + 1
        DoAsync(function() onComplete() end)
    end
end

onComplete()  -- release sentinel
```

**Why the sentinel matters:** Without it, if the first async callback fires before the loop finishes iterating, the counter could hit zero prematurely and the summary would fire with incomplete counts.

---

## Combat Safety

### InCombatLockdown()

Must check before any protected frame modification. Cannot modify action bars, secure buttons, or protected frames during combat.

```lua
if InCombatLockdown() then
    NS.Warn("Cannot modify bars during combat.")
    return
end
```

### Combat Events

| Event | Fires When |
|-------|------------|
| `PLAYER_REGEN_DISABLED` | Entering combat |
| `PLAYER_REGEN_ENABLED` | Leaving combat |

Pattern: Queue operations during combat and execute them on `PLAYER_REGEN_ENABLED`:

```lua
local pendingAction = nil

frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and pendingAction then
        pendingAction()
        pendingAction = nil
    end
end)
```

---

## Data Storage

### SavedVariables

- Declared in the `.toc` file.
- Available after `PLAYER_LOGIN` (not `ADDON_LOADED` for cross-addon data).
- Always merge with defaults on load to handle version migrations gracefully.

```lua
function NS.InitDB()
    BarSnapDB = BarSnapDB or {}
    for key, default in pairs(NS.DB_DEFAULTS) do
        if BarSnapDB[key] == nil then
            BarSnapDB[key] = NS.DeepCopy(default)
        end
    end
end
```

### Sparse Tables

For action bars, only store non-empty slots. Reduces memory and SavedVariables file size significantly.

```lua
-- Good: sparse (only occupied slots)
actions = { [1] = {type="spell", id=12345}, [5] = {type="macro", name="Opener"} }

-- Bad: dense (wastes space on 70 nil entries)
actions = { {type="spell", id=12345}, nil, nil, nil, {type="macro", name="Opener"}, ... }
```

### DeepCopy

Always deep-copy default tables when creating new entries to avoid reference sharing. Without this, modifying one preset's filters would modify all presets that share the same reference:

```lua
function NS.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = NS.DeepCopy(v)
    end
    return copy
end
```

---

## Blizzard Interface Code Sources

### GitHub Mirrors

| Repository | Notes |
|------------|-------|
| [tomrus88/BlizzardInterfaceCode][tomrus88] | Full interface code mirror |
| [Gethe/wow-ui-source][gethe] | Another mirror (`live` branch = retail) |
| [ketho-wow/BlizzardInterfaceResources][ketho-resources] | Extracted resources |

### Key Source Directories

| Directory | Contents |
|-----------|----------|
| `Interface/SharedXML/` | Shared templates (IconSelectorPopup, SharedUIPanelTemplates) |
| `Interface/AddOns/Blizzard_MacroUI/` | Macro UI including icon selector |
| `Interface/AddOns/Blizzard_GuildBankUI/` | Guild bank (also uses icon selector) |
| `Interface/FrameXML/` | Core UI frames |

These mirrors are invaluable for understanding undocumented APIs, template structures, and mixin behavior. When in doubt about how a Blizzard UI element works, read the source.

---

## External Links

### Official & Community Documentation

- [World of Warcraft API][wow-api] — Complete API reference on Warcraft Wiki
- [Widget API][widget-api] — Frame, texture, fontstring, and other widget methods
- [Patch 12.0.0 API Changes][patch-12-api] — Full list of additions, removals, and renames
- [WoW Events][wow-events] — All game events with descriptions
- [Wowhead Addon Guide][wowhead-addon-guide] — Comprehensive beginner's guide for addon coding in Lua
- [Blizzard Developer Portal][blizzard-dev] — Official Blizzard API docs (web APIs, not addon)

### Blizzard UI Source Code

- [tomrus88/BlizzardInterfaceCode][tomrus88] — Full mirror, good for browsing by addon
- [Gethe/wow-ui-source][gethe] — `live` branch = current retail
- [ketho-wow/BlizzardInterfaceResources][ketho-resources] — Extracted constants, enums, global strings
- [Blizzard_MacroIconSelector.lua][macro-icon-src] — How Blizzard implements the macro icon picker
- [Blizzard_MacroIconSelector.xml][macro-icon-xml] — XML template for MacroPopupFrame
- [Blizzard_MacroUI.lua][macro-ui-src] — Full macro UI source (RefreshIconDataProvider, etc.)

### Icon Picker Libraries

- [LibIconPicker][lib-icon-picker] — Recommended: callback-based, lazy rendering
- [AdvancedIconSelector][adv-icon-selector] — Embeddable library with search
- [BetterIconSelect][better-icon-select] — Improved fork of AdvancedIconSelector
- [LargerMacroIconSelection][larger-macro-icon] — Hooks native frames, adds search + bigger grid

### Addon Development Tools

- [WeakAuras2 Source][weakauras] — Excellent reference for complex addon patterns (icon pickers, async loading, pooling)
- [Townlong Yak FrameXML Browser][townlong-yak] — Browse Blizzard FrameXML by build number
- [WoWInterface AddOns][wowinterface] — Addon hosting and community
- [CurseForge WoW Addons][curseforge] — Primary addon distribution platform

### Communities

- [WoW UI & Macro Forums][wow-forums-ui] — Official Blizzard addon dev forums
- [r/wowaddons][reddit-wowaddons] — Reddit addon community
- [WoWInterface Forums][wowinterface-forums] — Long-running addon dev community

---

<!-- Reference-style links -->
[wow-api]: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
[widget-api]: https://warcraft.wiki.gg/wiki/Widget_API
[patch-12-api]: https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
[wow-events]: https://warcraft.wiki.gg/wiki/Events
[wowhead-addon-guide]: https://www.wowhead.com/guide/comprehensive-beginners-guide-for-wow-addon-coding-in-lua-5338
[blizzard-dev]: https://develop.battle.net/

[tomrus88]: https://github.com/tomrus88/BlizzardInterfaceCode
[gethe]: https://github.com/Gethe/wow-ui-source
[ketho-resources]: https://github.com/ketho-wow/BlizzardInterfaceResources
[macro-icon-src]: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroIconSelector.lua
[macro-icon-xml]: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroIconSelector.xml
[macro-ui-src]: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI.lua

[lib-icon-picker]: https://www.curseforge.com/wow/addons/libiconpicker
[adv-icon-selector]: https://www.curseforge.com/wow/addons/advancediconselector
[better-icon-select]: https://www.curseforge.com/wow/addons/bettericonselect
[larger-macro-icon]: https://github.com/ketho-wow/LargerMacroIconSelection

[weakauras]: https://github.com/WeakAuras/WeakAuras2
[townlong-yak]: https://www.townlong-yak.com/framexml/live
[wowinterface]: https://www.wowinterface.com/addons.php
[curseforge]: https://www.curseforge.com/wow/addons

[wow-forums-ui]: https://us.forums.blizzard.com/en/wow/c/ui-and-macro/
[reddit-wowaddons]: https://www.reddit.com/r/wowaddons/
[wowinterface-forums]: https://www.wowinterface.com/forums/
