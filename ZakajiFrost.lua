local addonName = ...
local FH = CreateFrame("Frame", addonName .. "Frame")

------------------------------------------------------------
-- Early exit if not a mage
------------------------------------------------------------

local _, playerClass = UnitClass("player")



local db

local function InitFrostDB()
    ZakajiBallsDB = ZakajiBallsDB or {}
    db = ZakajiBallsDB
    -- default if missing
    if db.frostTracker == nil then
        db.frostTracker = true
    end
end
if playerClass ~= "MAGE" then
    FH:Hide()
    return
end
------------------------------------------------------------
-- Config
------------------------------------------------------------

local ICON_SIZE                  = 24
local ICON_SPACING               = 4
local NUM_ICONS                  = 6
local BORDER_SIZE                = 2
local UPDATE_INTERVAL            = 0.10

------------------------------------------------------------
-- Spell / item IDs (2.4.3)
------------------------------------------------------------

local SPELL_FROST_NOVA_ID        = 122
local SPELL_FREEZE_ID            = 33395 -- Water Elemental: Freeze
local SPELL_FROSTBITE_ID         = 12494 -- Frostbite proc
local SPELL_POLYMORPH_ID         = 118
local SPELL_ICE_BARRIER_ID       = 11426
local SPELL_ARCANE_INTELLECT_ID  = 1459
local SPELL_ARCANE_BRILLIANCE_ID = 23028
local SPELL_DAMPEN_MAGIC_ID      = 604
local SPELL_MAGE_ARMOR_ID        = 6117
local SPELL_ICE_ARMOR_ID         = 7302

------------------------------------------------------------
-- Localized names
------------------------------------------------------------

local SPELL_FROST_NOVA           = GetSpellInfo(SPELL_FROST_NOVA_ID)
local SPELL_FREEZE               = GetSpellInfo(SPELL_FREEZE_ID)
local SPELL_FROSTBITE            = GetSpellInfo(SPELL_FROSTBITE_ID)
local SPELL_POLYMORPH            = GetSpellInfo(SPELL_POLYMORPH_ID)
local SPELL_ICE_BARRIER          = GetSpellInfo(SPELL_ICE_BARRIER_ID)
local SPELL_ARCANE_INTELLECT     = GetSpellInfo(SPELL_ARCANE_INTELLECT_ID)
local SPELL_ARCANE_BRILLIANCE    = GetSpellInfo(SPELL_ARCANE_BRILLIANCE_ID)
local SPELL_DAMPEN_MAGIC         = GetSpellInfo(SPELL_DAMPEN_MAGIC_ID)
local SPELL_MAGE_ARMOR           = GetSpellInfo(SPELL_MAGE_ARMOR_ID)
local SPELL_ICE_ARMOR            = GetSpellInfo(SPELL_ICE_ARMOR_ID)

------------------------------------------------------------
-- Frame + icons
------------------------------------------------------------

FH:SetSize(ICON_SIZE * NUM_ICONS + ICON_SPACING * (NUM_ICONS - 1), ICON_SIZE)
-- Horizontal bar, centered, 1/3 under the top (2/3 screen height)
FH:SetPoint("CENTER", UIParent, "TOP", 0, -GetScreenHeight() / 2 * 1.17)

FH.icons = {}

