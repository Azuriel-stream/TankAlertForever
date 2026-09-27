local ADDON_NAME, TAF = ...

TAF.SpellData = {}

-- Tracked abilities per class
-- Keyed by ability display name
TAF.SpellData.Abilities = {
    WARRIOR = {
        ["Taunt"] = {
            spellIDs = { 355 },
            isTaunt = true,
            default = true,
        },
        ["Mocking Blow"] = {
            spellIDs = { 694, 7400, 7402, 20559, 20560, 25266 },
            isTaunt = true,
            default = true,
        },
        ["Sunder Armor"] = {
            spellIDs = { 7386, 7405, 8380, 11596, 11597, 25225 },
            isTaunt = false,
            default = true,
        },
        ["Revenge"] = {
            spellIDs = { 6572, 6574, 7379, 11600, 11601, 25288 },
            isTaunt = false,
            default = true,
        },
        ["Shield Slam"] = {
            spellIDs = { 23922, 23923, 23924, 23925, 25258 },
            isTaunt = false,
            default = true,
        },
    },
    DRUID = {
        ["Growl"] = {
            spellIDs = { 6795 },
            isTaunt = true,
            default = true,
        },
    },
    PALADIN = {
        ["Hand of Reckoning"] = {
            spellIDs = { 62124 },
            isTaunt = true,
            default = true,
        },
        ["Righteous Defense"] = {
            spellIDs = { 31789 },
            isTaunt = true,
            default = true,
        },
        ["Holy Strike"] = {
            spellIDs = { 46399, 46400, 46401 },
            isTaunt = false,
            default = true,
        },
    },
    SHAMAN = {
        ["Earthshaker Slam"] = {
            spellIDs = {},
            isTaunt = true,
            default = true,
        },
        ["Earth Shock"] = {
            spellIDs = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 },
            isTaunt = false,
            default = true,
        },
        ["Frost Shock"] = {
            spellIDs = { 8056, 8058, 10472, 10473 },
            isTaunt = false,
            default = true,
        },
        ["Lightning Strike"] = {
            spellIDs = {},
            isTaunt = false,
            default = true,
        },
        ["Stormstrike"] = {
            spellIDs = { 17364 },
            isTaunt = false,
            default = true,
        },
    }
}

-- UI Display Ordering
TAF.SpellData.Order = {
    WARRIOR = { "Taunt", "Mocking Blow", "Sunder Armor", "Revenge", "Shield Slam" },
    DRUID = { "Growl" },
    PALADIN = { "Hand of Reckoning", "Righteous Defense", "Holy Strike" },
    SHAMAN = { "Earthshaker Slam", "Earth Shock", "Frost Shock", "Lightning Strike", "Stormstrike" }
}

-- Fast Lookup Cache (populated during initialization)
TAF.SpellData.NameLookup = {}
TAF.SpellData.IDLookup = {}

for classKey, abilities in pairs(TAF.SpellData.Abilities) do
    TAF.SpellData.NameLookup[classKey] = {}
    TAF.SpellData.IDLookup[classKey] = {}

    for abilityName, data in pairs(abilities) do
        -- Map name lowercase for case-insensitive matching
        TAF.SpellData.NameLookup[classKey][string.lower(abilityName)] = abilityName

        if data.spellIDs then
            for _, id in ipairs(data.spellIDs) do
                TAF.SpellData.IDLookup[classKey][id] = abilityName
            end
        end
    end
end

-- Helper to find ability by Spell ID or Spell Name
function TAF.SpellData:FindAbility(classKey, spellID, spellName)
    if not classKey then return nil end

    -- 1. Check ID lookup
    local idMap = self.IDLookup[classKey]
    if idMap and spellID and idMap[spellID] then
        return idMap[spellID]
    end

    -- 2. Check Name lookup
    local nameMap = self.NameLookup[classKey]
    if nameMap and spellName then
        local lowerName = string.lower(spellName)
        if nameMap[lowerName] then
            return nameMap[lowerName]
        end
    end

    return nil
end
