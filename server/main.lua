-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.2  —  server/main.lua
-- Per RDE Standards: MySQL.ready, prepared statements, Ox.GetPlayer
-- FIX v4.2: Server spawnt KEINEN Ped mehr.
--   → Nur DB-Check + GlobalState push
--   → Client spawnt Ped lokal und startet realisticArrival()
--   → Kein "Copy vom Player", kein SetEntityAsMissionEntity-Crash
-- ============================================================

local Ox = require '@ox_core.lib.init'

assert(type(Config) == 'table',         '[RDE-BG] Config is nil — check fxmanifest shared_scripts order')
assert(type(Config.Economy) == 'table', '[RDE-BG] Config.Economy missing')

-- ────────────────────────────────────────────────────────────
-- ECONOMY HELPERS
-- ────────────────────────────────────────────────────────────
local function getMoney(player)
    return tonumber(exports.ox_inventory:Search(player.source, 'count', Config.Economy.moneyItem)) or 0
end
local function removeMoney(player, amount)
    return exports.ox_inventory:RemoveItem(player.source, Config.Economy.moneyItem, amount)
end
local function addMoney(player, amount)
    return exports.ox_inventory:AddItem(player.source, Config.Economy.moneyItem, amount)
end

-- ────────────────────────────────────────────────────────────
-- GENERIC HELPERS
-- ────────────────────────────────────────────────────────────
local function cid(player)
    return player.charId or player.stateId or player.identifier
end

local function notify(src, title, desc, ntype, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = title,
        description = desc,
        type        = ntype   or 'inform',
        duration    = duration or 5000,
    })
end

local function generateSkills(rarityKey)
    local rData = Config.GetRarity(rarityKey)
    local bonus = rData.skillBonus or 0
    local skills = {}
    for k in pairs(Config.Skills) do
        skills[k] = math.random(10, 45) + bonus
    end
    return skills
end

local function calcHealth(skills, level)
    return math.min(200 + (level * 8) + (skills.stamina or 0) * 2, 1200)
end

local function calcPrice(skills, rarityKey)
    local total = 0
    for _, v in pairs(skills) do total = total + v end
    local base   = math.random(Config.Pricing.base.min, Config.Pricing.base.max)
    local rBonus = Config.Pricing.rarityBonus[rarityKey] or 0
    return math.floor(base + total * Config.Pricing.perSkillPt + rBonus)
end

