local ADDON_NAME, TAF = ...

local AbilityAlerts = TAF:RegisterModule("AbilityAlerts")
local frame = CreateFrame("Frame", "TAF_AbilityAlertsFrame")

-- Track recent active casts to correlate with avoidance/failure events
local activeCast = nil
local CAST_EXPIRY_SECONDS = 1.5

local MISS_TYPE_MAP = {
    ["MISS"]    = "MISSED",
    ["DODGE"]   = "DODGED",
    ["PARRY"]   = "PARRIED",
    ["BLOCK"]   = "BLOCKED",
    ["RESIST"]  = "RESISTED",
    ["IMMUNE"]  = "IMMUNE",
    ["DEFLECT"] = "DEFLECTED",
    ["REFLECT"] = "REFLECTED",
    ["EVADE"]   = "EVADED",
}

-- 1. Track player cast intent of monitored abilities
local function OnSpellcastSent(unit, target, castGUID, spellID)
    if unit ~= "player" then return end
    if not TAF.isEnabled then return end

    -- Handle both modern (unit, target, castGUID, spellID) and legacy (unit, spell, rank, target) signatures
    local resolvedSpellID = type(spellID) == "number" and spellID or (type(castGUID) == "number" and castGUID or nil)
    local rawSpellName = type(target) == "string" and target or nil
    local spellName = ""

    if resolvedSpellID then
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, resolvedSpellID)
            if ok and type(info) == "table" and info.name then
                spellName = TAF.Utils.SafeString(info.name, "")
            elseif ok and type(info) == "string" then
                spellName = TAF.Utils.SafeString(info, "")
            end
        end
        if spellName == "" and C_Spell and C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, resolvedSpellID)
            if ok and name then
                spellName = TAF.Utils.SafeString(name, "")
            end
        end
        if spellName == "" and GetSpellInfo then
            local ok, name = pcall(GetSpellInfo, resolvedSpellID)
            if ok and name then
                spellName = TAF.Utils.SafeString(name, "")
            end
        end
    elseif rawSpellName and rawSpellName ~= "" then
        spellName = rawSpellName
    end

    local abilityName = TAF.SpellData:FindAbility(TAF.playerClass, resolvedSpellID, spellName)
    if not abilityName then return end

    -- Verify if player has enabled tracking for this specific ability
    if not TAF:IsAbilityTracked(TAF.playerClass, abilityName) then
        return
    end

    -- Target resolution with secret-value protection (WoW 12.0+ compatibility)
    local safeTarget = TAF.Utils.SafeString(target, nil)
    if not safeTarget or safeTarget == "" or safeTarget == spellName or safeTarget:lower() == "target" then
        safeTarget = TAF.Utils.GetSafeUnitName("target", nil)
    end

    local cleanTarget = safeTarget
    if cleanTarget and cleanTarget ~= "" and cleanTarget:lower() ~= "target" then
        if string.find(cleanTarget, "-") then
            cleanTarget = string.match(cleanTarget, "([^-]+)") or cleanTarget
        end
    else
        cleanTarget = nil
    end

    local castRaidIcon = TAF.Utils.GetRaidTargetToken("target")
    if not castRaidIcon or castRaidIcon == "" then
        castRaidIcon = TAF.Utils.GetRaidTargetToken("mouseover")
    end

    activeCast = {
        abilityName = abilityName,
        target = cleanTarget,
        raidIcon = castRaidIcon,
        timestamp = GetTime(),
        castGUID = TAF.Utils.SafeString(castGUID, nil),
        spellID = resolvedSpellID,
    }
end

