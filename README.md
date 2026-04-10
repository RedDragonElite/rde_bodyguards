# 🛡️ RDE | Bodyguards | Next-Gen AI Protection System

[![License: RDE Black Flag](https://img.shields.io/badge/License-RDE%20Black%20Flag%20v6.66-black.svg)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Ready-blue.svg)](https://fivem.net/)
[![ox_core](https://img.shields.io/badge/Framework-ox__core-green.svg)](https://github.com/overextended/ox_core)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](#)
[![Stars](https://img.shields.io/github/stars/RedDragonElite/rde_bodyguards?style=social)](#)

**Self-healing AI bodyguards with full weapon management, tactical combat, ox_target commands, and deep progression — the most advanced protection system ever built for FiveM**

[Features](#-features) • [Installation](#-installation)

---

## 🎯 Overview

**RDE Bodyguards** is a complete private security experience. Recruit operatives from immersive broker NPCs, equip them with weapons and medical supplies via ox_inventory, and command them through 14 direct ox_target interactions. Every bodyguard has their own personality, skill tree, morale, wound system, and relationship tier — and they use items from their gear to heal themselves in combat.

### 🌟 Why Choose RDE Bodyguards?

* ✅ **Self-Healing AI** — BGs consume bandage/medkit from their ox_inventory stash automatically
* ✅ **14 ox_target Commands** — Follow, Stay, Patrol, Kill Target, Attack All, Peaceful, Aggressive, Heal, Holster, Draw, Choose Weapon, Manage Gear, Dismiss, Full Menu
* ✅ **Remote Control** — Command all BGs from F6 menu or radial at any distance
* ✅ **Full Weapon Management** — Auto-equip, holster/unholster, weapon selection, 60+ weapons recognized
* ✅ **Tactical Combat AI** — Cover system, flanking, suppressive fire, adrenaline, last stand
* ✅ **Deep Progression** — 100 levels, 10 prestige, 8 skills, achievements, daily rewards
* ✅ **Bond System** — 5 personalities, 5 relationship tiers, session memories, witness system
* ✅ **Multiplayer Sync** — StateBag + NetworkEntity sync across all clients
* ✅ **Cinematic Arrival** — Vehicle/foot arrival with parking, greetings, particle effects
* ✅ **Production Ready** — pcall safety, MySQL fallbacks, LOD, distance culling, <0.08ms

---

## ✨ Features

### 🩹 Self-Heal & Medical System

| | |
|---|---|
| **Automatic Self-Heal** | BGs check every 5s if wounded and consume bandage or medkit from their stash. Smart item choice: medkit for critical/serious, bandage for minor. Medical skill improves effectiveness. 50% heal penalty during combat. | 
| **Buddy Heal** | BGs with Medical 40+ scan for wounded allies within 8m, walk over, play CPR animation, and heal them. Grants XP and morale. |
| **Manual Heal Command** | Order any BG to heal via ox_target or F6 menu — bypasses cooldowns. |
| **Bulletproof Backend** | 3-method stash access: `GetInventoryItems` → `GetInventory` → direct MySQL on `ox_inventory`. Item removal also uses MySQL fallback if API fails. |

### 🔫 Weapon System

| | |
|---|---|
| **Auto-Equip** | BGs equip best weapon from stash after arrival. 60+ GTA V weapons recognized with priority ranking (pistols → SMGs → rifles → snipers → heavy). |
| **Weapon Selection** | Choose which weapon the BG uses via ox_target menu. All weapons from stash listed with ammo counts. |
| **Holster Toggle** | Holster/unholster via ox_target and F6 menu. Set BGs to unarmed with fists option. |
| **Re-Equip Thread** | Every 30s BGs check if unarmed and auto-equip. Case-insensitive weapon name matching. |

### 🎯 ox_target Command System

Every active bodyguard ped has these direct commands:

| Command | Description | Range |
|---|---|---|
| 💬 Interact | Bond interaction with personality animation | 2.5m |
| 🚶 Follow Me | Follow player in formation | 8m |
| 🛑 Stay Here | Hold current position (guard mode) | 8m |
| 🔄 Patrol Area | Patrol around current location | 8m |
| 🎯 Kill Target | Attack ped you're aiming at | 12m |
| 🔥 Attack All | Engage all hostiles in area | 12m |
| ☮️ Peaceful | No combat — ignore threats | 8m |
| 😤 Aggressive | Combat mode — engage threats | 8m |
| 🩹 Heal | Use bandage/medkit from gear | 3m |
| 🔒 Holster | Put weapon away | 4m |
| 🔓 Draw Weapon | Equip weapon from stash | 4m |
| 🔫 Choose Weapon | Select specific weapon from inventory | 3m |
| 💼 Manage Gear | Open ox_inventory stash | 2.5m |
| 👋 Dismiss | Departure animation + cleanup | 3m |

### 📻 Remote Control (Radial + F6)

All commands accessible at any distance:

* **Radial Menu** — Per-BG: Follow, Stay, Attack All, Heal + Global: All Follow, All Stay, All Attack
* **F6 Command Center** — Full 14-command quick order menu per BG + global mass commands + roster, leaderboard, formations, daily rewards

### ⚡ Combat AI

| Feature | Description |
|---|---|
| **Threat Detection** | Multi-layer 3-scan confirmation — prevents ghost enemies |
| **Tactical Cover** | Tactics 20+: seek cover when HP < 50% using `TaskSeekCoverFromPed` |
| **Flanking** | Tactics 65+: approach from random flanking angles |
| **Suppressive Fire** | Tactics 70+: lay covering fire on enemy position |
| **Adrenaline Rush** | 12s buff (+25% accuracy, +15% speed) triggered by player damage or kill |
| **Last Stand** | Below 15% HP: +40% accuracy, 3 ticks invulnerability |
| **Environmental** | Night: -18% accuracy (Tactics reduces penalty). Rain: -10% accuracy |
| **Bond Bonus** | +3% combat effectiveness per relationship tier (max +12% at Tier 5) |
| **Auto-Retreat** | Critical HP + Medical 30+: retreat to player for healing |

### 🏷️ 3D World Labels

Rich status above every BG's head:

* **Name + Level** in rarity color (Common → Uncommon → Rare → Epic → Legendary)
* **Wound Status** — `[!!] CRITICAL`, `[!] Serious`, `[*] Minor Wound`
* **HP Percentage** — Color gradient green → yellow → orange → red
* **Morale** — `[!!] MORALE LOW` / `[!] MORALE SHAKEN`
* **Combat State** — `>> COMBAT <<`, `>> AVENGE <<`, `[GUARDING]`, `[PATROL]`
* **Buffs** — `>> ADRENALINE <<`, `>> LAST STAND <<`
* **Holstered** — `[HOLSTERED]` when weapon is put away

### 📊 NUI HUD

Top-right panel with live BG status cards:

* Name, level, prestige, rarity, gender
* HP and morale bars with segment marks
* Wound, morale, relationship tier chips
* Adrenaline (pink) and Last Stand (orange) status chips
* Combat state with pulsating animation
* Clickable — opens full BG menu

### 🎭 Bond & Personality

* **5 Personalities** — Stoic, Loyal, Aggressive, Caring, Professional (deterministic from BG ID)
* **5 Relationship Tiers** — Hired Hand → Comrade → Trusted Ally → Blood Brother → Legendary Bond
* **Session Memories** — Kills, protections, deaths, heals, milestones logged per session
* **Milestone Celebrations** — Personality-based greeting animations + voice lines
* **Fatigue** — BGs lose effectiveness after 45min, recover after 10min dismissed
* **Witness** — BGs enter avenge mode when they see the player die
* **Body Language** — BGs mirror player behavior (crouch, cover)

### 📈 Progression

* **100 Levels** — Exponential XP curve (kills, protects, heals, guard/patrol ticks)
* **10 Prestige** — Reset to Lv.1, all skills permanently +10
* **8 Skill Trees** — Marksmanship, Close Combat, Stealth Ops, Tactical Awareness, Endurance, Combat Driving, Field Medicine, Demolition
* **Skill Training** — Pay cash to train skills at broker NPCs (+1-3 per session)
* **7 Achievements** — First Blood, Centurion, Untouchable, Unbreakable Bond, Prestige Master, Ghost Protocol, Field Medic
* **Daily Rewards** — XP for all active BGs (24h cooldown)

### 🚗 Cinematic Arrival & Departure

* **Vehicle Arrival** — Rarity-based vehicle pool (common→sedan, legendary→luxury), AI driver parks near player, BG exits, walks up, greets
* **Foot Arrival** — NavMesh pathfinding with stuck detection and teleport fallback
* **50m Notification** — "Almost there!" alert (same as rde_carservice)
* **Departure** — Farewell animation based on relationship tier, walk away, last wave, fade out

### 🤝 Trading

* **Player-to-Player** — Offer BGs to other players at custom prices
* **Database-Backed** — `rde_bg_trades` table with pending/accepted/rejected status

### 🏪 Recruitment

* **3 Broker NPCs** — Eclipse Blvd, Vinewood, East LS (configurable locations)
* **3 Candidates** — Each visit generates 3 unique recruits with rarity, personality, top skill preview
* **Price Preview** — Estimated cost based on skills + rarity
* **Immersive Flow** — Walk up → ox_target → browse candidates → negotiate → hire

### 🎨 Formations

* **Follow** — Trail behind player
* **Diamond** — 360° coverage
* **Wedge** — Forward assault formation
* **Stack** — Single file column

---

## 📦 Installation

### Prerequisites

Ensure you have these resources installed and started **before** rde_bodyguards:

```
✅ ox_core       (latest version)
✅ ox_lib        (latest version)
✅ oxmysql       (latest version)
✅ ox_inventory  (latest version)
✅ ox_target     (latest version)
```

### Quick Setup

1. **Download & Extract**

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_bodyguards.git
```

2. **Add to server.cfg**

```cfg
# Core dependencies (start first)
ensure ox_core
ensure ox_lib
ensure oxmysql
ensure ox_inventory
ensure ox_target

# RDE Bodyguards (start after dependencies)
ensure rde_bodyguards
```

3. **Database**

The resource automatically creates the `rde_bodyguards` and `rde_bg_trades` tables on first start. No manual SQL required.

4. **Configuration** (Optional)

Edit `shared/config.lua` to customize:

```lua
Config.MaxActive   = 3            -- Max simultaneous active BGs
Config.MaxOwned    = 20           -- Max BGs a player can own
Config.Economy.moneyItem = 'money' -- ox_inventory cash item name

Config.Wounds.selfHealItem = 'bandage' -- Heal item name
Config.Wounds.medkitItem   = 'medkit'  -- Medkit item name
```

5. **Restart & Test**

```
refresh
restart rde_bodyguards
```

Test with: `/bg` or press `F6`

---

## 🎮 Usage

### For Players

**Recruiting:**
1. Type `/bg` → "Recruit Operative" → waypoint set to nearest broker
2. Walk to broker NPC → ox_target → browse 3 candidates
3. Review rarity, personality, top skill, estimated price
4. Confirm hire → BG added to your roster

**Deploying:**
1. `/bg` → "Roster" → select BG → "Deploy"
2. BG arrives by vehicle (rarity-based) or on foot
3. After arrival, 14 ox_target commands available on ped

**Commanding:**
- Walk up → ox_target for direct commands
- Radial menu for quick Follow/Stay/Attack/Heal (any distance)
- F6 menu for full command center with individual + mass orders

**Equipping:**
1. ox_target → "Manage Gear" → opens BG's stash inventory
2. Put weapons and bandages/medkits in stash
3. BG auto-equips best weapon, auto-heals when wounded

### For Developers

**Exports:**

```lua
-- Get bodyguard data by ID
local bg = exports.rde_bodyguards:getBodyguard(id)

-- Get all bodyguards for a character
local bgs = exports.rde_bodyguards:getPlayerBodyguards(charId)
```

---

## 🔧 Configuration Examples

### Adjust Self-Heal Behavior

```lua
Config.SelfHeal = {
    enabled         = true,
    checkIntervalMs = 5000,    -- Check every 5 seconds
    cooldownMs      = 30000,   -- 30s between auto-heals
    bandageHealPct  = 0.25,    -- Bandage restores 25% max HP
    medkitHealPct   = 0.55,    -- Medkit restores 55% max HP
    minHealthPct    = 0.70,    -- Only heal when below 70% HP
    combatHealPenalty = 0.50,  -- 50% less effective in combat
}
```

### Adjust Combat AI

```lua
Config.AI = {
    engageRange    = 70.0,     -- Threat detection range
    retreatHealthPct = 0.25,   -- Retreat below 25% HP
    headshotChance = 0.12,     -- 12% headshot chance
    flanking       = true,     -- Enable flanking behavior
    suppressiveFire = true,    -- Enable suppressive fire
}
```

### Adrenaline System

```lua
Config.Adrenaline = {
    enabled       = true,
    durationMs    = 12000,     -- 12 second adrenaline rush
    cooldownMs    = 45000,     -- 45 second cooldown
    speedBoost    = 1.15,      -- +15% speed
    accuracyBoost = 1.25,      -- +25% accuracy
}
```

### Pricing

```lua
Config.Pricing = {
    base        = { min = 8000, max = 25000 },
    perSkillPt  = 120,
    rarityBonus = {
        common = 0, uncommon = 4000, rare = 12000,
        epic = 28000, legendary = 65000,
    },
}
```

---

## 🐛 Troubleshooting

### Common Issues

**Self-Heal Not Working?**

```
✅ Check server console: "[RDE-BG] SelfHeal BG X: bandage=Y medkit=Z"
✅ Items must be in BG's STASH (💼 Manage Gear), NOT player inventory
✅ Item names must match Config.Wounds.selfHealItem / medkitItem exactly
✅ BG must be below 70% HP (Config.SelfHeal.minHealthPct)
✅ 30s cooldown between auto-heals (manual heal via ox_target bypasses this)
```

**Weapons Not Equipping?**

```
✅ Put weapons in BG's gear stash via 💼 Manage Gear (ox_target)
✅ Weapons auto-equip after arrival — wait for "Ready for duty" notification
✅ Use 🔫 Choose Weapon in ox_target for manual weapon selection
✅ Check server console for weapon detection logs
```

**BG Not Arriving?**

```
✅ Vehicle arrival timeout: 120 seconds (traffic/detours need time)
✅ Foot arrival timeout: 90 seconds with stuck detection
✅ If timeout: BG is removed, try deploying again
✅ Check server console: "[RDE-BG] BG X authorized for player Y"
```

**AnimDict Errors?**

```
✅ All anim loading wrapped in pcall — errors are non-fatal
✅ If you see errors, the anim won't play but nothing crashes
✅ v2.0 uses only verified GTA V animation dictionaries
```

---

## 📊 Performance

### Benchmark Results

```
Resource: rde_bodyguards
├─ Idle:     0.01ms (no active BGs)
├─ Active:   0.03-0.08ms (per active BG)
├─ Memory:   3.5 MB baseline
├─ Threads:  Dynamic (max 3 concurrent, LOD-managed)
├─ Network:  StateBag sync + minimal events
└─ LOD:      4-tier distance culling (50/150/300/500m)
```

### Optimization Features

- ✅ Level of Detail (LOD) — reduced processing at distance
- ✅ Distance culling — invisible beyond 500m
- ✅ Adaptive update rates — slower under load
- ✅ Thread pool — max 3 concurrent AI threads
- ✅ Batch sync — throttled state updates
- ✅ Smart delta sync — only changed values transmitted
- ✅ Prepared SQL statements
- ✅ Automatic entity cleanup

---

## 🤝 Contributing

We welcome contributions! Here's how:

### Reporting Bugs

1. Check [existing issues](https://github.com/RedDragonElite/rde_bodyguards/issues)
2. Create new issue with template
3. Include: FiveM version, ox_core version, console errors, steps to reproduce

### Submitting PRs

1. Fork repository
2. Create feature branch: `git checkout -b feature/AmazingFeature`
3. Commit changes: `git commit -m 'Add AmazingFeature'`
4. Push to branch: `git push origin feature/AmazingFeature`
5. Open Pull Request

### Code Style

- Follow existing Lua conventions
- Comment complex logic
- Test thoroughly before PR
- Update documentation

---

## 📄 License

This project is licensed under the **RDE Black Flag Source License v6.66**.

### What This Means

✅ Free use on your server — always, forever, $0.00
✅ Modification allowed — break it, fix it, learn from it
✅ Distribution allowed — share it freely
⚠️ Credit header must remain — don't be a skid
❌ **NO SELLING** — Tebex, Patreon, "Premium Packs" = DMCA + public shame
❌ Liability and warranty not provided

---

## 🙏 Credits & Acknowledgments

### Frameworks & Libraries

- [ox_core](https://github.com/overextended/ox_core) — Core framework
- [ox_lib](https://github.com/overextended/ox_lib) — UI & utility library
- [ox_inventory](https://github.com/overextended/ox_inventory) — Inventory system
- [ox_target](https://github.com/overextended/ox_target) — Targeting system
- [oxmysql](https://github.com/overextended/oxmysql) — Database connector

### Special Thanks

- Overextended team for the ox ecosystem
- FiveM community for testing & feedback
- Contributors

---

## 💬 Support

### Get Help

- 🐛 [Issue Tracker](https://github.com/RedDragonElite/rde_bodyguards/issues) — Bug reports
- 💡 [Discussions](https://github.com/RedDragonElite/rde_bodyguards/discussions) — Feature requests

---

## 📈 Statistics

<div align="center">

![GitHub Downloads](https://img.shields.io/github/downloads/RedDragonElite/rde_bodyguards/total?style=for-the-badge)
![GitHub Stars](https://img.shields.io/github/stars/RedDragonElite/rde_bodyguards?style=for-the-badge)
![GitHub Forks](https://img.shields.io/github/forks/RedDragonElite/rde_bodyguards?style=for-the-badge)
![GitHub Issues](https://img.shields.io/github/issues/RedDragonElite/rde_bodyguards?style=for-the-badge)

</div>

---

<div align="center">

### ⭐ If you find this useful, please give it a star!

**Made with ❤️ by .:: RedDragonElite ::. | SerpentsByte**

*"We build the future on the graves of paid resources."*

[⬆ Back to Top](#️-rde--bodyguards--next-gen-ai-protection-system)

</div>
