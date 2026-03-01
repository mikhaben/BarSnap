local AddonName, NS = ...

local editorFrame = nil
local currentIndex = nil
local iconPickerFrame = nil

----------------------------------------------------------------------
-- Resolve an action table to its icon texture
----------------------------------------------------------------------
local function GetActionIcon(action)
    if not action or not action.type then return nil end
    local t = action.type
    local id = action.id

    if t == "spell" and id then
        return C_Spell and C_Spell.GetSpellTexture(id) or GetSpellTexture(id)
    elseif t == "item" and id then
        return C_Item and C_Item.GetItemIconByID(id) or GetItemIcon(id)
    elseif t == "macro" and action.name then
        local _, icon = GetMacroInfo(action.name)
        return icon
    elseif t == "mount" and id and C_MountJournal then
        local _, _, icon = C_MountJournal.GetMountInfoByID(id)
        return icon
    elseif t == "toy" and id and C_ToyBox and C_ToyBox.GetToyInfo then
        local _, _, icon = C_ToyBox.GetToyInfo(id)
        return icon
    elseif t == "flyout" and id then
        return C_Spell and C_Spell.GetSpellTexture(id)
    elseif t == "equipmentset" and action.name and C_EquipmentSet then
        local setID = C_EquipmentSet.GetEquipmentSetID(action.name)
        if setID then
            local _, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
            return icon
        end
    elseif t == "summonpet" and id and C_PetJournal then
        local _, _, _, _, _, _, _, _, _, petIcon = C_PetJournal.GetPetInfoByPetID(id)
        return petIcon
    end
    return nil
end

----------------------------------------------------------------------
-- Icon picker: shows preset's action icons in a grid
----------------------------------------------------------------------
local PICKER_COLS = 6
local PICKER_ICON = 32
local PICKER_GAP  = NS.PADDING / 2   -- half standard padding (5px)
local PICKER_PAD  = NS.PADDING
local PICKER_MIN_W = 150

local function CreateIconPicker(parent)
    if iconPickerFrame then return iconPickerFrame end

    local f = NS.CreateWindow({
        name   = "BarSnapIconPicker",
        title  = "Choose Icon",
        width  = PICKER_MIN_W,
        parent = parent,
        anchor = { frame = parent },
    })

    f.buttons = {}
    iconPickerFrame = f
    return f
end

