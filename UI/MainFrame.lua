local AddonName, NS = ...

local mainFrame = nil
local presetRows = {}
local emptyText = nil
local listContainer = nil

----------------------------------------------------------------------
-- Create the main window
----------------------------------------------------------------------
function NS.CreateMainFrame()
    if mainFrame then return mainFrame end

    local frame = CreateFrame("Frame", "BarSnapMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(NS.MAIN_WIDTH, NS.MAIN_HEIGHT)

    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")

    -- Title
    frame.TitleText:SetText("BarSnap")

    -- Close editor when main window closes
    frame:SetScript("OnHide", function()
        NS.CloseEditor()
    end)

    -- ESC to close
    tinsert(UISpecialFrames, "BarSnapMainFrame")

    -- Save Current Bars button
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(NS.MAIN_WIDTH - NS.PADDING * 2 - 16, 24)
    saveBtn:SetPoint("TOP", frame, "TOP", 0, -30)
    saveBtn:SetText("Save Current Bars")

    saveBtn:SetScript("OnClick", function()
        if not NS.CanModifyBars() then return end

        local actions = NS.ScanBars()
        local count = NS.CountActions(actions)

        -- Auto-name
        local baseName = "Preset #" .. (#NS.db.presets + 1)
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
            actions = actions,
        }

        table.insert(NS.db.presets, preset)
        NS.RefreshMainFrame()

        -- Open editor for the new preset
        NS.OpenEditor(#NS.db.presets)

        NS.Print("Saved '" .. name .. "' (" .. count .. " actions)")
    end)
    frame.saveBtn = saveBtn

    -- Divider
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("TOPRIGHT", saveBtn, "BOTTOMRIGHT", 0, -6)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- "Presets" label
    local presetsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetsLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)
    presetsLabel:SetText("Presets")
    presetsLabel:SetTextColor(unpack(NS.COLOR_YELLOW))

    -- Scroll frame for preset list
    local scrollFrame = CreateFrame("ScrollFrame", "BarSnapScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(NS.MAIN_WIDTH - NS.PADDING * 2 - 30)
    scrollChild:SetHeight(1) -- Will be updated dynamically
    scrollFrame:SetScrollChild(scrollChild)
    listContainer = scrollChild

    -- Empty state text
    emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOP", scrollChild, "TOP", 0, -20)
    emptyText:SetText("No presets yet")
    emptyText:Hide()

    frame:Hide()
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
    if not mainFrame or not listContainer then return end

    local presets = NS.db.presets
    local count = #presets

    -- Show/hide empty state
    if count == 0 then
        emptyText:Show()
    else
        emptyText:Hide()
    end

    -- Configure rows
    for i = 1, count do
        local row = NS.AcquirePresetRow(listContainer, i)
        presetRows[i] = row
        row:SetWidth(listContainer:GetWidth())
        row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -(i - 1) * NS.ROW_HEIGHT)
        row:SetPoint("RIGHT", listContainer, "RIGHT", 0, 0)
        NS.ConfigurePresetRow(row, presets[i], i)
    end

    -- Hide unused rows
    for i = count + 1, #presetRows do
        if presetRows[i] then
            presetRows[i]:Hide()
        end
    end

    -- Update scroll child height
    listContainer:SetHeight(math.max(count * NS.ROW_HEIGHT, 1))

    -- Resize main frame height dynamically (min 200, max ~500)
    local baseHeight = 100 -- title + save button + divider + label
    local listHeight = count * NS.ROW_HEIGHT
    local newHeight = math.max(200, math.min(baseHeight + listHeight + 40, 500))
    mainFrame:SetHeight(newHeight)
end
