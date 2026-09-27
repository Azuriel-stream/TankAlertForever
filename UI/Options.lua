local ADDON_NAME, TAF = ...

local Options = TAF:RegisterModule("Options")
local L = TAF.L

local optionsPanel = nil
local categoryID = nil
local widgetCounter = 0

local function GetUniqueWidgetName(prefix)
    widgetCounter = widgetCounter + 1
    return string.format("TAF_%s_%d", prefix or "Widget", widgetCounter)
end

-- UI Helper: Create Checkbox
local function CreateCheckbox(parent, text, tooltip, onClick)
    local name = GetUniqueWidgetName("CheckButton")
    local template = "InterfaceOptionsCheckButtonTemplate"
    local cb = CreateFrame("CheckButton", name, parent, template)

    local label = _G[name .. "Text"] or cb.Text
    if not label then
        label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    end
    label:SetText(text)
    cb.Text = label

    cb:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        if onClick then onClick(isChecked) end
    end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    return cb
end

-- UI Helper: Create Slider
local function CreateSlider(parent, text, minVal, maxVal, step, onValChanged)
    local name = GetUniqueWidgetName("Slider")
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    slider:SetHeight(16)

    local title = _G[name .. "Text"] or slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:ClearAllPoints()
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    title:SetText(text)

    local lowText = _G[name .. "Low"]
    if lowText then lowText:SetText(tostring(minVal)) end

    local highText = _G[name .. "High"]
    if highText then highText:SetText(tostring(maxVal)) end

    local valText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        valText:SetText(tostring(rounded))
        if onValChanged then
            onValChanged(rounded)
        end
    end)

    slider.valText = valText
    return slider
end

