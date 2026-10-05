local ADDON_NAME, TAF = ...

local L = TAF:NewLocale("enUS")
if not L then return end

-- General & Addon Info
L["ADDON_TITLE"] = "TankAlert Forever"
L["ADDON_LOADED"] = "v%s loaded. Type |cffFFFFFF/ta|r or |cffFFFFFF/tankalert|r for options."
L["ADDON_ENABLED"] = "|cff00FF00Enabled.|r"
L["ADDON_DISABLED"] = "|cffFF4444Disabled.|r"
L["CLASS_NOT_SUPPORTED"] = "|cffFF4444Class %s is not supported.|r"

-- Alert Formats (Combat & Chat)
L["ALERT_ABILITY_FAIL_TARGET"] = ">> %s %s on %s! << (Watch threat)"
L["ALERT_ABILITY_FAIL_NOTARGET"] = ">> %s %s! << (Watch threat)"
L["ALERT_CC_RW"] = ">> %s is %s on %s! (Watch threat) <<"
L["ALERT_CC_RW_NOTARGET"] = ">> %s is %s! (Watch threat) <<"
L["ALERT_CC_SELF"] = ">> I'm %s! (Watch threat) <<"
L["ALERT_DISARM_RW"] = ">> %s is DISARMED on %s! (Watch threat) <<"
L["ALERT_DISARM_RW_NOTARGET"] = ">> %s is DISARMED! (Watch threat) <<"
L["ALERT_DISARM_SELF"] = ">> I'm DISARMED! (Watch threat) <<"
L["ALERT_THREAT_WHISPER"] = "[TankAlert] Careful! You are at %d%% threat on %s!"

-- Failure Types
L["RESISTED"] = "RESISTED"
L["MISSED"] = "MISSED"
L["DODGED"] = "DODGED"
L["PARRIED"] = "PARRIED"
L["BLOCKED"] = "BLOCKED"
L["IMMUNE"] = "IMMUNE"
L["DEFLECTED"] = "DEFLECTED"
L["REFLECTED"] = "REFLECTED"
L["EVADED"] = "EVADED"

-- CC Types
L["STUNNED"] = "STUNNED"
L["FEARED"] = "FEARED"
L["INCAPACITATED"] = "INCAPACITATED"
L["DISARMED"] = "DISARMED"

-- UI Headers & Sections
L["UI_TAB_SETTINGS"] = "General Settings"
L["UI_SECTION_GENERAL"] = "General Alerts"
L["UI_SECTION_THREAT"] = "Threat Whispers"
L["UI_SECTION_CHANNEL"] = "Output Channel"
L["UI_SECTION_ABILITIES"] = "Tracked Abilities (%s)"
L["UI_NO_ABILITIES"] = "No configurable tank abilities for your class (%s)."

-- UI Checkboxes & Controls
L["OPT_ENABLE_ADDON"] = "Enable Addon"
L["OPT_ENABLE_ADDON_DESC"] = "Master switch to enable or disable TankAlert Forever functionality."
L["OPT_ANNOUNCE_CC"] = "Announce Loss of Control (CC)"
L["OPT_ANNOUNCE_CC_DESC"] = "Announce when you are Stunned, Feared, or Incapacitated."
L["OPT_ANNOUNCE_DISARM"] = "Announce Disarm"
L["OPT_ANNOUNCE_DISARM_DESC"] = "Announce when you are Disarmed."
L["OPT_ALERT_THROTTLE"] = "Alert Throttle (Seconds)"
L["OPT_ALERT_THROTTLE_DESC"] = "Minimum cooldown between CC or Disarm alert announcements."

L["OPT_ENABLE_WHISPERS"] = "Enable Threat Whispers"
L["OPT_ENABLE_WHISPERS_DESC"] = "Automatically whisper group members who are approaching your threat level on your target."
L["OPT_ONLY_TANK_WHISPERS"] = "Only if I am Tank"
L["OPT_ONLY_TANK_WHISPERS_DESC"] = "Only send threat whispers if you currently have aggro / are actively tanking the target."
L["OPT_WHISPER_THRESHOLD"] = "Whisper Threat Threshold %"
L["OPT_WHISPER_THRESHOLD_DESC"] = "Group members exceeding this threat percentage will receive a warning whisper."
L["OPT_WHISPER_THROTTLE"] = "Whisper Throttle (Seconds)"
L["OPT_WHISPER_THROTTLE_DESC"] = "Minimum cooldown between threat whispers to the same player."

L["CHAN_AUTO"] = "Auto (Smart Detect)"
L["CHAN_SAY"] = "Say"
L["CHAN_PARTY"] = "Party"
L["CHAN_RAID"] = "Raid"
L["CHAN_RAID_WARNING"] = "Raid Warning"

-- Slash Commands
L["CMD_STATUS_HEADER"] = "|cff00FF7F--- TankAlert Forever Status ---|r"
L["CMD_STATUS_ENABLED"] = "Enabled: %s"
L["CMD_STATUS_CHANNEL"] = "Channel: %s"
L["CMD_STATUS_CC"] = "CC Alerts: %s"
L["CMD_STATUS_DISARM"] = "Disarm Alerts: %s"
L["CMD_STATUS_WHISPER"] = "Threat Whispers: %s (Threshold: %d%%)"
