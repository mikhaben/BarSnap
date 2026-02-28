local AddonName, NS = ...
_G.BarSnap = NS

----------------------------------------------------------------------
-- Defaults
----------------------------------------------------------------------
NS.defaults = {
    presets = {},
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
-- Chat helpers
----------------------------------------------------------------------
function NS.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.CHAT_PREFIX .. tostring(msg))
end

function NS.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.CHAT_PREFIX .. "|cffff5555" .. tostring(msg) .. "|r")
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
-- Database init
----------------------------------------------------------------------
local function InitializeDatabase()
    if not BarSnapDB then
        BarSnapDB = NS.DeepCopy(NS.defaults)
    else
        BarSnapDB = MergeDefaults(BarSnapDB, NS.defaults)
    end
    NS.db = BarSnapDB

    -- Validate existing presets (skip corrupt entries)
    local valid = {}
    for i, preset in ipairs(NS.db.presets) do
        if type(preset) == "table" and type(preset.name) == "string" and preset.name ~= "" then
            -- Ensure filters table exists
            if type(preset.filters) ~= "table" then
                preset.filters = NS.DeepCopy(NS.DEFAULT_FILTERS)
            else
                for key, default in pairs(NS.DEFAULT_FILTERS) do
                    if preset.filters[key] == nil then
                        preset.filters[key] = default
                    end
                end
            end
            -- Ensure barFilters table exists
            if type(preset.barFilters) ~= "table" then
                preset.barFilters = NS.DeepCopy(NS.DEFAULT_BAR_FILTERS)
            else
                for bar = 1, NS.BAR_COUNT do
                    if preset.barFilters[bar] == nil then
                        preset.barFilters[bar] = true
                    end
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
    NS.db.presets = valid
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
SlashCmdList["BARSNAP"] = function()
    NS.ToggleMainFrame()
end
