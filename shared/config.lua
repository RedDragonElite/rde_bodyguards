-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v5.0  —  shared/config.lua
-- Per RDE Standards: Config = {} global, helpers at bottom
-- v5.0: Self-Heal · Weapon Equip · Tactical Cover · Adrenaline
-- ============================================================

Config = {}

-- ────────────────────────────────────────────────────────────
-- CORE
-- ────────────────────────────────────────────────────────────
Config.MaxActive   = 3
Config.MaxOwned    = 20
Config.Debug       = false

-- ────────────────────────────────────────────────────────────
-- WEAPONS & INVENTORY
-- ────────────────────────────────────────────────────────────
Config.Weapons = {
    useInventoryWeapons = true,   -- BGs use weapons from their ox_inventory
    unlimitedAmmo       = false,  -- If false, BGs consume ammo from inventory
    defaultMelee        = true,   -- Use fists if no weapons in inventory
    autoEquipBest       = true,   -- Auto-equip highest damage weapon
    allowWeaponSwitch   = true,   -- Allow player to select BG weapon via menu
    equipOnSpawn        = true,   -- v5.0: Auto-equip weapon immediately after arrival
    reEquipIntervalMs   = 30000,  -- v5.0: Re-check inventory for better weapons periodically
}

-- ────────────────────────────────────────────────────────────
-- ECONOMY
-- ────────────────────────────────────────────────────────────
Config.Economy = {
    moneyItem = 'money',   -- ox_inventory item name for cash
}

-- ────────────────────────────────────────────────────────────
-- PRICING
-- ────────────────────────────────────────────────────────────
Config.Pricing = {
    base        = { min = 8000, max = 25000 },
    perSkillPt  = 120,
    rarityBonus = {
        common    = 0,
        uncommon  = 4000,
        rare      = 12000,
        epic      = 28000,
        legendary = 65000,
    },
}

-- ────────────────────────────────────────────────────────────
-- PROGRESSION
-- ────────────────────────────────────────────────────────────
Config.MaxLevel    = 100
Config.MaxPrestige = 10
Config.BaseXP      = 1000
Config.XPMult      = 1.12

Config.XPRewards = {
    kill_ped     = 60,
    kill_player  = 250,
    kill_cop     = 120,
    headshot     = 90,
    stealth_kill = 110,
    protect      = 300,
    heal_player  = 140,
    heal_self    = 40,     -- v5.0: XP for self-healing
    heal_buddy   = 80,     -- v5.0: XP for healing another BG
    guard_tick   = 4,
    patrol_tick  = 2,
}

-- ────────────────────────────────────────────────────────────
-- SKILLS
-- ────────────────────────────────────────────────────────────
Config.Skills = {
    shooting   = { label='Marksmanship',      icon='crosshairs',        color='#ef4444', max=100, trainCost=1500 },
    combat     = { label='Close Combat',      icon='hand-fist',         color='#f59e0b', max=100, trainCost=1200 },
    stealth    = { label='Stealth Ops',       icon='user-secret',       color='#8b5cf6', max=100, trainCost=2000 },
    tactics    = { label='Tactical Awareness',icon='brain',             color='#ec4899', max=100, trainCost=2500 },
    stamina    = { label='Endurance',         icon='heart-pulse',       color='#10b981', max=100, trainCost=1000 },
    driving    = { label='Combat Driving',    icon='car',               color='#3b82f6', max=100, trainCost=1800 },
    medical    = { label='Field Medicine',    icon='briefcase-medical', color='#22c55e', max=100, trainCost=2200 },
    explosives = { label='Demolition',        icon='bomb',              color='#dc2626', max=100, trainCost=2800 },
}

-- ────────────────────────────────────────────────────────────
-- MORALE
-- ────────────────────────────────────────────────────────────
Config.Morale = {
    startValue      = 75,
    decayPerMin     = 1,
    gainOnKill      = 8,
    gainOnProtect   = 12,
    gainOnInteract  = 15,
    gainOnSelfHeal  = 3,    -- v5.0: Morale boost when BG heals themselves
    gainOnBuddyHeal = 6,    -- v5.0: Morale boost when BG heals a buddy
    penaltyOnDeath  = 30,
    thresholds = {
        { min=80, label='Motivated', combatMult=1.20, color='#10b981' },
        { min=50, label='Steady',    combatMult=1.00, color='#3b82f6' },
        { min=25, label='Shaken',    combatMult=0.80, color='#f59e0b' },
        { min=0,  label='Broken',    combatMult=0.55, color='#ef4444' },
    },
}

