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
    if not message or message == "" then return end
    channel = channel or self:GetOutputChannel()

    if not SendChatMessage then
        print("[TankAlert Preview] (" .. channel .. "): " .. message)
        return
    end

    -- Protection against sending RAID_WARNING without permissions
    if channel == "RAID_WARNING" and not TAF.Utils.IsRaidLeaderOrAssist() then
        channel = (TAF.Utils.GetGroupType() == "RAID") and "RAID" or "PARTY"
    end

    SendChatMessage(message, channel)
end

-- Ability Failure Alerts
function Announcer:SendAbilityAlert(abilityName, failureType, targetName, raidIcon)
    if not TAF.isEnabled then return end

    local now = GetTime()
    local abilityKey = abilityName or "Unknown"
    local lastTime = lastAbilityAlertTime[abilityKey] or 0

    -- 1.0 second throttle per ability to guard against duplicate combat log events
    if now - lastTime < 1.0 then
        return
    end
    lastAbilityAlertTime[abilityKey] = now

    local channel = self:GetOutputChannel()
    local targetFormatted = TAF.Utils.FormatTargetWithIcon(targetName, raidIcon)
    local msg = ""

    local localizedFail = TAF.L[failureType] or failureType

    if channel == "RAID_WARNING" then
        local myName = TAF.playerName or UnitName("player") or "Tank"
        if targetFormatted ~= "" then
            msg = string.format("%s's %s %s on %s. Watch threat!", myName, abilityName, localizedFail, targetFormatted)
        else
            msg = string.format("%s's %s %s. Watch threat!", myName, abilityName, localizedFail)
        end
    else
        if targetFormatted ~= "" then
            msg = string.format(TAF.L["ALERT_ABILITY_FAIL_TARGET"], abilityName, localizedFail, targetFormatted)
        else
            msg = string.format(TAF.L["ALERT_ABILITY_FAIL_NOTARGET"], abilityName, localizedFail)
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
    local localizedLoc = TAF.L[locType] or locType
    local msg = ""

    if channel == "RAID_WARNING" then
        local myName = TAF.playerName or UnitName("player") or "Tank"
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
        local myName = TAF.playerName or UnitName("player") or "Tank"
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
    if not recipientName or recipientName == "" then return end
    mobName = mobName or "the target"

    local msg = string.format(TAF.L["ALERT_THREAT_WHISPER"], math.floor(threatPercent), mobName)

    if SendChatMessage then
        SendChatMessage(msg, "WHISPER", nil, recipientName)
    else
        print("[TankAlert Whisper -> " .. recipientName .. "]: " .. msg)
    end
end
