local AddonName, NS = ...

NS.SLOT_MIN = 1
NS.SLOT_MAX = 180
NS.BAR_COUNT = 15
NS.SLOTS_PER_BAR = 12

NS.RETRY_MAX = 5
NS.RETRY_INTERVAL = 0.1

NS.CATEGORIES = {
    { key = "spells", label = "Spells" },
    { key = "macros", label = "Macros" },
    { key = "items",  label = "Items" },
    { key = "mounts", label = "Mounts" },
    { key = "toys",   label = "Toys" },
    { key = "pets",   label = "Pets" },
}

NS.DEFAULT_FILTERS = {
    spells = true,
    macros = true,
    items  = true,
    mounts = true,
    toys   = true,
    pets   = true,
}

NS.DEFAULT_BAR_FILTERS = {
    [1]  = true,  [2]  = true,  [3]  = true,  [4]  = true,
    [5]  = true,  [6]  = true,
    [7]  = false, [8]  = false, [9]  = false, [10] = false,
    [11] = false, [12] = false,
    [13] = true,  [14] = true,  [15] = true,
}

NS.BAR_LABELS = {
    [1]  = "Bar 1 (Main)",
    [7]  = "Bar 7 (Special)",
    [8]  = "Bar 8 (Special)",
    [9]  = "Bar 9 (Special)",
    [10] = "Bar 10 (Special)",
    [11] = "Bar 11 (Dragonriding)",
    [12] = "Bar 12 (Vehicle)",
    [13] = "Bar 13 (UI 6)",
    [14] = "Bar 14 (UI 7)",
    [15] = "Bar 15 (UI 8)",
}

local SPECIAL_BAR_TOOLTIP =
    "Slots %d-%d. Special paged bar.\nUsed by some classes for stance/form/override paging — when in the relevant state, your main bar displays these slots. Not visible as a separate bar in the Blizzard UI.\nRun /bs debug to see exactly which BarSnap bar holds the actions you placed."

local function specialTip(bar)
    local slotMin = (bar - 1) * 12 + 1
    local slotMax = bar * 12
    return string.format(SPECIAL_BAR_TOOLTIP, slotMin, slotMax)
end

NS.BAR_TOOLTIPS = {
    [1]  = "Slots 1-12. Main action bar.",
    [2]  = "Slots 13-24. Page 2 of the main bar — generally unused, only reached by paging.",
    [3]  = "Slots 25-36. One of the 4 standard multibars (Action Bar 2-5 in Blizzard's options panel).",
    [4]  = "Slots 37-48. One of the 4 standard multibars (Action Bar 2-5 in Blizzard's options panel).",
    [5]  = "Slots 49-60. One of the 4 standard multibars (Action Bar 2-5 in Blizzard's options panel).",
    [6]  = "Slots 61-72. One of the 4 standard multibars (Action Bar 2-5 in Blizzard's options panel).",
    [7]  = specialTip(7),
    [8]  = specialTip(8),
    [9]  = specialTip(9),
    [10] = specialTip(10),
    [11] = "Slots 121-132. Dragonriding/Skyriding bar.\nVisible and directly editable from the default UI when you mount a flying drake. Toggle on to capture and restore your Dragonriding action layout.",
    [12] = "Slots 133-144. Vehicle bar.\nSwaps onto your main bar when you mount a vehicle; Blizzard auto-fills the slots with the vehicle's actions, so capturing/restoring is rarely useful.",
    [13] = "Slots 145-156. Blizzard's MultiActionBar5 — visible as Action Bar 6 in the Blizzard Action Bars options.",
    [14] = "Slots 157-168. Blizzard's MultiActionBar6 — visible as Action Bar 7 in the Blizzard Action Bars options.",
    [15] = "Slots 169-180. Blizzard's MultiActionBar7 — visible as Action Bar 8 in the Blizzard Action Bars options.",
}

NS.TYPE_MAP = {
    spell        = "spells",
    item         = "items",
    macro        = "macros",
    summonmount  = "mounts",
    mount        = "mounts",
    toy          = "toys",
    flyout       = "spells",
    equipmentset = "items",
    summonpet    = "pets",
}

NS.MAIN_WIDTH      = 260
NS.EDITOR_WIDTH    = 330
NS.ROW_HEIGHT      = 30
NS.ICON_SIZE       = 22
NS.BTN_SIZE        = 20
NS.PADDING         = 10
NS.TITLE_BAR_HEIGHT = 28

NS.COLOR_WHITE      = { 1, 1, 1 }
NS.COLOR_YELLOW     = { 1, 0.82, 0 }
NS.COLOR_GRAY       = { 0.5, 0.5, 0.5 }
NS.COLOR_LABEL_GRAY = { 0.8, 0.8, 0.8 }

NS.TEX_FALLBACK_ICON = 134400
NS.TEX_PLAY          = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
NS.TEX_EDIT          = "Interface\\WorldMap\\GEAR_64GREY"
NS.TEX_TRASH         = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
NS.TEX_HIGHLIGHT     = "Interface\\Buttons\\ButtonHilight-Square"

NS.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

NS.CHAT_PREFIX = "|cff33bbff" .. AddonName .. ":|r "

NS.SCOPE_GLOBAL    = "global"
NS.SCOPE_CHARACTER = "character"
NS.SCOPE_BTN_HEIGHT = 24

NS.POPUP_DELETE_PRESET     = "BARSNAP_DELETE_PRESET"
NS.POPUP_CONFIRM_FORM_BARS = "BARSNAP_CONFIRM_FORM_BARS"
