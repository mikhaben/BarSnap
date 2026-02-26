local AddonName, NS = ...

----------------------------------------------------------------------
-- Place a single action into a slot by type
-- Returns true on success
----------------------------------------------------------------------
local function PlaceActionByType(slot, action)
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
        C_MountJournal.Pickup(id)

    elseif t == "toy" then
        if not id or not C_ToyBox then return false end
        C_ToyBox.PickupToyBoxItem(id)

    elseif t == "flyout" then
        if not id then return false end
        -- Flyout IDs are not spell IDs; use spellbook lookup
        local numTabs = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
        local placed = false
        for tab = 1, numTabs do
            local tabInfo = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if tabInfo then
                for i = tabInfo.itemIndexOffset + 1, tabInfo.itemIndexOffset + tabInfo.numSpellBookItems do
                    local bookType = C_SpellBook.GetSpellBookItemType(i, Enum.SpellBookSpellBank.Player)
                    if bookType == Enum.SpellBookItemType.Flyout then
                        local flyoutID = C_SpellBook.GetSpellBookItemFlyoutID(i, Enum.SpellBookSpellBank.Player)
                        if flyoutID == id then
                            C_SpellBook.PickupSpellBookItem(i, Enum.SpellBookSpellBank.Player)
                            placed = true
                            break
                        end
                    end
                end
            end
            if placed then break end
        end

    else
        return false
    end

    -- If cursor has something, place it
    if GetCursorInfo() then
        PlaceAction(slot)
        ClearCursor()
        return true
    end

    ClearCursor()
    return false
end

----------------------------------------------------------------------
-- Place with retry (up to RETRY_MAX attempts, RETRY_INTERVAL apart)
----------------------------------------------------------------------
local SAFETY_MAX = 10  -- absolute ceiling even if RETRY_MAX is corrupted

local function PlaceWithRetry(slot, action, attempt, callback)
    attempt = attempt or 1

    -- Safety: hard cap to prevent infinite loops
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
-- Apply a full preset
----------------------------------------------------------------------
function NS.ApplyPreset(preset)
    -- Guard: combat
    if not NS.CanModifyBars() then return end

    -- Guard: nil/empty preset
    if not preset or not preset.actions then
        NS.Warn("Preset has no actions to restore.")
        return
    end

    local actionCount = NS.CountActions(preset.actions)
    if actionCount == 0 then
        NS.Warn("Preset '" .. (preset.name or "?") .. "' is empty — nothing to restore.")
        return
    end

    local placed = 0
    local skipped = 0
    local pending = 1  -- sentinel: prevents early summary during loop

    -- Map action.type → filter key
    local filterKey = {
        spell  = "spells",
        item   = "items",
        macro  = "macros",
        mount  = "mounts",
        toy    = "toys",
        flyout = "spells",
    }

    local function onComplete()
        pending = pending - 1
        if pending > 0 then return end

        -- Summary
        if placed == 0 and skipped == 0 then
            NS.Print("Applied '" .. preset.name .. "' (no matching actions)")
        elseif skipped == 0 then
            NS.Print("Applied '" .. preset.name .. "' (" .. placed .. " actions)")
        else
            NS.Print("Applied '" .. preset.name .. "' — " .. placed .. " placed, " .. skipped .. " skipped (unavailable)")
        end
    end

    for slot = NS.SLOT_MIN, NS.SLOT_MAX do
        local action = preset.actions[slot]

        if action == nil then
            -- No action for this slot
            if not preset.preserveLayout then
                ClearSlot(slot)
            end
        else
            -- Check category filter
            local fk = filterKey[action.type]
            if fk and preset.filters and preset.filters[fk] == false then
                -- Category disabled, skip
            else
                -- Attempt to place
                pending = pending + 1
                PlaceWithRetry(slot, action, 1, function(success)
                    if success then
                        placed = placed + 1
                    else
                        skipped = skipped + 1
                    end
                    onComplete()
                end)
            end
        end
    end

    -- Release sentinel — if all callbacks already fired, this prints the summary
    onComplete()
end
