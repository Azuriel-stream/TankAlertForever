local ADDON_NAME, TAF = ...

TAF.Utils = {}

-- =========================================================================
-- Secret Value & Safe String Protection (WoW 12.0+ / Midnight compatibility)
-- =========================================================================

-- Detect if a value is protected as a secret value
function TAF.Utils.IsSecret(val)
    if val == nil then return false end

    -- Modern WoW 12.0+ official APIs
    if canaccessvalue then
        local ok, canAccess = pcall(canaccessvalue, val)
        if ok and not canAccess then
            return true
        end
    end
    if issecretvalue then
        local ok, isSecret = pcall(issecretvalue, val)
        if ok and isSecret then
            return true
        end
    end

    -- Universal fallback guard: test if equality or concatenation checks throw in protected call
    local ok = pcall(function() local _ = (val == "") end)
    if not ok then
        return true
    end
    local okConcat = pcall(function() local _ = (val .. "") end)
    if not okConcat then
        return true
    end

    return false
end

-- Safely sanitize and retrieve string, returning fallback if secret, nil, or invalid
function TAF.Utils.SafeString(val, fallback)
    if val == nil or TAF.Utils.IsSecret(val) then
        return fallback
    end
    if type(val) ~= "string" then
        local ok, str = pcall(tostring, val)
        if ok and not TAF.Utils.IsSecret(str) and type(str) == "string" then
            return str
        end
        return fallback
    end
    return val
end

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

-- Hidden scanning tooltip for resolving unsealed unit names
local scanTooltip = CreateFrame("GameTooltip", "TAF_ScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function TAF.Utils.GetTooltipUnitName(unit)
    if not unit or not UnitExists then return nil end
    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not exists then return nil end

    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetUnit, scanTooltip, unit)
    if ok then
        local line1 = _G["TAF_ScanTooltipTextLeft1"]
        if line1 and line1.GetText then
            local text = line1:GetText()
            if text and not TAF.Utils.IsSecret(text) and text ~= "" and text:lower() ~= "target" then
                return text
            end
        end
    end
    return nil
end

-- Resolve Full Character Name (supporting WoW:Forever first and last names)
function TAF.Utils.GetUnitFullName(unit)
    if not unit then return nil end
    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not exists then
        -- Also support passing "player" even before target is selected
        if unit ~= "player" then return nil end
    end

    local rawName, rawSurname
    local okName = pcall(function()
        rawName, rawSurname = UnitName(unit)
    end)
    if not okName then return nil end

    local name = TAF.Utils.SafeString(rawName, nil)
    local surname = TAF.Utils.SafeString(rawSurname, nil)

    if surname and surname ~= "" and name and name ~= "" then
        return name .. " " .. surname
    end

    if UnitFullName then
        pcall(function()
            local fn, ln = UnitFullName(unit)
            fn = TAF.Utils.SafeString(fn, nil)
            ln = TAF.Utils.SafeString(ln, nil)
            if fn and ln and ln ~= "" then
                name = fn .. " " .. ln
            elseif fn and fn ~= "" then
                name = fn
            end
        end)
    end

    if GetUnitName then
        pcall(function()
            local full = GetUnitName(unit, true)
            full = TAF.Utils.SafeString(full, nil)
            if full and full ~= "" then
                if string.find(full, "-") then
                    name = string.gsub(full, "-", " ")
                else
                    name = full
                end
            end
        end)
    end

    -- If UnitName/GetUnitName was sealed as a secret value, try resolving via tooltip scanner
    if not name or name == "" or name:lower() == "target" then
        local tipName = TAF.Utils.GetTooltipUnitName(unit)
        if tipName and tipName ~= "" then
            name = tipName
        end
    end

    return name
end

-- Safely retrieve unit name without exposing secret values or throwing comparison errors
function TAF.Utils.GetSafeUnitName(unit, fallback)
    if not unit then return fallback end

    local name = nil
    if TAF.Utils and TAF.Utils.GetUnitFullName then
        local ok, fullName = pcall(TAF.Utils.GetUnitFullName, unit)
        if ok and fullName then
            name = TAF.Utils.SafeString(fullName, nil)
        end
    end

    if not name or name == "" or (name:lower() == "target" and unit ~= "target") then
        if UnitName then
            local ok, raw = pcall(UnitName, unit)
            if ok and raw then
                local safe = TAF.Utils.SafeString(raw, nil)
                if safe and safe ~= "" then
                    name = safe
                end
            end
        end
    end

    if name and name ~= "" and name:lower() ~= "target" then
        return name
    end

    return fallback
end

-- Raid Target Icon Visual Textures (Inline FontString escape sequences)
TAF.Utils.RAID_ICON_TEXTURES = {
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
}

