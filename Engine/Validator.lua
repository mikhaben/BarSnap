local AddonName, NS = ...

----------------------------------------------------------------------
-- Combat guard
----------------------------------------------------------------------
function NS.CanModifyBars()
    if InCombatLockdown() then
        NS.Warn("Leave combat first")
        return false
    end
    return true
end

----------------------------------------------------------------------
-- Validate preset name (non-empty, trimmed)
-- Returns cleaned name or nil on failure
----------------------------------------------------------------------
function NS.ValidateName(name)
    if type(name) ~= "string" then return nil end
    name = name:trim()
    if name == "" then return nil end
    return name
end

----------------------------------------------------------------------
-- Ensure unique name among existing presets
-- Appends " (2)", " (3)" etc. if needed
----------------------------------------------------------------------
function NS.UniqueName(name, excludeIndex)
    if not NS.db or not NS.db.presets then return name end

    local function nameExists(n)
        for i, preset in ipairs(NS.db.presets) do
            if i ~= excludeIndex and preset.name == n then
                return true
            end
        end
        return false
    end

    if not nameExists(name) then return name end

    local suffix = 2
    while nameExists(name .. " (" .. suffix .. ")") do
        suffix = suffix + 1
    end
    return name .. " (" .. suffix .. ")"
end

----------------------------------------------------------------------
-- Validate a single action entry can be restored
-- Returns true if the action's requirements are met
----------------------------------------------------------------------
function NS.ValidateAction(action)
    if not action or type(action) ~= "table" then return false end

    local t = action.type
    local id = action.id

    if t == "spell" then
        return id and IsPlayerSpell(id)

    elseif t == "item" then
        if not id then return false end
        -- Item in bags OR is a toy the player has
        local count = GetItemCount(id)
        if count and count > 0 then return true end
        if C_ToyBox and C_ToyBox.PlayerHasToy and C_ToyBox.PlayerHasToy(id) then return true end
        return false

    elseif t == "macro" then
        if not action.name then return false end
        local idx = GetMacroIndexByName(action.name)
        return idx ~= nil and idx > 0

    elseif t == "mount" then
        if not id or not C_MountJournal then return false end
        local name = C_MountJournal.GetMountInfoByID(id)
        return name ~= nil

    elseif t == "toy" then
        if not id or not C_ToyBox then return false end
        return C_ToyBox.PlayerHasToy(id)

    elseif t == "flyout" then
        return id ~= nil

    end

    return false
end

----------------------------------------------------------------------
-- Find macro index by name
----------------------------------------------------------------------
function NS.FindMacroIndex(action)
    if not action or not action.name then return nil end
    local idx = GetMacroIndexByName(action.name)
    if idx and idx > 0 then return idx end
    return nil
end
