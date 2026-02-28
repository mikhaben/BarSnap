local AddonName, NS = ...

----------------------------------------------------------------------
-- Window factory: creates standard addon windows
--
-- Floating (no anchor): centered, draggable, ESC-closeable
-- Docked  (anchor given): attached to another frame, static
----------------------------------------------------------------------

local DEFAULT_MIN_H = 60
local DEFAULT_MAX_H = 800

function NS.CreateWindow(opts)
    local parent = opts.parent or UIParent
    local frame = CreateFrame("Frame", opts.name, parent, "BasicFrameTemplateWithInset")
    frame:SetWidth(opts.width)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText(opts.title or "")

    if opts.anchor then
        -- Docked: positioned relative to anchor frame
        local a = opts.anchor
        frame:SetPoint(
            a.point or "TOPLEFT",
            a.frame,
            a.to or "TOPRIGHT",
            a.x or 2,
            a.y or 0
        )
    else
        -- Floating: centered, draggable
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        if opts.name then
            tinsert(UISpecialFrames, opts.name)
        end
    end

    if opts.onHide then
        frame:SetScript("OnHide", opts.onHide)
    end

    -- Height clamping bounds
    local minH = opts.minH or DEFAULT_MIN_H
    local maxH = opts.maxH or DEFAULT_MAX_H

    function frame:SetContentHeight(h)
        local clamped = math.max(minH, math.min(h, maxH))
        self:SetHeight(clamped)
    end

    -- Standard content offset (below title bar + padding)
    frame.contentTop = NS.TITLE_BAR_HEIGHT + NS.PADDING

    frame:SetContentHeight(minH)
    frame:Hide()
    return frame
end