-- Build Configuration Frame
local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "TankAlertForeverOptionsPanel", UIParent, backdropTemplate)
    f:SetSize(520, 620)
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Backdrop styling
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
    end

    -- Header Title
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(L["ADDON_TITLE"] .. " |cff888888v" .. TAF.version .. "|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    local widgets = {}
    f.widgets = widgets

    -- 1. General Section
    local secGeneral = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secGeneral:SetPoint("TOPLEFT", 20, -55)
    secGeneral:SetText("|cffFFD100" .. L["UI_SECTION_GENERAL"] .. "|r")

    widgets.master = CreateCheckbox(f, L["OPT_ENABLE_ADDON"], L["OPT_ENABLE_ADDON_DESC"], function(checked)
        if checked then TAF:Enable() else TAF:Disable() end
    end)
    widgets.master:SetPoint("TOPLEFT", 20, -80)

    widgets.cc = CreateCheckbox(f, L["OPT_ANNOUNCE_CC"], L["OPT_ANNOUNCE_CC_DESC"], function(checked)
        TAF:SetGlobalOption("announceCC", checked)
    end)
    widgets.cc:SetPoint("TOPLEFT", 20, -110)

    widgets.disarm = CreateCheckbox(f, L["OPT_ANNOUNCE_DISARM"], L["OPT_ANNOUNCE_DISARM_DESC"], function(checked)
        TAF:SetGlobalOption("announceDisarm", checked)
    end)
    widgets.disarm:SetPoint("TOPLEFT", 260, -110)

    -- Alert Throttle Slider
    widgets.alertThrottle = CreateSlider(f, L["OPT_ALERT_THROTTLE"], 3, 30, 1, function(val)
        TAF:SetGlobalOption("alertThrottle", val)
    end)
    widgets.alertThrottle:SetPoint("TOPLEFT", 20, -155)

    -- 2. Threat Section
    local secThreat = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secThreat:SetPoint("TOPLEFT", 20, -195)
    secThreat:SetText("|cffFFD100" .. L["UI_SECTION_THREAT"] .. "|r")

    widgets.whisper = CreateCheckbox(f, L["OPT_ENABLE_WHISPERS"], L["OPT_ENABLE_WHISPERS_DESC"], function(checked)
        TAF:SetGlobalOption("announceThreatWhisper", checked)
    end)
    widgets.whisper:SetPoint("TOPLEFT", 20, -220)

    widgets.tankOnly = CreateCheckbox(f, L["OPT_ONLY_TANK_WHISPERS"], L["OPT_ONLY_TANK_WHISPERS_DESC"], function(checked)
        TAF:SetGlobalOption("onlyTankWhispers", checked)
    end)
    widgets.tankOnly:SetPoint("TOPLEFT", 260, -220)

    -- Threshold Slider
    widgets.threshold = CreateSlider(f, L["OPT_WHISPER_THRESHOLD"], 50, 100, 1, function(val)
        TAF:SetGlobalOption("threatWhisperThreshold", val)
    end)
    widgets.threshold:SetPoint("TOPLEFT", 20, -265)

    -- Whisper Throttle Slider
    widgets.whisperThrottle = CreateSlider(f, L["OPT_WHISPER_THROTTLE"], 5, 30, 1, function(val)
        TAF:SetGlobalOption("whisperThrottle", val)
    end)
    widgets.whisperThrottle:SetPoint("TOPLEFT", 260, -265)

    -- 3. Channel Selection
    local secChannel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secChannel:SetPoint("TOPLEFT", 20, -305)
    secChannel:SetText("|cffFFD100" .. L["UI_SECTION_CHANNEL"] .. "|r")

    local channels = {
        { key = "auto", label = L["CHAN_AUTO"] },
        { key = "say", label = L["CHAN_SAY"] },
        { key = "party", label = L["CHAN_PARTY"] },
        { key = "raid", label = L["CHAN_RAID"] },
        { key = "raid_warning", label = L["CHAN_RAID_WARNING"] }
    }

    widgets.channels = {}
    local function UpdateChannelChecks(selectedKey)
        TAF:SetGlobalOption("forceChannel", selectedKey)
        for k, cb in pairs(widgets.channels) do
            cb:SetChecked(k == selectedKey)
        end
    end

    local chanX, chanY = 20, -330
    for idx, ch in ipairs(channels) do
        local cb = CreateCheckbox(f, ch.label, nil, function()
            UpdateChannelChecks(ch.key)
        end)
        cb:SetPoint("TOPLEFT", chanX, chanY)
        widgets.channels[ch.key] = cb

        if idx % 2 == 1 then
            chanX = 260
        else
            chanX = 20
            chanY = chanY - 26
        end
    end

    -- 4. Tracked Class Abilities
    local pClass = TAF.playerClass or "WARRIOR"
    local secAbilities = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secAbilities:SetPoint("TOPLEFT", 20, -420)
    secAbilities:SetText("|cffFFD100" .. string.format(L["UI_SECTION_ABILITIES"], pClass) .. "|r")

    widgets.abilities = {}
    local abilityOrder = TAF.SpellData and TAF.SpellData.Order and TAF.SpellData.Order[pClass]
    if abilityOrder and #abilityOrder > 0 then
        local abX, abY = 20, -445
        for i, abName in ipairs(abilityOrder) do
            local capturedName = abName
            local cb = CreateCheckbox(f, capturedName, nil, function(checked)
                TAF:SetAbilityTracked(pClass, capturedName, checked)
            end)
            cb:SetPoint("TOPLEFT", abX, abY)
            widgets.abilities[capturedName] = cb

            if i % 2 == 1 then
                abX = 260
            else
                abX = 20
                abY = abY - 26
            end
        end
    else
        local noAbText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noAbText:SetPoint("TOPLEFT", 20, -445)
        noAbText:SetText(string.format(L["UI_NO_ABILITIES"], pClass))
    end

    -- 5. Test Simulation Buttons (Bottom)
    local testHeader = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("BOTTOMLEFT", 20, 48)
    testHeader:SetText("|cffFFD100Testing Simulator:|r")

    local btnMiss = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnMiss:SetSize(85, 22)
    btnMiss:SetPoint("BOTTOMLEFT", 20, 20)
    btnMiss:SetText("Test Miss")
    btnMiss:SetScript("OnClick", function()
        local testSpell = (abilityOrder and abilityOrder[1]) or "Taunt"
        TAF.AbilityAlerts:SimulateMiss(testSpell, "RESISTED")
    end)

    local btnCC = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnCC:SetSize(85, 22)
    btnCC:SetPoint("LEFT", btnMiss, "RIGHT", 10, 0)
    btnCC:SetText("Test CC")
    btnCC:SetScript("OnClick", function()
        TAF.LossOfControl:SimulateLOC("STUNNED")
    end)

    local btnDisarm = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnDisarm:SetSize(85, 22)
    btnDisarm:SetPoint("LEFT", btnCC, "RIGHT", 10, 0)
    btnDisarm:SetText("Test Disarm")
    btnDisarm:SetScript("OnClick", function()
        TAF.LossOfControl:SimulateDisarm()
    end)

    local btnWhisper = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnWhisper:SetSize(90, 22)
    btnWhisper:SetPoint("LEFT", btnDisarm, "RIGHT", 10, 0)
    btnWhisper:SetText("Test Whisper")
    btnWhisper:SetScript("OnClick", function()
        local fullName = (TAF.Utils and TAF.Utils.GetUnitFullName and TAF.Utils.GetUnitFullName("player")) or UnitName("player")
        TAF.ThreatMonitor:SimulateWhisper(fullName, 95)
    end)

    -- Synchronize UI with current settings on Show
    f:SetScript("OnShow", function()
        local g = TAF.db.global
        widgets.master:SetChecked(g.enabled)
        widgets.cc:SetChecked(g.announceCC)
        widgets.disarm:SetChecked(g.announceDisarm)
        widgets.whisper:SetChecked(g.announceThreatWhisper)
        widgets.tankOnly:SetChecked(g.onlyTankWhispers)

        widgets.alertThrottle:SetValue(g.alertThrottle)
        widgets.alertThrottle.valText:SetText(tostring(g.alertThrottle))

        widgets.threshold:SetValue(g.threatWhisperThreshold)
        widgets.threshold.valText:SetText(tostring(g.threatWhisperThreshold))

        widgets.whisperThrottle:SetValue(g.whisperThrottle)
        widgets.whisperThrottle.valText:SetText(tostring(g.whisperThrottle))

        for k, cb in pairs(widgets.channels) do
            cb:SetChecked(k == g.forceChannel)
        end

        local pClass = TAF.playerClass or "WARRIOR"
        for name, cb in pairs(widgets.abilities) do
            cb:SetChecked(TAF:IsAbilityTracked(pClass, name))
        end
    end)

    f:Hide()
    optionsPanel = f
    return f
end

function Options:Toggle()
    local panel = CreateOptionsPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

function Options:OnInitialize()
    -- Lazy initialization: panel is constructed on demand to avoid any load-time taint
end

-- =========================================================================
-- Slash Command Dispatcher
-- =========================================================================
local function HandleSlashCommands(msg)
    local raw = string.lower(string.trim and string.trim(msg or "") or string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    local cmd, arg = string.match(raw, "^(%S+)%s*(.*)$")
    cmd = cmd or ""

    if cmd == "" then
        Options:Toggle()
        return
    end

    if cmd == "on" then
        TAF:Enable()
    elseif cmd == "off" then
        TAF:Disable()
    elseif cmd == "toggle" then
        if arg == "cc" then
            local newVal = not TAF:GetGlobalOption("announceCC")
            TAF:SetGlobalOption("announceCC", newVal)
            TAF:Print("CC Alerts: %s", newVal and "|cff00FF00ON|r" or "|cffFF0000OFF|r")
        elseif arg == "disarm" then
            local newVal = not TAF:GetGlobalOption("announceDisarm")
            TAF:SetGlobalOption("announceDisarm", newVal)
            TAF:Print("Disarm Alerts: %s", newVal and "|cff00FF00ON|r" or "|cffFF0000OFF|r")
        elseif arg == "whisper" then
            local newVal = not TAF:GetGlobalOption("announceThreatWhisper")
            TAF:SetGlobalOption("announceThreatWhisper", newVal)
            TAF:Print("Threat Whispers: %s", newVal and "|cff00FF00ON|r" or "|cffFF0000OFF|r")
        else
            Options:Toggle()
        end
    elseif cmd == "status" then
        local g = TAF.db.global
        TAF:Print(L["CMD_STATUS_HEADER"])
        TAF:Print(L["CMD_STATUS_ENABLED"], g.enabled and "|cff00FF00Enabled|r" or "|cffFF0000Disabled|r")
        TAF:Print(L["CMD_STATUS_CHANNEL"], string.upper(g.forceChannel))
        TAF:Print(L["CMD_STATUS_CC"], g.announceCC and "|cff00FF00ON|r" or "|cffFF0000OFF|r")
        TAF:Print(L["CMD_STATUS_DISARM"], g.announceDisarm and "|cff00FF00ON|r" or "|cffFF0000OFF|r")
        TAF:Print(L["CMD_STATUS_WHISPER"], g.announceThreatWhisper and "|cff00FF00ON|r" or "|cffFF0000OFF|r", g.threatWhisperThreshold)
    elseif cmd == "test" then
        if arg == "cc" then
            TAF.LossOfControl:SimulateLOC("STUNNED")
        elseif arg == "disarm" then
            TAF.LossOfControl:SimulateDisarm()
        elseif string.sub(arg, 1, 7) == "whisper" then
            local customTarget = string.match(arg, "^whisper%s+(.+)$")
            local target = customTarget or (TAF.Utils and TAF.Utils.GetUnitFullName and TAF.Utils.GetUnitFullName("player")) or UnitName("player")
            TAF.ThreatMonitor:SimulateWhisper(target, 95)
        elseif arg == "miss" or arg == "" then
            local pClass = TAF.playerClass or "WARRIOR"
            local abilityOrder = TAF.SpellData and TAF.SpellData.Order and TAF.SpellData.Order[pClass]
            local testSpell = (abilityOrder and abilityOrder[1]) or "Taunt"
            TAF.AbilityAlerts:SimulateMiss(testSpell, "RESISTED")
        else
            TAF:Print("Available test options: |cffFFFFFF/ta test miss|r, |cffFFFFFF/ta test cc|r, |cffFFFFFF/ta test disarm|r, |cffFFFFFF/ta test whisper [target]|r")
        end
    elseif cmd == "debug" then
        local func = _G["TAF_BLOCKED_FUNC"] or (TAF.db and TAF.db._lastBlockedFunction) or "None recorded"
        local evt = _G["TAF_BLOCKED_EVENT"] or (TAF.db and TAF.db._lastBlockedEvent) or "None recorded"
        local stack = _G["TAF_BLOCKED_STACK"] or (TAF.db and TAF.db._lastBlockedStack) or "No stack available"
        TAF:Print("|cff00FF7F--- TAF Security Debug Info ---|r")
        TAF:Print("Last Event: |cffFFFFFF%s|r", evt)
        TAF:Print("Blocked Function: |cffFF4444%s|r", func)
        TAF:Print("Stack Trace:\n%s", stack)
    else
        TAF:Print("Unknown command. Type |cffFFFFFF/ta|r to open settings.")
    end
end

SLASH_TANKALERT1 = "/ta"
SLASH_TANKALERT2 = "/tankalert"
SlashCmdList["TANKALERT"] = HandleSlashCommands
