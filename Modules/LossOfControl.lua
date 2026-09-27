local ADDON_NAME, TAF = ...

local LossOfControl = TAF:RegisterModule("LossOfControl")
local frame = CreateFrame("Frame")

-- Track active CC states to prevent duplicate triggering
local activeStates = {
    STUN = false,
    FEAR = false,
    INCAPACITATE = false,
    DISARM = false
}

-- Map C_LossOfControl locTypes to our internal alert types
local LOC_TYPE_MAP = {
    ["STUN"] = "STUNNED",
    ["STUN_MECHANIC"] = "STUNNED",
    ["FEAR"] = "FEARED",
    ["FEAR_MECHANIC"] = "FEARED",
    ["CHARM"] = "FEARED",
    ["CONFUSE"] = "INCAPACITATED",
    ["PACIFY"] = "INCAPACITATED",
    ["PACIFYSILENCE"] = "INCAPACITATED",
    ["DISARM"] = "DISARMED"
}

-- Dispatch LOC Alert with Druid Form Guard
local function TriggerAlert(alertType)
    if not alertType then return end

    -- Druid Stance Guard: Only announce if in Bear Form / Dire Bear Form
    if TAF.playerClass == "DRUID" and not TAF.Utils.IsDruidBearForm() then
        return
    end

    local targetName = UnitName("target")
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")

    if alertType == "DISARMED" then
        TAF.Announcer:SendDisarmAlert(targetName, raidIcon)
    else
        TAF.Announcer:SendLossOfControlAlert(alertType, targetName, raidIcon)
    end
end

-- 1. Modern C_LossOfControl API Handler
local function CheckLossOfControlAPI()
    if not C_LossOfControl or not C_LossOfControl.GetNumEvents then
        return false
    end

    local numEvents = C_LossOfControl.GetNumEvents()
    if not numEvents or numEvents == 0 then
        wipe(activeStates)
        return true
    end

    for i = 1, numEvents do
        local eventInfo = C_LossOfControl.GetEventInfo(i)
        if eventInfo and eventInfo.locType then
            local alertType = LOC_TYPE_MAP[eventInfo.locType]
            if alertType and not activeStates[eventInfo.locType] then
                activeStates[eventInfo.locType] = true
                TriggerAlert(alertType)
            end
        end
    end
    return true
end

-- 2. Fallback / Complementary Aura Scanner (UNIT_AURA)
local function ScanAuras()
    if TAF.playerClass == "DRUID" and not TAF.Utils.IsDruidBearForm() then
        return
    end

    -- Support both modern C_UnitAuras and classic UnitDebuff
    local index = 1
    while true do
        local name, debuffType, spellID
        if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
            local auraData = C_UnitAuras.GetDebuffDataByIndex("player", index)
            if not auraData then break end
            name = auraData.name
            debuffType = auraData.dispelName
            spellID = auraData.spellId
        elseif UnitDebuff then
            local debuffName, _, _, dType, _, _, _, _, _, sID = UnitDebuff("player", index)
            if not debuffName then break end
            name = debuffName
            debuffType = dType
            spellID = sID
        else
            break
        end

        -- Check Disarm debuffs
        if name then
            local lowerName = string.lower(name)
            if lowerName == "disarm" or lowerName == "riposte" or string.find(lowerName, "disarm") then
                if not activeStates.DISARM then
                    activeStates.DISARM = true
                    TriggerAlert("DISARMED")
                end
            end
        end

        index = index + 1
    end
end

-- 3. UI Error Message Fallback (Catching errors during cast attempts while CC'd or Disarmed)
local function OnUIErrorMessage(message)
    if not message or type(message) ~= "string" then return end

    local lower = string.lower(message)

    if string.find(lower, "while stunned") then
        TriggerAlert("STUNNED")
    elseif string.find(lower, "while feared") or string.find(lower, "while fleeing") then
        TriggerAlert("FEARED")
    elseif string.find(lower, "while incapacitated") or string.find(lower, "while confused") then
        TriggerAlert("INCAPACITATED")
    elseif string.find(lower, "must have a melee weapon equipped in the main hand") then
        -- Verify weapon is actually equipped in slot 16 to confirm it's a Disarm
        if TAF.Utils.HasMeleeWeaponEquipped() then
            TriggerAlert("DISARMED")
        end
    end
end

local function OnEvent(self, event, arg1, ...)
    if not TAF.isEnabled then return end

    if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
        CheckLossOfControlAPI()
    elseif event == "UNIT_AURA" and arg1 == "player" then
        ScanAuras()
    elseif event == "UI_ERROR_MESSAGE" then
        -- In modern WoW, UI_ERROR_MESSAGE passes (errorType, message)
        local message = type(arg1) == "string" and arg1 or ...
        OnUIErrorMessage(message)
    end
end

function LossOfControl:OnInitialize()
    wipe(activeStates)
end

function LossOfControl:OnEnable()
    -- Register modern LOC events if available
    pcall(function()
        frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
        frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
    end)
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:SetScript("OnEvent", OnEvent)
end

function LossOfControl:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    wipe(activeStates)
end

-- Test Harness
function LossOfControl:SimulateLOC(locType)
    TriggerAlert(locType or "STUNNED")
end

function LossOfControl:SimulateDisarm()
    TriggerAlert("DISARMED")
end
