local ADDON_NAME, TAF = ...

local LossOfControl = TAF:RegisterModule("LossOfControl")
local frame = CreateFrame("Frame")

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

    local targetName = (TAF.Utils and TAF.Utils.GetUnitFullName and TAF.Utils.GetUnitFullName("target")) or UnitName("target")
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")

    if alertType == "DISARMED" then
        TAF.Announcer:SendDisarmAlert(targetName, raidIcon)
    else
        TAF.Announcer:SendLossOfControlAlert(alertType, targetName, raidIcon)
    end
end

-- 1. Combat Log Aura Detection (100% un-tainted, fires immediately on aura application)
local function OnCombatLogEvent()
    if not TAF.isEnabled then return end

    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          arg12, arg13, arg14 = CombatLogGetCurrentEventInfo()

    if destGUID ~= TAF.playerGUID then
        return
    end

    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
        local spellID = arg12
        local spellName = arg13

        if spellName then
            local lowerName = string.lower(spellName)
            local alertType = CC_SPELLS[lowerName]

            -- Check for generic patterns
            if not alertType then
                if string.find(lowerName, "stun") then
                    alertType = "STUNNED"
                elseif string.find(lowerName, "fear") or string.find(lowerName, "flee") or string.find(lowerName, "horror") then
                    alertType = "FEARED"
                elseif string.find(lowerName, "incapacitat") or string.find(lowerName, "sleep") or string.find(lowerName, "polymorph") then
                    alertType = "INCAPACITATED"
                elseif string.find(lowerName, "disarm") then
                    alertType = "DISARMED"
                end
            end

            if alertType and not activeStates[alertType] then
                activeStates[alertType] = true
                TriggerAlert(alertType)
            end
        end
    elseif subevent == "SPELL_AURA_REMOVED" then
        local spellName = arg13
        if spellName then
            local lowerName = string.lower(spellName)
            local alertType = CC_SPELLS[lowerName]
            if alertType then
                activeStates[alertType] = false
            end
        end
    end
end

-- 2. Aura Scanner (UNIT_AURA for player)
local function ScanAuras()
    if TAF.playerClass == "DRUID" and not TAF.Utils.IsDruidBearForm() then
        return
    end

    local index = 1
    while true do
        local name
        if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
            local auraData = C_UnitAuras.GetDebuffDataByIndex("player", index)
            if not auraData then break end
            name = auraData.name
        elseif UnitDebuff then
            local debuffName = UnitDebuff("player", index)
            if not debuffName then break end
            name = debuffName
        else
            break
        end

        if name then
            local lowerName = string.lower(name)
            local alertType = CC_SPELLS[lowerName]

            if not alertType then
                if string.find(lowerName, "disarm") or string.find(lowerName, "riposte") then
                    alertType = "DISARMED"
                end
            end

            if alertType and not activeStates[alertType] then
                activeStates[alertType] = true
                TriggerAlert(alertType)
            end
        end

        index = index + 1
    end
end

-- 3. UI Error Message Fallback (Catching errors during cast/attack attempts while CC'd or Disarmed)
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

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "UNIT_AURA" and arg1 == "player" then
        ScanAuras()
    elseif event == "UI_ERROR_MESSAGE" then
        local message = type(arg1) == "string" and arg1 or ...
        OnUIErrorMessage(message)
    end
end

function LossOfControl:OnInitialize()
    wipe(activeStates)
end

function LossOfControl:OnEnable()
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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
