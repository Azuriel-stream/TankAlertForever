local ADDON_NAME, TAF = ...

TAF.DefaultConfig = {
    global = {
        enabled = true,
        forceChannel = "auto",          -- "auto", "say", "party", "raid", "raid_warning"
        announceCC = true,
        announceDisarm = true,
        alertThrottle = 8,              -- seconds
        quietWhenThreatSolid = true,    -- skip non-taunt miss alerts while well ahead on threat
        announceThreatWhisper = true,
        threatWhisperThreshold = 90,     -- percentage (50 - 100)
        whisperThrottle = 15,           -- seconds
        onlyTankWhispers = true,
    },
    abilities = {
        WARRIOR = {
            ["Taunt"] = true,
            ["Sunder Armor"] = true,
            ["Shield Slam"] = true,
            ["Revenge"] = true,
            ["Mocking Blow"] = true,
        },
        DRUID = {
            ["Growl"] = true,
        },
        PALADIN = {
            ["Hand of Reckoning"] = true,
            ["Holy Strike"] = true,
            ["Righteous Defense"] = true,
        },
        SHAMAN = {
            ["Earthshaker Slam"] = true,
            ["Earth Shock"] = true,
            ["Frost Shock"] = true,
            ["Lightning Strike"] = true,
            ["Stormstrike"] = true,
        },
    }
}

-- Deep Copy Table Helper
local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end

-- Merge Defaults recursively without overwriting existing user values
local function MergeDefaults(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end
    for k, v in pairs(source) do
        if target[k] == nil then
            target[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(target[k]) == "table" and type(v) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

function TAF:InitConfig()
    if type(TankAlertForeverDB) ~= "table" then
        TankAlertForeverDB = CopyTable(TAF.DefaultConfig)
    else
        MergeDefaults(TankAlertForeverDB, TAF.DefaultConfig)
    end

    TAF.db = TankAlertForeverDB
end

function TAF:GetGlobalOption(key)
    if TAF.db and TAF.db.global then
        return TAF.db.global[key]
    end
    return TAF.DefaultConfig.global[key]
end

function TAF:SetGlobalOption(key, val)
    if TAF.db and TAF.db.global then
        TAF.db.global[key] = val
    end
end

function TAF:IsAbilityTracked(classKey, abilityName)
    if not classKey or not abilityName then return false end
    if TAF.db and TAF.db.abilities and TAF.db.abilities[classKey] then
        local setting = TAF.db.abilities[classKey][abilityName]
        if setting ~= nil then
            return setting
        end
    end
    -- Fallback to default
    if TAF.DefaultConfig.abilities[classKey] and TAF.DefaultConfig.abilities[classKey][abilityName] ~= nil then
        return TAF.DefaultConfig.abilities[classKey][abilityName]
    end
    return false
end

function TAF:SetAbilityTracked(classKey, abilityName, enabled)
    if not classKey or not abilityName then return end
    if not TAF.db then return end
    if not TAF.db.abilities then TAF.db.abilities = {} end
    if not TAF.db.abilities[classKey] then TAF.db.abilities[classKey] = {} end
    TAF.db.abilities[classKey][abilityName] = enabled and true or false
end