local function CreateIcon(index)
    local f = CreateFrame("Frame", addonName .. "Icon" .. index, FH)
    f:SetSize(ICON_SIZE, ICON_SIZE)

    if index == 1 then
        f:SetPoint("CENTER", FH, "CENTER",
            -(ICON_SIZE + ICON_SPACING) * (NUM_ICONS - 1) / 2, 0)
    else
        f:SetPoint("LEFT", FH.icons[index - 1], "RIGHT", ICON_SPACING, 0)
    end

    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- black border
    f.border = f:CreateTexture(nil, "BORDER")
    f.border:SetPoint("TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
    f.border:SetPoint("BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)
    f.border:SetColorTexture(0, 0, 0, 1)

    -- duration text
    f.timeText = f:CreateFontString(nil, "OVERLAY")
    f.timeText:SetDrawLayer("OVERLAY", 7)
    f.timeText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    f.timeText:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.timeText:SetTextColor(1, 1, 1, 1)
    f.timeText:SetText("")


    f:SetAlpha(0.15)

    return f
end

for i = 1, NUM_ICONS do
    FH.icons[i] = CreateIcon(i)
end

------------------------------------------------------------
-- Icon textures
------------------------------------------------------------

FH.icons[1].tex:SetTexture("Interface\\Icons\\spell_frost_frostnova")    -- Freeze/Fnova/Frostbite
FH.icons[2].tex:SetTexture("Interface\\Icons\\spell_nature_polymorph")   -- Sheep
FH.icons[3].tex:SetTexture("Interface\\Icons\\spell_ice_lament")         -- Ice Barrier
FH.icons[4].tex:SetTexture("Interface\\Icons\\inv_misc_gem_ruby_01")     -- Mana Ruby
FH.icons[5].tex:SetTexture("Interface\\Icons\\spell_holy_magicalsentry") -- Buff check
FH.icons[6].tex:SetTexture("Interface\\Icons\\spell_arcane_arcane02")    -- Spellsteal

------------------------------------------------------------
-- Helpers: auras & items
------------------------------------------------------------

local function HasBuff(unit, spellName)
    if not spellName then return false end

    local i = 1
    while true do
        local name = UnitBuff(unit, i)
        if not name then break end
        if name == spellName then
            return true
        end
        i = i + 1
    end

    return false
end

local function HasBuffAny(unit, ...)
    for i = 1, select("#", ...) do
        local spellName = select(i, ...)
        if spellName and HasBuff(unit, spellName) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Condition checks
------------------------------------------------------------

-- 1. Target in pet Freeze / Frost Nova / Frostbite, with duration
-- Freeze/Frost Nova/Frostbite scan
local function GetFreezeData(spellName)
    if not spellName then return false end

    local i = 1
    while true do
        -- here 'exp' is actually the expiration timestamp
        local name, _, _, _, _, exp = UnitDebuff("target", i)
        if not name then break end
        if name == spellName and exp and exp > 0 then
            return true, exp
        end
        i = i + 1
    end
    return false
end

local function CheckFrozenTarget()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        return false
    end

    local has, exp = GetFreezeData(SPELL_FREEZE)
    if has then return true, exp end

    has, exp = GetFreezeData(SPELL_FROST_NOVA)
    if has then return true, exp end

    has, exp = GetFreezeData(SPELL_FROSTBITE)
    if has then return true, exp end

    return false
end

-- 2. Polymorph duration on target (expiration only)
local function CheckSheepOnTarget()
    local function HasSheepOnUnit(unit)
        if not UnitExists(unit) or not UnitCanAttack("player", unit) then
            return false
        end

        local i = 1
        while true do
            -- on this client, the sixth return is expiration time
            local name, _, _, _, _, exp = UnitDebuff(unit, i)
            if not name then break end
            if name == SPELL_POLYMORPH and exp and exp > 0 then
                return true, exp
            end
            i = i + 1
        end

        return false
    end

    -- Priority: target, focus, arena1-3
    local units = { "target", "focus", "arena1", "arena2", "arena3" }
    for _, unit in ipairs(units) do
        local has, exp = HasSheepOnUnit(unit)
        if has then
            return true, exp
        end
    end

    return false
end

-- 3. Missing Ice Barrier AND Ice Barrier off cooldown
local function CheckIceBarrierReadyMissing()
    if SPELL_ICE_BARRIER and HasBuff("player", SPELL_ICE_BARRIER) then
        return false
    end

    local start, duration, enabled = GetSpellCooldown(SPELL_ICE_BARRIER_ID)
    if enabled == 0 then
        return false
    end

    if start == 0 or duration == 0 then
        return true
    end

    return false
end

-- 4. Current mana at least 1100 below max AND Mana Ruby available
local function CheckManaRuby()
    local maxMana = UnitPowerMax("player", 0)
    local curMana = UnitPower("player", 0)
    if maxMana - curMana < 1100 then
        return false
    end

    -- Spell is known?
    local spellName = GetSpellInfo("Conjure Mana Ruby") -- or use ID if you prefer
    if not spellName then
        return false
    end

    -- Conjure is just a sanity check; the gem itself is used via item,
    -- so just assume "available" once you have the spell and let you decide
    -- if the icon is worth pressing.
    return true
end

-- 5. Missing AI/AB, Dampen Magic, and Ice or Mage Armor (if any missing => show)
local function CheckMissingBuffs()
    local missingIntellect = not HasBuffAny("player",
        SPELL_ARCANE_INTELLECT, SPELL_ARCANE_BRILLIANCE)
    local missingDampen = not HasBuff("player", SPELL_DAMPEN_MAGIC)
    local missingArmor = not HasBuffAny("player",
        SPELL_MAGE_ARMOR, SPELL_ICE_ARMOR)

    return missingIntellect or missingDampen or missingArmor
end

-- 6. Spellstealable buff on target (approximate with Magic buffs)
local function CheckSpellsteal()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        return false
    end

    local i = 1
    while true do
        local name, _, _, debuffType = UnitBuff("target", i)
        if not name then break end
        if debuffType == "Magic" then
            return true
        end
        i = i + 1
    end

    return false
end

------------------------------------------------------------
-- Time formatting helper
------------------------------------------------------------

local function FormatTime(sec)
    if not sec or sec <= 0 then
        return ""
    end
    -- always integer seconds
    return tostring(math.floor(sec + 0.5))
end

------------------------------------------------------------
-- Update loop
------------------------------------------------------------

local elapsedSince = 0

local function UpdateIcon()
    if not db then InitFrostDB() end
    if db.frostTracker then
        FH:Show()
    else
        FH:Hide()
    end
end

ZakajiFrost_UpdateIcon = UpdateIcon

-- in OnUpdate
FH:SetScript("OnUpdate", function(self, elapsed)
    if not db then InitFrostDB() end
    if not db or not db.frostTracker then return end
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < UPDATE_INTERVAL then return end
    elapsedSince = 0

    -- 1. Freeze / Frost Nova / Frostbite
    do
        local has, exp = CheckFrozenTarget()
        if has and exp then
            FH.icons[1]:SetAlpha(1)
            local remaining = math.max(0, exp - GetTime())
            FH.icons[1].timeText:SetText(FormatTime(remaining))
        else
            FH.icons[1]:SetAlpha(0.15)
            FH.icons[1].timeText:SetText("")
        end
    end

    -- 2. Polymorph on target
    do
        local has, exp = CheckSheepOnTarget()
        if has and exp then
            FH.icons[2]:SetAlpha(1)
            local remaining = math.max(0, exp - GetTime())
            FH.icons[2].timeText:SetText(FormatTime(remaining))
        else
            FH.icons[2]:SetAlpha(0.15)
            FH.icons[2].timeText:SetText("")
        end
    end

    -- 3. Ice Barrier missing & ready
    if CheckIceBarrierReadyMissing() then
        FH.icons[3]:SetAlpha(1)
    else
        FH.icons[3]:SetAlpha(0.15)
    end
    -- make sure no stray text
    FH.icons[3].timeText:SetText("")

    -- 4. Mana Ruby usage
    if CheckManaRuby() then
        FH.icons[4]:SetAlpha(1)
    else
        FH.icons[4]:SetAlpha(0.15)
    end
    FH.icons[4].timeText:SetText("")

    -- 5. Missing buffs (AI/AB, Dampen, Armor)
    if CheckMissingBuffs() then
        FH.icons[5]:SetAlpha(1)
    else
        FH.icons[5]:SetAlpha(0.15)
    end
    FH.icons[5].timeText:SetText("")

    -- 7. Spellsteal opportunity
    if CheckSpellsteal() then
        FH.icons[6]:SetAlpha(1)
    else
        FH.icons[6]:SetAlpha(0.15)
    end
    FH.icons[6].timeText:SetText("")
end)
FH:RegisterEvent("PLAYER_ENTERING_WORLD")


FH:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        InitFrostDB()
        UpdateIcon()
    end
end)