local nameData = {
    male   = {'Marcus','Viktor','Leon','Dante','Axel','Kane','Zeke','Remy','Orion','Brock','Colt','Dex'},
    female = {'Raven','Nova','Luna','Aria','Storm','Jade','Lexa','Zara','Vex','Kira','Nyx','Sable'},
    last   = {'Shadow','Steel','Wolf','Hawk','Ghost','Blade','Viper','Frost','Cross','Ravage','Cipher','Drake'},
}
local function genName(gender)
    local pool = nameData[gender] or nameData.male
    return pool[math.random(#pool)] .. ' ' .. nameData.last[math.random(#nameData.last)]
end

-- ────────────────────────────────────────────────────────────
-- ACHIEVEMENTS
-- ────────────────────────────────────────────────────────────
local function checkAchievements(src, bgId, stats)
    local player = Ox.GetPlayer(src)
    if not player then return end

    local row = MySQL.single.await(
        'SELECT `achievements` FROM `rde_bodyguards` WHERE `id` = ?', {bgId}
    )
    if not row then return end

    local achieved    = json.decode(row.achievements or '[]') or {}
    local achievedSet = {}
    for _, a in ipairs(achieved) do achievedSet[a] = true end

    local changed = false
    for _, ach in ipairs(Config.Achievements) do
        if not achievedSet[ach.id] then
            local value = 0
            if ach.requirement == 'kills'    then value = stats.kills         or 0 end
            if ach.requirement == 'protects' then value = stats.protects      or 0 end
            if ach.requirement == 'relation' then value = stats.relation_level or 1 end
            if ach.requirement == 'prestige' then value = stats.prestige      or 0 end
            if ach.requirement == 'stealth'  then value = (stats.skills and stats.skills.stealth) or 0 end

            if value >= ach.value then
                table.insert(achieved, ach.id)
                achievedSet[ach.id] = true
                changed = true
                addMoney(player, ach.reward)
                notify(src, '🏆 ' .. ach.name, (ach.desc or '') .. ' — $' .. ach.reward .. ' reward!', 'success', 7000)
            end
        end
    end

    if changed then
        MySQL.update.await(
            'UPDATE `rde_bodyguards` SET `achievements` = ? WHERE `id` = ?',
            {json.encode(achieved), bgId}
        )
    end
end

-- ────────────────────────────────────────────────────────────
-- STATEBAGS  — GlobalState key = 'rde_bg_<id>'
-- ────────────────────────────────────────────────────────────
local activeBags = {}  -- [bgId] = { src, charId, data }

local function pushBag(bgId, data)
    GlobalState['rde_bg_' .. bgId] = json.encode(data)
end
local function clearBag(bgId)
    GlobalState['rde_bg_' .. bgId] = nil
    activeBags[bgId]               = nil
end

-- ────────────────────────────────────────────────────────────
-- DATABASE INIT
-- ────────────────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_bodyguards` (
            `id`             INT          AUTO_INCREMENT PRIMARY KEY,
            `owner`          VARCHAR(60)  NOT NULL,
            `name`           VARCHAR(80)  NOT NULL,
            `model`          VARCHAR(50)  NOT NULL,
            `gender`         ENUM('male','female') NOT NULL,
            `rarity`         VARCHAR(20)  DEFAULT 'common',
            `level`          SMALLINT     DEFAULT 1,
            `xp`             INT          DEFAULT 0,
            `prestige`       TINYINT      DEFAULT 0,
            `health`         SMALLINT     DEFAULT 200,
            `skills`         JSON         NOT NULL,
            `morale`         TINYINT      DEFAULT 75,
            `wound`          VARCHAR(20)  DEFAULT 'none',
            `affection`      INT          DEFAULT 0,
            `relation_level` TINYINT      DEFAULT 1,
            `total_kills`    INT          DEFAULT 0,
            `total_protects` INT          DEFAULT 0,
            `is_active`      TINYINT(1)   DEFAULT 0,
            `is_dead`        TINYINT(1)   DEFAULT 0,
            `death_time`     BIGINT       DEFAULT 0,
            `achievements`   JSON         DEFAULT (JSON_ARRAY()),
            `created_at`     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            `updated_at`     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_owner`  (`owner`),
            INDEX `idx_active` (`is_active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.update('UPDATE `rde_bodyguards` SET `is_active` = 0', {}, function()
        print('^2[RDE-BG]^7 Database ready ✓')
        TriggerClientEvent('rde_bg:serverReady', -1)
    end)
end)

-- ────────────────────────────────────────────────────────────
-- RECRUIT
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:recruit', function(src, gender, rarityOverride)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Player not found'} end
    local charId = cid(player)
    if not charId then return {ok=false, msg='No active character'} end

    local owned = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM `rde_bodyguards` WHERE `owner` = ?', {charId}
    )) or 0
    if owned >= Config.MaxOwned then
        return {ok=false, msg=L('recruit_fail_max', Config.MaxOwned)}
    end

    local rarityKey = rarityOverride or Config.RollRarity()
    local skills    = generateSkills(rarityKey)
    local hp        = calcHealth(skills, 1)
    local price     = calcPrice(skills, rarityKey)
    local name      = genName(gender or 'male')
    local pedPool   = Config.Peds[gender] or Config.Peds.male
    local model     = pedPool[math.random(#pedPool)]

    if getMoney(player) < price then
        return {ok=false, msg=L('recruit_fail_funds', price)}
    end
    if not removeMoney(player, price) then
        return {ok=false, msg='Payment failed'}
    end

    local id = MySQL.insert.await([[
        INSERT INTO `rde_bodyguards`
            (`owner`,`name`,`model`,`gender`,`rarity`,`level`,`xp`,`health`,`skills`,`morale`,`wound`,`affection`)
        VALUES (?,?,?,?,?,1,0,?,?,?,?,0)
    ]], {charId, name, model, gender or 'male', rarityKey, hp, json.encode(skills), Config.Morale.startValue, 'none'})

    if not id or id <= 0 then
        addMoney(player, price)
        return {ok=false, msg=L('recruit_fail_db')}
    end

    exports.ox_inventory:RegisterStash(
        Config.Stash.prefix .. id,
        name .. "'s Gear",
        Config.Stash.slots,
        Config.Stash.weight
    )

    notify(src, '✅ ' .. L('menu_recruit'), L('recruited', name, price), 'success', 6000)
    return {ok=true, id=id, name=name, model=model, rarity=rarityKey, price=price, skills=skills, level=1, health=hp,
            morale=Config.Morale.startValue, wound='none', affection=0, relation_level=1, prestige=0, gender=gender or 'male'}
end)

-- ────────────────────────────────────────────────────────────
-- WEAPON SYSTEM - ox_inventory integration
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:getInventoryWeapons', function(src, bgId)
    local stashId = Config.Stash.prefix .. bgId
    local items = exports.ox_inventory:GetInventoryItems(stashId) or {}
    
    local weapons = {}
    for _, item in pairs(items) do
        if item.name and item.name:lower():match('^weapon_') then
            table.insert(weapons, {
                name = item.name,
                slot = item.slot,
                count = item.count or 1,
                metadata = item.metadata or {},
                ammo = item.metadata and item.metadata.ammo or 0,
            })
        end
    end
    
    -- Sort by damage/tier (implement proper sorting logic)
    table.sort(weapons, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)
    
    return weapons
end)

lib.callback.register('rde_bg:getWeaponData', function(src, bgId, weaponName)
    local stashId = Config.Stash.prefix .. bgId
    local items = exports.ox_inventory:GetInventoryItems(stashId) or {}
    
    for _, item in pairs(items) do
        if item.name == weaponName then
            return {
                name = item.name,
                ammo = item.metadata and item.metadata.ammo or 0,
                components = item.metadata and item.metadata.components or {},
            }
        end
    end
    
    return nil
end)

-- ────────────────────────────────────────────────────────────
-- GET ALL
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:getAll', function(src)
    local player = Ox.GetPlayer(src)
    if not player then return {} end
    local charId = cid(player)
    if not charId then return {} end

    local rows = MySQL.query.await(
        'SELECT * FROM `rde_bodyguards` WHERE `owner` = ? ORDER BY `level` DESC, `created_at` DESC',
        {charId}
    ) or {}

    for _, r in ipairs(rows) do
        r.skills       = json.decode(r.skills)       or {}
        r.achievements = json.decode(r.achievements) or {}
    end
    return rows
end)

-- ────────────────────────────────────────────────────────────
-- SPAWN  — DB-only, kein Server-Ped.
-- Client spawnt den Ped lokal (client/main.lua → activateBodyguard).
-- Server: nur Ownership-Check, MaxActive-Check, DB-Update, StateBag.
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:spawn', function(src, bgId)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Player not found'} end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT * FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?', {bgId, charId}
    )
    if not bg          then return {ok=false, msg='Bodyguard not found'} end
    if bg.is_dead == 1 then return {ok=false, msg=L('deploy_fail_dead')} end

    local active = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM `rde_bodyguards` WHERE `owner` = ? AND `is_active` = 1', {charId}
    )) or 0
    if active >= Config.MaxActive then
        return {ok=false, msg=L('deploy_fail_max', Config.MaxActive)}
    end

    MySQL.update.await('UPDATE `rde_bodyguards` SET `is_active` = 1 WHERE `id` = ?', {bgId})

    bg.skills       = json.decode(bg.skills or '{}') or {}
    bg.achievements = json.decode(bg.achievements or '[]') or {}

    -- GlobalState StateBag fuer andere Clients (kein Ped-Handle noetig)
    local bagData = {
        id             = bg.id,
        name           = bg.name,
        model          = bg.model,
        gender         = bg.gender,
        rarity         = bg.rarity,
        level          = bg.level,
        health         = bg.health,
        morale         = bg.morale or Config.Morale.startValue,
        wound          = bg.wound  or 'none',
        affection      = bg.affection,
        relation_level = bg.relation_level,
        skills         = bg.skills,
        total_kills    = bg.total_kills,
        prestige       = bg.prestige or 0,
        owner_src      = src,
        network_id     = nil,  -- Will be set by client
    }
    pushBag(bgId, bagData)
    activeBags[bgId] = {src=src, charId=charId, data=bagData}

    print(('[RDE-BG] BG %d authorized for player %d — client will spawn ped'):format(bgId, src))
    return {ok=true, bodyguard=bg}
end)

-- ────────────────────────────────────────────────────────────
-- SYNC NETWORK ID (called by owner after ped spawns)
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:syncNetworkId', function(bgId, netId)
    local src = source
    if not activeBags[bgId] or activeBags[bgId].src ~= src then return end
    
    -- Update the statebag with network ID
    activeBags[bgId].data.network_id = netId
    pushBag(bgId, activeBags[bgId].data)
    
    -- Force broadcast to ALL clients
    TriggerClientEvent('rde_bg:forceSync', -1, bgId, activeBags[bgId].data)
    
    print(('[RDE-BG] Network ID %d synced for BG %d'):format(netId, bgId))
end)

-- ────────────────────────────────────────────────────────────
-- DESPAWN (networked entity version)
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:despawn', function(bgId)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local row = MySQL.single.await(
        'SELECT `id` FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?', {bgId, charId}
    )
    if not row then return end

    -- Server hat keinen Ped-Handle (client spawnt lokal) — nur StateBag + DB
    clearBag(bgId)
    MySQL.update('UPDATE `rde_bodyguards` SET `is_active` = 0 WHERE `id` = ?', {bgId})

    print(('[RDE-BG] Despawned networked bodyguard %d for player %d'):format(bgId, src))
end)

RegisterNetEvent('rde_bg:dismissAll', function()
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local rows = MySQL.query.await(
        'SELECT `id` FROM `rde_bodyguards` WHERE `owner` = ? AND `is_active` = 1', {charId}
    ) or {}

    for _, r in ipairs(rows) do
        clearBag(r.id)
    end

    MySQL.update('UPDATE `rde_bodyguards` SET `is_active` = 0 WHERE `owner` = ?', {charId})
    print(('[RDE-BG] Dismissed all bodyguards for player %d'):format(src))
end)

-- ────────────────────────────────────────────────────────────
-- MORALE UPDATE
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:updateMorale', function(bgId, delta)
    local src   = source
    local entry = activeBags[bgId]
    if not entry or entry.src ~= src then return end

    MySQL.update(
        'UPDATE `rde_bodyguards` SET `morale` = GREATEST(0, LEAST(100, `morale` + ?)) WHERE `id` = ?',
        {delta, bgId}
    )

    if entry.data then
        entry.data.morale = math.max(0, math.min(100, (entry.data.morale or 75) + delta))
        pushBag(bgId, entry.data)
    end
end)

-- ────────────────────────────────────────────────────────────
-- WOUND UPDATE
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:setWound', function(bgId, woundType)
    local src   = source
    local entry = activeBags[bgId]
    if not entry or entry.src ~= src then return end
    if not Config.Wounds.types[woundType] then return end

    MySQL.update('UPDATE `rde_bodyguards` SET `wound` = ? WHERE `id` = ?', {woundType, bgId})
    if entry.data then
        entry.data.wound = woundType
        pushBag(bgId, entry.data)
    end
end)

-- ────────────────────────────────────────────────────────────
-- ADD XP
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:addXP', function(bgId, xpType, customAmt)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `id`,`name`,`xp`,`level`,`health`,`skills` FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?',
        {bgId, charId}
    )
    if not bg then return end

    local gain   = customAmt or Config.XPRewards[xpType] or 0
    local newXP  = (bg.xp or 0) + gain
    local newLvl = bg.level or 1
    local leveled = false

    while newLvl < Config.MaxLevel do
        local needed = Config.XPForLevel(newLvl)
        if newXP >= needed then
            newXP  = newXP - needed
            newLvl = newLvl + 1
            leveled = true
        else break end
    end

    local skills = json.decode(bg.skills or '{}') or {}
    local newHP  = calcHealth(skills, newLvl)

    MySQL.update(
        'UPDATE `rde_bodyguards` SET `xp` = ?, `level` = ?, `health` = ? WHERE `id` = ?',
        {newXP, newLvl, newHP, bgId}
    )

    if leveled then
        notify(src, '⭐ ' .. L('level_up', bg.name, newLvl), '', 'success', 5000)
        TriggerClientEvent('rde_bg:levelUp', src, bgId, newLvl)
    end

    local entry = activeBags[bgId]
    if entry and entry.data then
        entry.data.level  = newLvl
        entry.data.health = newHP
        pushBag(bgId, entry.data)
    end
end)

-- ────────────────────────────────────────────────────────────
-- KILL
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:kill', function(bgId)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `id`,`total_kills`,`total_protects`,`relation_level`,`prestige`,`skills` FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?',
        {bgId, charId}
    )
    if not bg then return end

    MySQL.update('UPDATE `rde_bodyguards` SET `total_kills` = `total_kills` + 1 WHERE `id` = ?', {bgId})

    checkAchievements(src, bgId, {
        kills         = (bg.total_kills or 0) + 1,
        protects      = bg.total_protects  or 0,
        relation_level= bg.relation_level  or 1,
        prestige      = bg.prestige        or 0,
        skills        = json.decode(bg.skills or '{}') or {},
    })
end)

-- ────────────────────────────────────────────────────────────
-- PROTECT
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:protect', function(bgId)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `id`,`total_kills`,`total_protects`,`relation_level`,`prestige`,`skills` FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?',
        {bgId, charId}
    )
    if not bg then return end

    MySQL.update('UPDATE `rde_bodyguards` SET `total_protects` = `total_protects` + 1 WHERE `id` = ?', {bgId})

    checkAchievements(src, bgId, {
        kills         = bg.total_kills    or 0,
        protects      = (bg.total_protects or 0) + 1,
        relation_level= bg.relation_level or 1,
        prestige      = bg.prestige       or 0,
        skills        = json.decode(bg.skills or '{}') or {},
    })
end)

-- ────────────────────────────────────────────────────────────
-- DIED
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:died', function(bgId)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT * FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ?', {bgId, charId}
    )
    if not bg then return end

    clearBag(bgId)

    if Config.Death.permanent then
        MySQL.update('DELETE FROM `rde_bodyguards` WHERE `id` = ?', {bgId})
        notify(src, '💀 Permanently Lost', L('death_permanent', bg.name), 'error', 8000)
    else
        local penXP  = math.floor((bg.xp or 0) * (1 - Config.Death.xpPenaltyPct))
        local penAff = math.max(0, (bg.affection or 0) - Config.Death.affectionPenalty)
        local cost   = Config.Death.reviveBaseCost + (bg.level or 1) * Config.Death.reviveCostPerLvl

        MySQL.update(
            'UPDATE `rde_bodyguards` SET `is_active`=0,`is_dead`=1,`xp`=?,`affection`=?,`wound`=?,`death_time`=? WHERE `id`=?',
            {penXP, penAff, 'critical', os.time(), bgId}
        )
        notify(src, '💀 ' .. bg.name .. ' is Down', L('death_revive', bg.name, cost), 'error', 8000)
    end
end)

-- ────────────────────────────────────────────────────────────
-- REVIVE
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:revive', function(src, bgId)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Not found'} end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT * FROM `rde_bodyguards` WHERE `id` = ? AND `owner` = ? AND `is_dead` = 1', {bgId, charId}
    )
    if not bg then return {ok=false, msg='Not dead or not yours'} end

    local cost = Config.Death.reviveBaseCost + (bg.level or 1) * Config.Death.reviveCostPerLvl
    if os.time() - (bg.death_time or 0) < math.floor(Config.Death.earlyReviveMs / 1000) then
        cost = math.floor(cost * 0.5)
    end

    if getMoney(player) < cost then return {ok=false, msg=L('revive_fail_cost', cost)} end
    if not removeMoney(player, cost) then return {ok=false, msg='Payment failed'} end

    MySQL.update(
        "UPDATE `rde_bodyguards` SET `is_dead`=0,`wound`='minor',`morale`=40 WHERE `id`=?",
        {bgId}
    )
    notify(src, '💊 Revived', L('revived', bg.name), 'success')
    return {ok=true}
end)

-- ────────────────────────────────────────────────────────────
-- AFFECTION
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:affection', function(bgId, amount)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `id`,`name`,`affection`,`relation_level`,`total_kills`,`total_protects`,`prestige`,`skills` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?',
        {bgId, charId}
    )
    if not bg then return end

    local newAff = math.max(0, (bg.affection or 0) + amount)
    local newRel = bg.relation_level or 1
    local oldRel = newRel

    for _, tier in ipairs(Config.Relationship.tiers) do
        if newAff >= tier.required then newRel = tier.level end
    end

    MySQL.update(
        'UPDATE `rde_bodyguards` SET `affection`=?,`relation_level`=? WHERE `id`=?',
        {newAff, newRel, bgId}
    )

    if newRel > oldRel then
        local tier = Config.GetRelTier(newRel)
        notify(src, '💖 Bond Deepened', L('bond_deepened', bg.name, tier.name), 'success', 6000)
        TriggerClientEvent('rde_bg:bondDeepened', src, bgId, tier.name)
        checkAchievements(src, bgId, {
            kills         = bg.total_kills    or 0,
            protects      = bg.total_protects or 0,
            relation_level= newRel,
            prestige      = bg.prestige       or 0,
            skills        = json.decode(bg.skills or '{}') or {},
        })
    end

    local entry = activeBags[bgId]
    if entry and entry.data then
        entry.data.affection      = newAff
        entry.data.relation_level = newRel
        pushBag(bgId, entry.data)
    end
end)

-- ────────────────────────────────────────────────────────────
-- TRAIN SKILL
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:trainSkill', function(src, bgId, skillName)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Not found'} end
    local charId = cid(player)

    local skillCfg = Config.Skills[skillName]
    if not skillCfg then return {ok=false, msg='Invalid skill'} end

    if getMoney(player) < skillCfg.trainCost then
        return {ok=false, msg=L('skill_fail_funds', skillCfg.trainCost)}
    end

    local bg = MySQL.single.await(
        'SELECT `skills` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?', {bgId, charId}
    )
    if not bg then return {ok=false, msg='Not found'} end

    local skills = json.decode(bg.skills) or {}
    if (skills[skillName] or 0) >= skillCfg.max then
        return {ok=false, msg=L('skill_maxed')}
    end
    if not removeMoney(player, skillCfg.trainCost) then return {ok=false, msg='Payment failed'} end

    local gain = math.random(1, 3)
    skills[skillName] = math.min((skills[skillName] or 0) + gain, skillCfg.max)
    MySQL.update.await('UPDATE `rde_bodyguards` SET `skills`=? WHERE `id`=?', {json.encode(skills), bgId})

    local entry = activeBags[bgId]
    if entry and entry.data then
        entry.data.skills = skills
        pushBag(bgId, entry.data)
    end

    return {ok=true, newValue=skills[skillName], gain=gain}
end)

-- ────────────────────────────────────────────────────────────
-- PRESTIGE
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:prestige', function(src, bgId)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Not found'} end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT * FROM `rde_bodyguards` WHERE `id`=? AND `owner`=? AND `level`=?',
        {bgId, charId, Config.MaxLevel}
    )
    if not bg then return {ok=false, msg=L('prestige_fail_level', Config.MaxLevel)} end
    if (bg.prestige or 0) >= Config.MaxPrestige then return {ok=false, msg=L('prestige_fail_max')} end

    local skills = json.decode(bg.skills) or {}
    for k, v in pairs(skills) do
        local cap = Config.Skills[k] and Config.Skills[k].max or 100
        skills[k] = math.min(v + 10, cap)
    end
    local newP = (bg.prestige or 0) + 1

    MySQL.update.await(
        'UPDATE `rde_bodyguards` SET `level`=1,`xp`=0,`skills`=?,`prestige`=? WHERE `id`=?',
        {json.encode(skills), newP, bgId}
    )
    notify(src, '🌟 PRESTIGE ' .. newP, L('prestige_done', bg.name), 'success', 8000)
    return {ok=true, prestige=newP}
end)

-- ────────────────────────────────────────────────────────────
-- INVENTORY
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:openInventory', function(src, bgId)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false} end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `name` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?', {bgId, charId}
    )
    if not bg then return {ok=false} end

    local stashId = Config.Stash.prefix .. bgId
    exports.ox_inventory:RegisterStash(stashId, bg.name .. "'s Gear", Config.Stash.slots, Config.Stash.weight)
    exports.ox_inventory:forceOpenInventory(src, 'stash', stashId)
    return {ok=true}
end)

-- ────────────────────────────────────────────────────────────
-- GET WEAPONS FROM STASH
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:getWeapons', function(src, bgId)
    local player = Ox.GetPlayer(src)
    if not player then return {} end
    local charId = cid(player)

    local bg = MySQL.single.await(
        'SELECT `id` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?', {bgId, charId}
    )
    if not bg then return {} end

    local stashId = Config.Stash.prefix .. bgId
    pcall(function()
        exports.ox_inventory:RegisterStash(stashId, 'BG Gear', Config.Stash.slots, Config.Stash.weight)
    end)

    -- Try multiple methods to get stash items
    local invItems = nil

    -- Method 1: GetInventory
    local ok1, inv = pcall(function()
        return exports.ox_inventory:GetInventory(stashId, false)
    end)
    if ok1 and inv then
        invItems = inv.items or inv
    end

    -- Method 2: GetInventoryItems
    if not invItems or not next(invItems) then
        local ok2, items2 = pcall(function()
            return exports.ox_inventory:GetInventoryItems(stashId)
        end)
        if ok2 and items2 then invItems = items2 end
    end

    -- Method 3: MySQL direct
    if not invItems or not next(invItems) then
        local dbRow = MySQL.single.await(
            'SELECT `data` FROM `ox_inventory` WHERE `owner` = ? LIMIT 1', {stashId}
        )
        if dbRow and dbRow.data then
            local ok3, parsed = pcall(json.decode, dbRow.data)
            if ok3 and parsed then invItems = parsed end
        end
    end

    if not invItems then return {} end

    local priority = {
        -- Pistols (10-19)
        weapon_pistol=10, weapon_pistol_mk2=12, weapon_combatpistol=14,
        weapon_appistol=15, weapon_stungun=5, weapon_pistol50=16,
        weapon_snspistol=8, weapon_snspistol_mk2=10, weapon_heavypistol=17,
        weapon_vintagepistol=13, weapon_flaregun=3, weapon_marksmanpistol=11,
        weapon_revolver=18, weapon_revolver_mk2=19, weapon_doubleaction=14,
        weapon_raypistol=16, weapon_ceramicpistol=13, weapon_navyrevolver=17,
        weapon_gadgetpistol=12, weapon_pistolxm3=14, weapon_tecpistol=15,
        -- SMGs (20-34)
        weapon_microsmg=20, weapon_smg=25, weapon_smg_mk2=28,
        weapon_assaultsmg=27, weapon_combatpdw=26, weapon_machinepistol=22,
        weapon_minismg=21, weapon_raycarbine=30,
        -- Shotguns (35-44)
        weapon_pumpshotgun=35, weapon_pumpshotgun_mk2=38,
        weapon_sawnoffshotgun=32, weapon_assaultshotgun=40,
        weapon_bullpupshotgun=38, weapon_musket=30, weapon_heavyshotgun=42,
        weapon_dbshotgun=36, weapon_autoshotgun=39, weapon_combatshotgun=43,
        -- Assault Rifles (50-64)
        weapon_assaultrifle=50, weapon_assaultrifle_mk2=55,
        weapon_carbinerifle=55, weapon_carbinerifle_mk2=58,
        weapon_advancedrifle=52, weapon_specialcarbine=58,
        weapon_specialcarbine_mk2=60, weapon_bullpuprifle=53,
        weapon_bullpuprifle_mk2=56, weapon_compactrifle=48,
        weapon_militaryrifle=62, weapon_heavyrifle=63, weapon_tacticalrifle=61,
        weapon_battlerifle=64,
        -- LMGs (45-49)
        weapon_mg=45, weapon_combatmg=47, weapon_combatmg_mk2=49,
        weapon_gusenberg=44,
        -- Sniper (65-75)
        weapon_sniperrifle=65, weapon_heavysniper=70,
        weapon_heavysniper_mk2=72, weapon_marksmanrifle=68,
        weapon_marksmanrifle_mk2=70, weapon_precisionrifle=73,
        -- Heavy (76-85)
        weapon_rpg=80, weapon_grenadelauncher=78, weapon_grenadelauncher_smoke=5,
        weapon_minigun=85, weapon_firework=5, weapon_railgun=82,
        weapon_hominglauncher=79, weapon_compactlauncher=76,
        weapon_rayminigun=83, weapon_emplauncher=77,
        -- Melee (1-4)
        weapon_dagger=3, weapon_bat=2, weapon_bottle=1,
        weapon_crowbar=2, weapon_unarmed=0, weapon_flashlight=1,
        weapon_golfclub=2, weapon_nightstick=2, weapon_hammer=2,
        weapon_hatchet=3, weapon_knuckle=2, weapon_knife=3,
        weapon_machete=4, weapon_switchblade=3, weapon_wrench=2,
        weapon_battleaxe=4, weapon_poolcue=2, weapon_stone_hatchet=3,
        -- Thrown (1-5)
        weapon_grenade=5, weapon_bzgas=2, weapon_molotov=4,
        weapon_stickybomb=5, weapon_proxmine=5, weapon_snowball=1,
        weapon_pipebomb=4, weapon_ball=1, weapon_smokegrenade=2,
        weapon_flare=1,
    }
    local weapons = {}
    for _, item in pairs(invItems) do
        if item and item.name then
            local lowerName = item.name:lower()
            local p = priority[lowerName] or 0
            if p > 0 then
                table.insert(weapons, {
                    name = item.name,
                    prio = p,
                    ammo = (item.metadata and item.metadata.ammo) or 250,
                })
            end
        end
    end
    table.sort(weapons, function(a, b) return a.prio > b.prio end)
    return weapons
end)

-- ────────────────────────────────────────────────────────────
-- LEADERBOARD
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:leaderboard', function(src, category)
    local queries = {
        level = 'SELECT `name`,`level`,`prestige`,`total_kills` FROM `rde_bodyguards` ORDER BY `prestige` DESC,`level` DESC LIMIT 10',
        kills = 'SELECT `name`,`total_kills`,`level` FROM `rde_bodyguards` ORDER BY `total_kills` DESC LIMIT 10',
        bond  = 'SELECT `name`,`affection`,`relation_level` FROM `rde_bodyguards` ORDER BY `affection` DESC LIMIT 10',
    }
    return MySQL.query.await(queries[category] or queries.level) or {}
end)

-- ────────────────────────────────────────────────────────────
-- OX CORE LIFECYCLE HOOKS
-- ────────────────────────────────────────────────────────────
AddEventHandler('ox:playerLogout', function(source, userId, charId)
    if not charId then return end
    local rows = MySQL.query.await(
        'SELECT `id` FROM `rde_bodyguards` WHERE `owner`=? AND `is_active`=1', {charId}
    ) or {}
    for _, r in ipairs(rows) do clearBag(r.id) end
    MySQL.update('UPDATE `rde_bodyguards` SET `is_active`=0 WHERE `owner`=?', {charId})
end)

AddEventHandler('ox:playerLoaded', function(source)
    TriggerClientEvent('rde_bg:serverReady', source)
end)

-- ────────────────────────────────────────────────────────────
-- PUBLIC EXPORTS
-- ────────────────────────────────────────────────────────────
exports('getBodyguard', function(id)
    local r = MySQL.single.await('SELECT * FROM `rde_bodyguards` WHERE `id`=?', {id})
    if r then r.skills = json.decode(r.skills) or {} end
    return r
end)

exports('getPlayerBodyguards', function(charId)
    local rows = MySQL.query.await('SELECT * FROM `rde_bodyguards` WHERE `owner`=?', {charId}) or {}
    for _, r in ipairs(rows) do r.skills = json.decode(r.skills) or {} end
    return rows
end)

print('^2[RDE-BG]^7 Server v4.2 loaded ✓ (Client-side ped spawn)')