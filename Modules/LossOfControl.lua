local ADDON_NAME, TAF = ...

local LossOfControl = TAF:RegisterModule("LossOfControl")
local frame = CreateFrame("Frame", "TAF_LossOfControlFrame")

-- Track active CC states to prevent duplicate triggering
local activeStates = {
    STUNNED = false,
    FEARED = false,
    INCAPACITATED = false,
    DISARMED = false
}

-- Comprehensive Known CC Spell Lookup (all lowercase)
local CC_SPELLS = {
    -- Stuns
    ["hammer of justice"] = "STUNNED",
    ["kidney shot"] = "STUNNED",
    ["cheap shot"] = "STUNNED",
    ["bash"] = "STUNNED",
    ["intercept stun"] = "STUNNED",
    ["concussion blow"] = "STUNNED",
    ["charge stun"] = "STUNNED",
    ["war stomp"] = "STUNNED",
    ["pounce"] = "STUNNED",
    ["impact"] = "STUNNED",
    ["blackout"] = "STUNNED",
    ["tidal charm"] = "STUNNED",
    ["pyroclasm"] = "STUNNED",
    ["mace stun effect"] = "STUNNED",
    ["revenge stun"] = "STUNNED",

    -- Fears
    ["psychic scream"] = "FEARED",
    ["howl of terror"] = "FEARED",
    ["fear"] = "FEARED",
    ["intimidating shout"] = "FEARED",
    ["scare beast"] = "FEARED",
    ["seduction"] = "FEARED",
    ["terrify"] = "FEARED",
    ["panic"] = "FEARED",
    ["bellowing roar"] = "FEARED",
    ["frightening shout"] = "FEARED",

    -- Incapacitates / Disorients / Sleeps / Confused
    ["polymorph"] = "INCAPACITATED",
    ["polymorph: pig"] = "INCAPACITATED",
    ["polymorph: turtle"] = "INCAPACITATED",
    ["sap"] = "INCAPACITATED",
    ["gouge"] = "INCAPACITATED",
    ["blind"] = "INCAPACITATED",
    ["freezing trap"] = "INCAPACITATED",
    ["freezing trap effect"] = "INCAPACITATED",
    ["repentance"] = "INCAPACITATED",
    ["sleep"] = "INCAPACITATED",
    ["wyvern sting"] = "INCAPACITATED",
    ["scatter shot"] = "INCAPACITATED",
    ["reckless charge"] = "INCAPACITATED",
    ["hibernate"] = "INCAPACITATED",
    ["shackle undead"] = "INCAPACITATED",

    -- Disarms
    ["disarm"] = "DISARMED",
    ["riposte"] = "DISARMED"
}

-- Dispatch LOC Alert with Druid Form Guard
local function TriggerAlert(alertType)
    if not alertType then return end

    -- Druid Stance Guard: Only announce if in Bear Form / Dire Bear Form
    if TAF.playerClass == "DRUID" and not TAF.Utils.IsDruidBearForm() then
        return
    end

    local rawTarget = (TAF.Utils and TAF.Utils.GetUnitFullName and TAF.Utils.GetUnitFullName("target")) or UnitName("target")
    local targetName = TAF.Utils.SafeString(rawTarget, nil)
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")

    if alertType == "DISARMED" then
        TAF.Announcer:SendDisarmAlert(targetName, raidIcon)
    else
        TAF.Announcer:SendLossOfControlAlert(alertType, targetName, raidIcon)
    end
end

