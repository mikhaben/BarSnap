local AddonName, NS = ...
_G.BarSnap = NS

----------------------------------------------------------------------
-- Defaults
----------------------------------------------------------------------
NS.defaults = {
    presets = {},
}

NS.charDefaults = {
    presets = {},
    scope = NS.SCOPE_CHARACTER,
}

----------------------------------------------------------------------
-- Deep copy
----------------------------------------------------------------------
function NS.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = NS.DeepCopy(v)
    end
    return copy
end

----------------------------------------------------------------------
-- Merge defaults into saved (add missing keys only)
----------------------------------------------------------------------
local function MergeDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then
                saved[k] = NS.DeepCopy(v)
            else
                saved[k] = v
            end
        elseif type(v) == "table" and type(saved[k]) == "table" then
            MergeDefaults(saved[k], v)
        end
    end
    return saved
end

----------------------------------------------------------------------
-- DJB2 hash of a macro body. Whitespace-normalized (matches ABP's PackMacro)
-- so trivial formatting changes don't change the hash. Returns nil for
-- empty bodies — those carry no identifying information.
----------------------------------------------------------------------
function NS.HashMacroBody(body)
    if not body or body == "" then return nil end
    body = body:gsub("^%s+", ""):gsub("%s+\n", "\n"):gsub("\n%s+", "\n"):gsub("%s+$", "")
    if body == "" then return nil end
    local h = 5381
    for i = 1, #body do
        h = (h * 33 + body:byte(i)) % 2147483648
    end
    return h
end

----------------------------------------------------------------------
-- Chat helpers
----------------------------------------------------------------------
function NS.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.CHAT_PREFIX .. tostring(msg))
end

function NS.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.CHAT_PREFIX .. "|cffff5555" .. tostring(msg) .. "|r")
end

----------------------------------------------------------------------
-- Tooltip helper (replaces repeated OnEnter/OnLeave boilerplate)
----------------------------------------------------------------------
function NS.SetupTooltip(frame, title, bodyText, r, g, b)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if bodyText then
            GameTooltip:AddLine(bodyText, r or 1, g or 1, b or 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

----------------------------------------------------------------------
-- Read version from TOC metadata
----------------------------------------------------------------------
local function ReadVersion()
    local fn = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if fn then
        return fn(AddonName, "Version")
    end
end

----------------------------------------------------------------------
-- Validate a presets array (skip corrupt entries, repair missing fields)
----------------------------------------------------------------------
local function ValidatePresets(presets)
    if type(presets) ~= "table" then
        NS.Warn("Preset store was corrupt (not a table) — resetting")
        return {}
    end
    local valid = {}
    for i, preset in ipairs(presets) do
        if type(preset) == "table" and type(preset.name) == "string" and preset.name ~= "" then
            if type(preset.filters) ~= "table" then
                preset.filters = NS.DeepCopy(NS.DEFAULT_FILTERS)
            else
                for key, default in pairs(NS.DEFAULT_FILTERS) do
                    if preset.filters[key] == nil then
                        preset.filters[key] = default
                    end
                end
            end
            -- Migration safety: when upgrading from a pre-1.2 preset that
            -- never scanned slots 97-180, we default the new bars to
            -- disabled so apply can't silently clear those slots. Bars
            -- 7-12 stay disabled here for legacy presets too (we don't
            -- know whether a legacy preset has valid form-bar data) —
            -- new presets get the proper defaults from DEFAULT_BAR_FILTERS.
            if type(preset.barFilters) ~= "table" then
                preset.barFilters = {}
            end
            for bar = 1, 6 do
                if preset.barFilters[bar] == nil then
                    preset.barFilters[bar] = true
                end
            end
            for bar = 7, NS.BAR_COUNT do
                if preset.barFilters[bar] == nil then
                    preset.barFilters[bar] = false
                end
            end
            if type(preset.actions) ~= "table" then
                preset.actions = {}
            end
            if preset.preserveLayout == nil then
                preset.preserveLayout = false
            end
            valid[#valid + 1] = preset
        else
            NS.Warn("Skipped corrupt preset at index " .. i)
        end
    end
    return valid
end

----------------------------------------------------------------------
-- Database init
----------------------------------------------------------------------
local function InitializeDatabase()
    -- Global (account-wide) database
    if not BarSnapDB then
        BarSnapDB = NS.DeepCopy(NS.defaults)
    else
        BarSnapDB = MergeDefaults(BarSnapDB, NS.defaults)
    end
    NS.db = BarSnapDB
    NS.db.presets = ValidatePresets(NS.db.presets)

    -- Per-character database
    if not BarSnapCharDB then
        BarSnapCharDB = NS.DeepCopy(NS.charDefaults)
    else
        BarSnapCharDB = MergeDefaults(BarSnapCharDB, NS.charDefaults)
    end
    NS.charDb = BarSnapCharDB
    NS.charDb.presets = ValidatePresets(NS.charDb.presets)

    -- Validate scope value
    if NS.charDb.scope ~= NS.SCOPE_GLOBAL and NS.charDb.scope ~= NS.SCOPE_CHARACTER then
        NS.charDb.scope = NS.SCOPE_GLOBAL
    end
end

----------------------------------------------------------------------
-- Scope accessors
----------------------------------------------------------------------
function NS.GetActiveScope()
    if NS.charDb then
        return NS.charDb.scope or NS.SCOPE_GLOBAL
    end
    return NS.SCOPE_GLOBAL
end

function NS.SetActiveScope(scope)
    if not NS.charDb then return end
    NS.charDb.scope = scope
    NS.CloseEditor()
    StaticPopup_Hide(NS.POPUP_CONFIRM_FORM_BARS)
    NS.RefreshMainFrame()
end

function NS.GetActivePresets()
    if NS.GetActiveScope() == NS.SCOPE_CHARACTER then
        return NS.charDb.presets
    end
    return NS.db.presets
end

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        NS.version = ReadVersion()
        InitializeDatabase()
        NS.InitializeSettings()
        NS.Print("Loaded — /bs to open")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

----------------------------------------------------------------------
-- Toggle main window (used by slash command + settings panel)
----------------------------------------------------------------------
function NS.ToggleMainFrame()
    if not NS.db then return end
    if not NS.mainFrame then
        NS.CreateMainFrame()
    end
    NS.mainFrame:SetShown(not NS.mainFrame:IsShown())
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_BARSNAP1 = "/bs"
SLASH_BARSNAP2 = "/barsnap"
SlashCmdList["BARSNAP"] = function(msg)
    msg = msg and msg:trim():lower() or ""
    if msg == "debug" then
        NS.DebugScan()
        return
    end
    NS.ToggleMainFrame()
end
