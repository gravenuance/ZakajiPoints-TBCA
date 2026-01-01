local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

local defaults = {
    sound = true,
    attachToNameplate = false,
    energyTicker = true,
}

local db

local function InitDB()
    ZakajiBallsDB = ZakajiBallsDB or {}
    for k, v in pairs(defaults) do
        if ZakajiBallsDB[k] == nil then
            ZakajiBallsDB[k] = v
        end
    end
    db = ZakajiBallsDB
    if GetCVar("nameplateMaxDistance") ~= "41" then
        SetCVar("nameplateMaxDistance", "41")
    end
end

local NUM_POINTS = 5
local SIZE = 28
local GAP = 6
local SOUND_ID = 1332
local BASE_SCALE = 1.0
local NAMEPLATE_SCALE = 0.7
local frame = CreateFrame("Frame", "ZakajiPointsFrame", UIParent)

local function PositionFrame()
    frame:ClearAllPoints()

    if not db then InitDB() end

    local wantNameplate = db.attachToNameplate

    if wantNameplate and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local plate = C_NamePlate.GetNamePlateForUnit("target")

        if not plate or not UnitExists("target") then
            frame:Hide()

            return
        end

        local anchor = plate.UnitFrame or plate

        frame:SetScale(NAMEPLATE_SCALE)
        frame:SetPoint("TOP", anchor, "BOTTOM", 0, 20)
        frame:Show()
        return
    end

    frame:SetScale(BASE_SCALE)
    frame:Show()

    local screenH = UIParent:GetHeight()
    local offsetY = -screenH * (1 / 5)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
end

frame:SetSize((SIZE * NUM_POINTS) + (GAP * (NUM_POINTS - 1)), SIZE)

local points = {}
local fills  = {}

for i = 1, NUM_POINTS do
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(SIZE, SIZE)
    if i == 1 then
        bg:SetPoint("LEFT", frame, "LEFT", 0, 0)
    else
        bg:SetPoint("LEFT", points[i - 1], "RIGHT", GAP, 0)
    end
    bg:SetTexture("Interface\\AddOns\\ZakajiPoints\\testicles")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    points[i] = bg

    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints(bg)
    fill:SetTexture("Interface\\AddOns\\ZakajiPoints\\testicles")
    fill:SetVertexColor(1, 0.8, 0, 1)
    fill:Hide()
    fills[i] = fill
end

local lastCP = 0

local function UpdateComboPoints()
    if not UnitExists("target") or UnitIsDead("target") then
        for i = 1, NUM_POINTS do
            fills[i]:Hide()
        end
        lastCP = 0
        return
    end

    local cp = GetComboPoints("player", "target") or 0

    for i = 1, NUM_POINTS do
        if i <= cp then
            fills[i]:Show()
        else
            fills[i]:Hide()
        end
    end


    if db and db.sound and cp == NUM_POINTS and lastCP ~= NUM_POINTS then
        PlaySound(SOUND_ID)
    end

    lastCP = cp
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        PositionFrame()
        UpdateComboPoints()
    elseif event == "UNIT_POWER_UPDATE" then
        if arg1 == "player" then
            UpdateComboPoints()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitDB()
        PositionFrame()
        UpdateComboPoints()
    end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_POWER_UPDATE")


SLASH_ZAKAJIBALLS1 = "/balls"
SlashCmdList.ZAKAJIBALLS = function(msg)
    if not db then InitDB() end
    msg = msg and msg:lower() or ""

    if msg == "sound" then
        db.sound = not db.sound
        print("ZakajiBalls: sound is now " .. (db.sound and "ON" or "OFF"))
    elseif msg == "nameplate" then
        db.attachToNameplate = not db.attachToNameplate
        print("ZakajiBalls: attachToNameplate is now " .. (db.attachToNameplate and "ON" or "OFF"))
        PositionFrame()
    elseif msg == "ticker" then
        db.energyTicker = not db.energyTicker
        if ZakajiEnergy_UpdateIcon then
            ZakajiEnergy_UpdateIcon()
        end
        print("ZakajiBalls: energy ticker is now " .. (db.energyTicker and "ON" or "OFF"))
    else
        print("ZakajiBalls commands:")
        print("/balls sound - toggle sound on 5 combo points")
        print("/balls nameplate - toggle attaching under target nameplate")
        print("/balls ticker - toggle energy ticker display")
    end
end