-- 1. Modern C_LossOfControl API Handler (Official replacement for CLEU LOC tracking)
local function OnLossOfControlAdded(eventIndex)
    if not C_LossOfControl or not C_LossOfControl.GetActiveLossOfControlData then return end
    local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, eventIndex)
    if not ok or not data or TAF.Utils.IsSecret(data) then return end

    local locType = TAF.Utils.SafeString(data.locType, "")
    local spellName = TAF.Utils.SafeString(data.name, "")
    if spellName == "" and data.spellID and not TAF.Utils.IsSecret(data.spellID) then
        if C_Spell and C_Spell.GetSpellName then
            local okName, name = pcall(C_Spell.GetSpellName, data.spellID)
            if okName then spellName = TAF.Utils.SafeString(name, "") end
        elseif GetSpellInfo then
            local okInfo, name = pcall(GetSpellInfo, data.spellID)
            if okInfo then spellName = TAF.Utils.SafeString(name, "") end
        end
    end
    local alertType = nil

    if locType == "STUN" or locType == "STUN_MECHANIC" then
        alertType = "STUNNED"
    elseif locType == "FEAR" or locType == "FEAR_MECHANIC" or locType == "CHARM" then
        alertType = "FEARED"
    elseif locType == "CONFUSE" or locType == "INCAPACITATE" or locType == "SLEEP" or locType == "PACIFY" then
        alertType = "INCAPACITATED"
    elseif locType == "DISARM" then
        alertType = "DISARMED"
    end

    if not alertType and spellName ~= "" then
        local lower = string.lower(spellName)
        alertType = CC_SPELLS[lower]
        if not alertType then
            if string.find(lower, "stun") then alertType = "STUNNED"
            elseif string.find(lower, "fear") or string.find(lower, "flee") then alertType = "FEARED"
            elseif string.find(lower, "incapacitat") or string.find(lower, "sleep") then alertType = "INCAPACITATED"
            elseif string.find(lower, "disarm") then alertType = "DISARMED" end
        end
    end

    if alertType and not activeStates[alertType] then
        activeStates[alertType] = true
        TriggerAlert(alertType)
    end
end

local function OnLossOfControlUpdate()
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount then
        local ok, count = pcall(C_LossOfControl.GetActiveLossOfControlDataCount)
        if ok and count and not TAF.Utils.IsSecret(count) and count == 0 then
            activeStates.STUNNED = false
            activeStates.FEARED = false
            activeStates.INCAPACITATED = false
            activeStates.DISARMED = false
        end
    end
end

-- 2. UI Error Message Fallback (Catching errors during cast/attack attempts while CC'd or Disarmed)
local function OnUIErrorMessage(message)
    local safeMsg = TAF.Utils.SafeString(message, "")
    if safeMsg == "" then return end

    local lower = string.lower(safeMsg)

    if string.find(lower, "while stunned") or string.find(lower, "you are stunned") then
        if not activeStates.STUNNED then
            activeStates.STUNNED = true
            TriggerAlert("STUNNED")
        end
    elseif string.find(lower, "while feared") or string.find(lower, "while fleeing") or string.find(lower, "you are fleeing") then
        if not activeStates.FEARED then
            activeStates.FEARED = true
            TriggerAlert("FEARED")
        end
    elseif string.find(lower, "while incapacitated") or string.find(lower, "while confused") or string.find(lower, "while asleep") or string.find(lower, "you are incapacitated") then
        if not activeStates.INCAPACITATED then
            activeStates.INCAPACITATED = true
            TriggerAlert("INCAPACITATED")
        end
    elseif string.find(lower, "must have a melee weapon equipped in the main hand") or string.find(lower, "while disarmed") or string.find(lower, "you are disarmed") then
        if TAF.Utils.HasMeleeWeaponEquipped() and not activeStates.DISARMED then
            activeStates.DISARMED = true
            TriggerAlert("DISARMED")
        end
    end
end

local function OnEvent(self, event, arg1, ...)
    if not TAF.isEnabled then return end

    if event == "LOSS_OF_CONTROL_ADDED" then
        OnLossOfControlAdded(arg1)
    elseif event == "LOSS_OF_CONTROL_UPDATE" then
        OnLossOfControlUpdate()
    elseif event == "UI_ERROR_MESSAGE" then
        local message = type(arg1) == "string" and arg1 or ...
        OnUIErrorMessage(message)
    end
end

function LossOfControl:OnInitialize()
    wipe(activeStates)
end

function LossOfControl:OnEnable()
    pcall(frame.RegisterEvent, frame, "LOSS_OF_CONTROL_ADDED")
    pcall(frame.RegisterEvent, frame, "LOSS_OF_CONTROL_UPDATE")
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
    local testType = locType or "STUNNED"
    TAF:Print("Simulating Loss of Control: |cffFFFFFF%s|r", testType)
    TriggerAlert(testType)
end

function LossOfControl:SimulateDisarm()
    TAF:Print("Simulating Disarm...")
    TriggerAlert("DISARMED")
end
