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
    local presets = NS.GetActivePresets()
    if not presets then return name end

    local function nameExists(n)
        for i, preset in ipairs(presets) do
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
        return NS.FindMacroIndex(action) ~= nil

    elseif t == "mount" then
        if not id or not C_MountJournal then return false end
        -- Random Favourite Mount is always available
        if id == 0 or id == 0xFFFFFFF then return true end
        local name = C_MountJournal.GetMountInfoByID(id)
        return name ~= nil

    elseif t == "toy" then
        if not id or not C_ToyBox then return false end
        return C_ToyBox.PlayerHasToy(id)

    elseif t == "flyout" then
        return id ~= nil

    elseif t == "equipmentset" then
        if not action.name or not C_EquipmentSet then return false end
        local setID = C_EquipmentSet.GetEquipmentSetID(action.name)
        return setID ~= nil

    elseif t == "summonpet" then
        if not id or not C_PetJournal then return false end
        local _, _, _, _, _, _, _, _, _, _, petID = C_PetJournal.GetPetInfoByPetID(id)
        return petID ~= nil

    end

    return false
end

----------------------------------------------------------------------
-- Find macro index by name. New presets carry an explicit isCharacter
-- marker — we search only that pool, so we never silently substitute a
-- same-named macro from the other pool (e.g. user deleted their
-- character macro between save and restore).
-- Legacy presets (isCharacter == nil) fall back to searching both pools
-- account-first, matching the previous GetMacroIndexByName behaviour.
----------------------------------------------------------------------
function NS.FindMacroIndex(action)
    if not action or not action.name then return nil end

    local accountEnd = MAX_ACCOUNT_MACROS
    local charEnd    = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS

    if action.isCharacter == true then
        for i = accountEnd + 1, charEnd do
            if GetMacroInfo(i) == action.name then return i end
        end
        return nil
    elseif action.isCharacter == false then
        for i = 1, accountEnd do
            if GetMacroInfo(i) == action.name then return i end
        end
        return nil
    else
        for i = 1, charEnd do
            if GetMacroInfo(i) == action.name then return i end
        end
        return nil
    end
end
