local AddonName, NS = ...

----------------------------------------------------------------------
-- Per-apply lookup caches. Built once at the start of ApplyPreset
-- and reused across all 132 slots (including retries) so a preset with
-- N mounts on a maxed-collector account doesn't do N × 500 journal scans.
----------------------------------------------------------------------
local mountCache = nil   -- [mountID] = displayIndex
local flyoutCache = nil  -- [flyoutID] = spellbookIndex

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

----------------------------------------------------------------------
-- Place a single action into a slot by type. Returns true on success.
-- Caller wraps in pcall (see PlaceActionByType) so an unexpected WoW
-- API error doesn't kill the whole apply loop.
----------------------------------------------------------------------
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
        PickupItem(id)

    elseif t == "macro" then
        local macroIdx = NS.FindMacroIndex(action)
        if not macroIdx then return false end
        PickupMacro(macroIdx)

    elseif t == "mount" then
        if not id or not C_MountJournal then return false end
        -- Random Favourite Mount uses sentinel ID
        if id == 0 or id == 0xFFFFFFF then
            C_MountJournal.Pickup(0)
        else
            local displayIndex = mountCache and mountCache[id]
            if displayIndex then
                C_MountJournal.Pickup(displayIndex)
            else
                -- Journal filter may have hidden the mount; fall back to its spell ID
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

----------------------------------------------------------------------
-- Place with retry (up to RETRY_MAX attempts, RETRY_INTERVAL apart)
----------------------------------------------------------------------
local SAFETY_MAX = 10  -- absolute ceiling even if RETRY_MAX is corrupted

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

----------------------------------------------------------------------
-- Clear a single slot
----------------------------------------------------------------------
local function ClearSlot(slot)
    ClearCursor()
    PickupAction(slot)
    ClearCursor()
end

----------------------------------------------------------------------
-- Decide what to do with a single slot. Three outcomes:
--   action  → place this action
--   "skip"  → leave the slot entirely alone (no place, no clear)
--   nil     → no action to place; caller may clear based on preserveLayout
--
-- "skip" is reserved for disabled bars: a user (or the legacy-preset
-- migration) opting out of an entire bar means "don't touch it", not
-- "wipe it". This is what makes the bars-9-11 migration safety hold —
-- a legacy preset whose barFilters[9-11] default to false will leave
-- form/dragonriding bars untouched even when preserveLayout is off.
----------------------------------------------------------------------
local function SlotAction(preset, slot, bar)
    if preset.barFilters and preset.barFilters[bar] == false then return "skip" end
    local action = preset.actions[slot]
    if not action then return nil end
    local fk = NS.TYPE_MAP[action.type]
    if fk and preset.filters and preset.filters[fk] == false then return nil end
    return action
end

----------------------------------------------------------------------
-- Returns a list of bar numbers (9-11) that this preset would visibly
-- modify on apply, or nil if none. A bar counts as "modified" when its
-- filter is enabled AND either the preset has actions that would
-- actually be placed (passing category filters) OR preserveLayout is
-- off and the current bar has any actions to clear. No-op clears
-- (empty preset slots + empty current slots) and category-filtered
-- slots do not trigger the warning — false positives train users to
-- click through every popup.
----------------------------------------------------------------------
function NS.GetAffectedSpecialBars(preset)
    if not preset or not preset.barFilters then return nil end

    local affected = nil
    for bar = 9, NS.BAR_COUNT do
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

----------------------------------------------------------------------
-- Apply a full preset. Combat-guarded; does not show any UI. Callers
-- that need a form-bar confirmation popup go through
-- NS.RequestApplyPreset (UI layer).
----------------------------------------------------------------------
function NS.ApplyPreset(preset)
    if not NS.CanModifyBars() then return end

    if not preset or not preset.actions then
        NS.Warn("Preset has no actions to restore.")
        return
    end

    -- Populate caches for this apply (cleared at the end so the journal
    -- and spellbook can refilter freely afterwards).
    mountCache = BuildMountCache()
    flyoutCache = BuildFlyoutCache()

    local placed = 0
    local skipped = 0
    local pending = 1  -- sentinel: prevents early summary during loop

    local function onComplete()
        pending = pending - 1
        if pending > 0 then return end

        mountCache = nil
        flyoutCache = nil

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

        if outcome == "skip" then
            -- Bar disabled — leave the slot exactly as it is
        elseif outcome then
            pending = pending + 1
            PlaceWithRetry(slot, outcome, 1, function(success)
                if success then placed = placed + 1
                else skipped = skipped + 1 end
                onComplete()
            end)
        elseif not preset.preserveLayout then
            ClearSlot(slot)
        end
    end

    -- Release sentinel — if all callbacks already fired, this prints the summary
    onComplete()
end
