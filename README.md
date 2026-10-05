# TankAlert Forever

**TankAlert Forever** is the modern rewrite of the popular Classic tank utility addon **TankAlert**, tailored for the **WoW: Forever** client environment.

It assists tanks in communicating critical combat state changes and ability failures to their group automatically, while keeping group members informed of threat spikes.

---

## Features

### 1. Ability Failure Alerts (Secure Modern Pipeline)
Monitors tank ability failures without relying on restricted or forbidden combat log events:
* Tracks cast intent via `UNIT_SPELLCAST_SENT` and correlates it with the result on your target via `UNIT_COMBAT` (Miss, Dodge, Parry, Resist, Block, Immune, Deflect, Reflect, Evade) and `UI_ERROR_MESSAGE`.
* **Warrior:** Taunt, Sunder Armor, Shield Slam, Revenge, Mocking Blow
* **Druid:** Growl
* **Paladin:** Hand of Reckoning, Holy Strike, Righteous Defense
* **Shaman:** Earthshaker Slam, Earth Shock, Frost Shock, Lightning Strike, Stormstrike

### 2. Loss of Control & Disarm Alerts
Detects loss of control effects (Stuns, Fears, Incapacitate, Confused) and disarm states using modern `C_LossOfControl` APIs (`LOSS_OF_CONTROL_ADDED` / `LOSS_OF_CONTROL_UPDATE`) and `UI_ERROR_MESSAGE`:
* Druid stance awareness ensures alerts only fire when in Bear Form / Dire Bear Form.
* Built-in alert throttling prevents notification spam.

### 3. Native Threat Whispers
Monitors threat across party/raid members using WoW's native threat API (`UnitDetailedThreatSituation`):
* Whispers DPS/Healers when they exceed a configurable threat threshold (default: 90%).
* Full support for first and last names in whispers.
* Configurable "Only if I am Tank" filter ensures whispers are only sent by the active tank.
* Per-player whisper throttling prevents whisper spam.

### 4. Smart Channel Dispatching
* Automatically sends to `RAID_WARNING` if in a raid with Assist or Lead privileges.
* Falls back to `RAID`, `PARTY`, or `SAY` depending on group composition.
* Manual channel overrides supported (`SAY`, `PARTY`, `RAID`, `RAID_WARNING`).
* Automatically formats target raid icons (`{rt1}`–`{rt8}`) into announcements.

---

## Project Structure

* `Core/`: Namespace initialization, configuration defaults, and shared utilities.
* `Data/`: Spell definitions, spell IDs, and failure mappings per class.
* `Modules/`: Discrete feature modules (Ability Alerts, Loss of Control, Threat Monitor, Announcer).
* `UI/`: Modern options interface and slash command dispatcher.
* `Locales/`: Localization tables.
* `DESIGN.md`: Full architecture, API decisions, and technical specifications.

---

## Slash Commands

* `/ta` or `/tankalert` — Open configuration panel
* `/ta on` — Enable addon
* `/ta off` — Disable addon
* `/ta toggle cc` — Toggle Loss of Control alerts
* `/ta toggle disarm` — Toggle Disarm alerts
* `/ta toggle whisper` — Toggle Threat whispers
* `/ta status` — Show current configuration status
* `/ta test miss [ability]` — Simulate an ability miss / resist
* `/ta test cc` — Simulate a loss-of-control alert
* `/ta test disarm` — Simulate a disarm alert
* `/ta test whisper [target]` — Simulate a high-threat whisper
* `/ta debug` — Show the last action WoW blocked for this addon (with stack)
* `/ta debug on` / `/ta debug off` — Opt-in diagnostics: show Lua errors and log taint to `Logs\taint.log` (off by default; TankAlert no longer changes these settings by itself)
