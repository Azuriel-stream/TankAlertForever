local ADDON_NAME, TAF = ...

local Announcer = TAF:RegisterModule("Announcer")

local lastCCAlertTime = 0
local lastDisarmAlertTime = 0
local lastAbilityAlertTime = {}

function Announcer:OnInitialize()
    lastCCAlertTime = 0
    lastDisarmAlertTime = 0
    lastAbilityAlertTime = {}
end

function Announcer:OnEnable()
    -- Ready to announce
end

function Announcer:OnDisable()
    -- Reset throttles
    lastCCAlertTime = 0
    lastDisarmAlertTime = 0
    wipe(lastAbilityAlertTime)
end

-- Resolve the appropriate chat channel based on settings and group status
function Announcer:GetOutputChannel()
    local forced = TAF:GetGlobalOption("forceChannel") or "auto"
    forced = TAF.Utils.SafeString(forced, "auto")
    forced = string.lower(forced)

    local groupType = TAF.Utils.GetGroupType()
    local isLeadOrAssist = TAF.Utils.IsRaidLeaderOrAssist()

    if forced == "auto" then
        if groupType == "RAID" then
            return isLeadOrAssist and "RAID_WARNING" or "RAID"
        elseif groupType == "PARTY" then
            return "PARTY"
        else
            return "SAY"
        end
    end

    -- Explicit Forced Channel Handling with Safe Fallback
    if forced == "raid_warning" then
        if groupType == "RAID" and isLeadOrAssist then
            return "RAID_WARNING"
        elseif groupType == "RAID" then
            return "RAID"
        elseif groupType == "PARTY" then
            return "PARTY"
        else
            return "SAY"
        end
    elseif forced == "raid" then
        if groupType == "RAID" then
            return "RAID"
        elseif groupType == "PARTY" then
            return "PARTY"
        else
            return "SAY"
        end
    elseif forced == "party" then
        if groupType == "PARTY" or groupType == "RAID" then
            return "PARTY"
        else
            return "SAY"
        end
    elseif forced == "say" then
        return "SAY"
    end

    return "SAY"
end

-- Safe Chat Message Dispatcher
function Announcer:SendMessage(message, channel)
    local safeMsg = TAF.Utils.SafeString(message, "")
    if safeMsg == "" then return end
    channel = channel or self:GetOutputChannel()
    channel = TAF.Utils.SafeString(channel, "SAY")

    -- Protection against sending RAID_WARNING without permissions
    if channel == "RAID_WARNING" and not TAF.Utils.IsRaidLeaderOrAssist() then
        channel = (TAF.Utils.GetGroupType() == "RAID") and "RAID" or "PARTY"
    end

    -- Modern WoW Hardware Event Protection:
    -- In combat, public channels (SAY, YELL) require physical user input (hardware events).
    -- When in combat with SAY, or when playing solo, route directly to local chat print.
    local inCombat = InCombatLockdown and InCombatLockdown()
    local isSolo = TAF.Utils.GetGroupType() == "NONE"

    if (inCombat and (channel == "SAY" or channel == "YELL")) or (isSolo and channel == "SAY") then
        TAF:Print(safeMsg)
        return
    end

    local sent = false
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        local ok = pcall(C_ChatInfo.SendChatMessage, safeMsg, channel)
        sent = ok
    elseif SendChatMessage then
        local ok = pcall(SendChatMessage, safeMsg, channel)
        sent = ok
    end

    if not sent then
        TAF:Print(safeMsg)
    end
end

-- Ability Failure Alerts
function Announcer:SendAbilityAlert(abilityName, failureType, targetName, raidIcon, spellID)
    if not TAF.isEnabled then return end

    local now = GetTime()
    local safeAbility = TAF.Utils.SafeString(abilityName, "Ability")
    local lastTime = lastAbilityAlertTime[safeAbility] or 0

    -- 1.0 second throttle per ability to guard against duplicate combat log events
    if now - lastTime < 1.0 then
        return
    end
    lastAbilityAlertTime[safeAbility] = now

    local channel = self:GetOutputChannel()
    local targetFormatted = TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    local safeFail = TAF.Utils.SafeString(failureType, "FAILED")
    local localizedFail = TAF.L[safeFail] or safeFail
    local abilityDisplay = (TAF.Utils and TAF.Utils.GetSpellDisplay and TAF.Utils.GetSpellDisplay(spellID, safeAbility)) or ("[" .. safeAbility .. "]")
    local msg = ""

    if channel == "RAID_WARNING" then
        local rawPlayer = TAF.playerName or UnitName("player")
        local myName = TAF.Utils.SafeString(rawPlayer, "Tank")
        if targetFormatted ~= "" then
            msg = string.format(">> %s's %s %s on %s! << (Watch threat)", myName, abilityDisplay, localizedFail, targetFormatted)
        else
            msg = string.format(">> %s's %s %s! << (Watch threat)", myName, abilityDisplay, localizedFail)
        end
    else
        if targetFormatted ~= "" then
            msg = string.format(TAF.L["ALERT_ABILITY_FAIL_TARGET"], abilityDisplay, localizedFail, targetFormatted)
        else
            msg = string.format(TAF.L["ALERT_ABILITY_FAIL_NOTARGET"], abilityDisplay, localizedFail)
        end
    end

    self:SendMessage(msg, channel)
