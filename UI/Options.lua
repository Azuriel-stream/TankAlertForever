local ADDON_NAME, TAF = ...

local Options = TAF:RegisterModule("Options")
local L = TAF.L

local optionsPanel = nil
local widgetCounter = 0

local function GetUniqueWidgetName(prefix)
    widgetCounter = widgetCounter + 1
    return string.format("TAF_%s_%d", prefix or "Widget", widgetCounter)
end

-- UI Helper: Create Checkbox
-- UICheckButtonTemplate replaces the deprecated InterfaceOptionsCheckButtonTemplate (DeprecatedTemplates.xml).
local function CreateCheckbox(parent, text, tooltip, onClick)
    local name = GetUniqueWidgetName("CheckButton")
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)

    local label = cb.Text
    label:SetFontObject("GameFontHighlight")
    label:SetText(text)

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
-- MinimalSliderWithSteppersTemplate replaces the deprecated OptionsSliderTemplate. It shows < > stepper
-- buttons and renders the current value in its Right label via a formatter.
local function CreateSlider(parent, text, minVal, maxVal, step, onValChanged)
    local name = GetUniqueWidgetName("Slider")
    local slider = CreateFrame("Frame", name, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(220, 24)

    local title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 19, 2)
    title:SetText(text)

    local Label = MinimalSliderWithSteppersMixin.Label
    local formatters = {
        [Label.Right] = CreateMinimalSliderFormatter(Label.Right, function(value)
            return tostring(math.floor(value + 0.5))
        end),
    }
    step = step or 1
    slider:Init(minVal, minVal, maxVal, (maxVal - minVal) / step, formatters)

    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if onValChanged then
            onValChanged(math.floor(value + 0.5))
        end
    end, slider)

    return slider
end

-- UI Helper: gold section header with a horizontal divider underneath
local function CreateSectionHeader(parent, text, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(text)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -2)
    divider:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    return header
end

-- UI Helper: modern menu dropdown (radio list) for the output channel
local CHANNELS = {
    { key = "auto", label = "CHAN_AUTO" },
    { key = "say", label = "CHAN_SAY" },
    { key = "party", label = "CHAN_PARTY" },
    { key = "raid", label = "CHAN_RAID" },
    { key = "raid_warning", label = "CHAN_RAID_WARNING" },
}

local function CreateChannelDropdown(parent)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(220)

    local function IsSelected(key)
        return TAF:GetGlobalOption("forceChannel") == key
    end
    local function SetSelected(key)
        TAF:SetGlobalOption("forceChannel", key)
    end

    dropdown:SetupMenu(function(_, rootDescription)
        for _, ch in ipairs(CHANNELS) do
            rootDescription:CreateRadio(L[ch.label], IsSelected, SetSelected, ch.key)
        end
    end)
    return dropdown
end

