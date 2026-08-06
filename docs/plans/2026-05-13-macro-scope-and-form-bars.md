# Macro Scope Fix + Form Bar Capture + Restore Warning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the character-specific macro restore bug, add capture/restore for druid form bars and the dragonriding bar, and warn the user before a restore would modify a special bar.

**Architecture:** Three independent surgical changes to existing modules — no new files. (1) Add an `isCharacter` marker to scanned macros and route lookup through the correct pool first. (2) Bump `SLOT_MAX` from 96 to 132 and `BAR_COUNT` from 8 to 11 so slot ranges 97-132 (Bear / Moonkin / Dragonriding pages) are scanned and restored exactly like existing bars. (3) Wrap `ApplyPreset` with a `confirmed` flag and a `StaticPopupDialog` shown when the apply would write to or clear slots 97-132.

**Tech Stack:** Lua 5.1 (WoW sandbox), WoW Retail Interface 120000 (Midnight), no test framework — verification is manual in-game reproduction.

---

## Background

**Bug 1 — character macros:** `Engine/Scanner.lua:35-41` stores macros as `{type="macro", name=name}` with no marker for general-vs-character pool. `GetMacroIndexByName` (Blizzard FrameXML) iterates from index 1 upward and returns the first match — so account-pool macros always win over character-pool macros when names collide. Users with same-named macros in both pools have their character-macro slots silently overwritten by the general one on restore. Reported by Felidae_Kree, KitNova, Rubyurek. Pool sizes are `MAX_ACCOUNT_MACROS` and `MAX_CHARACTER_MACROS` (Blizzard globals); the code uses these directly so it survives any Blizzard-side bump to the limits.

**Bug 2 — druid form bars:** Reported by Calmcacil. `Constants.lua:5` sets `SLOT_MAX = 96`, so only bars 1-8 (slots 1-96) are scanned. In current Retail, bar 1's secure-template `page` attribute is re-targeted to higher slot ranges based on state-driver conditions (`[bonusbar:N]`, `[shapeshift]`, `[bonusbar:5]`). For druids: Bear → page 9 (slots 97-108), Moonkin/Travel → page 10 (slots 109-120). For everyone on a flying mount: Skyriding → page 11 (slots 121-132). This is Blizzard FrameXML's slot model — verifiable at runtime via `GetActionInfo(slot)` while in the relevant form. ElvUI's class paging defaults (`ElvUI/Game/Shared/Defaults/Profile.lua:3294`) mirror it; we cite them as the easiest-to-read summary, not as the authority.

**Slot range decision:** Scan and restore up to slot 132 (inclusive). Override / Vehicle / Possess bars use runtime indices (`GetOverrideBarIndex` / `GetVehicleBarIndex`) and contain encounter-specific or vehicle-specific actions — out of scope per user direction.

**Migration constraint:** Existing presets stored in `BarSnapDB` / `BarSnapCharDB` have `barFilters` with keys `[1..8]` only. The existing migration in `Core.lua:101-105` sets any missing key in `[1..NS.BAR_COUNT]` to `true`. If we naively bump `BAR_COUNT` to 11, the next login migration sets `barFilters[9..11] = true` for every legacy preset, and the next restore silently clears those slots. Therefore migration for the new keys must default to `false` (legacy presets opt-in only) — new presets created after this change get `true` from `DEFAULT_BAR_FILTERS`.

---

## File Structure

No new files. Six existing files touched:

- `Constants.lua` — bump `SLOT_MAX` to 132, `BAR_COUNT` to 11, extend `DEFAULT_BAR_FILTERS`, add `BAR_LABELS` table.
- `Engine/Scanner.lua` — record `isCharacter` on scanned macro entries.
- `Engine/Validator.lua` — refactor `FindMacroIndex` to search the action's pool first; route `ValidateAction` macros through it.
- `Engine/Restore.lua` — add `PresetAffectsSpecialBars`, gate `ApplyPreset` behind a `confirmed` flag with the new popup.
- `Core.lua` — split bar-filter migration so legacy presets default new keys (9-11) to `false`.
- `UI/EditorFrame.lua` — use `BAR_LABELS` when rendering bar checkbox labels. Define the `BARSNAP_CONFIRM_FORM_BARS` popup alongside the existing `BARSNAP_DELETE_PRESET`.