-- ────────────────────────────────────────────────────────────
-- WOUNDS
-- ────────────────────────────────────────────────────────────
Config.Wounds = {
    enabled      = true,
    healOverTime = true,
    healTickMs   = 60000,
    selfHealItem = 'bandage',
    medkitItem   = 'medkit',
    order = { 'none', 'minor', 'serious', 'critical' },
    types = {
        none     = { speedMult=1.00, accuracyMult=1.00, label='Healthy',      color='#10b981' },
        minor    = { speedMult=0.95, accuracyMult=0.92, label='Minor Wound',  color='#fbbf24' },
        serious  = { speedMult=0.80, accuracyMult=0.75, label='Serious',      color='#f97316' },
        critical = { speedMult=0.55, accuracyMult=0.50, label='Critical',     color='#ef4444' },
    },
}

-- ────────────────────────────────────────────────────────────
-- v5.0: SELF-HEAL SYSTEM
-- BGs with bandage/medkit in inventory auto-heal when wounded
-- ────────────────────────────────────────────────────────────
Config.SelfHeal = {
    enabled           = true,
    checkIntervalMs   = 5000,     -- How often to check if BG should self-heal
    cooldownMs        = 30000,    -- Minimum time between self-heal attempts
    animDurationMs    = 3500,     -- Duration of the healing animation
    bandageHealPct    = 0.25,     -- Bandage restores 25% max HP
    medkitHealPct     = 0.55,     -- Medkit restores 55% max HP
    bandageWoundClear = 1,        -- Bandage reduces wound by 1 tier
    medkitWoundClear  = 2,        -- Medkit reduces wound by 2 tiers
    minHealthPct      = 0.70,     -- Only self-heal when HP is below this %
    combatHealPenalty = 0.50,     -- Healing is 50% less effective during combat
    medicalSkillBonus = true,     -- Medical skill improves healing effectiveness
    -- Medical skill bonus: +0.5% heal per medical skill point
    medicalBonusPer   = 0.005,
    -- Priority: medkit if critical/serious, bandage for minor
    smartItemChoice   = true,
}

-- ────────────────────────────────────────────────────────────
-- v5.0: BUDDY HEAL SYSTEM
-- BGs with medical skill > 40 heal nearby wounded BGs
-- ────────────────────────────────────────────────────────────
Config.BuddyHeal = {
    enabled           = true,
    minMedicalSkill   = 40,       -- Minimum medical skill to buddy-heal
    scanRadiusM       = 8.0,      -- Scan radius for wounded buddies
    cooldownMs        = 45000,    -- Cooldown between buddy heals
    healPct           = 0.20,     -- Base heal amount (20% of target max HP)
    checkIntervalMs   = 8000,     -- How often to scan for wounded buddies
}

-- ────────────────────────────────────────────────────────────
-- v5.0: ADRENALINE SYSTEM
-- Temporary combat buff when player takes damage or BG gets a kill
-- ────────────────────────────────────────────────────────────
Config.Adrenaline = {
    enabled           = true,
    triggerOnPlayerHit = true,     -- Trigger when player takes damage
    triggerOnKill      = true,     -- Trigger after BG gets a kill
    durationMs        = 12000,    -- Adrenaline lasts 12 seconds
    cooldownMs        = 45000,    -- Cooldown between adrenaline rushes
    speedBoost        = 1.15,     -- 15% speed boost during adrenaline
    accuracyBoost     = 1.25,     -- 25% accuracy boost
    damageResistPct   = 0.15,     -- 15% damage resistance
}

-- ────────────────────────────────────────────────────────────
-- v5.0: TACTICAL COVER SYSTEM
-- BGs seek cover during combat based on tactics skill
-- ────────────────────────────────────────────────────────────
Config.TacticalCover = {
    enabled           = true,
    minTacticsSkill   = 20,       -- Min tactics to use cover
    seekCoverHealthPct= 0.50,     -- Seek cover when below 50% HP
    coverScanRadius   = 25.0,     -- Radius to scan for cover
    coverDurationMs   = 4000,     -- Stay in cover for 4s then peek
    reloadInCover     = true,     -- Go to cover during reload
}

