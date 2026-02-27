--[[
    BarSnap - Action Bar Preset Manager
    UI/Settings.lua - Blizzard addon settings panel
]]--

local AddonName, NS = ...

local PADDING_LEFT = 16
local PADDING_TOP = -16

function NS.InitializeSettings()
    local panel = CreateFrame("Frame", "BarSnapSettingsPanel")

    -- Title + version
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PADDING_LEFT, PADDING_TOP)
    title:SetText("BarSnap - " .. (NS.Version or "1.0.0"))

    -- Author
    local author = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    author:SetText("by justLuther")

    -- Slash command hint
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -6)
    hint:SetText("/bs or /barsnap — toggle window")
    hint:SetTextColor(unpack(NS.COLOR_GRAY))

    -- Open button
    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(160, 28)
    openBtn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open BarSnap")
    openBtn:SetScript("OnClick", function()
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
    end)

    -- Register with Blizzard Settings
    local category = Settings.RegisterCanvasLayoutCategory(panel, "BarSnap")
    category.ID = "BarSnap"
    Settings.RegisterAddOnCategory(category)

    NS.settingsCategory = category
end
