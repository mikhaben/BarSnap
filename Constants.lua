local AddonName, NS = ...

-- Slot range (action bars 1-8, 12 slots each = 96)
NS.SLOT_MIN = 1
NS.SLOT_MAX = 96
NS.BAR_COUNT = 8
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

-- Default bar filters (all enabled)
NS.DEFAULT_BAR_FILTERS = {
    [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [8] = true,
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
NS.EDITOR_WIDTH    = 240
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
