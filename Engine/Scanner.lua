local AddonName, NS = ...

----------------------------------------------------------------------
-- Reusable scan buffer (GC-friendly)
----------------------------------------------------------------------
local scanBuffer = {}

----------------------------------------------------------------------
-- ScanBars: read all 96 slots → sparse actions table
----------------------------------------------------------------------
function NS.ScanBars()
    wipe(scanBuffer)

    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local actionType, id = GetActionInfo(slot)

        if actionType == "spell" then
            scanBuffer[slot] = { type = "spell", id = id }

        elseif actionType == "item" then
            -- Check if this item is actually a toy
            if id and C_ToyBox and C_ToyBox.GetToyInfo then
                local toyID = C_ToyBox.GetToyInfo(id)
                if toyID then
                    scanBuffer[slot] = { type = "toy", id = id }
                else
                    scanBuffer[slot] = { type = "item", id = id }
                end
            else
                scanBuffer[slot] = { type = "item", id = id }
            end

        elseif actionType == "macro" then
            local name = GetMacroInfo(id)
            if name then
                scanBuffer[slot] = { type = "macro", name = name }
            end

        elseif actionType == "summonmount" then
            scanBuffer[slot] = { type = "mount", id = id }

        elseif actionType == "companion" or actionType == "toy" then
            -- Companion might be a toy; validate via C_ToyBox
            if C_ToyBox and C_ToyBox.GetToyInfo and id then
                local toyID = C_ToyBox.GetToyInfo(id)
                if toyID then
                    scanBuffer[slot] = { type = "toy", id = id }
                end
            end

        elseif actionType == "flyout" then
            scanBuffer[slot] = { type = "flyout", id = id }

        -- nil/unknown type → skip (sparse)
        end
    end

    -- Return a deep copy so the buffer can be reused
    return NS.DeepCopy(scanBuffer)
end

----------------------------------------------------------------------
-- Count non-empty actions in a table
----------------------------------------------------------------------
function NS.CountActions(actions)
    if not actions then return 0 end
    local count = 0
    for _ in pairs(actions) do
        count = count + 1
    end
    return count
end
