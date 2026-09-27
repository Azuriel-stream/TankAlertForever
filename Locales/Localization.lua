local ADDON_NAME, TAF = ...

TAF.L = setmetatable({}, {
    __index = function(tbl, key)
        -- Fallback to the raw key if translation is missing
        return key
    end
})

local currentLocale = GetLocale and GetLocale() or "enUS"

function TAF:NewLocale(locale)
    if locale == "enUS" or locale == currentLocale then
        return TAF.L
    end
    return nil
end
