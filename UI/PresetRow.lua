local AddonName, NS = ...

----------------------------------------------------------------------
-- Preset row pool
----------------------------------------------------------------------
local rowPool = {}
local poolSize = 0

----------------------------------------------------------------------
-- Create a single preset row (icon + name + apply + edit buttons)
----------------------------------------------------------------------
function NS.CreatePresetRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(NS.ROW_HEIGHT)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(NS.ICON_SIZE, NS.ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    icon:SetTexCoord(unpack(NS.ICON_TEXCOORD))
    row.icon = icon

    -- Name text
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -(NS.BTN_SIZE * 2 + 8), 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Edit button (pencil/gear)
    local editBtn = CreateFrame("Button", nil, row)
    editBtn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
    editBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local editTex = editBtn:CreateTexture(nil, "ARTWORK")
    editTex:SetAllPoints()
    editTex:SetTexture(NS.TEX_EDIT)
    editTex:SetDesaturated(false)
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

    -- Apply button (play arrow)
    local applyBtn = CreateFrame("Button", nil, row)
    applyBtn:SetSize(NS.BTN_SIZE, NS.BTN_SIZE)
    applyBtn:SetPoint("RIGHT", editBtn, "LEFT", -4, 0)

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

    -- Store in pool
    poolSize = poolSize + 1
    rowPool[poolSize] = row

    return row
end

----------------------------------------------------------------------
-- Acquire a row from pool (create if needed)
----------------------------------------------------------------------
function NS.AcquirePresetRow(parent, index)
    local row = rowPool[index]
    if not row then
        row = NS.CreatePresetRow(parent)
    end
    row:SetParent(parent)
    return row
end

----------------------------------------------------------------------
-- Configure a row with preset data
----------------------------------------------------------------------
function NS.ConfigurePresetRow(row, preset, index)
    if not row or not preset then return end

    -- Icon
    row.icon:SetTexture(preset.icon or NS.TEX_FALLBACK_ICON)

    -- Name
    row.nameText:SetText(preset.name or "Unnamed")
    row.nameText:SetTextColor(unpack(NS.COLOR_WHITE))

    -- Apply click
    row.applyBtn:SetScript("OnClick", function()
        NS.ApplyPreset(preset)
    end)

    -- Edit click
    row.editBtn:SetScript("OnClick", function()
        NS.OpenEditor(index)
    end)

    row.presetIndex = index
    row:Show()
end