-- ────────────────────────────────────────────────────────────
-- v5.0: LAST STAND SYSTEM
-- Critically wounded BGs get a temporary fighting spirit boost
-- ────────────────────────────────────────────────────────────
Config.LastStand = {
    enabled           = true,
    triggerHealthPct   = 0.15,    -- Trigger below 15% HP
    durationMs        = 10000,   -- Last stand lasts 10 seconds
    accuracyBoost     = 1.40,    -- 40% accuracy boost (fighting for survival)
    speedBoost        = 1.10,    -- 10% speed boost
    invulnerableTicks = 3,       -- Invulnerable for ~3 health-check ticks
}

-- ────────────────────────────────────────────────────────────
-- v5.0: ENVIRONMENTAL AWARENESS
-- ────────────────────────────────────────────────────────────
Config.Environment = {
    enabled           = true,
    nightAccuracyMult = 0.82,    -- Reduced accuracy at night (22:00-06:00)
    rainAccuracyMult  = 0.90,    -- Reduced accuracy in rain
    nightTacticsBonus = 0.005,   -- Per tactics point, reduces night penalty
    flashlightWeapon  = true,    -- BGs toggle flashlight attachments at night
}

-- ────────────────────────────────────────────────────────────
-- RELATIONSHIP
-- ────────────────────────────────────────────────────────────
Config.Relationship = {
    tiers = {
        { level=1, name='Hired Hand',     required=0,     color='#9ca3af', icon='handshake'     },
        { level=2, name='Comrade',        required=1000,  color='#60a5fa', icon='shield-halved' },
        { level=3, name='Trusted Ally',   required=5000,  color='#34d399', icon='star'          },
        { level=4, name='Blood Brother',  required=15000, color='#fbbf24', icon='heart'         },
        { level=5, name='Legendary Bond', required=35000, color='#a855f7', icon='crown'         },
    },
    interactCooldownMs = 180000,
    gainPerInteract    = { min=15, max=60 },
    decayPerDay        = 8,
    -- v5.0: Bond tier combat bonuses
    combatBonusPerTier = 0.03,   -- +3% combat effectiveness per relationship tier
}

-- ────────────────────────────────────────────────────────────
-- FORMATIONS
-- ────────────────────────────────────────────────────────────
Config.Formations = {
    follow  = { slots = { {angle=180,dist=2.8},{angle=135,dist=3.5},{angle=225,dist=3.5},{angle=90,dist=4.5},{angle=270,dist=4.5} } },
    diamond = { slots = { {angle=180,dist=3.0},{angle=90,dist=3.0},{angle=270,dist=3.0},{angle=0,dist=3.5},{angle=180,dist=5.5} } },
    wedge   = { slots = { {angle=160,dist=3.5},{angle=200,dist=3.5},{angle=135,dist=5.0},{angle=225,dist=5.0},{angle=180,dist=6.5} } },
    stack   = { slots = { {angle=180,dist=2.5},{angle=180,dist=4.5},{angle=180,dist=6.5},{angle=180,dist=8.5},{angle=180,dist=10.5} } },
}

-- ────────────────────────────────────────────────────────────
-- AI
-- ────────────────────────────────────────────────────────────
Config.AI = {
    followUpdateMs   = 600,
    threatScanMs     = 1500,
    healthCheckMs    = 1000,
    engageRange      = 70.0,
    protectionRadius = 18.0,
    bodyBlockChance  = 0.35,
    retreatHealthPct = 0.25,
    headshotChance   = 0.12,
    suppressiveFire  = true,
    flanking         = true,
    patrolRadius     = 12.0,
    patrolWaitMs     = { min=4000, max=9000 },
}

-- ────────────────────────────────────────────────────────────
-- VEHICLES
-- ────────────────────────────────────────────────────────────
Config.Vehicles = {
    standard   = { 'baller3','dubsta2','xls','granger','serrano' },
    tactical   = { 'insurgent3','menacer','zhaba' },
    luxury     = { 'cognoscenti2','schafter6','stretch' },
    helicopter = { 'volatus','swift2' },
    spawnDist  = { min=80, max=180 },
    deleteDelayMs = 90000,
}