-- Build Configuration Frame
-- ButtonFrameTemplate: standard Blizzard window (portrait, title bar, close button, Inset, bottom button bar).
local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local f = CreateFrame("Frame", "TankAlertForeverOptionsPanel", UIParent, "ButtonFrameTemplate")
    f:SetSize(540, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    f:SetTitle(L["ADDON_TITLE"] .. " |cff888888v" .. TAF.version .. "|r")
    f:SetPortraitToClassIcon(TAF.playerClass or "WARRIOR")

    local widgets = {}
    f.widgets = widgets
    local content = f.Inset

    -- Attic (between title bar and Inset): master switch next to the portrait
    widgets.master = CreateCheckbox(f, L["OPT_ENABLE_ADDON"], L["OPT_ENABLE_ADDON_DESC"], function(checked)
        if checked then TAF:Enable() else TAF:Disable() end
    end)
    widgets.master:SetPoint("TOPLEFT", 64, -28)

    -- 1. Alerts
    CreateSectionHeader(content, L["UI_SECTION_GENERAL"], -12)

    widgets.cc = CreateCheckbox(content, L["OPT_ANNOUNCE_CC"], L["OPT_ANNOUNCE_CC_DESC"], function(checked)
        TAF:SetGlobalOption("announceCC", checked)
    end)
    widgets.cc:SetPoint("TOPLEFT", 14, -40)

    widgets.disarm = CreateCheckbox(content, L["OPT_ANNOUNCE_DISARM"], L["OPT_ANNOUNCE_DISARM_DESC"], function(checked)
        TAF:SetGlobalOption("announceDisarm", checked)
    end)
    widgets.disarm:SetPoint("TOPLEFT", 268, -40)

    widgets.alertThrottle = CreateSlider(content, L["OPT_ALERT_THROTTLE"], 3, 30, 1, function(val)
        TAF:SetGlobalOption("alertThrottle", val)
    end)
    widgets.alertThrottle:SetPoint("TOPLEFT", 0, -88)

    -- 2. Threat whispers
    CreateSectionHeader(content, L["UI_SECTION_THREAT"], -126)

    widgets.whisper = CreateCheckbox(content, L["OPT_ENABLE_WHISPERS"], L["OPT_ENABLE_WHISPERS_DESC"], function(checked)
        TAF:SetGlobalOption("announceThreatWhisper", checked)
    end)
    widgets.whisper:SetPoint("TOPLEFT", 14, -154)

    widgets.tankOnly = CreateCheckbox(content, L["OPT_ONLY_TANK_WHISPERS"], L["OPT_ONLY_TANK_WHISPERS_DESC"], function(checked)
        TAF:SetGlobalOption("onlyTankWhispers", checked)
    end)
    widgets.tankOnly:SetPoint("TOPLEFT", 268, -154)

    widgets.threshold = CreateSlider(content, L["OPT_WHISPER_THRESHOLD"], 50, 100, 1, function(val)
        TAF:SetGlobalOption("threatWhisperThreshold", val)
    end)
    widgets.threshold:SetPoint("TOPLEFT", 0, -202)

    widgets.whisperThrottle = CreateSlider(content, L["OPT_WHISPER_THROTTLE"], 5, 30, 1, function(val)
        TAF:SetGlobalOption("whisperThrottle", val)
    end)
    widgets.whisperThrottle:SetPoint("TOPLEFT", 254, -202)

    -- 3. Output channel
    CreateSectionHeader(content, L["UI_SECTION_CHANNEL"], -240)
    widgets.channel = CreateChannelDropdown(content)
    widgets.channel:SetPoint("TOPLEFT", 18, -270)

    -- 4. Tracked class abilities
    local pClass = TAF.playerClass or "WARRIOR"
    CreateSectionHeader(content, string.format(L["UI_SECTION_ABILITIES"], pClass), -310)

    widgets.abilities = {}
    local abilityOrder = TAF.SpellData and TAF.SpellData.Order and TAF.SpellData.Order[pClass]
    if abilityOrder and #abilityOrder > 0 then
        for i, abName in ipairs(abilityOrder) do
            local capturedName = abName
            local cb = CreateCheckbox(content, capturedName, nil, function(checked)
                TAF:SetAbilityTracked(pClass, capturedName, checked)
            end)
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            cb:SetPoint("TOPLEFT", 14 + col * 254, -338 - row * 28)
            widgets.abilities[capturedName] = cb
        end
    else
        local noAbText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noAbText:SetPoint("TOPLEFT", 18, -342)
        noAbText:SetText(string.format(L["UI_NO_ABILITIES"], pClass))
    end

    -- 5. Test buttons in the bottom button bar
    local tests = {
        { text = "Test Miss", width = 90, run = function()
            local testSpell = (abilityOrder and abilityOrder[1]) or "Taunt"
            TAF.AbilityAlerts:SimulateMiss(testSpell, "RESISTED")
        end },
        { text = "Test CC", width = 80, run = function() TAF.LossOfControl:SimulateLOC("STUNNED") end },
        { text = "Test Disarm", width = 90, run = function() TAF.LossOfControl:SimulateDisarm() end },
        { text = "Test Whisper", width = 100, run = function()
            TAF.ThreatMonitor:SimulateWhisper(TAF.Utils.GetSafeUnitName("player", "Player"), 95)
        end },
    }
    local prev
    for _, def in ipairs(tests) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(def.width, 22)
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            btn:SetPoint("BOTTOMLEFT", 6, 3)
        end
        btn:SetText(def.text)
        btn:SetScript("OnClick", def.run)
        prev = btn
    end

    -- Synchronize UI with current settings on Show
    f:SetScript("OnShow", function()
        local g = TAF.db.global
        widgets.master:SetChecked(g.enabled)
        widgets.cc:SetChecked(g.announceCC)
        widgets.disarm:SetChecked(g.announceDisarm)
        widgets.whisper:SetChecked(g.announceThreatWhisper)
        widgets.tankOnly:SetChecked(g.onlyTankWhispers)

        widgets.alertThrottle:SetValue(g.alertThrottle)
        widgets.threshold:SetValue(g.threatWhisperThreshold)
        widgets.whisperThrottle:SetValue(g.whisperThrottle)

        widgets.channel:GenerateMenu()

        for name, cb in pairs(widgets.abilities) do
            cb:SetChecked(TAF:IsAbilityTracked(pClass, name))
        end
    end)

    f:Hide()
    optionsPanel = f
    tinsert(UISpecialFrames, "TankAlertForeverOptionsPanel")
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
            local target = customTarget or TAF.Utils.GetSafeUnitName("player", "Player")
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
