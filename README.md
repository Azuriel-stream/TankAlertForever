# TankAlert Forever

**TankAlert Forever** is the modern rewrite of the popular Classic tank utility addon **TankAlert**, tailored for the **WoW: Forever** client environment.

It assists tanks in communicating critical combat state changes and ability failures to their group automatically, while keeping group members informed of threat spikes.

---

## Features

### 1. Ability Failure Alerts (CLEU Powered)
Listens directly to the combat log (`COMBAT_LOG_EVENT_UNFILTERED`) to reliably catch resisted, missed, dodged, parried, or immune tank abilities without relying on fragile chat-message string matching:
* **Warrior:** Taunt, Sunder Armor, Shield Slam, Revenge, Mocking Blow
* **Druid:** Growl
* **Paladin:** Hand of Reckoning, Holy Strike, Righteous Defense
* **Shaman:** Earthshaker Slam, Earth Shock, Frost Shock, Lightning Strike, Stormstrike

### 2. Loss of Control & Disarm Alerts
Detects loss of control effects (Stuns, Fears, Incapacitate, Confused) and disarm states using modern aura and Loss-of-Control APIs, alerting party or raid members so they know when to pull back or pop defensives.
* Druid stance awareness ensures alerts only fire when in Bear Form / Dire Bear Form.
* Built-in alert throttling prevents notification spam.

### 3. Native Threat Whispers
Monitors threat across party/raid members using WoW's native threat API (`UnitDetailedThreatSituation`):
* Whispers DPS/Healers when they exceed a configurable threat threshold (default: 90%).
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
* `Modules/`: Discrete feature modules (Combat Log Ability Alerts, Loss of Control, Threat Monitor, Announcer).
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
