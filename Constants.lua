local AddonName, NS = ...

-- Slot range (main action bars 1-6, 12 slots each = 72)
NS.SLOT_MIN = 1
NS.SLOT_MAX = 72

-- Retry config for restore operations
NS.RETRY_MAX = 3
NS.RETRY_INTERVAL = 0.1

-- Action categories (order matters for UI display)
NS.CATEGORIES = {
    { key = "spells", label = "Spells" },
    { key = "macros", label = "Macros" },
    { key = "items",  label = "Items" },
    { key = "mounts", label = "Mounts" },
    { key = "toys",   label = "Toys" },
}

-- Default filters (all enabled)
NS.DEFAULT_FILTERS = {
    spells = true,
    macros = true,
    items  = true,
    mounts = true,
    toys   = true,
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
}

-- Layout
NS.MAIN_WIDTH  = 220
NS.MAIN_HEIGHT = 320
NS.EDITOR_WIDTH = 240
NS.ROW_HEIGHT = 28
NS.ICON_SIZE = 22
NS.BTN_SIZE = 22
NS.PADDING = 8

-- Colors {r, g, b}
NS.COLOR_WHITE      = { 1, 1, 1 }
NS.COLOR_YELLOW     = { 1, 0.82, 0 }
NS.COLOR_GREEN      = { 0.3, 1, 0.3 }
NS.COLOR_RED        = { 1, 0.3, 0.3 }
NS.COLOR_GRAY       = { 0.5, 0.5, 0.5 }
NS.COLOR_LABEL_GRAY = { 0.8, 0.8, 0.8 }

-- Textures
NS.TEX_FALLBACK_ICON = 134400  -- INV_Misc_QuestionMark
NS.TEX_PLAY          = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
NS.TEX_EDIT          = "Interface\\WorldMap\\GEAR_64GREY"
NS.TEX_TRASH         = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
NS.TEX_HIGHLIGHT     = "Interface\\Buttons\\ButtonHilight-Square"
NS.TEX_ICON_BORDER   = "Interface\\Buttons\\UI-Quickslot2"

-- Icon texture coordinate crop
NS.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

-- Chat prefix
NS.CHAT_PREFIX = "|cff33bbff" .. AddonName .. ":|r "
