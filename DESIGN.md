# TankAlertForever: System Architecture & Technical Design Document

## 1. Executive Summary & Vision

**TankAlertForever** is a modern, modular rewrite of the classic **TankAlert** addon (originally authored by Azuriel for Vanilla / Turtle WoW 1.12). 

While the legacy addon served as an essential tool for tanks by alerting groups to critical ability failures, loss of control (CC/Disarm), and warning group members via threat whispers, its 1.12 implementation was constrained by the limitations of the Vanilla WoW client:
- Fragile string parsing of chat messages (`CHAT_MSG_SPELL_SELF_DAMAGE`) and error toasts (`UI_ERROR_MESSAGE`).
- Dependency on third-party threat sync addon communications (`TWThreat` / `TWTv4`).
- A monolithic single-file architecture mixing GUI, business logic, settings, and event loops.
- Deprecated 1.12 API calls and global namespace pollution.

**TankAlertForever** modernizes this feature set for the **WoW: Forever** client environment (modern WoW API architecture, Lua 5.1/LuaJIT runtime, structured event payloads, and modern frame/settings frameworks). The rewrite provides superior reliability, multi-language resilience, performance optimization, and clean extensibility.

---

## 2. Legacy vs. Modern Architectural Comparison

| Dimension | Legacy `TankAlert` (Turtle WoW 1.12) | Modern `TankAlertForever` (WoW: Forever) |
| :--- | :--- | :--- |
| **Code Structure** | Single monolithic file (`TankAlert.lua`, ~977 lines) | Modular architecture (`Core/`, `Modules/`, `Data/`, `UI/`, `Locales/`) |
| **Namespace** | Globals and file-scope locals (`TankAlert_Settings`, `TankAlert_GUI`) | Strict private namespace injection (`local ADDON_NAME, TAF = ...`) |
| **Combat Failure Detection** | Chat log regex matching (`CHAT_MSG_SPELL_SELF_DAMAGE`) | Combat Log Event System (`COMBAT_LOG_EVENT_UNFILTERED` with `CombatLogGetCurrentEventInfo()`) |
| **Loss of Control (CC)** | String matching on `UI_ERROR_MESSAGE` ("while stunned", etc.) only on cast attempt | Native Loss of Control events (`C_LossOfControlModel` / `LOSS_OF_CONTROL_ADDED` / `UNIT_AURA`) |
| **Disarm Detection** | Error string match + checking inventory slot 16 | Dedicated aura/loss-of-control checks + weapon slot validation |
| **Threat System** | Proprietary string parsing of `CHAT_MSG_ADDON` (`TWTv4=` protocol) + 2s polling frame | Native Modern Threat API (`UnitDetailedThreatSituation`) + modular provider interface |
| **Group / Raid APIs** | `GetNumRaidMembers()`, `GetNumPartyMembers()`, `GetRaidRosterInfo()` | `IsInRaid()`, `IsInGroup()`, `GetNumGroupMembers()`, `UnitIsGroupLeader()`, `UnitIsGroupAssistant()` |
| **Raid Target Icons** | Manually parsed color strings (`|cffFFFF00[Star]|r`) | Native chat tokens (`{rt1}`..`{rt8}`) and UI textures |
| **Settings / GUI** | Manual 1.12 `CreateFrame` with `OptionsCheckButtonTemplate` & `getglobal()` | Modern Settings API (`Settings.RegisterAddOnCategory` / Canvas UI) |
| **Localization** | Hardcoded English regex patterns | Decoupled localization table (`Locales/`) & Spell ID references |

---

## 3. Project Structure & Directory Layout

```text
TankAlertForever/
├── TankAlertForever.toc           # Addon metadata & file load sequence
├── DESIGN.md                      # This comprehensive architecture document
├── README.md                      # User guide, installation & slash commands
├── Core/
│   ├── Init.lua                   # Addon namespace, lifecycle management & module loader
│   ├── Config.lua                 # Database (SavedVariables), default values & profile migrations
│   └── Utils.lua                  # Group detection, channel formatting & raid icon helpers
├── Data/
│   └── SpellData.lua              # Class ability definitions, spell IDs, and failure mappings
├── Modules/
│   ├── AbilityAlerts.lua          # Subevent-driven combat log tracking (SPELL_MISSED, SWING_MISSED)
│   ├── LossOfControl.lua          # Stun, Fear, Incapacitate, Confused & Disarm monitoring
│   ├── ThreatMonitor.lua          # Native threat calculation & throttled whisper alerts
│   └── Announcer.lua              # Centralized message dispatcher with intelligent routing & throttles
├── UI/
│   └── Options.lua                # Modern settings panel, widget factory & config binding
└── Locales/
    ├── enUS.lua                   # Base English localization
    └── Localization.lua           # Localization initialization & fallback system
```

