local AddonName, NS = ...

----------------------------------------------------------------------
-- Icon button factory (shared by Apply, Delete, Edit)
----------------------------------------------------------------------
local function CreateIconButton(parent, texture, anchor, tooltip, opts)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
    btn:SetPoint(unpack(anchor))

    local tex = btn:CreateTexture(nil, "ARTWORK")
    if opts and opts.texSize then
        tex:SetSize(opts.texSize, opts.texSize)
        tex:SetPoint("CENTER")
    else
        tex:SetAllPoints()
    end
    tex:SetTexture(texture)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(NS.TEX_HIGHLIGHT)
    hl:SetAlpha(0.3)

    NS.SetupTooltip(btn, tooltip.title, tooltip.body, tooltip.r, tooltip.g, tooltip.b)
    return btn
end

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
        row.applyBtn = CreateIconButton(row, NS.TEX_PLAY,
            {"RIGHT", row, "RIGHT", 0, 0},
            { title = "Apply Preset" })

        -- Delete button (trash icon) — middle
        row.deleteBtn = CreateIconButton(row, NS.TEX_TRASH,
            {"RIGHT", row.applyBtn, "LEFT", -3, 0},
            { title = "Delete Preset", body = "This cannot be undone", r = 1, g = 0.3, b = 0.3 },
            { texSize = NS.BTN_SIZE - 4 })

        -- Edit button (pencil/gear) — leftmost of the three
        row.editBtn = CreateIconButton(row, NS.TEX_EDIT,
            {"RIGHT", row.deleteBtn, "LEFT", -3, 0},
            { title = "Edit Preset" })
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