-- ────────────────────────────────────────────────────────────
-- PED MODELS
-- ────────────────────────────────────────────────────────────
Config.Peds = {
    male = {
        'a_m_m_acult_01', 'a_m_m_acult_02', 'a_m_m_beach_01', 'a_m_m_beach_02',
        'a_m_m_bevhills_01', 'a_m_m_bevhills_02', 'a_m_m_business_01',
        'a_m_m_eastsa_01', 'a_m_m_eastsa_02', 'a_m_m_farmer_01',
        'a_m_m_genfat_01', 'a_m_m_genfat_02', 'a_m_m_golfer_01',
        'a_m_m_hasjew_01', 'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02',
        'a_m_m_indian_01', 'a_m_m_ktown_01', 'a_m_m_malibu_01',
        'a_m_m_mexcntry_01', 'a_m_m_mexlabor_01', 'a_m_m_og_boss_01',
        'a_m_m_paparazzi_01', 'a_m_m_polynesian_01', 'a_m_m_prolhost_01',
        'a_m_m_rurmeth_01', 'a_m_m_salton_01', 'a_m_m_salton_02',
        'a_m_m_salton_03', 'a_m_m_salton_04', 'a_m_m_skater_01',
        'a_m_m_skidrow_01', 'a_m_m_soucent_01', 'a_m_m_soucent_02',
        'a_m_m_soucent_03', 'a_m_m_soucent_04', 'a_m_m_stlat_02',
        'a_m_m_tennis_01', 'a_m_m_tourist_01', 'a_m_m_trampbeac_01',
        'a_m_m_tramp_01', 'a_m_m_vinewood_01', 'a_m_m_vinewood_02',
        'a_m_m_vinewood_03', 'a_m_m_vinewood_04',
        'a_m_y_scrubs_01', 'a_m_y_jetski_01', 'a_m_y_motox_01',
        'a_m_y_motox_02', 'a_m_y_dhill_01', 'a_m_y_roadcyc_01',
        'g_m_m_armboss_01', 'g_m_m_chiboss_01', 'g_m_m_chicold_01',
        'g_m_m_korboss_01', 'g_m_m_mexboss_01', 'g_m_m_mexboss_02',
        'g_m_y_armgoon_02', 'g_m_y_azteca_01', 'g_m_y_ballaeast_01',
        'g_m_y_ballaorig_01', 'g_m_y_ballasout_01', 'g_m_y_famca_01',
        'g_m_y_famdnf_01', 'g_m_y_famfor_01', 'g_m_y_korean_01',
        'g_m_y_korean_02', 'g_m_y_lost_01', 'g_m_y_lost_02',
        'g_m_y_lost_03', 'g_m_y_mexgang_01', 'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03', 'g_m_y_pologoon_01',
        'g_m_y_pologoon_02', 'g_m_y_salvaboss_01', 'g_m_y_salvagoon_01',
        'g_m_y_salvagoon_02', 'g_m_y_salvagoon_03',
        's_m_m_autoshop_01', 's_m_m_autoshop_02', 's_m_m_bouncer_01',
        's_m_m_chemsec_01', 's_m_m_ciasec_01', 's_m_m_cntrybar_01',
        's_m_m_doctor_01', 's_m_m_dockwork_01', 's_m_m_fiboffice_01',
        's_m_m_fibsec_01', 's_m_m_fireman_01', 's_m_m_gaffer_01',
        's_m_m_gardener_01', 's_m_m_gentransport', 's_m_m_hairdress_01',
        's_m_m_highsec_01', 's_m_m_highsec_02', 's_m_m_janitor',
        's_m_m_lathandy_01', 's_m_m_lsmetro_01', 's_m_m_mariachi_01',
        's_m_m_movalien_01', 's_m_m_movblimp_01', 's_m_m_movspace_01',
        's_m_m_paramedic_01', 's_m_m_pilot_01', 's_m_m_pilot_02',
        's_m_m_postal_01', 's_m_m_postal_02', 's_m_m_scientist_01',
        's_m_m_security_01', 's_m_m_strperf_01', 's_m_m_strpreach_01',
        's_m_m_strvend_01', 's_m_m_trucker_01', 's_m_m_ups_01',
        's_m_m_ups_02', 's_m_y_airworker', 's_m_y_ammucity_01',
        's_m_y_armymech_01', 's_m_y_autopsy_01', 's_m_y_barman_01',
        's_m_y_baywatch_01', 's_m_y_blackops_01', 's_m_y_blackops_02',
        's_m_y_bodybuild_01', 's_m_y_bouncer_01', 's_m_y_chef_01',
        's_m_y_clown_01', 's_m_y_clubbar_01', 's_m_y_construct_01',
        's_m_y_construct_02', 's_m_y_dealer', 's_m_y_devinsec_01',
        's_m_y_dockwork_01', 's_m_y_doorman_01', 's_m_y_dwairy_01',
        's_m_y_factory_01', 's_m_y_fireman_01', 's_m_y_grip_01',
        's_m_y_hwaycop_01', 's_m_y_marine_01', 's_m_y_marine_02',
        's_m_y_marine_03', 's_m_y_mime', 's_m_y_pestcont_01',
        's_m_y_pilot_01', 's_m_y_prismuscl_01', 's_m_y_prisoner_01',
        's_m_y_robber_01', 's_m_y_sheriff_01', 's_m_y_shop_mask',
        's_m_y_strvend_01', 's_m_y_swat_01', 's_m_y_uscg_01',
        's_m_y_valet_01', 's_m_y_vindouche_01', 's_m_y_waiter_01',
        's_m_y_winclean_01', 's_m_y_xmech_01', 's_m_y_xmech_02',
        'u_m_y_biker_01', 'u_m_y_biker_02', 'u_m_y_chip',
        'u_m_y_fibmugger_01', 'u_m_y_guido_01', 'u_m_y_gunvend_01',
        'u_m_y_hippie_01', 'u_m_y_imporage', 'u_m_y_juggernaut_01',
        'u_m_y_proldriver_01', 'u_m_y_prolhost_01', 'u_m_y_paparazzi',
        'u_m_y_party_01', 'u_m_y_rsranger_01', 'u_m_y_staggrm_01',
        'u_m_y_tattoo_01',
    },

    female = {
        'a_f_y_business_01', 'a_f_y_business_02', 'a_f_y_business_03',
        'a_f_y_epsilon_01', 'a_f_y_fitness_01', 'a_f_y_fitness_02',
        'a_f_y_gencaspat_01', 'a_f_y_genhot_01', 'a_f_y_genstreet_01',
        'a_f_y_genstreet_02', 'a_f_y_mistress', 'a_f_y_runner_01',
        'a_f_y_scrubs_01', 'a_f_y_studioparty_01', 'a_f_y_studioparty_02',
        'a_f_y_vinewood_01', 'a_f_y_vinewood_02', 'a_f_y_vinewood_03',
        'a_f_y_vinewood_04', 'a_f_y_hipster_01', 'a_f_y_hipster_02',
        'a_f_y_hipster_03', 'a_f_y_hipster_04',
        'a_f_y_beach_01', 'a_f_y_bevhills_01', 'a_f_y_bevhills_02',
        'a_f_y_bevhills_03', 'a_f_y_bevhills_04',
        'g_f_y_ballas_01', 'g_f_y_famca_01', 'g_f_y_lost_01',
        'g_f_y_vagos_01',
        's_f_m_autoshop_01', 's_f_m_fembarber', 's_f_m_maid_01',
        's_f_m_shop_high', 's_f_m_sweatshop_01', 's_f_y_airhostess_01',
        's_f_y_bartender_01', 's_f_y_baywatch_01', 's_f_y_beachbarstaff_01',
        's_f_y_casino_01', 's_f_y_clubbar_01', 's_f_y_factory_01',
        's_f_y_hooker_01', 's_f_y_hooker_02', 's_f_y_hooker_03',
        's_f_y_migrant_01', 's_f_y_movalien_01', 's_f_y_ranger_01',
        's_f_y_scrubs_01', 's_f_y_sheriff_01', 's_f_y_shop_low',
        's_f_y_shop_mid', 's_f_y_stripper_01', 's_f_y_stripper_02',
        's_f_y_stripperlite', 's_f_y_sweatshop_01', 's_f_y_uscg_01',
        's_f_y_warrens_01',
    },
}