---

## 4. Module Specifications & Technical Workflows

### 4.1. Core Engine (`Core/Init.lua`, `Core/Config.lua`, `Core/Utils.lua`)
- **Namespace Injection**: Every Lua file starts with `local ADDON_NAME, TAF = ...`. The `TAF` table acts as the unified internal bus across modules.
- **Module Lifecycle**:
  - `TAF:RegisterModule(name, moduleTable)` registers functional subsystems.
  - Lifecycle hooks: `OnInitialize()` (called on `ADDON_LOADED`) and `OnEnable()` / `OnDisable()` (toggled by user or class gate).
- **Settings Store**:
  - SavedVariable name: `TankAlertForeverDB`.
  - Deep-copy merging against default configuration on initialization to guarantee schema integrity across versions.
- **Roster & Channel Utils**:
  - Replaces all legacy group checks with modern APIs:
    ```lua
    function TAF.Utils.GetGroupType()
        if IsInRaid() then return "RAID" end
        if IsInGroup() then return "PARTY" end
        return "NONE"
    end
    ```
  - Automatically identifies whether player has Assist/Lead status for `RAID_WARNING` output permissions (`UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")`).

---

### 4.2. Ability Failure Tracking (`Modules/AbilityAlerts.lua` & `Data/SpellData.lua`)
- **Modern Security Architecture**:
  - In modern client builds (1.60.1 / 12.0+), `COMBAT_LOG_EVENT_UNFILTERED` is restricted from third-party addons (`ADDON_ACTION_FORBIDDEN`).
  - TankAlertForever uses the modern secure event pipeline:
    1. `UNIT_SPELLCAST_SENT`: Captures player cast intent, target, and spell ID.
    2. `COMBAT_TEXT_UPDATE`: Captures combat avoidance resolutions (`MISS`, `DODGE`, `PARRY`, `BLOCK`, `RESIST`, `IMMUNE`, `DEFLECT`, `REFLECT`).
    3. `UI_ERROR_MESSAGE`: Captures out-of-range, facing, and immunity errors.
    4. `COMBAT_LOG_MESSAGE`: Fallback for text combat log messages where supported.
- **Evaluation Pipeline**:
  ```mermaid
  flowchart TD
      A[UNIT_SPELLCAST_SENT] --> B{unit == player?}
      B -- Yes --> C{Is spell tracked for player's class?}
      C -- Yes --> D[Record Active Cast & Target Context]
      D --> E[Wait for Combat Resolution]
      E --> F{COMBAT_TEXT_UPDATE / UI_ERROR_MESSAGE}
      F -- Avoidance Detected --> G[Format Alert with Target & Raid Icon]
      G --> H[Dispatch to TAF.Announcer]
  ```
- **Tracked Classes & Abilities** (extensible via `Data/SpellData.lua`):
  - **Warrior**: Taunt, Sunder Armor, Shield Slam, Revenge, Mocking Blow.
  - **Druid**: Growl.
  - **Paladin**: Hand of Reckoning, Holy Strike, Righteous Defense.
  - **Shaman**: Earthshaker Slam, Earth Shock, Frost Shock, Lightning Strike, Stormstrike.
  - *Future Expansion Ready*: Death Knight (Dark Command, Death Grip), Monk, Demon Hunter.

---

### 4.3. Loss of Control & Disarm Monitoring (`Modules/LossOfControl.lua`)
- **Modern Loss of Control Engine**:
  - Registers `LOSS_OF_CONTROL_ADDED` / `LOSS_OF_CONTROL_UPDATE` via the modern `C_LossOfControl` API (`GetActiveLossOfControlData`).
  - Fallback/Complementary: `UI_ERROR_MESSAGE` monitoring for disarms and action locks.
- **Aura Mechanics Tracked**:
  - `STUN`: Kidney Shot, Hammer of Justice, Bash, etc.
  - `FEAR`: Psychic Scream, Howl of Terror, Intimidating Shout.
  - `INCAPACITATE` / `CONFUSED`: Polymorph, Sap, Gouge, Scatter Shot.
  - `DISARM`: Weapon disarm effects, verified with inventory slot 16 (`TAF.Utils.HasMeleeWeaponEquipped()`).
- **Stance / Form Guards**:
  - Druids: Only announce CC if in Bear Form / Dire Bear Form (`TAF.Utils.IsDruidBearForm()`).
- **Anti-Spam Throttles**:
  - Independent cooldown for CC alerts (default 8s).
  - Independent cooldown for Disarm alerts (default 8s).

---

