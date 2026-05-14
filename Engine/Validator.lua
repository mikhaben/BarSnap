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
-- Find macro index by name. New presets carry an explicit isCharacter
-- marker — we search only that pool, so we never silently substitute a
-- same-named macro from the other pool (e.g. user deleted their
-- character macro between save and restore).
-- Legacy presets (isCharacter == nil) fall back to searching both pools
-- account-first, matching the previous GetMacroIndexByName behaviour.
----------------------------------------------------------------------
function NS.FindMacroIndex(action)
    if not action or not action.name then return nil end

    local accountEnd = MAX_ACCOUNT_MACROS or 120
    local charEnd    = accountEnd + (MAX_CHARACTER_MACROS or 18)

    local lo, hi
    if action.isCharacter == true then
        lo, hi = accountEnd + 1, charEnd
    elseif action.isCharacter == false then
        lo, hi = 1, accountEnd
    else
        lo, hi = 1, charEnd
    end

    for i = lo, hi do
        if GetMacroInfo(i) == action.name then return i end
    end
    return nil
end
