local AddonName, NS = ...
_G.BarSnap = NS

----------------------------------------------------------------------
-- Defaults
----------------------------------------------------------------------
NS.defaults = {
    presets = {},
    windowPos = { point = "CENTER", x = 0, y = 0 },
}

----------------------------------------------------------------------
-- Deep copy
----------------------------------------------------------------------
function NS.DeepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in next, orig, nil do
        copy[NS.DeepCopy(k)] = NS.DeepCopy(v)
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
        InitializeDatabase()
        NS.Print("Loaded — /bs to open")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_BARSNAP1 = "/bs"
SLASH_BARSNAP2 = "/barsnap"
SlashCmdList["BARSNAP"] = function(msg)
    msg = (msg or ""):trim():lower()
    if msg == "reset" then
        NS.db.windowPos = { point = "CENTER", x = 0, y = 0 }
        if NS.mainFrame then
            NS.mainFrame:ClearAllPoints()
            NS.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        NS.Print("Window position reset.")
        return
    end
    -- Toggle main window
    if NS.mainFrame then
        if NS.mainFrame:IsShown() then
            NS.mainFrame:Hide()
        else
            NS.mainFrame:Show()
        end
    else
        NS.CreateMainFrame()
        NS.mainFrame:Show()
    end
end