end

-- Loss of Control Alerts (Stun, Fear, Incapacitate)
function Announcer:SendLossOfControlAlert(locType, targetName, raidIcon)
    if not TAF.isEnabled or not TAF:GetGlobalOption("announceCC") then return end

    local now = GetTime()
    local throttle = TAF:GetGlobalOption("alertThrottle") or 8
    if now - lastCCAlertTime < throttle then
        return
    end
    lastCCAlertTime = now

    local channel = self:GetOutputChannel()
    local targetFormatted = TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    local safeLoc = TAF.Utils.SafeString(locType, "CC")
    local localizedLoc = TAF.L[safeLoc] or safeLoc
    local msg = ""

    if channel == "RAID_WARNING" then
        local rawPlayer = TAF.playerName or UnitName("player")
        local myName = TAF.Utils.SafeString(rawPlayer, "Tank")
        if targetFormatted ~= "" then
            msg = string.format(TAF.L["ALERT_CC_RW"], myName, localizedLoc, targetFormatted)
        else
            msg = string.format(TAF.L["ALERT_CC_RW_NOTARGET"], myName, localizedLoc)
        end
    else
        msg = string.format(TAF.L["ALERT_CC_SELF"], localizedLoc)
    end

    self:SendMessage(msg, channel)
end

-- Disarm Alerts
function Announcer:SendDisarmAlert(targetName, raidIcon)
    if not TAF.isEnabled or not TAF:GetGlobalOption("announceDisarm") then return end

    local now = GetTime()
    local throttle = TAF:GetGlobalOption("alertThrottle") or 8
    if now - lastDisarmAlertTime < throttle then
        return
    end
    lastDisarmAlertTime = now

    local channel = self:GetOutputChannel()
    local targetFormatted = TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    local msg = ""

    if channel == "RAID_WARNING" then
        local rawPlayer = TAF.playerName or UnitName("player")
        local myName = TAF.Utils.SafeString(rawPlayer, "Tank")
        if targetFormatted ~= "" then
            msg = string.format(TAF.L["ALERT_DISARM_RW"], myName, targetFormatted)
        else
            msg = string.format(TAF.L["ALERT_DISARM_RW_NOTARGET"], myName)
        end
    else
        msg = TAF.L["ALERT_DISARM_SELF"]
    end

    self:SendMessage(msg, channel)
end

-- Whisper Dispatcher
function Announcer:SendWhisper(recipientName, threatPercent, mobName)
    local safeRecipient = TAF.Utils.SafeString(recipientName, "")
    if safeRecipient == "" then return end
    local safeMob = TAF.Utils.SafeString(mobName, "the target")
    local safePct = (type(threatPercent) == "number" and not TAF.Utils.IsSecret(threatPercent)) and threatPercent or 0

    local msg = string.format(TAF.L["ALERT_THREAT_WHISPER"], math.floor(safePct), safeMob)

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        pcall(C_ChatInfo.SendChatMessage, msg, "WHISPER", nil, safeRecipient)
    elseif SendChatMessage then
        pcall(SendChatMessage, msg, "WHISPER", nil, safeRecipient)
    else
        print("[TankAlert Whisper -> " .. safeRecipient .. "]: " .. msg)
    end
end

-- =========================================================================
-- Local Chat Message Color Filter
-- Enhances readability in local chat frame with vivid colors:
-- Gold arrows, Bright Red avoidance (DODGED/PARRIED), and Amber warning
-- =========================================================================

local AVOIDANCE_TYPES = {
    "DODGED", "PARRIED", "MISSED", "RESISTED", "BLOCKED",
    "IMMUNE", "DEFLECTED", "REFLECTED", "EVADED"
}

local function TankAlertMessageFilter(self, event, msg, author, ...)
    if msg and string.find(msg, "^>> ") and string.find(msg, "<<") then
        local coloredMsg = msg

        -- Highlight failure type in vivid bright red
        for _, failType in ipairs(AVOIDANCE_TYPES) do
            if string.find(coloredMsg, failType) then
                coloredMsg = string.gsub(coloredMsg, failType, "|cffFF2222" .. failType .. "|r")
            end
        end

        -- Highlight arrows in bright gold
        coloredMsg = string.gsub(coloredMsg, "^>> ", "|cffFFD700>> |r")
        coloredMsg = string.gsub(coloredMsg, " <<", " |cffFFD700<<|r")

        -- Highlight threat warning in bright amber
        coloredMsg = string.gsub(coloredMsg, "%(Watch threat%)", "|cffFF9900(Watch threat)|r")

        return false, coloredMsg, author, ...
    end
    return false, msg, author, ...
end

if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", TankAlertMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", TankAlertMessageFilter)
end
