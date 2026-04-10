# 🛡️ RDE | Ultimate Bodyguard System | Next-Gen AI Protection for FiveM

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![FiveM](https://img.shields.io/badge/FiveM-Ready-blue.svg)](https://fivem.net/)
[![ox_core](https://img.shields.io/badge/Framework-ox__core-green.svg)](https://github.com/overextended/ox_core)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](#)
[![Stars](https://img.shields.io/github/stars/RedDragonElite/rde_bodyguards?style=social)](#)

**The most advanced AI bodyguard system ever built for FiveM — self-healing NPCs, full weapon management, tactical combat AI, adrenaline rushes, and cinematic immersion**

[Features](#-features) • [Installation](#-installation) • [Commands](#-commands) • [Configuration](#-configuration) • [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

**RDE Bodyguards** delivers a complete private security experience. Recruit, train, equip, and command AI bodyguards with deep personality, progression, and bond systems. Every bodyguard has their own inventory, skill tree, morale, wounds, and relationship tier — and they use items from their gear to heal themselves in combat.

### 🌟 Why Choose RDE Bodyguards?

* ✅ **Self-Healing AI** — BGs consume bandage/medkit from their ox_inventory stash
* ✅ **Full ox_target Commands** — 14 direct commands on every bodyguard ped
* ✅ **Remote Control** — Command all BGs from F6 menu at any distance
* ✅ **Weapon Management** — Auto-equip, holster/unholster, weapon selection from inventory
* ✅ **Tactical Combat** — Cover system, flanking, suppressive fire, adrenaline rushes
* ✅ **Deep Progression** — 100 levels, 10 prestige tiers, 8 skill trees, achievements
* ✅ **Bond System** — 5 relationship tiers, personality-driven interactions, session memories
* ✅ **Multiplayer Sync** — StateBag + NetworkEntity sync across all clients
* ✅ **Cinematic Arrival** — Vehicle/foot arrival with parking, greetings, particle effects
* ✅ **Production Ready** — pcall safety, MySQL fallbacks, LOD, distance culling

---

## ✨ Features

### 🩹 Self-Heal System

| | |
|---|---|
| **Automatic Healing** | BGs check every 5 seconds if wounded and consume bandage or medkit from their stash inventory. Smart item choice: medkit for critical/serious wounds, bandage for minor. Medical skill improves effectiveness (+0.5% per skill point). Healing is 50% less effective during combat. |
| **Buddy Heal** | BGs with Medical skill 40+ scan for wounded allies within 8m, walk to them, play CPR animation, and heal them. Grants XP and morale to the healer. |
| **Manual Heal** | Player can order any BG to heal via ox_target or F6 menu, bypassing cooldowns. |
| **Bulletproof Backend** | 3-method stash access: `GetInventoryItems` → `GetInventory` → direct MySQL query on `ox_inventory` table. Item removal also uses MySQL fallback. |

### 🔫 Weapon System

| | |
|---|---|
| **Auto-Equip** | BGs automatically equip the best weapon from their stash after arrival. 60+ GTA V weapons recognized with priority ranking. |
| **Weapon Selection** | Player chooses which weapon the BG uses via ox_target menu. All weapons from inventory listed with ammo counts. |
| **Holster Toggle** | Holster/unholster commands via ox_target and F6 menu. BGs can be set to unarmed. |
| **Re-Equip Thread** | Every 30s, BGs check if they've become unarmed and re-equip automatically. |

### 🎯 ox_target Command System

Every active bodyguard ped has 14 direct commands accessible via ox_target:

| Command | Description | Range |
|---|---|---|
| 💬 Interact | Bond interaction with personality animation | 2.5m |
| 🚶 Follow Me | BG follows player in formation | 8m |
| 🛑 Stay Here | BG holds current position (guard mode) | 8m |
| 🔄 Patrol Area | BG patrols around current position | 8m |
| 🎯 Kill Target | BG attacks the ped you're aiming at | 12m |
| 🔥 Attack All | BG engages all hostiles in area | 12m |
| ☮️ Peaceful | Disable combat — BG ignores threats | 8m |
| 😤 Aggressive | Enable combat — BG engages threats | 8m |
| 🩹 Heal | Use bandage/medkit from gear | 3m |
| 🔒 Holster | Put weapon away | 4m |
| 🔓 Draw Weapon | Equip weapon | 4m |
| 🔫 Choose Weapon | Select specific weapon from inventory | 3m |
| 💼 Manage Gear | Open BG's ox_inventory stash | 2.5m |
| 👋 Dismiss | Send BG away with departure animation | 3m |

### 📻 Radial Menu (Remote Control)

All commands available from any distance via radial menu and F6 Bodyguard Command Center:

* **Per-BG Commands** — Follow, Stay, Attack All, Heal (radial)
* **Global Commands** — All: Follow / Stay / Attack / Heal / Holster / Draw (radial + F6)
* **Individual Quick Orders** — Full 14-command menu per BG accessible from F6

### ⚡ Combat AI

| Feature | Description |
|---|---|
| **Threat Detection** | Multi-layer 3-scan confirmation system prevents ghost enemies |
| **Tactical Cover** | BGs with Tactics 20+ seek cover when HP < 50% |
| **Flanking** | BGs with Tactics 65+ flank enemies from random angles |
| **Suppressive Fire** | BGs with Tactics 70+ lay down covering fire |
| **Adrenaline Rush** | 12s buff (+25% accuracy, +15% speed) on player damage or kill |
| **Last Stand** | Below 15% HP: +40% accuracy, 3 ticks invulnerability |
| **Environmental Awareness** | Night: -18% accuracy (reduced by Tactics skill). Rain: -10% |
| **Bond Combat Bonus** | +3% effectiveness per relationship tier (max +12% at Tier 5) |
| **Auto-Retreat** | Critically wounded BGs with Medical 30+ retreat to player |

### 🏷️ 3D World Labels

Rich status information displayed above each BG's head:

* **Name + Level** in rarity color
* **Wound Status** with severity icons (`[!!]` critical, `[!]` serious, `[*]` minor)
* **HP Percentage** with color gradient (green → yellow → orange → red)
* **Morale Warning** at Shaken (<50) and Low (<30)
* **State Indicator** — `>> COMBAT <<`, `>> AVENGE <<`, `[GUARDING]`, `[PATROL]`
* **Adrenaline** and **Last Stand** active indicators
* **Holstered** indicator when weapon is put away

### 📊 HUD System

NUI-based HUD panel (top-right) showing all active BGs:

* Name, level, prestige, rarity color
* HP and morale bars with segment marks
* Wound, morale, and relationship tier chips
* Adrenaline (pink) and Last Stand (orange) status chips
* Combat state with pulsating card animation
* Clickable cards open full BG menu

### 🎭 Bond & Personality System

* **5 Personalities** — Stoic, Loyal, Aggressive, Caring, Professional
* **5 Relationship Tiers** — Hired Hand → Comrade → Trusted Ally → Blood Brother → Legendary Bond
* **Session Memories** — BGs remember kills, protects, deaths, heals, milestones
* **Milestone Celebrations** — Personality-specific animations and voice lines
* **Fatigue System** — BGs lose effectiveness after 45min, rest by dismissing 10min
* **Witness System** — BGs enter avenge mode if they witness the player's death

### 📈 Progression

* **100 Levels** with exponential XP curve
* **10 Prestige Tiers** — Reset to Lv.1, all skills +10
* **8 Skill Trees** — Shooting, Combat, Stealth, Tactics, Stamina, Driving, Medical, Explosives
* **Trainable Skills** — Pay to train at broker NPCs
* **Achievements** — 7 unlockable achievements with cash rewards
* **Daily Rewards** — XP for all active BGs

### 🚗 Cinematic Arrival & Departure

* **Vehicle Arrival** — Rarity-based vehicle pool, AI driver, parking sequence, key handover
* **Foot Arrival** — NavMesh pathfinding, stuck detection, teleport fallback
* **Departure** — Farewell animation (relationship-based), walk away, fade out
* **50m Notification** — "Almost there!" alert like rde_carservice

### 🤝 Trading System

* **Player-to-Player Trades** — Offer BGs to other players at custom prices
* **Trade Validation** — Ownership checks, payment processing, status tracking

---

## 📦 Installation

### Prerequisites

```
✅ ox_core       (latest)
✅ ox_lib        (latest)
✅ oxmysql       (latest)
✅ ox_inventory  (latest)
✅ ox_target     (latest)
```

### Quick Setup

1. **Download & Extract**
```bash
cd resources
git clone https://github.com/RedDragonElite/rde_bodyguards.git
```

2. **Add to server.cfg**
```cfg
# Dependencies (start first)
ensure ox_core
ensure ox_lib
ensure oxmysql
ensure ox_inventory
ensure ox_target

# RDE Bodyguards
ensure rde_bodyguards
```

3. **Database**

The resource automatically creates the `rde_bodyguards` table on first start. No manual SQL required.

4. **Restart & Test**
```
refresh
restart rde_bodyguards
```

Test with: `/bg` or press `F6`

---

## 🎮 Commands

### Chat Commands

| Command | Description |
|---|---|
| `/bg` | Open Bodyguard Command Center (F6) |
| `/bg_follow` | All BGs: follow player |
| `/bg_guard` | All BGs: hold position |
| `/bg_patrol` | All BGs: patrol area |
| `/bg_dismiss` | Dismiss all active BGs |

### Keybinds

| Key | Action |
|---|---|
| `F6` | Open Bodyguard Command Center |

---

## 🔧 Configuration

All configuration is in `shared/config.lua`. Key settings:

### Core
```lua
Config.MaxActive   = 3       -- Max simultaneous active BGs
Config.MaxOwned    = 20      -- Max BGs a player can own
```

### Self-Heal
```lua
Config.SelfHeal = {
    enabled         = true,
    checkIntervalMs = 5000,   -- Check every 5s
    cooldownMs      = 30000,  -- 30s between heals
    bandageHealPct  = 0.25,   -- 25% HP restore
    medkitHealPct   = 0.55,   -- 55% HP restore
    minHealthPct    = 0.70,   -- Heal when below 70%
}
```

### Heal Items
```lua
Config.Wounds = {
    selfHealItem = 'bandage', -- Item name in ox_inventory
    medkitItem   = 'medkit',  -- Item name in ox_inventory
}
```

### Economy
```lua
Config.Economy = {
    moneyItem = 'money',      -- ox_inventory cash item
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

### Self-Heal Not Working?
```
✅ Check server console for: "[RDE-BG] SelfHeal BG X: bandage=Y medkit=Z"
✅ Ensure items are named exactly as Config.Wounds.selfHealItem / medkitItem
✅ Verify items are in the BG's stash (💼 Manage Gear), not player inventory
✅ BG must be below 70% HP to auto-heal (Config.SelfHeal.minHealthPct)
```

### Weapons Not Equipping?
```
✅ Put weapons in BG's gear stash (💼 Manage Gear via ox_target)
✅ Weapon names must follow ox_inventory convention (e.g. 'WEAPON_PISTOL')
✅ Check server console for weapon detection logs
✅ Try manual equip via 🔫 Choose Weapon in ox_target
```

### AnimDict Errors?
```
✅ v5.2 wraps all anim loading in pcall — errors are non-fatal
✅ If you see errors, the anim simply won't play but nothing crashes
```

### BG Not Arriving?
```
✅ Vehicle arrival has 120s timeout — traffic/detours need time
✅ Foot arrival has 90s timeout with stuck detection
✅ Check server console for spawn authorization logs
```

---

## 📊 Performance

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
- ✅ Level of Detail (LOD) system — reduced processing at distance
- ✅ Distance culling — invisible beyond 500m
- ✅ Adaptive update rates — slower updates under load
- ✅ Thread pool management — max 3 concurrent AI threads
- ✅ Batch sync — throttled state updates
- ✅ Smart delta sync — only changed values transmitted

---

## 🤝 Contributing

1. Fork repository
2. Create feature branch: `git checkout -b feature/AmazingFeature`
3. Commit changes: `git commit -m 'Add AmazingFeature'`
4. Push to branch: `git push origin feature/AmazingFeature`
5. Open Pull Request

### Reporting Bugs
1. Check [existing issues](https://github.com/RedDragonElite/rde_bodyguards/issues)
2. Include: FiveM version, ox_core version, console errors, steps to reproduce

---

## 📄 License

This project is licensed under the **MIT License**.

### What This Means
✅ Commercial use allowed
✅ Modification allowed
✅ Distribution allowed
✅ Private use allowed
⚠️ License and copyright notice required
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

---

## 💬 Support

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

[⬆ Back to Top](#️-rde--ultimate-bodyguard-system--next-gen-ai-protection-for-fivem)

</div>