-- ────────────────────────────────────────────────────────────
-- RARITIES
-- ────────────────────────────────────────────────────────────
Config.Rarities = {
    { key='common',    weight=60, skillBonus=0,   label='Common',    color='#9ca3af' },
    { key='uncommon',  weight=25, skillBonus=10,  label='Uncommon',  color='#4ade80' },
    { key='rare',      weight=10, skillBonus=25,  label='Rare',      color='#60a5fa' },
    { key='epic',      weight=4,  skillBonus=50,  label='Epic',      color='#a78bfa' },
    { key='legendary', weight=1,  skillBonus=100, label='Legendary', color='#fbbf24' },
}
Config.RarityByKey = {}
for _, r in ipairs(Config.Rarities) do
    Config.RarityByKey[r.key] = r
end

-- ────────────────────────────────────────────────────────────
-- DEATH / REVIVE
-- ────────────────────────────────────────────────────────────
Config.Death = {
    permanent        = false,
    reviveBaseCost   = 4500,
    reviveCostPerLvl = 200,
    earlyReviveMs    = 300000,
    xpPenaltyPct     = 0.15,
    affectionPenalty = 400,
}

-- ────────────────────────────────────────────────────────────
-- STASHES
-- ────────────────────────────────────────────────────────────
Config.Stash = {
    prefix = 'rde_bg_',
    slots  = 30,
    weight = 100000,
}