-- 2. Detect combat avoidance on target via UNIT_COMBAT
local function OnUnitCombat(unit, action, modifier, amount, damageType)
    if not activeCast then return end

    -- Filter: Only inspect combat feedback occurring on the target, focus, or mouseover
    if unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then
        return
    end

    local now = GetTime()
    if (now - activeCast.timestamp) > CAST_EXPIRY_SECONDS then
        activeCast = nil
        return
    end

    local safeAction = TAF.Utils.SafeString(action, "")

    -- If damage landed successfully, the strike did not miss or fail
    if safeAction == "WOUND" or safeAction == "DAMAGE" then
        activeCast = nil
        return
    end

    local mappedMiss = MISS_TYPE_MAP[safeAction]
    if mappedMiss then
        local targetName = TAF.Utils.SafeString(activeCast.target, nil)
        if targetName and (targetName == "" or targetName:lower() == "target") then
            targetName = nil
        end

        if not targetName and unit then
            targetName = TAF.Utils.GetSafeUnitName(unit, nil)
        end

        if not targetName then
            targetName = TAF.Utils.GetSafeUnitName("target", nil)
        end

        if not targetName or targetName == "" or targetName:lower() == "target" then
            targetName = "Target"
        end

        -- Resolve raid icon: check active unit first, fallback to cached castRaidIcon or current target/mouseover/focus
        local raidIcon = TAF.Utils.GetRaidTargetToken(unit)
        if not raidIcon or raidIcon == "" then
            if activeCast.raidIcon and activeCast.raidIcon ~= "" then
                raidIcon = activeCast.raidIcon
            else
                raidIcon = TAF.Utils.GetRaidTargetToken("target")
                if not raidIcon or raidIcon == "" then
                    raidIcon = TAF.Utils.GetRaidTargetToken("mouseover")
                    if not raidIcon or raidIcon == "" then
                        raidIcon = TAF.Utils.GetRaidTargetToken("focus")
                    end
                end
            end
        end

        TAF.Announcer:SendAbilityAlert(activeCast.abilityName, mappedMiss, targetName, raidIcon, activeCast.spellID)
        activeCast = nil
    end
end

-- 3. UI Error Message Fallback (Immunity, range, facing)
local function OnUIErrorMessage(errorType, message)
    local errText = TAF.Utils.SafeString(message, "")
    if errText == "" then
        errText = TAF.Utils.SafeString(errorType, "")
    end
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
        local raidIcon = activeCast.raidIcon
        if not raidIcon or raidIcon == "" then
            raidIcon = TAF.Utils.GetRaidTargetToken("target")
        end
        TAF.Announcer:SendAbilityAlert(activeCast.abilityName, missType, targetName, raidIcon, activeCast.spellID)
        activeCast = nil
    end
end

local function OnEvent(self, event, arg1, arg2, ...)
    if not TAF.isEnabled then return end

    if event == "UNIT_SPELLCAST_SENT" then
        OnSpellcastSent(arg1, arg2, ...)
    elseif event == "UNIT_COMBAT" then
        OnUnitCombat(arg1, arg2, ...)
    elseif event == "UI_ERROR_MESSAGE" then
        OnUIErrorMessage(arg1, arg2)
    end
end

function AbilityAlerts:OnInitialize()
    activeCast = nil
end

function AbilityAlerts:OnEnable()
    frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    frame:RegisterEvent("UNIT_COMBAT")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:SetScript("OnEvent", OnEvent)
end

function AbilityAlerts:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    activeCast = nil
end

-- Test Harness: Simulate an ability failure
function AbilityAlerts:SimulateMiss(abilityName, missType, targetName)
    local testAbility = TAF.Utils.SafeString(abilityName, "Taunt")
    local testMiss = TAF.Utils.SafeString(missType, "RESISTED")
    local testTarget = TAF.Utils.SafeString(targetName, nil)
    if not testTarget or testTarget == "" or testTarget:lower() == "target" then
        testTarget = TAF.Utils.GetSafeUnitName("target", "Target Dummy")
    end
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")
    if not raidIcon or raidIcon == "" then
        raidIcon = "{rt8}"
    end

    local testSpellID = nil
    if TAF.SpellData and TAF.SpellData.Abilities and TAF.SpellData.Abilities[TAF.playerClass] then
        local entry = TAF.SpellData.Abilities[TAF.playerClass][testAbility]
        if entry and entry.spellIDs and entry.spellIDs[1] then
            testSpellID = entry.spellIDs[1]
        end
    end

    TAF.Announcer:SendAbilityAlert(testAbility, testMiss, testTarget, raidIcon, testSpellID)
end