-- Mapping of text tokens to visual textures
TAF.Utils.RAID_TOKEN_MAP = {
    ["{rt1}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    ["{rt2}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    ["{rt3}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    ["{rt4}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    ["{rt5}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    ["{rt6}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    ["{rt7}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    ["{rt8}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
    ["{star}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    ["{circle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    ["{coin}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    ["{diamond}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    ["{triangle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    ["{moon}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    ["{square}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    ["{cross}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    ["{x}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    ["{skull}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
}

-- Replace text raid tokens with inline textures for reliable rendering in local chat and UI frames
function TAF.Utils.ReplaceRaidTokens(text)
    if not text or text == "" then return text end

    -- Universal token regex substitution (avoiding C_ChatInfo expression calls which cause taint in combat)
    for token, texture in pairs(TAF.Utils.RAID_TOKEN_MAP) do
        text = string.gsub(text, token, texture)
    end

    return text
end

local RAID_INDEX_TOKENS = {
    [1] = "{rt1}",
    [2] = "{rt2}",
    [3] = "{rt3}",
    [4] = "{rt4}",
    [5] = "{rt5}",
    [6] = "{rt6}",
    [7] = "{rt7}",
    [8] = "{rt8}",
}

-- Retrieve raid target icon index from visible unit frame texture coordinates
function TAF.Utils.GetRaidTargetIconFromFrame(unit)
    if not unit then return nil end

    local texture = nil
    if unit == "target" then
        if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
            texture = TargetFrame.TargetFrameContent.TargetFrameContentContextual.RaidTargetIcon
        end
        if not texture then
            texture = _G["TargetFrameRaidTargetIcon"] or (TargetFrame and TargetFrame.raidTargetIcon)
        end
    elseif unit == "focus" then
        if FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual then
            texture = FocusFrame.TargetFrameContent.TargetFrameContentContextual.RaidTargetIcon
        end
        if not texture then
            texture = _G["FocusFrameRaidTargetIcon"] or (FocusFrame and FocusFrame.raidTargetIcon)
        end
    end

    -- Also check nameplates if unit has an active nameplate
    if not texture and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local okPlate, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if okPlate and plate and plate.UnitFrame and plate.UnitFrame.RaidTargetFrame then
            texture = plate.UnitFrame.RaidTargetFrame.RaidTargetIcon
        end
    end

    if not texture then
        return nil
    end

    local okShown, isShown = pcall(function() return texture:IsShown() end)
    if not okShown or not isShown then
        return nil
    end

    local okCoord, ulx, uly = pcall(function() return texture:GetTexCoord() end)
    if not okCoord or ulx == nil or uly == nil or TAF.Utils.IsSecret(ulx) or TAF.Utils.IsSecret(uly) then
        return nil
    end

    local okCalc, index = pcall(function()
        local col = math.floor(ulx * 4 + 0.5)
        local row = math.floor(uly * 4 + 0.5)
        return row * 4 + col + 1
    end)

    if okCalc and index and index >= 1 and index <= 8 then
        return index
    end
    return nil
end

-- Cache for player-applied raid target markers
local playerMarkedCache = {}

local function OnSetRaidTarget(unit, index)
    if not unit or not index then return end
    if TAF.Utils.IsSecret(index) or type(index) ~= "number" then return end

    local name = nil
    if UnitName then
        local rawName = UnitName(unit)
        name = TAF.Utils.SafeString(rawName, nil)
    end

    local guid = nil
    if UnitGUID then
        local rawGUID = UnitGUID(unit)
        guid = TAF.Utils.SafeString(rawGUID, nil)
    end

    if index >= 1 and index <= 8 then
        if name then playerMarkedCache[name] = index end
        if guid then playerMarkedCache[guid] = index end
    else
        if name then playerMarkedCache[name] = nil end
        if guid then playerMarkedCache[guid] = nil end
    end
end

if hooksecurefunc then
    if SetRaidTarget then
        pcall(hooksecurefunc, "SetRaidTarget", OnSetRaidTarget)
    end
    if SetRaidTargetIcon then
        pcall(hooksecurefunc, "SetRaidTargetIcon", OnSetRaidTarget)
    end
end

-- Safely retrieve numerical raid target index (1-8)
function TAF.Utils.GetRaidTargetIndex(unit)
    -- 1. Check local player-applied raid target cache first
    if unit then
        if UnitGUID then
            local rawGUID = UnitGUID(unit)
            local safeGUID = TAF.Utils.SafeString(rawGUID, nil)
            if safeGUID and playerMarkedCache[safeGUID] then
                return playerMarkedCache[safeGUID]
            end
        end
        if UnitName then
            local rawName = UnitName(unit)
            local safeName = TAF.Utils.SafeString(rawName, nil)
            if safeName and playerMarkedCache[safeName] then
                return playerMarkedCache[safeName]
            end
        end
    end

    -- 2. Try reading the unsealed texture coordinates from the unit's UI frame
    local frameIndex = TAF.Utils.GetRaidTargetIconFromFrame(unit)
    if frameIndex and not TAF.Utils.IsSecret(frameIndex) then
        return frameIndex
    end

    -- 3. Standard API call for friendly / unsealed contexts
    if not unit or not GetRaidTargetIndex then return nil end
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if ok and index and not TAF.Utils.IsSecret(index) and type(index) == "number" and index >= 1 and index <= 8 then
        return index
    end
    return nil
end

-- Resolve Raid Target Icon Token ({rt1} to {rt8}) for a unit
function TAF.Utils.GetRaidTargetToken(unit)
    local index = TAF.Utils.GetRaidTargetIndex(unit)
    if not index then
        -- Fallbacks if unit (e.g. mouseover or unselected target) didn't return an index
        if unit ~= "target" then index = TAF.Utils.GetRaidTargetIndex("target") end
        if not index and unit ~= "mouseover" then index = TAF.Utils.GetRaidTargetIndex("mouseover") end
        if not index and unit ~= "focus" then index = TAF.Utils.GetRaidTargetIndex("focus") end
    end

    if index and RAID_INDEX_TOKENS[index] then
        return RAID_INDEX_TOKENS[index]
    end
    return ""
end

-- Match destination GUID against common target units to fetch raid icon
function TAF.Utils.GetRaidTargetTokenByGUID(destGUID)
    local safeGUID = TAF.Utils.SafeString(destGUID, nil)
    if not safeGUID or safeGUID == "" then return "" end

    local candidateUnits = {"target", "focus", "mouseover", "targettarget", "boss1", "boss2", "boss3", "boss4"}
    for _, u in ipairs(candidateUnits) do
        local ok, exists = pcall(UnitExists, u)
        if ok and exists then
            local okGuid, guid = pcall(UnitGUID, u)
            if okGuid then
                local safeU = TAF.Utils.SafeString(guid, nil)
                if safeU and safeU == safeGUID then
                    local token = TAF.Utils.GetRaidTargetToken(u)
                    if token ~= "" then
                        return token
                    end
                end
            end
        end
    end
    return ""
end

-- Check if player currently has a main-hand weapon equipped
function TAF.Utils.HasMeleeWeaponEquipped()
    if not GetInventoryItemLink then return false end
    local ok, link = pcall(GetInventoryItemLink, "player", 16)
    return ok and link ~= nil
end

-- Druid Bear Form Check
function TAF.Utils.IsDruidBearForm()
    if TAF.playerClass ~= "DRUID" then
        return false
    end

    -- Modern API: GetShapeshiftFormID()
    if GetShapeshiftFormID then
        local ok, formID = pcall(GetShapeshiftFormID)
        if ok and formID and not TAF.Utils.IsSecret(formID) and type(formID) == "number" then
            if formID == 1 or formID == 5 then
                return true
            end
        end
    end

    -- Fallback: iterate shapeshift forms
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        local okNum, numForms = pcall(GetNumShapeshiftForms)
        if okNum and numForms and not TAF.Utils.IsSecret(numForms) and type(numForms) == "number" then
            for i = 1, numForms do
                local okInfo, _, name, isActive, _, spellID = pcall(GetShapeshiftFormInfo, i)
                if okInfo and isActive and not TAF.Utils.IsSecret(isActive) then
                    if spellID and not TAF.Utils.IsSecret(spellID) and (spellID == 5487 or spellID == 9634) then
                        return true
                    end
                    local safeName = TAF.Utils.SafeString(name, nil)
                    if safeName and (string.find(safeName, "Bear") or string.find(safeName, "dire bear", 1, true)) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- Helper to format target name with icon
function TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    local safeTarget = TAF.Utils.SafeString(targetName, "")
    local safeIcon = TAF.Utils.SafeString(raidIcon, "")

    if safeTarget == "" then
        return ""
    end
    if safeIcon ~= "" then
        return safeIcon .. " " .. safeTarget
    end
    return safeTarget
end

-- Helper to format spell display with interactive hyperlink when available
function TAF.Utils.GetSpellDisplay(spellID, fallbackName)
    local link = nil
    if spellID and type(spellID) == "number" and spellID > 0 then
        if C_Spell and C_Spell.GetSpellLink then
            local ok, spellLink = pcall(C_Spell.GetSpellLink, spellID)
            if ok and spellLink and not TAF.Utils.IsSecret(spellLink) and spellLink ~= "" then
                link = spellLink
            end
        end
        if not link and GetSpellLink then
            local ok, spellLink = pcall(GetSpellLink, spellID)
            if ok and spellLink and not TAF.Utils.IsSecret(spellLink) and spellLink ~= "" then
                link = spellLink
            end
        end
    end

    if link then
        return link
    end

    local safeName = TAF.Utils.SafeString(fallbackName, "Ability")
    if string.sub(safeName, 1, 1) == "[" and string.sub(safeName, -1) == "]" then
        return safeName
    end
    return "[" .. safeName .. "]"
end
