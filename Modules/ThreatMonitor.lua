local ADDON_NAME, TAF = ...

local ThreatMonitor = TAF:RegisterModule("ThreatMonitor")
local frame = CreateFrame("Frame", "TAF_ThreatMonitorFrame")

local ticker = nil
local whisperThrottle = {}

-- Scan Group Threat against current target
local function CheckThreat()
    if not TAF.isEnabled then return end
    if not TAF:GetGlobalOption("announceThreatWhisper") then return end

    -- Threat requires a valid hostile or attackable target
    local okExists, exists = pcall(UnitExists, "target")
    if not okExists or not exists then return end

    local okDead, isDead = pcall(UnitIsDead, "target")
    if okDead and isDead then return end

    local okFriend, isFriend = pcall(UnitIsFriend, "player", "target")
    if okFriend and isFriend then return end

    local mobName = TAF.Utils.GetSafeUnitName("target", "the target")
    local onlyTank = TAF:GetGlobalOption("onlyTankWhispers")

    -- 1. Main Tank Validation: Check if player is the active tank
    if onlyTank then
        local okThreat, isTanking = pcall(UnitDetailedThreatSituation, "player", "target")
        if not okThreat or TAF.Utils.IsSecret(isTanking) or not isTanking then
            return
        end
    end

    local threshold = TAF:GetGlobalOption("threatWhisperThreshold") or 90
    local throttleSeconds = TAF:GetGlobalOption("whisperThrottle") or 15
    local now = GetTime()

    local groupType = TAF.Utils.GetGroupType()
    local unitPrefix = (groupType == "RAID") and "raid" or "party"
    local count = (groupType == "RAID") and GetNumGroupMembers() or GetNumSubgroupMembers()

    if not count or count == 0 then return end

    for i = 1, count do
        local unit = unitPrefix .. i
        local okUnit, unitExists = pcall(UnitExists, unit)
        if okUnit and unitExists and not UnitIsUnit(unit, "player") and not UnitIsDeadOrGhost(unit) then
            local okSit, isMemberTanking, _, threatPct, rawThreatPct = pcall(UnitDetailedThreatSituation, unit, "target")
            
            -- Skip if check failed or if the member is actively tanking (e.g. co-tank taunt)
            if okSit and (TAF.Utils.IsSecret(isMemberTanking) or not isMemberTanking) then
                local pct = threatPct or rawThreatPct
                if pct and not TAF.Utils.IsSecret(pct) and type(pct) == "number" and pct >= threshold then
                    local memberName = TAF.Utils.GetSafeUnitName(unit, nil)
                    if memberName and memberName ~= "" then
                        local lastWhisper = whisperThrottle[memberName] or 0
                        if now - lastWhisper >= throttleSeconds then
                            whisperThrottle[memberName] = now
                            TAF.Announcer:SendWhisper(memberName, pct, mobName)
                        end
                    end
                end
            end
        end
    end
end

-- Combat State Handlers
local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: start threat ticker
        wipe(whisperThrottle)
        if ticker then ticker:Cancel() end
        if C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(1.0, CheckThreat)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat: stop threat ticker
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        wipe(whisperThrottle)
    end
end

function ThreatMonitor:OnInitialize()
    wipe(whisperThrottle)
end

function ThreatMonitor:OnEnable()
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", OnEvent)

    -- If already in combat when enabled
    if InCombatLockdown and InCombatLockdown() then
        if ticker then ticker:Cancel() end
        if C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(1.0, CheckThreat)
        end
    end
end

function ThreatMonitor:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    wipe(whisperThrottle)
end

-- Test Harness
function ThreatMonitor:SimulateWhisper(targetPlayerName, threatPercent, mobName)
    local recipient = TAF.Utils.SafeString(targetPlayerName, nil) or TAF.Utils.GetSafeUnitName("player", "Player")
    local pct = (type(threatPercent) == "number" and not TAF.Utils.IsSecret(threatPercent)) and threatPercent or 95
    local mob = TAF.Utils.SafeString(mobName, nil) or TAF.Utils.GetSafeUnitName("target", "Training Dummy")
    TAF:Print("Sending test whisper to |cffFFFFFF%s|r...", recipient)
    TAF.Announcer:SendWhisper(recipient, pct, mob)
end
