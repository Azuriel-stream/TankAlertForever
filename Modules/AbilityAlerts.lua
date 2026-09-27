local ADDON_NAME, TAF = ...

local AbilityAlerts = TAF:RegisterModule("AbilityAlerts")
local frame = CreateFrame("Frame")

-- Event Dispatcher
local function OnCombatLogEvent()
    if not TAF.isEnabled then return end

    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          arg12, arg13, arg14, arg15 = CombatLogGetCurrentEventInfo()

    -- Filter: Only process events originated by the player
    if sourceGUID ~= TAF.playerGUID then
        return
    end

    if subevent == "SPELL_MISSED" then
        local spellID = arg12
        local spellName = arg13
        local spellSchool = arg14
        local missType = arg15

        if not missType then return end

        local abilityName = TAF.SpellData:FindAbility(TAF.playerClass, spellID, spellName)
        if not abilityName then return end

        -- Verify if player has enabled tracking for this specific ability
        if not TAF:IsAbilityTracked(TAF.playerClass, abilityName) then
            return
        end

        -- Determine Target Raid Icon
        local raidIcon = TAF.Utils.GetRaidTargetTokenByGUID(destGUID)

        -- Clean up destination name (remove realm name if cross-realm mob/player)
        local targetName = destName
        if targetName and string.find(targetName, "-") then
            targetName = string.match(targetName, "([^-]+)")
        end

        TAF.Announcer:SendAbilityAlert(abilityName, missType, targetName, raidIcon)
    end
end

function AbilityAlerts:OnInitialize()
    -- Initialized
end

function AbilityAlerts:OnEnable()
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", OnCombatLogEvent)
end

function AbilityAlerts:OnDisable()
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", nil)
end

-- Test Harness: Simulate an ability failure
function AbilityAlerts:SimulateMiss(abilityName, missType, targetName)
    local testAbility = abilityName or "Taunt"
    local testMiss = missType or "RESISTED"
    local testTarget = targetName or UnitName("target") or "Target Dummy"
    local raidIcon = TAF.Utils.GetRaidTargetToken("target")

    TAF.Announcer:SendAbilityAlert(testAbility, testMiss, testTarget, raidIcon)
end