---

## Task 1: Fix character-specific macro restore

**Files:**
- Modify: `Engine/Scanner.lua:35-41`
- Modify: `Engine/Validator.lua:72-75, 109-114`

- [ ] **Step 1: Record `isCharacter` on scanned macros**

Replace `Engine/Scanner.lua:35-41`:

```lua
        elseif actionType == "macro" then
            if id and id > 0 then  -- WoW bug: id=0 for broken/empty macros
                local name = GetMacroInfo(id)
                if name then
                    scanBuffer[slot] = {
                        type = "macro",
                        name = name,
                        isCharacter = id > MAX_ACCOUNT_MACROS,
                    }
                end
            end
```

Rationale: `id` is the macro index returned by `GetActionInfo`. `MAX_ACCOUNT_MACROS` is a Blizzard global (currently 120). Any index above that range belongs to the character pool (per `wow-addon-dev/apis.md:169` and the Blizzard `GetMacroIndexByName` source).

- [ ] **Step 2: Refactor `FindMacroIndex` to search the correct pool, only falling back for legacy entries**

Replace `Engine/Validator.lua:109-114` with:

```lua
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
        -- Legacy: no scope marker, search both account-first
        for i = 1, charEnd do
            if GetMacroInfo(i) == action.name then return i end
        end
        return nil
    end
end
```

- [ ] **Step 3: Route `ValidateAction` macros through `FindMacroIndex`**

Replace `Engine/Validator.lua:72-75`:

```lua
    elseif t == "macro" then
        return NS.FindMacroIndex(action) ~= nil
```

Reason: `ValidateAction` previously called `GetMacroIndexByName` directly, which has the same general-first bug. Both call sites must agree, otherwise validation can report "available" for a name that resolves to a different macro on restore.

- [ ] **Step 4: Manual repro — verify the fix**

In-game test (any character with macros):

