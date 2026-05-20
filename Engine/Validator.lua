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

