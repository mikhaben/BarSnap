local _, NS = ...

local mountCache = nil
local flyoutCache = nil

local macroNameAcct = nil
local macroNameChar = nil
local macroHashAcct = nil
local macroHashChar = nil

local function BuildMacroCaches()
    local accountEnd = MAX_ACCOUNT_MACROS or 120
    local charEnd    = accountEnd + (MAX_CHARACTER_MACROS or 18)
    local na, nc, ha, hc = {}, {}, {}, {}
    for i = 1, charEnd do
        local name, _, body = GetMacroInfo(i)
        if name then
            local isChar = i > accountEnd
            local nameCache = isChar and nc or na
            if not nameCache[name] then nameCache[name] = i end
            if body and body ~= "" then
                local hash = NS.HashMacroBody(body)
                if hash then
                    local hashCache = isChar and hc or ha
                    if not hashCache[hash] then hashCache[hash] = i end
                end
            end
        end
    end
    macroNameAcct, macroNameChar = na, nc
    macroHashAcct, macroHashChar = ha, hc
end

function NS.FindMacroIndex(action)
    if not action or not action.name then return nil end
    if not macroNameAcct then BuildMacroCaches() end

    local h = action.bodyHash
    if action.isCharacter == true then
        if macroNameChar[action.name] then return macroNameChar[action.name] end
        if h and macroHashChar[h] then return macroHashChar[h] end
        if h and macroHashAcct[h] then return macroHashAcct[h] end
    elseif action.isCharacter == false then
        if macroNameAcct[action.name] then return macroNameAcct[action.name] end
        if h and macroHashAcct[h] then return macroHashAcct[h] end
        if h and macroHashChar[h] then return macroHashChar[h] end
    else
        if macroNameAcct[action.name] then return macroNameAcct[action.name] end
        if macroNameChar[action.name] then return macroNameChar[action.name] end
        if h and macroHashAcct[h] then return macroHashAcct[h] end
        if h and macroHashChar[h] then return macroHashChar[h] end
    end
    return nil
end

local function BuildMountCache()
    local cache = {}
    if not C_MountJournal then return cache end
    local n = C_MountJournal.GetNumDisplayedMounts() or 0
    for i = 1, n do
        local _, _, _, _, _, _, _, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if mountID then cache[mountID] = i end
    end
    return cache
end