local function ShowIconPicker()
    if not currentIndex then return end
    local preset = NS.GetActivePresets()[currentIndex]
    if not preset or not preset.actions then return end

    local picker = CreateIconPicker(editorFrame)

    -- Collect unique icons from preset actions
    local icons = {}
    local seen = {}
    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local action = preset.actions[slot]
        if action then
            local icon = GetActionIcon(action)
            if icon and not seen[icon] then
                seen[icon] = true
                icons[#icons + 1] = icon
            end
        end
    end

    -- Hide old buttons
    for _, btn in ipairs(picker.buttons) do
        btn:Hide()
    end

    if #icons == 0 then
        picker:SetWidth(PICKER_MIN_W)
        picker:SetContentHeight(56)
        picker:Show()
        return
    end

    -- Size the frame to fit the grid (flex-wrap: cols shrink to icon count)
    local cols = math.min(#icons, PICKER_COLS)
    local rows = math.ceil(#icons / PICKER_COLS)
    local gridW = cols * (PICKER_ICON + PICKER_GAP) - PICKER_GAP
    local gridH = rows * (PICKER_ICON + PICKER_GAP) - PICKER_GAP
    local frameW = math.max(PICKER_MIN_W, gridW + PICKER_PAD * 2 + 16)
    picker:SetWidth(frameW)
    picker:SetContentHeight(gridH + NS.PADDING + picker.contentTop)

    -- Create / reuse buttons
    for i, icon in ipairs(icons) do
        local btn = picker.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, picker)
            btn:SetSize(PICKER_ICON, PICKER_ICON)

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(unpack(NS.ICON_TEXCOORD))
            btn.tex = tex

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(NS.TEX_HIGHLIGHT)
            hl:SetBlendMode("ADD")

            local check = btn:CreateTexture(nil, "OVERLAY")
            check:SetSize(16, 16)
            check:SetPoint("BOTTOMRIGHT", 2, -2)
            check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            check:Hide()
            btn.check = check

            picker.buttons[i] = btn
        end

        local col = (i - 1) % PICKER_COLS
        local row = math.floor((i - 1) / PICKER_COLS)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", picker, "TOPLEFT",
            PICKER_PAD + col * (PICKER_ICON + PICKER_GAP),
            -(picker.contentTop + row * (PICKER_ICON + PICKER_GAP)))

        btn.tex:SetTexture(icon)
        btn.check:SetShown(icon == preset.icon)

        btn:SetScript("OnClick", function()
            preset.icon = icon
            -- Update all checkmarks
            for j = 1, #icons do
                local b = picker.buttons[j]
                if b and b:IsShown() then
                    b.check:SetShown(icons[j] == icon)
                end
            end
            NS.RefreshEditor()
            NS.RefreshMainFrame()
        end)

        btn:Show()
    end

    picker:Show()
end

----------------------------------------------------------------------
-- Delete confirmation popup
----------------------------------------------------------------------
StaticPopupDialogs["BARSNAP_DELETE_PRESET"] = {
    text = "Delete preset '%s'?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local data = self.data
        if not data then return end
        local idx = data.idx
        local activePresets = NS.GetActivePresets()
        if not idx or not activePresets[idx] then return end
        -- Verify name still matches to prevent wrong-preset deletion after index shifts
        if activePresets[idx].name ~= data.name then return end
        table.remove(activePresets, idx)
        NS.CloseEditor()
        NS.RefreshMainFrame()
    end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
    preferredIndex = 3,
}

----------------------------------------------------------------------
-- Create the editor frame (anchored to right of main window)
----------------------------------------------------------------------
function NS.CreateEditorFrame(parent)
    if editorFrame then return editorFrame end

    local frame = NS.CreateWindow({
        name   = "BarSnapEditorFrame",
        title  = "Edit Preset",
        width  = NS.EDITOR_WIDTH,
        parent = parent,
        anchor = { frame = parent },
    })

    -- Icon display
    local iconBtn = CreateFrame("Frame", nil, frame)
    iconBtn:SetSize(36, 36)
    iconBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", NS.PADDING, -frame.contentTop)

    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(unpack(NS.ICON_TEXCOORD))
    iconBtn.texture = iconTex

    frame.iconBtn = iconBtn

    -- Name input
    local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetHeight(22)
    nameBox:SetPoint("TOPLEFT", frame, "TOPLEFT", NS.PADDING + 36 + 12, -frame.contentTop)
    nameBox:SetPoint("RIGHT", frame, "RIGHT", -NS.PADDING, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    nameBox:SetFontObject(GameFontHighlight)

    nameBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()  -- triggers OnEditFocusLost which handles save
    end)

    nameBox:SetScript("OnEscapePressed", function(self)
        -- Revert to saved name before losing focus
        if currentIndex and NS.GetActivePresets()[currentIndex] then
            self:SetText(NS.GetActivePresets()[currentIndex].name)
        end
        self:ClearFocus()
    end)

    nameBox:SetScript("OnEditFocusLost", function(self)
        if not currentIndex then return end
        local preset = NS.GetActivePresets()[currentIndex]
        if not preset then return end

        local newName = NS.ValidateName(self:GetText())
        if not newName then
            self:SetText(preset.name)
            return
        end
        newName = NS.UniqueName(newName, currentIndex)
        preset.name = newName
        self:SetText(newName)
        NS.RefreshMainFrame()
    end)
    frame.nameBox = nameBox

    -- "Change Icon" button (below icon, aligned with name input)
    local changeIconBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    changeIconBtn:SetSize(85, 22)
    changeIconBtn:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -2)
    changeIconBtn:SetText("Change Icon")

    changeIconBtn:SetScript("OnClick", function()
        if not currentIndex or not NS.GetActivePresets()[currentIndex] then return end
        if iconPickerFrame and iconPickerFrame:IsShown() then
            iconPickerFrame:Hide()
        else
            ShowIconPicker()
        end
    end)
    frame.changeIconBtn = changeIconBtn

    -- 2-column checkbox helper
    local colWidth = (NS.EDITOR_WIDTH - NS.PADDING * 2) / 2

    local function CreateTwoColCheckboxes(parent, items, anchorBelow, onClick)
        local cbs = {}
        local prevLeft = nil
        for i, item in ipairs(items) do
            local col = (i - 1) % 2  -- 0=left, 1=right
            local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            cb:SetSize(24, 24)

            if col == 0 then
                if prevLeft then
                    cb:SetPoint("TOPLEFT", prevLeft, "BOTTOMLEFT", 0, -2)
                else
                    cb:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, -4)
                end
                prevLeft = cb
            else
                cb:SetPoint("LEFT", prevLeft, "LEFT", colWidth, 0)
            end

            local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            label:SetText(item.label)
            label:SetTextColor(unpack(NS.COLOR_LABEL_GRAY))

            cb:SetScript("OnClick", function(self)
                if onClick then onClick(item.key, self:GetChecked()) end
            end)

            cbs[item.key] = cb
        end
        return cbs, prevLeft
    end

    -- Section: Restore Categories
    local catHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catHeader:SetPoint("LEFT", frame, "LEFT", NS.PADDING, 0)
    catHeader:SetPoint("TOP", changeIconBtn, "BOTTOM", 0, -10)
    catHeader:SetText("Restore categories")
    catHeader:SetTextColor(unpack(NS.COLOR_YELLOW))
    frame.catHeader = catHeader

    -- Category checkboxes (2-column)
    local catCBs, catLastRow = CreateTwoColCheckboxes(frame, NS.CATEGORIES, catHeader, function(key, checked)
        if not currentIndex then return end
        local preset = NS.GetActivePresets()[currentIndex]
        if not preset or not preset.filters then return end
        preset.filters[key] = checked and true or false
        NS.UpdateCategoryWarning()
    end)
    frame.checkboxes = catCBs

    -- Section: Action Bars
    local barHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barHeader:SetPoint("TOPLEFT", catLastRow, "BOTTOMLEFT", 0, -10)
    barHeader:SetText("Action bars")
    barHeader:SetTextColor(unpack(NS.COLOR_YELLOW))
    frame.barHeader = barHeader

    -- Bar filter items
    local barItems = {}
    for i = 1, NS.BAR_COUNT do
        barItems[i] = { key = i, label = "Bar " .. i }
    end

    -- Bar checkboxes (2-column)
    local barCBs, barLastRow = CreateTwoColCheckboxes(frame, barItems, barHeader, function(key, checked)
        if not currentIndex then return end
        local preset = NS.GetActivePresets()[currentIndex]
        if not preset or not preset.barFilters then return end
        preset.barFilters[key] = checked and true or false
        NS.UpdateCategoryWarning()
    end)
    frame.barCheckboxes = barCBs

    -- Section: Options
    local optHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", barLastRow, "BOTTOMLEFT", 0, -10)
    optHeader:SetText("Options")
    optHeader:SetTextColor(unpack(NS.COLOR_YELLOW))
    frame.optHeader = optHeader

    -- "Keep unlisted slots" checkbox
    local preserveCB = CreateFrame("CheckButton", "BarSnapPreserveLayout", frame, "UICheckButtonTemplate")
    preserveCB:SetSize(24, 24)
    preserveCB:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -4)

    local preserveLabel = preserveCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    preserveLabel:SetPoint("LEFT", preserveCB, "RIGHT", 2, 0)
    preserveLabel:SetText("Keep unlisted slots")
    preserveLabel:SetTextColor(unpack(NS.COLOR_LABEL_GRAY))

    NS.SetupTooltip(preserveCB, "Keep unlisted slots", "When enabled, slots not in this preset\nstay as-is instead of being cleared.")

    preserveCB:SetScript("OnClick", function(self)
        if not currentIndex then return end
        local preset = NS.GetActivePresets()[currentIndex]
        if not preset then return end
        preset.preserveLayout = self:GetChecked() and true or false
    end)
    frame.preserveCB = preserveCB

    -- Warning: all filters disabled
    local allDisabledWarn = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    allDisabledWarn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", NS.PADDING, NS.PADDING)
    allDisabledWarn:SetJustifyH("LEFT")
    allDisabledWarn:SetText("All filters disabled — nothing will restore!")
    allDisabledWarn:SetTextColor(unpack(NS.COLOR_YELLOW))
    allDisabledWarn:Hide()
    frame.allDisabledWarn = allDisabledWarn

    -- Calculate editor height dynamically from content
    local HEADER_H = 14   -- GameFontNormal approximate height
    local CB_H = 24       -- UICheckButtonTemplate size
    local CB_GAP = 2      -- gap between checkbox rows
    local catRows = math.ceil(#NS.CATEGORIES / 2)
    local barRows = math.ceil(NS.BAR_COUNT / 2)

    local totalH = frame.contentTop + 22 + 2 + 22  -- content top, name input, gap, change icon btn
        + 10 + HEADER_H + 4 + catRows * (CB_H + CB_GAP) - CB_GAP   -- categories section
        + 10 + HEADER_H + 4 + barRows * (CB_H + CB_GAP) - CB_GAP   -- bars section
        + 10 + HEADER_H + 4 + CB_H                                  -- options section
        + NS.PADDING * 3                                             -- bottom padding + warning area
    frame:SetContentHeight(totalH)

    editorFrame = frame
    return frame
end

----------------------------------------------------------------------
-- Update "all categories disabled" warning visibility
----------------------------------------------------------------------
function NS.UpdateCategoryWarning()
    if not editorFrame or not currentIndex then return end
    local preset = NS.GetActivePresets()[currentIndex]
    if not preset then
        editorFrame.allDisabledWarn:Hide()
        return
    end

    -- Check if any category is enabled
    local anyCatEnabled = false
    if preset.filters then
        for _, cat in ipairs(NS.CATEGORIES) do
            if preset.filters[cat.key] ~= false then
                anyCatEnabled = true
                break
            end
        end
    end

    -- Check if any bar is enabled
    local anyBarEnabled = false
    if preset.barFilters then
        for bar = 1, NS.BAR_COUNT do
            if preset.barFilters[bar] ~= false then
                anyBarEnabled = true
                break
            end
        end
    end

    -- Warn if ALL categories disabled OR ALL bars disabled — either blocks all restoration
    editorFrame.allDisabledWarn:SetShown(not anyCatEnabled or not anyBarEnabled)
end

----------------------------------------------------------------------
-- Open editor for a specific preset index
----------------------------------------------------------------------
function NS.OpenEditor(index)
    if not editorFrame then
        NS.CreateEditorFrame(NS.mainFrame)
    end

    local preset = NS.GetActivePresets()[index]
    if not preset then return end

    -- Close icon picker when switching presets
    if iconPickerFrame then iconPickerFrame:Hide() end

    currentIndex = index
    NS.RefreshEditor()
    editorFrame:Show()
end

----------------------------------------------------------------------
-- Refresh editor contents from current preset
----------------------------------------------------------------------
function NS.RefreshEditor()
    if not editorFrame or not currentIndex then return end
    local preset = NS.GetActivePresets()[currentIndex]
    if not preset then
        editorFrame:Hide()
        return
    end

    -- Icon
    editorFrame.iconBtn.texture:SetTexture(preset.icon or NS.TEX_FALLBACK_ICON)

    -- Name
    editorFrame.nameBox:SetText(preset.name or "")

    -- Category checkboxes
    for key, cb in pairs(editorFrame.checkboxes) do
        local checked = true
        if preset.filters and preset.filters[key] ~= nil then
            checked = preset.filters[key]
        end
        cb:SetChecked(checked)
    end

    -- Bar checkboxes
    for bar, cb in pairs(editorFrame.barCheckboxes) do
        local checked = true
        if preset.barFilters and preset.barFilters[bar] ~= nil then
            checked = preset.barFilters[bar]
        end
        cb:SetChecked(checked)
    end

    -- Preserve layout
    editorFrame.preserveCB:SetChecked(preset.preserveLayout or false)

    -- Warning visibility
    NS.UpdateCategoryWarning()
end

----------------------------------------------------------------------
-- Close editor
----------------------------------------------------------------------
function NS.CloseEditor()
    currentIndex = nil
    if iconPickerFrame then iconPickerFrame:Hide() end
    if editorFrame then
        editorFrame:Hide()
    end
end
