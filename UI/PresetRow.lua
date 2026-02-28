local AddonName, NS = ...

----------------------------------------------------------------------
-- Initialize a preset row (creates children on first use, configures every call)
-- Used as the element initializer for the WowScrollBoxList DataProvider.
----------------------------------------------------------------------
function NS.InitPresetRow(row, preset, index)
    -- Create child widgets on first use
    if not row.icon then
        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(NS.ICON_SIZE, NS.ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexCoord(unpack(NS.ICON_TEXCOORD))
        row.icon = icon

        -- Name text
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -(NS.BTN_SIZE * 3 + 10), 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        -- Apply button (play arrow) — rightmost
        local applyBtn = CreateFrame("Button", nil, row)
        applyBtn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
        applyBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        local applyTex = applyBtn:CreateTexture(nil, "ARTWORK")
        applyTex:SetAllPoints()
        applyTex:SetTexture(NS.TEX_PLAY)
        applyBtn.texture = applyTex

        local applyHL = applyBtn:CreateTexture(nil, "HIGHLIGHT")
        applyHL:SetAllPoints()
        applyHL:SetTexture(NS.TEX_HIGHLIGHT)
        applyHL:SetAlpha(0.3)

        applyBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Apply Preset")
            GameTooltip:Show()
        end)
        applyBtn:SetScript("OnLeave", GameTooltip_Hide)
        row.applyBtn = applyBtn

        -- Delete button (trash icon) — middle
        local deleteBtn = CreateFrame("Button", nil, row)
        deleteBtn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
        deleteBtn:SetPoint("RIGHT", applyBtn, "LEFT", -3, 0)

        local deleteTex = deleteBtn:CreateTexture(nil, "ARTWORK")
        deleteTex:SetSize(NS.BTN_SIZE - 4, NS.BTN_SIZE - 4)
        deleteTex:SetPoint("CENTER")
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
        row.deleteBtn = deleteBtn

        -- Edit button (pencil/gear) — leftmost of the three
        local editBtn = CreateFrame("Button", nil, row)
        editBtn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
        editBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -3, 0)

        local editTex = editBtn:CreateTexture(nil, "ARTWORK")
        editTex:SetAllPoints()
        editTex:SetTexture(NS.TEX_EDIT)
        editBtn.texture = editTex

        local editHL = editBtn:CreateTexture(nil, "HIGHLIGHT")
        editHL:SetAllPoints()
        editHL:SetTexture(NS.TEX_HIGHLIGHT)
        editHL:SetAlpha(0.3)

        editBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Edit Preset")
            GameTooltip:Show()
        end)
        editBtn:SetScript("OnLeave", GameTooltip_Hide)
        row.editBtn = editBtn
    end

    -- Configure data (runs every time element is recycled)
    row:SetHeight(NS.ROW_HEIGHT)
    row.icon:SetTexture(preset.icon or NS.TEX_FALLBACK_ICON)
    row.nameText:SetText(preset.name or "Unnamed")
    row.nameText:SetTextColor(unpack(NS.COLOR_WHITE))

    row.applyBtn:SetScript("OnClick", function()
        NS.ApplyPreset(preset)
    end)

    row.deleteBtn:SetScript("OnClick", function()
        local popup = StaticPopup_Show("BARSNAP_DELETE_PRESET", preset.name)
        if popup then
            popup.data = { idx = index, name = preset.name }
        end
    end)

    row.editBtn:SetScript("OnClick", function()
        NS.OpenEditor(index)
    end)
end