1. `/run print(MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS)` — note the values; the code uses the globals, so any current Retail values are fine.
2. Create a general macro named `BSTest` (Macro UI → General Macros).
3. Create a character-specific macro also named `BSTest` (Macro UI → Character Specific Macros). Give the two macros visibly different icons.
4. Place general `BSTest` on bar slot 1, character `BSTest` on bar slot 2.
5. `/bs` → Save preset "MacroTest".
6. Drag the actions off slots 1 and 2 (or apply a different preset).
7. Apply "MacroTest". Slot 1 must show the general icon, slot 2 must show the character icon.
8. `/reload` between save and apply — confirm the SavedVariables round-trip preserves `isCharacter`.
9. Regression: character-only macro `BSCharOnly` (no general dup) — save, apply, must restore.
10. **Deliberate-no-fallback check:** save preset, then delete the character `BSTest` macro. Apply preset. Slot 2 should report a skipped action in the chat summary — NOT silently get the general macro placed in it. (This is the new safer behavior — the user explicitly saved a character-pool macro, so we don't substitute the account one.)
11. Legacy regression: any preset saved before this change (macros stored without `isCharacter`) — apply it, account-pool macros must still place correctly.

- [ ] **Step 5: Commit**

```bash
git add Engine/Scanner.lua Engine/Validator.lua
git commit -m "fix: restore character-specific macros correctly

Macros were stored by name only. GetMacroIndexByName returns the first
match by iteration order, so account-pool macros always won over
character-pool macros when names collided, silently overwriting
character-specific bar placements on restore.

Scanner now records isCharacter on each macro entry. FindMacroIndex
searches only the marked pool for new entries (so a missing character
macro is reported skipped rather than substituted with the account
namesake), and falls back to both-pools account-first for legacy
entries that have no marker."
```

---

## Task 2: Capture and restore form / dragonriding bars (slots 97-132)

**Files:**
- Modify: `Constants.lua:1-10, 34-37`
- Modify: `Core.lua:98-106`
- Modify: `UI/EditorFrame.lua:332-336`

- [ ] **Step 1: Extend slot and bar constants**

In `Constants.lua`, replace lines 1-10 plus the `DEFAULT_BAR_FILTERS` block (lines 34-37) so the file now reads:

```lua
local AddonName, NS = ...

-- Slot range:
-- bars 1-8 = slots 1-96 (regular).
-- bars 9-11 = slots 97-132 (form / dragonriding pages used by druid Bear,
--   druid Moonkin/Travel, and the Skyriding bonus bar on flying mounts).
-- Override / Vehicle / Possess bars use runtime indices and are out of scope.
NS.SLOT_MIN = 1
NS.SLOT_MAX = 132
NS.BAR_COUNT = 11
NS.SLOTS_PER_BAR = 12
```

Replace the `DEFAULT_BAR_FILTERS` block:

```lua
-- Default bar filters (all enabled for newly created presets;
-- legacy presets default 9-11 to false during migration — see Core.lua)
NS.DEFAULT_BAR_FILTERS = {
    [1] = true, [2] = true, [3] = true, [4]  = true,
    [5] = true, [6] = true, [7] = true, [8]  = true,
    [9] = true, [10] = true, [11] = true,
}

-- Display labels for the bar-filter checkboxes. Generic "Bar N" is fine for
-- 1-8; the special bars get descriptive labels so users know what they control.
NS.BAR_LABELS = {
    [9]  = "Bar 9 — Bear",
    [10] = "Bar 10 — Moonkin / Travel",
    [11] = "Bar 11 — Dragonriding",
}
```

- [ ] **Step 2: Split bar-filter migration so legacy presets opt out of form bars**

Replace `Core.lua:98-106` with:

```lua
            if type(preset.barFilters) ~= "table" then
                preset.barFilters = NS.DeepCopy(NS.DEFAULT_BAR_FILTERS)
            else
                -- Existing bars: missing key means default-enabled
                for bar = 1, 8 do
                    if preset.barFilters[bar] == nil then
                        preset.barFilters[bar] = true
                    end
                end
                -- New form / dragonriding bars: legacy presets opt out by
                -- default so an upgrade never silently clears slots 97-132
                for bar = 9, NS.BAR_COUNT do
                    if preset.barFilters[bar] == nil then
                        preset.barFilters[bar] = false
                    end
                end
            end
```

Sanity check: a brand-new preset created after this change goes through `NS.DeepCopy(NS.DEFAULT_BAR_FILTERS)` (see `MainFrame.lua` save path), so it gets `[9..11]=true`. Only the migration path treats missing keys as `false`.

- [ ] **Step 3: Use `BAR_LABELS` in the editor's bar checkbox list**

Replace `UI/EditorFrame.lua:332-336` (the `barItems` build):

```lua
    -- Bar filter items
    local barItems = {}
    for i = 1, NS.BAR_COUNT do
        barItems[i] = { key = i, label = NS.BAR_LABELS[i] or ("Bar " .. i) }
    end
```

Nothing else in `EditorFrame` needs to change — the height calculation already derives `barRows = math.ceil(NS.BAR_COUNT / 2)` at line 389, and the 2-column layout in `CreateTwoColCheckboxes` already handles odd counts (an 11-item list lays out as 5 rows of 2 plus a trailing single).

- [ ] **Step 4: Manual repro — verify slot model then capture/restore form bars**

Requires a druid character (or any character with a Skyriding mount for the dragonriding check).

1. **Verify the slot model holds on this client** (this guards against any future Blizzard patch reshuffling pages):
   - In humanoid: `/run print(GetActionInfo(1), GetActionInfo(97), GetActionInfo(109), GetActionInfo(121))`
   - Shift into Bear Form, place a junk spell on the visible slot 1, then `/run print(GetActionInfo(97))` — must return the placed spell. If it returns `nil` and another slot is populated instead, the slot map has changed and the rest of this PR needs review before proceeding.
   - Shift to Moonkin, place a junk spell on visible slot 1, then `/run print(GetActionInfo(109))` — must return the placed spell.
   - Mount a Skyriding mount, place a junk spell on visible slot 1, then `/run print(GetActionInfo(121))` — must return the placed spell.
2. Now the actual test. Without changing form, place a recognizable spell (e.g. `Wrath`) on visible main bar slot 1.
3. Shapeshift into Bear Form. Place a different spell (e.g. `Mangle`) on visible slot 1.
4. `/bs` → Save preset "DruidTest". Open the editor — confirm "Bar 9 — Bear" is present and checked by default for this new preset.
5. Shift back to humanoid. Wipe slot 1 absolute via `/run PickupAction(1); ClearCursor()`. Also wipe slot 97 the same way.
6. Apply "DruidTest" (the popup from Task 3 will appear — accept). `Wrath` must reappear at slot 1; shift into Bear and `Mangle` must be there.
7. Dragonriding regression: mount a Skyriding mount, place an action on the visible bar (slot 121), save preset, dismount, apply preset, remount — action must be there.
8. **Legacy preset regression:** open a preset that existed before this change. Confirm the new Bar 9/10/11 checkboxes are **unchecked**. Apply it — slots 97-132 must be untouched (verify with `/run print(GetActionInfo(97), GetActionInfo(109), GetActionInfo(121))` before and after).

- [ ] **Step 5: Commit**

```bash
git add Constants.lua Core.lua UI/EditorFrame.lua
git commit -m "feat: capture and restore druid form and dragonriding bars

Bumps SLOT_MAX to 132 and BAR_COUNT to 11 so the scanner and restore
loop now cover slots 97-132. In current Retail these slot ranges back
Bar 1 when paged to Bear (page 9 → 97-108), Moonkin/Travel (page 10 →
109-120), and Dragonriding (page 11 → 121-132).

Legacy presets default the three new bar filters to false at migration
time so upgrading never silently wipes a druid's form bars. New presets
default them on. The editor labels the three new checkboxes by form."
```

---

## Task 3: Warn before a restore would modify a special bar

**Files:**
- Modify: `Engine/Restore.lua:159-167` (gate `ApplyPreset`) plus a new helper above it
- Modify: `Core.lua:159-164` (close the popup on scope switch)
- Modify: `UI/EditorFrame.lua` — add `BARSNAP_CONFIRM_FORM_BARS` popup definition near line 189

- [ ] **Step 1: Add the affected-bar detection helper**

Add this function in `Engine/Restore.lua` immediately above the existing `function NS.ApplyPreset(preset)` (around line 155, before the comment header). The heuristic warns **only when something will actually change** — applying a preset that clears already-empty slots is silently fine:

```lua
----------------------------------------------------------------------
-- Returns a list of bar numbers (9-11) that this preset would visibly
-- modify on apply, or nil if none. A bar counts as "modified" when its
-- filter is enabled AND either the preset has actions in that slot range
-- (will write) OR preserveLayout is off and the current bar has any
-- actions to clear. No-op clears (empty preset slots + empty current
-- slots) do not trigger the warning — false positives train users to
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
                    if preset.actions[slot] then affects = true; break end
                end
            end

            if not affects and not preset.preserveLayout then
                -- Would clear current contents — only warn if there's anything to clear
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
```

- [ ] **Step 2: Gate `ApplyPreset` behind a `skipConfirm` flag, stashing preset identity**

Replace the `NS.ApplyPreset(preset)` signature and the first few lines (currently `Engine/Restore.lua:159-167`):

```lua
function NS.ApplyPreset(preset, skipConfirm)
    -- Guard: combat
    if not NS.CanModifyBars() then return end

    -- Guard: nil/empty preset
    if not preset or not preset.actions then
        NS.Warn("Preset has no actions to restore.")
        return
    end

    -- Special-bar confirmation (Bear, Moonkin/Travel, Dragonriding)
    if not skipConfirm then
        local affected = NS.GetAffectedSpecialBars(preset)
        if affected then
            local labels = {}
            for _, bar in ipairs(affected) do
                labels[#labels + 1] = NS.BAR_LABELS[bar] or ("Bar " .. bar)
            end
            local popup = StaticPopup_Show("BARSNAP_CONFIRM_FORM_BARS",
                preset.name or "?", table.concat(labels, ", "))
            if popup then
                -- Stash identity, not a raw reference: the preset could be
                -- deleted, renamed, or moved (scope switch) between Show and
                -- OnAccept. Re-resolve by (scope, name) at accept time and
                -- bail if the preset is gone.
                popup.data = {
                    scope = NS.GetActiveScope(),
                    name  = preset.name,
                }
            end
            return
        end
    end
```

The rest of `ApplyPreset` (the `actionCount` check and the slot loop) stays untouched.

- [ ] **Step 3: Close the popup when the user switches scope**

The popup's `OnAccept` re-resolves by `(scope, name)`, so a scope switch could leave a stale popup showing a different scope's preset. Replace `Core.lua:159-164` (`NS.SetActiveScope`):

```lua
function NS.SetActiveScope(scope)
    if not NS.charDb then return end
    NS.charDb.scope = scope
    NS.CloseEditor()
    StaticPopup_Hide("BARSNAP_CONFIRM_FORM_BARS")
    NS.RefreshMainFrame()
end
```

- [ ] **Step 4: Define the popup with name-based re-resolution**

In `UI/EditorFrame.lua`, immediately below the existing `StaticPopupDialogs["BARSNAP_DELETE_PRESET"]` block (after line 189), add:

```lua
----------------------------------------------------------------------
-- Confirm before applying a preset that would modify special bars
-- (Bear, Moonkin/Travel, Dragonriding). Text args:
--   1st %s = preset name
--   2nd %s = comma-separated bar labels
-- self.data is { scope, name } — we re-resolve the preset at OnAccept
-- time so deletion or rename between show and click doesn't apply the
-- wrong preset, and a stale apply is silently dropped.
----------------------------------------------------------------------
StaticPopupDialogs["BARSNAP_CONFIRM_FORM_BARS"] = {
    text = "Applying '%s' will modify: %s.\n\nContinue?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local data = self.data
        if not data or not data.name then return end
        if data.scope ~= NS.GetActiveScope() then return end
        for _, p in ipairs(NS.GetActivePresets()) do
            if p.name == data.name then
                NS.ApplyPreset(p, true)
                return
            end
        end
    end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
    preferredIndex = 3,
}
```

`text` uses sequential `%s` substitution — `StaticPopup_Show(name, sub1, sub2)` calls `format(text, sub1, sub2)`.

- [ ] **Step 5: Manual repro — confirm the popup fires and short-circuit works**

1. **Popup fires when preset writes to a special bar.** Use the "DruidTest" preset from Task 2 Step 4 (has slot 97 data). Apply it — popup must appear listing "Bar 9 — Bear". No → bars unchanged. Yes → Bear bar restored.
2. **Popup fires when clearing a populated special bar.** New preset (humanoid only, no form data, `preserveLayout=false`), but the druid's Bear bar currently has actions. Apply — popup must appear (the apply would clear non-empty Bear slots).
3. **Popup is silent on no-op clear** — the tightened heuristic case. Same humanoid-only preset, but absolute slots 97-132 are all currently empty. Apply — popup must NOT appear. The slots stay empty.
4. **PreserveLayout suppresses unnecessary warnings.** Humanoid-only preset with `preserveLayout` on (no slot 97-132 data, slots may be populated). Apply — popup must NOT appear (preserveLayout means no clearing).
5. **Regular presets are unaffected.** Apply any preset whose Bar 9/10/11 filters are disabled. Popup must NOT appear.
6. **Legacy preset regression.** Apply a preset saved before this PR — its Bar 9/10/11 filters are `false` after migration. Popup must NOT appear; behavior identical to pre-PR.
7. **ESC + No paths.** ESC dismisses the popup. No does nothing. Neither calls `ApplyPreset`.
8. **Combat ordering.** Enter combat, click Apply — the `CanModifyBars` warn fires first and no popup appears.
9. **Stale popup on delete.** Click Apply on a preset that would warn → popup appears. Without clicking Yes, open editor, delete that preset (delete confirmation flow). Now click Yes on the form-bar popup. Nothing should happen — the apply is silently dropped because re-resolution by name fails. (A short red-prefix warn message in chat is acceptable but not required; silence is also fine.)
10. **Stale popup on scope switch.** Click Apply on a preset in the Global scope → popup appears. Without clicking Yes, switch to Character scope via the scope toggle. The popup must close automatically (per Step 3's `StaticPopup_Hide` in `SetActiveScope`).

- [ ] **Step 6: Commit**

```bash
git add Engine/Restore.lua Core.lua UI/EditorFrame.lua
git commit -m "feat: warn before applying a preset that modifies special bars

Before writing to or clearing slots 97-132 (Bear, Moonkin/Travel,
Dragonriding), ApplyPreset now shows a confirmation popup listing the
affected bars. The check fires only when the apply will visibly change
something — preserveLayout-on presets with no form data, presets whose
bar 9-11 filters are off, legacy presets after migration, and presets
that would only clear already-empty slots all bypass it silently.

The popup stashes (scope, name) rather than a raw preset reference and
re-resolves on accept, so deletion or scope-switch between show and
click drops the apply safely. SetActiveScope also force-hides the
popup to keep it from operating on the wrong scope."
```

---

## Self-Review

**Spec coverage:**
- Macro scope bug → Task 1 ✓
- Druid form bar capture (Calmcacil) → Task 2 ✓
- Dragonriding bar capture → Task 2 ✓ (slot 121-132)
- Warning when restore would touch a special bar → Task 3 ✓
- Skip override/vehicle bars per user choice → noted in Background, SLOT_MAX caps at 132 ✓

**Placeholder scan:** No TBD / TODO / "appropriate" / "similar to" terms remain. All code blocks are complete and runnable.

**Type / name consistency:**
- `MAX_ACCOUNT_MACROS` / `MAX_CHARACTER_MACROS` — WoW globals, referenced consistently in `FindMacroIndex`.
- `NS.BAR_LABELS` defined in Task 2 Step 1, consumed in Task 2 Step 3 and Task 3 Step 2.
- `NS.GetAffectedSpecialBars` defined in Task 3 Step 1, consumed in Task 3 Step 2.
- `ApplyPreset(preset, skipConfirm)` signature change — only one call site exists today (`UI/PresetRow.lua:75`) and it passes nothing, so `skipConfirm=nil` → falsy on first click. The popup's `OnAccept` re-resolves the preset by `(scope, name)` and re-enters with `skipConfirm=true`.
- `isCharacter` field on macro actions — written by Scanner (Task 1 Step 1), read by `FindMacroIndex` (Task 1 Step 2). The branch on `isCharacter == true / false / nil` covers new character entries, new account entries, and legacy entries respectively.

**Reviewer feedback applied:**
- Popup re-entry race (critic #1, architect #6) — `popup.data` now holds `{scope, name}` and re-resolves at accept time. `SetActiveScope` hides the popup.
- Macro fallback policy (critic #9) — explicit `isCharacter` entries do **not** fall back to the other pool. Legacy entries still do, account-first, preserving old behavior.
- Popup false-positive (critic #4) — `GetAffectedSpecialBars` now requires actual data (preset OR current bar) before warning; no-op clears stay silent.
- Slot-model authority (critic #5) — Background reframes ElvUI as "easiest-to-read summary," and Task 2 Step 4.1 runs `GetActionInfo` for slots 97/109/121 in the actual forms as a runtime guard before trusting the plan.
- Param naming (architect #1) — `confirmed` → `skipConfirm`.
