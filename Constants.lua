local AddonName, NS = ...

-- Bar N occupies slots (N-1)*SLOTS_PER_BAR + 1 .. N*SLOTS_PER_BAR.
-- Retail slot layout:
--   1-12     Main bar (Action Bar 1, visible)
--   13-24    Main bar page 2 (paging slot, usually unused)
--   25-72    Blizzard MultiBar1-4 — visible as Action Bar 2-5 in the
--            options panel (Bottom Left, Bottom Right, Right, Left;
--            Blizzard's label ↔ internal MultiBar mapping is not 1:1)
--   73-120   Class form/stance pages — Druid Bear (73-84), Cat (85-96),
--            Moonkin (97-108), Travel (109-120); Rogue Stealth at 73-84;
--            Warrior stances 73-108; Evoker bonus 73-84. Paged onto
--            Bar 1 when in form — NOT separate visible bars.
--   121-132  Dragonriding override / vehicle / possess (paged)
--   133-144  Reserved / unused
--   145-180  Blizzard MultiBar5/6/7 — visible as Action Bar 6, 7, 8
--            in the options panel.
NS.SLOT_MIN = 1
NS.SLOT_MAX = 180
NS.BAR_COUNT = 15
NS.SLOTS_PER_BAR = 12

-- Retry config for restore operations
NS.RETRY_MAX = 5
NS.RETRY_INTERVAL = 0.1

-- Action categories (order matters for UI display)
NS.CATEGORIES = {
    { key = "spells", label = "Spells" },
    { key = "macros", label = "Macros" },
    { key = "items",  label = "Items" },
    { key = "mounts", label = "Mounts" },
    { key = "toys",   label = "Toys" },
    { key = "pets",   label = "Pets" },
}

-- Default filters (all enabled)
NS.DEFAULT_FILTERS = {
    spells = true,
    macros = true,
    items  = true,
    mounts = true,
    toys   = true,
    pets   = true,
}

-- Default bar filters.
-- Enabled by default: bars 1-6 (the standard visible Action Bar 1 + the
-- 4 MultiBars) and bars 13-15 (the additional visible Action Bar 6-8
-- added in retail) — these are the bars a user can see and configure
-- directly in Blizzard's Action Bars options.
-- Disabled by default: bars 7-12 — class form/stance pages (Druid forms,
-- Rogue stealth, Warrior stances), Dragonriding override, and the
-- reserved page 12. Users opt-in via the editor if they want the addon
-- to manage their form bars.
-- Migration in Core.lua uses the same split.
NS.DEFAULT_BAR_FILTERS = {
    [1]  = true,  [2]  = true,  [3]  = true,  [4]  = true,
    [5]  = true,  [6]  = true,
    [7]  = false, [8]  = false, [9]  = false, [10] = false,
    [11] = false, [12] = false,
    [13] = true,  [14] = true,  [15] = true,
}

-- Bar labels shown next to each editor checkbox. Short hint for the
-- non-obvious bars so users can correlate to their in-game UI without
-- overflowing the 2-column checkbox layout. Full context in BAR_TOOLTIPS.
NS.BAR_LABELS = {
    [1]  = "Bar 1 (Main)",
    [7]  = "Bar 7 (Bear)",
    [8]  = "Bar 8 (Cat)",
    [9]  = "Bar 9 (Moonkin)",
    [10] = "Bar 10 (Travel)",
    [11] = "Bar 11 (Dragon)",
    [13] = "Bar 13 (UI 6)",
    [14] = "Bar 14 (UI 7)",
    [15] = "Bar 15 (UI 8)",
}

-- Per-bar tooltips shown on hover in the editor. Bars 1, 3-6 (visible
-- Action Bars 1-5) get short geographic hints; bars 7-15 get the
-- form/stance/Edit-Mode context.
NS.BAR_TOOLTIPS = {
    [1]  = "Slots 1-12. Main action bar.",
    [2]  = "Slots 13-24. Page 2 of the main bar — generally unused, only reached by paging.",
    [3]  = "Slots 25-36. One of the 4 multibars (Action Bar 2-5 in Blizzard's options panel).",
    [4]  = "Slots 37-48. One of the 4 multibars (Action Bar 2-5 in Blizzard's options panel).",
    [5]  = "Slots 49-60. One of the 4 multibars (Action Bar 2-5 in Blizzard's options panel).",
    [6]  = "Slots 61-72. One of the 4 multibars (Action Bar 2-5 in Blizzard's options panel).",
    [7]  = "Slots 73-84. Druid Bear form / Rogue Stealth / Warrior Battle / Evoker bonus bar.\nPaged onto your main bar when in form — not a separate visible bar in the Blizzard UI.",
    [8]  = "Slots 85-96. Druid Cat (Prowl) / Warrior Defensive stance.\nPaged onto your main bar when in form.",
    [9]  = "Slots 97-108. Druid Moonkin form / Warrior Berserker stance.\nPaged onto your main bar when in form.",
    [10] = "Slots 109-120. Druid Travel form.\nPaged onto your main bar when in form.",
    [11] = "Slots 121-132. Dragonriding/Skyriding override, vehicle, possess.\nNot directly user-editable — paged dynamically by Blizzard.",
    [12] = "Slots 133-144. Reserved / unused.",
    [13] = "Slots 145-156. Blizzard's MultiActionBar5 — visible as Action Bar 6 in the Blizzard Action Bars options.",
    [14] = "Slots 157-168. Blizzard's MultiActionBar6 — visible as Action Bar 7 in the Blizzard Action Bars options.",
    [15] = "Slots 169-180. Blizzard's MultiActionBar7 — visible as Action Bar 8 in the Blizzard Action Bars options.",
}

-- Map GetActionInfo type strings to our category keys
-- Maps both WoW API type strings AND our stored type strings to category keys
NS.TYPE_MAP = {
    spell        = "spells",
    item         = "items",
    macro        = "macros",
    summonmount  = "mounts",  -- WoW API type
    mount        = "mounts",  -- our stored type
    toy          = "toys",
    flyout       = "spells",  -- flyouts grouped with spells
    equipmentset = "items",   -- equipment sets grouped with items
    summonpet    = "pets",    -- battle pets
}

-- Layout
NS.MAIN_WIDTH      = 260
NS.EDITOR_WIDTH    = 300
NS.ROW_HEIGHT      = 30
NS.ICON_SIZE       = 22
NS.BTN_SIZE        = 20
NS.PADDING         = 10
NS.TITLE_BAR_HEIGHT = 28

-- Colors {r, g, b}
NS.COLOR_WHITE      = { 1, 1, 1 }
NS.COLOR_YELLOW     = { 1, 0.82, 0 }
NS.COLOR_GRAY       = { 0.5, 0.5, 0.5 }
NS.COLOR_LABEL_GRAY = { 0.8, 0.8, 0.8 }

-- Textures
NS.TEX_FALLBACK_ICON = 134400  -- INV_Misc_QuestionMark
NS.TEX_PLAY          = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
NS.TEX_EDIT          = "Interface\\WorldMap\\GEAR_64GREY"
NS.TEX_TRASH         = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
NS.TEX_HIGHLIGHT     = "Interface\\Buttons\\ButtonHilight-Square"

-- Icon texture coordinate crop
NS.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

-- Chat prefix
NS.CHAT_PREFIX = "|cff33bbff" .. AddonName .. ":|r "

-- Preset scope
NS.SCOPE_GLOBAL    = "global"
NS.SCOPE_CHARACTER = "character"
NS.SCOPE_BTN_HEIGHT = 24

-- StaticPopup dialog names
NS.POPUP_DELETE_PRESET     = "BARSNAP_DELETE_PRESET"
NS.POPUP_CONFIRM_FORM_BARS = "BARSNAP_CONFIRM_FORM_BARS"