local function BuildFlyoutCache()
    local cache = {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return cache end
    local numTabs = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for tab = 1, numTabs do
        local tabInfo = C_SpellBook.GetSpellBookSkillLineInfo(tab)
        if tabInfo then
            for i = tabInfo.itemIndexOffset + 1, tabInfo.itemIndexOffset + tabInfo.numSpellBookItems do
                local itemInfo = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if itemInfo and itemInfo.itemType == Enum.SpellBookItemType.Flyout then
                    cache[itemInfo.actionID] = i
                end
            end
        end
    end
    return cache
end

local function PlaceActionImpl(slot, action)
    if not action or not action.type then return false end

    ClearCursor()

    local t = action.type
    local id = action.id

    if t == "spell" then
        if not id or not IsPlayerSpell(id) then return false end
        C_Spell.PickupSpell(id)

    elseif t == "item" then
        if not id then return false end
        C_Item.PickupItem(id)

    elseif t == "macro" then
        local macroIdx = NS.FindMacroIndex(action)
        if macroIdx then
            PickupMacro(macroIdx)
        elseif action.name then
            PickupMacro(action.name)
        else
            return false
        end

    elseif t == "mount" then
        if not id or not C_MountJournal then return false end
        if id == 0 or id == 0xFFFFFFF then
            C_MountJournal.Pickup(0)
        else
            local displayIndex = mountCache and mountCache[id]
            if displayIndex then
                C_MountJournal.Pickup(displayIndex)
            else
                local _, spellID = C_MountJournal.GetMountInfoByID(id)
                if spellID then
                    C_Spell.PickupSpell(spellID)
                else
                    return false
                end
            end
        end

    elseif t == "toy" then
        if not id or not C_ToyBox then return false end
        C_ToyBox.PickupToyBoxItem(id)

    elseif t == "flyout" then
        if not id then return false end
        local spellbookIdx = flyoutCache and flyoutCache[id]
        if not spellbookIdx then return false end
        C_SpellBook.PickupSpellBookItem(spellbookIdx, Enum.SpellBookSpellBank.Player)

    elseif t == "equipmentset" then
        if not action.name or not C_EquipmentSet then return false end
        local setID = C_EquipmentSet.GetEquipmentSetID(action.name)
        if not setID then return false end
        C_EquipmentSet.PickupEquipmentSet(setID)

    elseif t == "summonpet" then
        if not id or not C_PetJournal then return false end
        C_PetJournal.PickupPet(id)

    else
        return false
    end

    if GetCursorInfo() then
        PlaceAction(slot)
        ClearCursor()
        return true
    end

    ClearCursor()
    return false
end

local function PlaceActionByType(slot, action)
    local ok, result = pcall(PlaceActionImpl, slot, action)
    if not ok then
        ClearCursor()
        NS.Warn("Place error (slot " .. slot .. "): " .. tostring(result))
        return false
    end
    return result
end

local SAFETY_MAX = 10

local function PlaceWithRetry(slot, action, attempt, callback)
    attempt = attempt or 1

    if attempt > SAFETY_MAX then
        if callback then callback(false) end
        return
    end

    if PlaceActionByType(slot, action) then
        if callback then callback(true) end
        return
    end

    if attempt < NS.RETRY_MAX then
        C_Timer.After(NS.RETRY_INTERVAL, function()
            if InCombatLockdown() then
                if callback then callback(false) end
                return
            end
            PlaceWithRetry(slot, action, attempt + 1, callback)
        end)
    else
        if callback then callback(false) end
    end
end

local function ClearSlot(slot)
    ClearCursor()
    PickupAction(slot)
    ClearCursor()
end

local LEAVE_SLOT_UNTOUCHED = "skip"

local function SlotAction(preset, slot, bar)
    if preset.barFilters and preset.barFilters[bar] == false then return LEAVE_SLOT_UNTOUCHED end
    local action = preset.actions[slot]
    if not action then return nil end
    local fk = NS.TYPE_MAP[action.type]
    if fk and preset.filters and preset.filters[fk] == false then return nil end
    return action
end

function NS.GetAffectedSpecialBars(preset)
    if not preset or not preset.barFilters then return nil end

    local affected = nil
    for bar = 7, 12 do
        if preset.barFilters[bar] ~= false then
            local slotMin = (bar - 1) * NS.SLOTS_PER_BAR + 1
            local slotMax = bar * NS.SLOTS_PER_BAR
            local affects = false

            if preset.actions then
                for slot = slotMin, slotMax do
                    local action = preset.actions[slot]
                    if action then
                        local fk = NS.TYPE_MAP[action.type]
                        if not (fk and preset.filters and preset.filters[fk] == false) then
                            affects = true
                            break
                        end
                    end
                end
            end

            if not affects and not preset.preserveLayout then
                for slot = slotMin, slotMax do
                    if GetActionInfo(slot) then affects = true; break end
                end
            end

            if affects then
                affected = affected or {}
                affected[#affected + 1] = bar
            end
        end
    end
    return affected
end

function NS.ApplyPreset(preset)
    if not NS.CanModifyBars() then return end

    if not preset or not preset.actions then
        NS.Warn("Preset has no actions to restore.")
        return
    end

    mountCache = BuildMountCache()
    flyoutCache = BuildFlyoutCache()
    BuildMacroCaches()

    local placed = 0
    local skipped = 0
    local pending = 1

    local function onComplete()
        pending = pending - 1
        if pending > 0 then return end

        mountCache = nil
        flyoutCache = nil
        macroNameAcct, macroNameChar = nil, nil
        macroHashAcct, macroHashChar = nil, nil

        if placed == 0 and skipped == 0 then
            NS.Print("Applied '" .. preset.name .. "' (no matching actions)")
        elseif skipped == 0 then
            NS.Print("Applied '" .. preset.name .. "' (" .. placed .. " actions)")
        else
            NS.Print("Applied '" .. preset.name .. "' — " .. placed .. " placed, " .. skipped .. " skipped (unavailable)")
        end
    end

    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local bar = math.ceil(slot / NS.SLOTS_PER_BAR)
        local outcome = SlotAction(preset, slot, bar)

        if outcome == nil then
            if not preset.preserveLayout then ClearSlot(slot) end
        elseif outcome ~= LEAVE_SLOT_UNTOUCHED then
            pending = pending + 1
            PlaceWithRetry(slot, outcome, 1, function(success)
                if success then placed = placed + 1
                else skipped = skipped + 1 end
                onComplete()
            end)
        end
    end

    onComplete()
end
