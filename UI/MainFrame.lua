local AddonName, NS = ...

local mainFrame = nil
local emptyText = nil
local scrollBox = nil
local scrollBar = nil
local dataProvider = nil

----------------------------------------------------------------------
-- Create the main window
----------------------------------------------------------------------
function NS.CreateMainFrame()
    if mainFrame then return mainFrame end

    local frame = NS.CreateWindow({
        name   = "BarSnapMainFrame",
        title  = "BarSnap",
        width  = NS.MAIN_WIDTH,
        minH   = 170,
        maxH   = 500,
        onHide = function() NS.CloseEditor() end,
    })

    -- Scope toggle button
    local scopeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scopeBtn:SetHeight(NS.SCOPE_BTN_HEIGHT)
    scopeBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", NS.PADDING, -frame.contentTop)
    scopeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -NS.PADDING, -frame.contentTop)

    local function UpdateScopeButton()
        local scope = NS.GetActiveScope()
        if scope == NS.SCOPE_CHARACTER then
            local charName = UnitName("player") or "Character"
            scopeBtn:SetText("Scope: " .. charName)
        else
            scopeBtn:SetText("Scope: Global")
        end
    end

    scopeBtn:SetScript("OnClick", function()
        local current = NS.GetActiveScope()
        if current == NS.SCOPE_GLOBAL then
            NS.SetActiveScope(NS.SCOPE_CHARACTER)
        else
            NS.SetActiveScope(NS.SCOPE_GLOBAL)
        end
        UpdateScopeButton()
    end)

    NS.SetupTooltip(scopeBtn, "Preset Scope", "Click to toggle between Global\nand Character-specific presets.")

    frame.scopeBtn = scopeBtn
    frame.UpdateScopeButton = UpdateScopeButton
    UpdateScopeButton()

    -- Save Current Bars button
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetHeight(24)
    saveBtn:SetPoint("TOPLEFT", scopeBtn, "BOTTOMLEFT", 0, -4)
    saveBtn:SetPoint("TOPRIGHT", scopeBtn, "BOTTOMRIGHT", 0, -4)
    saveBtn:SetText("Save Current Bars")

    saveBtn:SetScript("OnClick", function()
        if not NS.CanModifyBars() then return end

        local actions = NS.ScanBars()
        local count = NS.CountActions(actions)

        -- Auto-name
        local baseName = "Preset #" .. (#NS.GetActivePresets() + 1)
        local name = NS.UniqueName(baseName)

        -- Current spec (for labeling)
        local specID = 0
        if GetSpecializationInfo then
            local spec = GetSpecialization()
            if spec then
                specID = GetSpecializationInfo(spec) or 0
            end
        end

        -- First non-empty slot's icon as default
        local icon = NS.TEX_FALLBACK_ICON
        for slot = NS.SLOT_MIN, NS.SLOT_MAX do
            if actions[slot] then
                local actionIcon = GetActionTexture(slot)
                if actionIcon then
                    icon = actionIcon
                    break
                end
            end
        end

        local preset = {
            name = name,
            icon = icon,
            timestamp = time(),
            specID = specID,
            preserveLayout = false,
            filters = NS.DeepCopy(NS.DEFAULT_FILTERS),
            barFilters = NS.DeepCopy(NS.DEFAULT_BAR_FILTERS),
            actions = actions,
        }

        table.insert(NS.GetActivePresets(), preset)
        NS.RefreshMainFrame()

        -- Open editor for the new preset
        NS.OpenEditor(#NS.GetActivePresets())

        NS.Print("Saved '" .. name .. "' (" .. count .. " actions)")
    end)
    frame.saveBtn = saveBtn

    -- Divider
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -5)
    divider:SetPoint("TOPRIGHT", saveBtn, "BOTTOMRIGHT", 0, -5)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- "Presets" label
    local presetsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetsLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)
    presetsLabel:SetText("Presets")
    presetsLabel:SetTextColor(unpack(NS.COLOR_YELLOW))

    -- ScrollBox (modern list container — anchors managed by ScrollUtil below)
    scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")

    -- ScrollBar (minimal style, to the right of scroll box)
    scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 2, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 2, 0)

    -- View + DataProvider
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(NS.ROW_HEIGHT)

    dataProvider = CreateDataProvider()

    view:SetElementInitializer("Frame", function(row, data)
        NS.InitPresetRow(row, data.preset, data.index)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    -- Let WoW manage scrollbar visibility + scroll box anchors automatically
    -- This prevents race conditions between our manual SetShown and ScrollUtil's internal callbacks
    local anchorsWithBar = {
        CreateAnchor("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -3),
        CreateAnchor("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(NS.PADDING + 14), NS.PADDING),
    }
    local anchorsWithoutBar = {
        CreateAnchor("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -3),
        CreateAnchor("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -NS.PADDING, NS.PADDING),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, anchorsWithBar, anchorsWithoutBar)

    scrollBox:SetDataProvider(dataProvider)

    -- Empty state text (centered in the list area)
    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOP", scrollBox, "TOP", 0, -20)
    emptyText:SetText("No presets yet")
    emptyText:Hide()

    mainFrame = frame
    NS.mainFrame = frame

    -- Initial refresh
    NS.RefreshMainFrame()

    -- Create editor (hidden by default)
    NS.CreateEditorFrame(frame)

    return frame
end

----------------------------------------------------------------------
-- Refresh the preset list display
----------------------------------------------------------------------
function NS.RefreshMainFrame()
    if not mainFrame or not dataProvider then return end

    if mainFrame.UpdateScopeButton then
        mainFrame.UpdateScopeButton()
    end

    local presets = NS.GetActivePresets()
    local count = #presets

    emptyText:SetShown(count == 0)

    -- Rebuild data
    dataProvider:Flush()
    for i, preset in ipairs(presets) do
        dataProvider:Insert({ preset = preset, index = i })
    end

    -- Resize main frame height dynamically
    -- Header: padding(38) + save btn(24) + gap(4) + scope btn(24) + gap(5) + divider(1) + gap(4) + label(12) + gap(3) = 115
    local headerHeight = mainFrame.contentTop + 24 + 4 + NS.SCOPE_BTN_HEIGHT + 5 + 1 + 4 + 12 + 3
    local footerHeight = NS.PADDING
    local listHeight = count * NS.ROW_HEIGHT
    local totalHeight = headerHeight + footerHeight + math.max(40, listHeight)
    mainFrame:SetContentHeight(totalHeight)
end