-- ────────────────────────────────────────────────────────────
-- ACHIEVEMENTS
-- ────────────────────────────────────────────────────────────
Config.Achievements = {
    { id='first_blood',    name='First Blood',        desc='First kill',               icon='droplet', requirement='kills',    value=1,   reward=500    },
    { id='centurion',      name='Centurion',           desc='100 kills',                icon='shield',  requirement='kills',    value=100, reward=10000  },
    { id='untouchable',    name='Untouchable',         desc='50 player protections',    icon='lock',    requirement='protects', value=50,  reward=15000  },
    { id='max_bond',       name='Unbreakable Bond',    desc='Reach max relationship',   icon='heart',   requirement='relation', value=5,   reward=25000  },
    { id='prestige_max',   name='Prestige Master',     desc='Max prestige reached',     icon='crown',   requirement='prestige', value=10,  reward=100000 },
    { id='ghost_protocol', name='Ghost Protocol',      desc='25 stealth skill',         icon='ghost',   requirement='stealth',  value=25,  reward=8000   },
    { id='field_medic',    name='Field Medic',         desc='Medical skill 50+',        icon='kit-medical', requirement='medical', value=50, reward=12000 },
}

-- ────────────────────────────────────────────────────────────
-- HUD
-- ────────────────────────────────────────────────────────────
Config.HUD = {
    enabled      = true,
    maxVisible   = 5,
    updateRateMs = 500,
}

-- ────────────────────────────────────────────────────────────
-- SYNC & PERFORMANCE
-- ────────────────────────────────────────────────────────────
Config.Sync = {
    stateBagUpdateMs     = 300,
    globalStateUpdateMs  = 500,
    healthSyncMs         = 1000,
    statsSyncMs          = 2000,
    positionSyncMs       = 250,
    throttleUpdates      = true,
    batchSync            = true,
    compressionLevel     = 2,
}

Config.Performance = {
    followThreadMs       = 150,
    aiThreadMs           = 200,
    combatThreadMs       = 100,
    maxRenderDistance    = 500.0,
    fadeOutDistance      = 450.0,
    enableLOD            = true,
    lodNearDistance      = 50.0,
    lodMidDistance       = 150.0,
    lodFarDistance       = 300.0,
    maxActiveThreads     = 3,
    cleanupIntervalMs    = 30000,
}

Config.RelGroupName = 'RDE_BODYGUARDS'

-- ============================================================
-- SHARED HELPER FUNCTIONS
-- ============================================================

function Config.XPForLevel(level)
    return math.floor(Config.BaseXP * (Config.XPMult ^ (level - 1)))
end

function Config.GetMoraleTier(morale)
    morale = morale or 0
    for _, t in ipairs(Config.Morale.thresholds) do
        if morale >= t.min then return t end
    end
    return Config.Morale.thresholds[#Config.Morale.thresholds]
end

function Config.GetRelTier(level)
    level = level or 1
    local tier = Config.Relationship.tiers[1]
    for _, t in ipairs(Config.Relationship.tiers) do
        if level >= t.level then tier = t end
    end
    return tier
end

function Config.GetRarity(key)
    return Config.RarityByKey[key] or Config.RarityByKey['common'] or Config.Rarities[1]
end

function Config.RollRarity()
    local roll = math.random(100)
    local acc  = 0
    for _, r in ipairs(Config.Rarities) do
        acc = acc + r.weight
        if roll <= acc then return r.key end
    end
    return 'common'
end

function Config.GetWoundIndex(woundKey)
    for i, w in ipairs(Config.Wounds.order) do
        if w == woundKey then return i end
    end
    return 1
end

-- v5.0: Get wound key by index (reverse lookup)
function Config.GetWoundByIndex(index)
    return Config.Wounds.order[index] or 'none'
end

-- v5.0: Check if it's nighttime (22:00-06:00)
function Config.IsNightTime()
    local h = GetClockHours and GetClockHours() or 12
    return h >= 22 or h < 6
end
