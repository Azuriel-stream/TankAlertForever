local ADDON_NAME, TAF = ...

TAF.Utils = {}

-- Determine Current Group Composition
function TAF.Utils.GetGroupType()
    if IsInRaid and IsInRaid() then
        return "RAID"
    elseif IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return "NONE"
end

-- Check Raid Leader or Assist Privileges
function TAF.Utils.IsRaidLeaderOrAssist()
    if not (IsInRaid and IsInRaid()) then
        return false
    end
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    end
    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
        return true
    end
    return false
end

-- Resolve Raid Target Icon Token ({rt1} to {rt8})
function TAF.Utils.GetRaidTargetToken(unit)
    if not unit or not GetRaidTargetIndex then return "" end
    local index = GetRaidTargetIndex(unit)
    if index and index >= 1 and index <= 8 then
        return string.format("{rt%d}", index)
    end
    return ""
end

-- Match destination GUID against common target units to fetch raid icon
function TAF.Utils.GetRaidTargetTokenByGUID(destGUID)
    if not destGUID then return "" end
    local candidateUnits = {"target", "focus", "mouseover", "targettarget", "boss1", "boss2", "boss3", "boss4"}
    for _, u in ipairs(candidateUnits) do
        if UnitExists(u) and UnitGUID(u) == destGUID then
            local token = TAF.Utils.GetRaidTargetToken(u)
            if token ~= "" then
                return token
            end
        end
    end
    return ""
end

-- Check if player currently has a main-hand weapon equipped
function TAF.Utils.HasMeleeWeaponEquipped()
    if not GetInventoryItemLink then return false end
    return GetInventoryItemLink("player", 16) ~= nil
end

-- Druid Bear Form Check
function TAF.Utils.IsDruidBearForm()
    if TAF.playerClass ~= "DRUID" then
        return false
    end

    -- Modern API: GetShapeshiftFormID()
    if GetShapeshiftFormID then
        local formID = GetShapeshiftFormID()
        -- 1 = Bear Form, 5 = Dire Bear Form (standard client form IDs)
        if formID == 1 or formID == 5 then
            return true
        end
    end

    -- Fallback: iterate shapeshift forms
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        local numForms = GetNumShapeshiftForms()
        for i = 1, numForms do
            local _, name, isActive, _, spellID = GetShapeshiftFormInfo(i)
            if isActive then
                -- Classic Bear Form (5487) and Dire Bear Form (9634)
                if spellID == 5487 or spellID == 9634 then
                    return true
                end
                if name and (string.find(name, "Bear") or string.find(name, "dire bear", 1, true)) then
                    return true
                end
            end
        end
    end

    return false
end

-- Helper to format target name with icon
function TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    if not targetName or targetName == "" then
        return ""
    end
    if raidIcon and raidIcon ~= "" then
        return raidIcon .. " " .. targetName
    end
    return targetName
end
