local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

local TICK_INTERVAL = 2.0

local parent = PlayerFrame

local ticker = CreateFrame("Frame", "MyEnergyTicker", UIParent)
ticker:SetSize(32, 32)
ticker:SetPoint("CENTER", parent, "CENTER", 35, -5)

local ICON_PATH = "Interface\\AddOns\\ZakajiPoints\\ejaculation"

-- Greyscale base
local iconGrey = ticker:CreateTexture(nil, "BACKGROUND")
iconGrey:SetAllPoints()
iconGrey:SetTexture(ICON_PATH)
iconGrey:SetDesaturated(true)

-- Colored overlay
local iconColor = ticker:CreateTexture(nil, "ARTWORK")
iconColor:SetAllPoints()
iconColor:SetTexture(ICON_PATH)
iconColor:SetDesaturated(false)

ticker:Hide()

local lastTickTime = GetTime()
local lastEnergy   = UnitPower("player", Enum.PowerType.Energy) or 0

local function IsTickerEnabled()
    return ZakajiBallsDB and ZakajiBallsDB.energyTicker ~= false
end

local function UpdateIcon()
    if not IsTickerEnabled() then
        ticker:Hide()
        return
    end

    ticker:Show()

    local now = GetTime()
    local dt  = now - lastTickTime
    if dt < 0 then dt = 0 end
    if dt > TICK_INTERVAL then dt = TICK_INTERVAL end

    local progress   = dt / TICK_INTERVAL
    local greyAlpha  = 1 - progress
    local colorAlpha = progress

    iconGrey:SetAlpha(greyAlpha)
    iconColor:SetAlpha(colorAlpha)
end

ZakajiEnergy_UpdateIcon = UpdateIcon

ticker:SetScript("OnUpdate", function(self, elapsed)
    UpdateIcon()
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_POWER_FREQUENT") -- TBCA energy updates

f:SetScript("OnEvent", function(_, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        ZakajiBallsDB = ZakajiBallsDB or {}
        if ZakajiBallsDB.energyTicker == nil then
            ZakajiBallsDB.energyTicker = true
        end

        lastTickTime = GetTime()
        lastEnergy   = UnitPower("player", Enum.PowerType.Energy)
        UpdateIcon()
        return
    end

    if not IsTickerEnabled() then
        ticker:Hide()
        return
    end

    if unit ~= "player" or powerType ~= "ENERGY" then
        return
    end

    local current = UnitPower("player", Enum.PowerType.Energy)
    local diff    = current - lastEnergy

    if diff > 0 then
        lastTickTime = GetTime()
    end

    lastEnergy = current
end)
