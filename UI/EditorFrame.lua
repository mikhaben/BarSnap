local AddonName, NS = ...

local editorFrame = nil
local currentIndex = nil

----------------------------------------------------------------------
-- Delete confirmation popup
----------------------------------------------------------------------
StaticPopupDialogs["BARSNAP_DELETE_PRESET"] = {
    text = "Delete preset '%s'?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local idx = self.data
        if not idx or not NS.db or not NS.db.presets[idx] then return end
        table.remove(NS.db.presets, idx)
        currentIndex = nil
        if editorFrame then editorFrame:Hide() end
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

    local frame = CreateFrame("Frame", "BarSnapEditorFrame", parent, "BasicFrameTemplateWithInset")
    frame:SetSize(NS.EDITOR_WIDTH, 310)
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("Edit Preset")
    frame:Hide()

    local content = frame.InsetFrame or frame

    -- Icon button (click to pick)
    local iconBtn = CreateFrame("Button", nil, frame)
    iconBtn:SetSize(36, 36)
    iconBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", NS.PADDING + 4, -30)

    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(unpack(NS.ICON_TEXCOORD))
    iconBtn.texture = iconTex

    local iconBorder = iconBtn:CreateTexture(nil, "OVERLAY")
    iconBorder:SetPoint("CENTER")
    iconBorder:SetSize(46, 46)
    iconBorder:SetTexture(NS.TEX_ICON_BORDER)
    iconBorder:SetAlpha(0.6)

    iconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to change icon")
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    iconBtn:SetScript("OnClick", function()
        if not currentIndex then return end
        local preset = NS.db.presets[currentIndex]
        if not preset then return end

        -- Use Blizzard's built-in icon selector
        if IconSelectorPopup then
            IconSelectorPopup:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)

            -- Set up the callback
            local info = {
                editMode = false,
                doneFunc = function(data)
                    local selectedIcon = IconSelectorPopup:GetIconByIndex(IconSelectorPopup.iconSelector:GetSelectedIndex())
                    if selectedIcon then
                        preset.icon = selectedIcon
                        NS.RefreshEditor()
                        NS.RefreshMainFrame()
                    end
                end,
                cancelFunc = function() end,
            }

            -- Show the icon selector
            IconSelectorPopup:Show()
            IconSelectorPopup:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
            IconSelectorPopup:Update()

            -- Hook the Okay button
            IconSelectorPopup.OkayButton:SetScript("OnClick", function()
                local selectedIdx = IconSelectorPopup.iconSelector:GetSelectedIndex()
                if selectedIdx then
                    local icon = IconSelectorPopup:GetIconByIndex(selectedIdx)
                    if icon then
                        preset.icon = icon
                        NS.RefreshEditor()
                        NS.RefreshMainFrame()
                    end
                end
                IconSelectorPopup:Hide()
            end)
        end
    end)
    frame.iconBtn = iconBtn

    -- Name input
    local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetHeight(22)
    nameBox:SetPoint("LEFT", iconBtn, "RIGHT", 12, 0)
    nameBox:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    nameBox:SetFontObject(GameFontHighlight)

    nameBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if not currentIndex then return end
        local preset = NS.db.presets[currentIndex]
        if not preset then return end

        local newName = NS.ValidateName(self:GetText())
        if not newName then
            -- Revert
            self:SetText(preset.name)
            return
        end
        newName = NS.UniqueName(newName, currentIndex)
        preset.name = newName
        self:SetText(newName)
        NS.RefreshMainFrame()
    end)

    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if currentIndex and NS.db.presets[currentIndex] then
            self:SetText(NS.db.presets[currentIndex].name)
        end
    end)

    -- Also save on focus lost
    nameBox:SetScript("OnEditFocusLost", function(self)
        if not currentIndex then return end
        local preset = NS.db.presets[currentIndex]
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

    -- Delete button (trash icon, right of name)
    local deleteBtn = CreateFrame("Button", nil, frame)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("LEFT", nameBox, "RIGHT", 4, 0)

    local deleteTex = deleteBtn:CreateTexture(nil, "ARTWORK")
    deleteTex:SetAllPoints()
    deleteTex:SetTexture(NS.TEX_TRASH)
    deleteBtn.texture = deleteTex

    local deleteHL = deleteBtn:CreateTexture(nil, "HIGHLIGHT")
    deleteHL:SetAllPoints()
    deleteHL:SetTexture(NS.TEX_HIGHLIGHT)
    deleteHL:SetAlpha(0.3)

    deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Preset")
        GameTooltip:AddLine("This cannot be undone", 1, 0.3, 0.3)
        GameTooltip:Show()
    end)
    deleteBtn:SetScript("OnLeave", GameTooltip_Hide)

    deleteBtn:SetScript("OnClick", function()
        if not currentIndex then return end
        local preset = NS.db.presets[currentIndex]
        if not preset then return end
        local popup = StaticPopup_Show("BARSNAP_DELETE_PRESET", preset.name)
        if popup then
            popup.data = currentIndex
        end
    end)
    frame.deleteBtn = deleteBtn

    -- Section: Restore Categories
    local catHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catHeader:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -14)
    catHeader:SetText("Restore categories")
    catHeader:SetTextColor(unpack(NS.COLOR_YELLOW))
    frame.catHeader = catHeader

    -- Category checkboxes
    frame.checkboxes = {}
    local lastAnchor = catHeader
    for i, cat in ipairs(NS.CATEGORIES) do
        local cb = CreateFrame("CheckButton", "BarSnapCat_" .. cat.key, frame, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, (i == 1) and -4 or -2)

        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(cat.label)
        label:SetTextColor(unpack(NS.COLOR_LABEL_GRAY))
        cb.label = label

        cb.categoryKey = cat.key
        cb:SetScript("OnClick", function(self)
            if not currentIndex then return end
            local preset = NS.db.presets[currentIndex]
            if not preset or not preset.filters then return end
            preset.filters[cat.key] = self:GetChecked() and true or false
            NS.UpdateCategoryWarning()
        end)

        frame.checkboxes[cat.key] = cb
        lastAnchor = cb
    end

    -- Section: Options
    local optHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
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
    preserveCB.label = preserveLabel

    preserveCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Keep unlisted slots")
        GameTooltip:AddLine("When enabled, slots not in this preset\nstay as-is instead of being cleared.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    preserveCB:SetScript("OnLeave", GameTooltip_Hide)

    preserveCB:SetScript("OnClick", function(self)
        if not currentIndex then return end
        local preset = NS.db.presets[currentIndex]
        if not preset then return end
        preset.preserveLayout = self:GetChecked() and true or false
    end)
    frame.preserveCB = preserveCB

    -- Warning: all categories disabled
    local allDisabledWarn = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    allDisabledWarn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
    allDisabledWarn:SetJustifyH("LEFT")
    allDisabledWarn:SetText("All categories disabled — nothing will restore!")
    allDisabledWarn:SetTextColor(unpack(NS.COLOR_YELLOW))
    allDisabledWarn:Hide()
    frame.allDisabledWarn = allDisabledWarn

    editorFrame = frame
    NS.editorFrame = frame
    return frame
end

----------------------------------------------------------------------
-- Update "all categories disabled" warning visibility
----------------------------------------------------------------------
function NS.UpdateCategoryWarning()
    if not editorFrame or not currentIndex then return end
    local preset = NS.db.presets[currentIndex]
    if not preset or not preset.filters then
        editorFrame.allDisabledWarn:Hide()
        return
    end
    for _, cat in ipairs(NS.CATEGORIES) do
        if preset.filters[cat.key] ~= false then
            editorFrame.allDisabledWarn:Hide()
            return
        end
    end
    editorFrame.allDisabledWarn:Show()
end

----------------------------------------------------------------------
-- Open editor for a specific preset index
----------------------------------------------------------------------
function NS.OpenEditor(index)
    if not editorFrame then
        NS.CreateEditorFrame(NS.mainFrame)
    end

    local preset = NS.db.presets[index]
    if not preset then return end

    currentIndex = index
    NS.RefreshEditor()
    editorFrame:Show()
end

----------------------------------------------------------------------
-- Refresh editor contents from current preset
----------------------------------------------------------------------
function NS.RefreshEditor()
    if not editorFrame or not currentIndex then return end
    local preset = NS.db.presets[currentIndex]
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
    if editorFrame then
        editorFrame:Hide()
    end
end
