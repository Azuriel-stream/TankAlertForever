local ADDON_NAME, TAF = ...

local AbilityAlerts = TAF:RegisterModule("AbilityAlerts")
local frame = CreateFrame("Frame", "TAF_AbilityAlertsFrame")

-- Track recent active casts to correlate with avoidance/failure events
local activeCast = nil
local CAST_EXPIRY_SECONDS = 1.5

local MISS_TYPE_MAP = {
    ["MISS"] = "MISSED",
    ["DODGE"] = "DODGED",
    ["PARRY"] = "PARRIED",
    ["BLOCK"] = "BLOCKED",
    ["RESIST"] = "RESISTED",
    ["ABSORB"] = "ABSORBED",
    ["IMMUNE"] = "IMMUNE",
    ["DEFLECT"] = "DEFLECTED",
    ["REFLECT"] = "REFLECTED",
}

-- 1. Track player casts of monitored abilities
local function OnSpellcastSent(unit, target, castGUID, spellID)
    if unit ~= "player" then return end
    if not TAF.isEnabled then return end

    local spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID)) or ""
    local abilityName = TAF.SpellData:FindAbility(TAF.playerClass, spellID, spellName)
    if not abilityName then return end

    -- Verify if player has enabled tracking for this specific ability
    if not TAF:IsAbilityTracked(TAF.playerClass, abilityName) then
        return
    end

    local cleanTarget = (target and target ~= "") and target or UnitName("target") or "Unknown Target"
    if string.find(cleanTarget, "-") then
        cleanTarget = string.match(cleanTarget, "([^-]+)")
    end

    activeCast = {
        abilityName = abilityName,
        target = cleanTarget,
        timestamp = GetTime(),
        castGUID = castGUID,
        spellID = spellID,
    }
end

-- 2. Floating combat text updates (MISS, DODGE, PARRY, BLOCK, RESIST, IMMUNE)
local function OnCombatTextUpdate(messageType)
    if not activeCast then return end
    if (GetTime() - activeCast.timestamp) > CAST_EXPIRY_SECONDS then
        activeCast = nil
        return
    end

    local mappedMiss = MISS_TYPE_MAP[messageType]
    if mappedMiss then
        local targetName = activeCast.target
        local raidIcon = TAF.Utils.GetRaidTargetToken("target")
        TAF.Announcer:SendAbilityAlert(activeCast.abilityName, mappedMiss, targetName, raidIcon)
        activeCast = nil
    end
end

-- 3. Formatted combat log text fallback (e.g. from COMBAT_LOG_MESSAGE in modern clients)
local function OnCombatLogMessage(message)
    if not message or type(message) ~= "string" or not activeCast then return end
    if (GetTime() - activeCast.timestamp) > CAST_EXPIRY_SECONDS then
        activeCast = nil
        return
    end

    local lower = string.lower(message)
    local missType = nil
    if string.find(lower, "resist") then
        missType = "RESISTED"
    elseif string.find(lower, "dodge") then
        missType = "DODGED"
    elseif string.find(lower, "parr") then
        missType = "PARRIED"
    elseif string.find(lower, "block") then
        missType = "BLOCKED"
    elseif string.find(lower, "miss") then
        missType = "MISSED"
    elseif string.find(lower, "immune") then
        missType = "IMMUNE"
    elseif string.find(lower, "deflect") then
        missType = "DEFLECTED"
    elseif string.find(lower, "reflect") then
        missType = "REFLECTED"
    end

    if missType then
        local targetName = activeCast.target
        local raidIcon = TAF.Utils.GetRaidTargetToken("target")
        TAF.Announcer:SendAbilityAlert(activeCast.abilityName, missType, targetName, raidIcon)
        activeCast = nil
    end
end

-- 4. UI Error Message Fallback (Immunity, range, facing)
local function OnUIErrorMessage(errorType, message)
    local errText = type(message) == "string" and message or (type(errorType) == "string" and errorType or "")
    if not activeCast or errText == "" then return end
    if (GetTime() - activeCast.timestamp) > CAST_EXPIRY_SECONDS then
        activeCast = nil
        return
    end

    local lower = string.lower(errText)
    local missType = nil
    if string.find(lower, "immune") then
        missType = "IMMUNE"
    elseif string.find(lower, "too close") or string.find(lower, "out of range") then
        missType = "OUT OF RANGE"
    elseif string.find(lower, "interrupted") then
        missType = "INTERRUPTED"
    end

    if missType then
        local targetName = activeCast.target
        local raidIcon = TAF.Utils.GetRaidTargetToken("target")
        TAF.Announcer:SendAbilityAlert(activeCast.abilityName, missType, targetName, raidIcon)
        activeCast = nil
    end
end

local function OnEvent(self, event, arg1, arg2, arg3, arg4)
    if not TAF.isEnabled then return end

    if event == "UNIT_SPELLCAST_SENT" then
        OnSpellcastSent(arg1, arg2, arg3, arg4)
    elseif event == "COMBAT_TEXT_UPDATE" then
        OnCombatTextUpdate(arg1)
    elseif event == "COMBAT_LOG_MESSAGE" then
        OnCombatLogMessage(arg1)
    elseif event == "UI_ERROR_MESSAGE" then
        OnUIErrorMessage(arg1, arg2)
    end
end

function AbilityAlerts:OnInitialize()
    activeCast = nil
end

function AbilityAlerts:OnEnable()
    frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    frame:RegisterEvent("COMBAT_TEXT_UPDATE")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    pcall(frame.RegisterEvent, frame, "COMBAT_LOG_MESSAGE")
    frame:SetScript("OnEvent", OnEvent)
end

function AbilityAlerts:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    activeCast = nil
end

-- Test Harness: Simulate an ability failure
function AbilityAlerts:SimulateMiss(abilityName, missType, targetName)
    local testAbility = abilityName or "Taunt"
    local testMiss = missType or "RESISTED"
    local testTarget = targetName or UnitName("target") or "Target Dummy"
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")

    TAF.Announcer:SendAbilityAlert(testAbility, testMiss, testTarget, raidIcon)
end