### 4.4. Threat Monitoring & Whisper Engine (`Modules/ThreatMonitor.lua`)
- **Native Threat Engine**:
  - Eliminates reliance on fragile third-party chat addons (`TWTv4`).
  - Utilizes modern native API:
    ```lua
    local isTanking, status, threatPct, rawThreatPct, threatValue = UnitDetailedThreatSituation(unit, "target")
    ```
- **Monitoring Loop**:
  - Runs on a lightweight ticker (`C_Timer.NewTicker(1.0, CheckThreat)`) or combat update events (`UNIT_THREAT_LIST_UPDATE`).
  - Active only while in combat (`PLAYER_REGEN_DISABLED` to `PLAYER_REGEN_ENABLED`).
- **Main Tank Gate ("Only if I am Tank")**:
  - Validates that player is the current tank of the target (`isTanking == true` or highest threat on threat table) before broadcasting whispers to other party/raid members.
- **Whisper Dispatcher**:
  - When non-tank group member's threat percentage exceeds configured threshold (default: 90%), fires a warning whisper:
    `"[TankAlert] Careful! You are at {pct}% threat on {target}!"`
  - Per-player throttle table (default: 15s) prevents whisper spam.

---

### 4.5. Central Announcer & Channel Routing (`Modules/Announcer.lua`)
- **Channel Hierarchy**:
  - **Auto**:
    - If in Raid & Player is Leader/Assist -> `RAID_WARNING`
    - If in Raid -> `RAID`
    - If in Party -> `PARTY`
    - If Solo / Standalone -> `SAY`
  - **Manual Overrides**: `SAY`, `PARTY`, `RAID`, `RAID_WARNING`.
- **Raid Icon Integration**:
  - Queries `GetRaidTargetIndex(targetUnit)`.
  - Translates index `1`..`8` to modern chat tokens `{rt1}`..`{rt8}` which render native icons in WoW chat frames without custom color code hacks.

---

### 4.6. UI & Configuration System (`UI/Options.lua`)
- **Integration**:
  - Integrates with the modern WoW Settings Category API (`Settings.RegisterCanvasLayoutCategory` or standard interface options fallback).
- **Control Layout**:
  1. **Global Settings**: Master toggle, Alert throttle slider, Output channel dropdown/radios.
  2. **Alert Types**: CC alerts toggle, Disarm alerts toggle.
  3. **Threat Whispers**: Enable whispers toggle, "Only if I am Tank" toggle, Threat threshold slider (50% - 100%), Whisper throttle slider (5s - 30s).
  4. **Class Abilities**: Dynamically generated checkboxes based on player's current class and `Data/SpellData.lua`.
- **Slash Commands**:
  - `/ta` or `/tankalert` -> Opens configuration UI.
  - `/ta on` / `/ta off` -> Master enable/disable.
  - `/ta toggle <cc|disarm|whisper>` -> Direct toggle support for macros.
  - `/ta status` -> Prints current status to chat frame.

---

## 5. SavedVariables Schema (`TankAlertForeverDB`)

```lua
TankAlertForeverDB = {
    global = {
        enabled = true,
        forceChannel = "auto",          -- "auto", "say", "party", "raid", "raid_warning"
        announceCC = true,
        announceDisarm = true,
        alertThrottle = 8,              -- seconds
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
```

---

## 6. Implementation Strategy & Milestones

1. **Phase 1: Project Setup & Specification** *(Completed)*
   - Detailed analysis of 1.12 codebase.
   - Folder structure creation adhering to modern WoW addon best practices.
   - Comprehensive system design document.

2. **Phase 2: Core Infrastructure & Data Definitions**
   - Implement `TankAlertForever.toc`.
   - Implement `Core/Init.lua`, `Core/Config.lua`, and `Core/Utils.lua`.
   - Populate `Data/SpellData.lua` with spell IDs, localized names, and miss types.
   - Setup `Locales/enUS.lua` and localization system.

3. **Phase 3: Event & Detection Modules**
   - Implement `Modules/Announcer.lua` (routing, throttling, raid icons).
   - Implement `Modules/AbilityAlerts.lua` (CLEU `SPELL_MISSED` parser).
   - Implement `Modules/LossOfControl.lua` (Loss of Control & Aura mechanic monitor).
   - Implement `Modules/ThreatMonitor.lua` (Native `UnitDetailedThreatSituation` ticker & whisper logic).

4. **Phase 4: Modern Configuration UI & Slash Commands**
   - Implement `UI/Options.lua` using modern options framework.
   - Register slash commands `/ta` and `/tankalert`.

5. **Phase 5: Verification & Quality Assurance**
   - Syntax validation, unit testing of string/throttle helpers.
   - Cross-client combat log compatibility check.
