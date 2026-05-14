local AddonName, NS = ...

----------------------------------------------------------------------
-- ScanBars: read all 132 slots → sparse actions table
----------------------------------------------------------------------
function NS.ScanBars()
    local accountMax = MAX_ACCOUNT_MACROS or 120
    local actions = {}

    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local actionType, id = GetActionInfo(slot)

        if actionType == "spell" then
            -- Normalize to base spell ID so presets survive talent/spec changes
            local baseID = FindBaseSpellByID and FindBaseSpellByID(id) or id
            actions[slot] = { type = "spell", id = baseID }

        elseif actionType == "item" then
            -- Check if this item is actually a toy
            if id and C_ToyBox and C_ToyBox.GetToyInfo then
                local toyID = C_ToyBox.GetToyInfo(id)
                if toyID then
                    actions[slot] = { type = "toy", id = id }
                else
                    actions[slot] = { type = "item", id = id }
                end
            else
                actions[slot] = { type = "item", id = id }
            end

        elseif actionType == "macro" then
            if id and id > 0 then  -- WoW bug: id=0 for broken/empty macros
                local name = GetMacroInfo(id)
                if name then
                    actions[slot] = {
                        type = "macro",
                        name = name,
                        isCharacter = id > accountMax,
                    }
                else
                    NS.Warn("Slot " .. slot .. ": macro id " .. id .. " has no name; skipped")
                end
            end

        elseif actionType == "summonmount" then
            actions[slot] = { type = "mount", id = id }

        elseif actionType == "toy" then
            -- Trust WoW's type classification
            actions[slot] = { type = "toy", id = id }

        elseif actionType == "companion" then
            -- Legacy type: check if toy, otherwise treat as battle pet
            if id and C_ToyBox and C_ToyBox.GetToyInfo then
                local toyID = C_ToyBox.GetToyInfo(id)
                if toyID then
                    actions[slot] = { type = "toy", id = id }
                else
                    actions[slot] = { type = "summonpet", id = id }
                end
            elseif id then
                actions[slot] = { type = "summonpet", id = id }
            end

        elseif actionType == "flyout" then
            actions[slot] = { type = "flyout", id = id }

        elseif actionType == "equipmentset" then
            local setName = GetActionText(slot)
            if setName then
                actions[slot] = { type = "equipmentset", name = setName }
            end

        elseif actionType == "summonpet" then
            if id then
                actions[slot] = { type = "summonpet", id = id }
            end

        -- nil/unknown type → skip (sparse)
        end
    end

    return actions
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
