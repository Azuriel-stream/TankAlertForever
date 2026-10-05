local ADDON_NAME, TAF = ...

_G["TAF"] = TAF
_G["TankAlertForever"] = TAF

TAF.name = ADDON_NAME
TAF.version = "2.0.0"
TAF.modules = {}
TAF.isInitialized = false
TAF.isEnabled = false

local eventFrame = CreateFrame("Frame", "TAF_EventFrame")
TAF.eventFrame = eventFrame

-- Security Action Interceptor: Captures blocked/forbidden functions quietly for /ta debug
local securityFrame = CreateFrame("Frame", "TAF_SecurityFrame")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_BLOCKED")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_FORBIDDEN")
securityFrame:SetScript("OnEvent", function(self, event, addonName, functionName)
    local stack = (debugstack and debugstack(2, 8, 8)) or "No stack available"
    _G["TAF_BLOCKED_FUNC"] = functionName
    _G["TAF_BLOCKED_STACK"] = stack
    _G["TAF_BLOCKED_EVENT"] = event
    if TankAlertForeverDB then
        TankAlertForeverDB._lastBlockedEvent = event
        TankAlertForeverDB._lastBlockedAddon = addonName
        TankAlertForeverDB._lastBlockedFunction = functionName
        TankAlertForeverDB._lastBlockedStack = stack
    end
end)

-- Safe Helper Print (avoids touching DEFAULT_CHAT_FRAME to eliminate frame taint)
function TAF:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    msg = tostring(msg)
    -- Render chat raid icon tokens ({rt1} to {rt8}) as inline visual textures in local chat output
    if TAF.Utils and TAF.Utils.ReplaceRaidTokens then
        msg = TAF.Utils.ReplaceRaidTokens(msg)
    else
        msg = string.gsub(msg, "{rt([1-8])}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t")
    end

    if string.find(msg, "^>> ") and string.find(msg, "<<") then
        for _, failType in ipairs({"DODGED", "PARRIED", "MISSED", "RESISTED", "BLOCKED", "IMMUNE", "DEFLECTED", "REFLECTED", "EVADED"}) do
            if string.find(msg, failType) then
                msg = string.gsub(msg, failType, "|cffFF2222" .. failType .. "|r")
            end
        end
        msg = string.gsub(msg, "^>> ", "|cffFFD700>> |r")
        msg = string.gsub(msg, " <<", " |cffFFD700<<|r")
        msg = string.gsub(msg, "%(Watch threat%)", "|cffFF9900(Watch threat)|r")
    end

    print("|cff00FF7F[TankAlert]|r " .. msg)
end

-- Module Registration
function TAF:RegisterModule(name, moduleTable)
    if not moduleTable then
        moduleTable = {}
    end
    moduleTable.name = name
    TAF.modules[name] = moduleTable
    TAF[name] = moduleTable
    return moduleTable
end

function TAF:GetModule(name)
    return TAF.modules[name]
end

-- Class Support Verification
function TAF:IsSupportedClass(classKey)
    local checkClass = classKey or TAF.playerClass
    if not checkClass then return true end
    -- Check if SpellData has abilities defined for this class
    if TAF.SpellData and TAF.SpellData[checkClass] then
        return true
    end
    -- Fallback to standard hybrid/tank classes
    return (checkClass == "WARRIOR" or checkClass == "DRUID" or checkClass == "PALADIN" or checkClass == "SHAMAN")
end

-- Lifecycle Management
function TAF:Enable()
    if TAF.isEnabled then return end
    TAF.isEnabled = true
    if TAF.db and TAF.db.global then
        TAF.db.global.enabled = true
    end

    for name, mod in pairs(TAF.modules) do
        if type(mod.OnEnable) == "function" then
            local success, err = pcall(mod.OnEnable, mod)
            if not success then
                TAF:Print("|cffFF4444Error enabling module %s:|r %s", name, tostring(err))
            end
        end
    end
    TAF:Print(TAF.L["ADDON_ENABLED"])
end

function TAF:Disable()
    if not TAF.isEnabled then return end
    TAF.isEnabled = false
    if TAF.db and TAF.db.global then
        TAF.db.global.enabled = false
    end

    for name, mod in pairs(TAF.modules) do
        if type(mod.OnDisable) == "function" then
            local success, err = pcall(mod.OnDisable, mod)
            if not success then
                TAF:Print("|cffFF4444Error disabling module %s:|r %s", name, tostring(err))
            end
        end
    end
    TAF:Print(TAF.L["ADDON_DISABLED"])
end

-- Event Handling
local function OnEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not TAF.isInitialized then
            TAF.isInitialized = true
            
            -- Initialize Database Configuration
            if type(TAF.InitConfig) == "function" then
                TAF:InitConfig()
            end

            -- Enable script errors and taint logging automatically
            pcall(function()
                if SetCVar then
                    SetCVar("scriptErrors", "1")
                    SetCVar("taintLog", "1")
                end
            end)

            -- Initialize Modules
            for name, mod in pairs(TAF.modules) do
                if type(mod.OnInitialize) == "function" then
                    local success, err = pcall(mod.OnInitialize, mod)
                    if not success then
                        TAF:Print("|cffFF4444Error initializing module %s:|r %s", name, tostring(err))
                    end
                end
            end
        end
        eventFrame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Retrieve Player Details
        if not TAF.playerClass then
            local _, class = UnitClass("player")
            TAF.playerClass = class
        end
        TAF.playerGUID = UnitGUID("player")
        TAF.playerName = (TAF.Utils and TAF.Utils.GetSafeUnitName and TAF.Utils.GetSafeUnitName("player", "Player")) or "Player"

        -- Enable modules if global master switch is on
        if TAF.db and TAF.db.global and TAF.db.global.enabled then
            if not TAF.isEnabled then
                TAF.isEnabled = true
                for name, mod in pairs(TAF.modules) do
                    if type(mod.OnEnable) == "function" then
                        local success, err = pcall(mod.OnEnable, mod)
                        if not success then
                            TAF:Print("|cffFF4444Error enabling module %s:|r %s", name, tostring(err))
                        end
                    end
                end
            end
        end

        -- Welcome Message
        if event == "PLAYER_LOGIN" then
            TAF:Print(TAF.L["ADDON_LOADED"], TAF.version)
            eventFrame:UnregisterEvent("PLAYER_LOGIN")
        end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
