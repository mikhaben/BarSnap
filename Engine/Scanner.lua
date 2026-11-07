local _, NS = ...

local function GetMacroDuplicates()
    local counts = {}
    local total = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
    for i = 1, total do
        local name = GetMacroInfo(i)
        if name then counts[name] = (counts[name] or 0) + 1 end
    end
    local dupes = {}
    for name, count in pairs(counts) do
        if count > 1 then dupes[name] = true end
    end
    return dupes
end

function NS.ScanBars()
    local accountMax = MAX_ACCOUNT_MACROS or 120
    local actions = {}
    local capturedDuped = {}

    local dupes = nil

    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local actionType, id = GetActionInfo(slot)

        if actionType == "spell" then
            local baseID = FindBaseSpellByID and FindBaseSpellByID(id) or id
            actions[slot] = { type = "spell", id = baseID }

        elseif actionType == "item" then
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
            local bar = math.ceil(slot / NS.SLOTS_PER_BAR)
            if not id or id <= 0 then
                NS.Warn(string.format("Slot %d (bar %d): broken macro reference (id=%s) — recreate the macro to fix",
                    slot, bar, tostring(id)))
            else
                local name, _, body = GetMacroInfo(id)
                if not name then
                    NS.Warn(string.format("Slot %d (bar %d): macro idx %d has no name — skipped",
                        slot, bar, id))
                else
                    actions[slot] = {
                        type        = "macro",
                        name        = name,
                        isCharacter = id > accountMax,
                        bodyHash    = NS.HashMacroBody(body),
                    }
                    if not dupes then dupes = GetMacroDuplicates() end
                    if dupes[name] then capturedDuped[name] = true end
                end
            end

        elseif actionType == "summonmount" then
            actions[slot] = { type = "mount", id = id }

        elseif actionType == "toy" then
            actions[slot] = { type = "toy", id = id }

        elseif actionType == "companion" then
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

        end
    end

    local dupNames = {}
    for name in pairs(capturedDuped) do dupNames[#dupNames + 1] = name end
    if #dupNames > 0 then
        table.sort(dupNames)
        local sample = table.concat(dupNames, ", ", 1, math.min(5, #dupNames))
        local suffix = #dupNames > 5 and (" (and " .. (#dupNames - 5) .. " more)") or ""
        NS.Warn(string.format("Captured macros with duplicate names: %s%s — consider renaming for clarity.",
            sample, suffix))
    end

    return actions
end

function NS.CountActions(actions)
    if not actions then return 0 end
    local count = 0
    for _ in pairs(actions) do
        count = count + 1
    end
    return count
end

function NS.DebugScan()
    local accountMax = MAX_ACCOUNT_MACROS or 120
    NS.Print(string.format("Scan (MAX_ACCOUNT_MACROS=%s, MAX_CHARACTER_MACROS=%s, slots %d-%d, bars 1-%d):",
        tostring(MAX_ACCOUNT_MACROS), tostring(MAX_CHARACTER_MACROS),
        NS.SLOT_MIN, NS.SLOT_MAX, NS.BAR_COUNT))

    local perBar = {}
    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local actionType = GetActionInfo(slot)
        if actionType then
            local bar = math.ceil(slot / NS.SLOTS_PER_BAR)
            perBar[bar] = (perBar[bar] or 0) + 1
        end
    end

    local hasActive = false
    for bar = 1, NS.BAR_COUNT do
        if perBar[bar] then
            if not hasActive then
                NS.Print("Active bars:")
                hasActive = true
            end
            local slotMin = (bar - 1) * NS.SLOTS_PER_BAR + 1
            local slotMax = bar * NS.SLOTS_PER_BAR
            local label = (NS.BAR_LABELS and NS.BAR_LABELS[bar]) or ("Bar " .. bar)
            NS.Print(string.format("  %s [slots %d-%d]: %d action%s",
                label, slotMin, slotMax, perBar[bar],
                perBar[bar] == 1 and "" or "s"))
        end
    end

    local printed = 0
    for bar = 1, NS.BAR_COUNT do
        local slotMin = (bar - 1) * NS.SLOTS_PER_BAR + 1
        local slotMax = bar * NS.SLOTS_PER_BAR
        for slot = slotMin, slotMax do
            local actionType, id = GetActionInfo(slot)
            if actionType then
                local detail
                if actionType == "macro" then
                    local name = (id and id > 0) and GetMacroInfo(id) or nil
                    local pool = (id and id > accountMax) and "char" or "account"
                    detail = string.format("macro idx=%s name=%q pool=%s",
                        tostring(id), tostring(name), pool)
                else
                    detail = string.format("%s id=%s", actionType, tostring(id))
                end
                NS.Print(string.format("  bar %d slot %d: %s", bar, slot, detail))
                printed = printed + 1
            end
        end
    end

    if printed == 0 then
        NS.Print(string.format("  (all %d slots empty)", NS.SLOT_MAX))
    end
end
