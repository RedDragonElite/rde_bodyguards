-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.0  —  server/events.lua
-- Daily rewards · passive morale decay · heal over time · trading
-- ============================================================

local Ox = require '@ox_core.lib.init'

assert(type(Config) == 'table',        '[RDE-BG] events.lua: Config nil — check shared_scripts order')
assert(type(Config.Morale) == 'table', '[RDE-BG] events.lua: Config.Morale missing')

local function getCharId(player)
    -- BUG FIX #3: charId is a number but DB owner column is VARCHAR(60).
    -- Always return as string so comparisons with DB values work in Lua 5.4
    -- where 1 == "1" evaluates to false (strict equality).
    return tostring(player.charId or player.stateId or player.identifier)
end

local function addMoney(player, amount)
    return exports.ox_inventory:AddItem(player.source, Config.Economy.moneyItem, amount)
end
local function removeMoney(player, amount)
    return exports.ox_inventory:RemoveItem(player.source, Config.Economy.moneyItem, amount)
end
local function getMoney(player)
    return tonumber(exports.ox_inventory:Search(player.source, 'count', Config.Economy.moneyItem)) or 0
end

local function notify(src, title, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, {title=title, description=desc, type=ntype or 'inform', duration=5000})
end

-- ────────────────────────────────────────────────────────────
-- BUG FIX #1: Ox.GetPlayers() returns OxPlayer[] NOT source numbers.
-- Ox.GetPlayerFromCharId() is the correct API for charId lookups.
-- BUG FIX #3: tonumber() so charId type matches what ox_core expects.
-- ────────────────────────────────────────────────────────────
local function findOnlinePlayerByCharId(targetCid)
    -- Ox.GetPlayerFromCharId expects a number (charId)
    return Ox.GetPlayerFromCharId(tonumber(targetCid))
end

-- ────────────────────────────────────────────────────────────
-- MYSQL.READY: all DB-dependent startup code goes here
-- NEVER use MySQL.*.await on the top-level of a script file
-- ────────────────────────────────────────────────────────────
MySQL.ready(function()

    -- Trades table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_bg_trades` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `seller_cid` VARCHAR(60) NOT NULL,
            `buyer_cid`  VARCHAR(60) NOT NULL,
            `bg_id`      INT NOT NULL,
            `price`      INT NOT NULL,
            `status`     ENUM('pending','accepted','rejected') DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_buyer` (`buyer_cid`),
            INDEX `idx_seller` (`seller_cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- ── PASSIVE MORALE DECAY (every 60s server-side) ──────
    -- BUG FIX: decayPerMin is integer so SQL TINYINT won't overflow
    CreateThread(function()
        while true do
            Wait(60000)
            MySQL.update(
                'UPDATE `rde_bodyguards` SET `morale` = GREATEST(0, `morale` - ?) WHERE `is_active` = 1',
                {Config.Morale.decayPerMin}
            )
        end
    end)

    -- ── HEAL OVER TIME (wound recovery when morale > 50) ──
    if Config.Wounds and Config.Wounds.healOverTime then
        CreateThread(function()
            -- Build heal progression from config order array
            local woundOrder = Config.Wounds.order  -- {'none','minor','serious','critical'}
            local healTo = {}
            -- critical → serious → minor → none
            for i = #woundOrder, 2, -1 do
                healTo[woundOrder[i]] = woundOrder[i - 1]
            end

            while true do
                Wait(Config.Wounds.healTickMs or 60000)

                local bgs = MySQL.query.await(
                    "SELECT `id`,`wound`,`morale` FROM `rde_bodyguards` WHERE `is_active`=1 AND `wound` != 'none'"
                )
                if bgs then
                    for _, bg in ipairs(bgs) do
                        if (bg.morale or 0) >= 50 then
                            local next = healTo[bg.wound]
                            if next then
                                MySQL.update(
                                    'UPDATE `rde_bodyguards` SET `wound`=? WHERE `id`=?',
                                    {next, bg.id}
                                )
                            end
                        end
                    end
                end
            end
        end)
    end

    -- ── RANDOM FIELD TRAINING EVENTS (5-10 min, 5% per active BG) ──
    CreateThread(function()
        while true do
            Wait(math.random(300000, 600000))

            local bgs = MySQL.query.await(
                'SELECT `id`,`name`,`owner` FROM `rde_bodyguards` WHERE `is_active`=1'
            )
            if not bgs then goto continue end

            -- Collect skill keys once (Config.Skills is a hash)
            local skillKeys = {}
            for k in pairs(Config.Skills) do table.insert(skillKeys, k) end

            for _, bg in ipairs(bgs) do
                if math.random(100) <= 5 then
                    local sk      = skillKeys[math.random(#skillKeys)]
                    local cap     = Config.Skills[sk] and Config.Skills[sk].max or 100

                    -- Safe JSON_SET with cap
                    MySQL.update(
                        [[UPDATE `rde_bodyguards`
                          SET `skills` = JSON_SET(`skills`, CONCAT('$.', ?),
                              LEAST(CAST(JSON_UNQUOTE(JSON_EXTRACT(`skills`, CONCAT('$.', ?))) AS UNSIGNED) + 1, ?))
                          WHERE `id` = ?]],
                        {sk, sk, cap, bg.id}
                    )

                    -- BUG FIX: use findOnlinePlayerByCharId, not Ox.GetPlayers() direct loop
                    local p = findOnlinePlayerByCharId(bg.owner)
                    if p then
                        notify(p.source, '📈 Field Experience',
                            bg.name .. ' improved ' .. Config.Skills[sk].label .. ' +1!', 'success')
                    end
                end
            end
            ::continue::
        end
    end)

    print('^2[RDE-BG]^7 Events MySQL.ready ✓')
end)

-- ────────────────────────────────────────────────────────────
-- DAILY REWARD
-- ────────────────────────────────────────────────────────────
local lastDaily = {}  -- [charId] = os.time()

RegisterNetEvent('rde_bg:claimDaily', function()
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end
    local charId = getCharId(player)

    local now  = os.time()
    local last = lastDaily[charId] or 0

    if now - last < 86400 then
        local h = math.floor((86400 - (now - last)) / 3600)
        notify(src, '⏰ Too Early', L('daily_too_early', h), 'warning')
        return
    end

    local bgs = MySQL.query.await(
        'SELECT `id`,`name`,`level` FROM `rde_bodyguards` WHERE `owner`=? AND `is_active`=1', {charId}
    )
    if not bgs or #bgs == 0 then
        notify(src, '❌', L('daily_no_active'), 'error')
        return
    end

    local totalXP = 0
    for _, bg in ipairs(bgs) do
        local xp = 100 + bg.level * 10
        MySQL.update('UPDATE `rde_bodyguards` SET `xp` = `xp` + ? WHERE `id`=?', {xp, bg.id})
        totalXP = totalXP + xp
    end

    lastDaily[charId] = now
    notify(src, '🎁 Daily Reward', L('daily_claimed', totalXP), 'success')
end)

-- ────────────────────────────────────────────────────────────
-- TRADING
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:createTrade', function(src, bgId, targetCid, price)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false, msg='Not found'} end
    local charId = getCharId(player)

    if type(price) ~= 'number' or price < 1000 or price > 2000000 then
        return {ok=false, msg='Invalid price (1,000 – 2,000,000)'}
    end

    local bg = MySQL.single.await(
        'SELECT `name`,`is_active` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?', {bgId, charId}
    )
    if not bg then return {ok=false, msg='Not your bodyguard'} end
    if bg.is_active == 1 then return {ok=false, msg='Despawn first'} end

    local tid = MySQL.insert.await(
        'INSERT INTO `rde_bg_trades` (`seller_cid`,`buyer_cid`,`bg_id`,`price`) VALUES (?,?,?,?)',
        {charId, targetCid, bgId, price}
    )

    -- BUG FIX: correct Ox.GetPlayers iteration
    local buyer = findOnlinePlayerByCharId(targetCid)
    if buyer then
        notify(buyer.source, '🤝 Trade Offer', L('trade_offer', bg.name, price, tid), 'inform')
    end

    return {ok=true, tradeId=tid}
end)

lib.callback.register('rde_bg:acceptTrade', function(src, tradeId)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false} end
    local charId = getCharId(player)

    local trade = MySQL.single.await(
        "SELECT * FROM `rde_bg_trades` WHERE `id`=? AND `buyer_cid`=? AND `status`='pending'",
        {tradeId, charId}
    )
    if not trade then return {ok=false, msg='No valid pending trade'} end

    if getMoney(player) < trade.price then return {ok=false, msg='Need $' .. trade.price} end
    if not removeMoney(player, trade.price) then return {ok=false, msg='Payment failed'} end

    -- BUG FIX: correct seller lookup
    local seller = findOnlinePlayerByCharId(trade.seller_cid)
    if seller then
        addMoney(seller, trade.price)
        notify(seller.source, '💰 Trade Complete', L('trade_complete_sell', trade.price), 'success')
    end

    MySQL.update('UPDATE `rde_bodyguards` SET `owner`=? WHERE `id`=?', {charId, trade.bg_id})
    MySQL.update("UPDATE `rde_bg_trades` SET `status`='accepted' WHERE `id`=?", {tradeId})

    notify(src, '✅', L('trade_complete_buy'), 'success')
    return {ok=true}
end)

-- ────────────────────────────────────────────────────────────
-- v5.2: SELF-HEAL CALLBACK — BULLETPROOF STASH ACCESS
-- ox_inventory stash items may not be in memory when closed.
-- We try multiple methods + MySQL direct query as fallback.
-- ────────────────────────────────────────────────────────────
lib.callback.register('rde_bg:selfHeal', function(src, bgId, itemPriority)
    local player = Ox.GetPlayer(src)
    if not player then return {ok=false} end
    local charId = getCharId(player)

    local bg = MySQL.single.await(
        'SELECT `id`,`name` FROM `rde_bodyguards` WHERE `id`=? AND `owner`=?', {bgId, charId}
    )
    if not bg then return {ok=false, msg='Not your bodyguard'} end

    local stashId = Config.Stash.prefix .. bgId
    -- Ensure stash is registered every time (idempotent)
    pcall(function()
        exports.ox_inventory:RegisterStash(stashId, bg.name .. "'s Gear", Config.Stash.slots, Config.Stash.weight)
    end)

    local bandageItem = Config.Wounds.selfHealItem or 'bandage'
    local medkitItem  = Config.Wounds.medkitItem   or 'medkit'

    local bandageCount = 0
    local medkitCount  = 0

    -- ── METHOD 1: GetInventoryItems ──
    local ok1, items1 = pcall(function()
        return exports.ox_inventory:GetInventoryItems(stashId)
    end)
    if ok1 and items1 then
        for _, item in pairs(items1) do
            if item and item.name == bandageItem then bandageCount = bandageCount + (item.count or 1) end
            if item and item.name == medkitItem  then medkitCount  = medkitCount  + (item.count or 1) end
        end
    end

    -- ── METHOD 2: GetInventory (loads stash into memory) ──
    if bandageCount == 0 and medkitCount == 0 then
        local ok2, inv = pcall(function()
            return exports.ox_inventory:GetInventory(stashId)
        end)
        if ok2 and inv then
            local invItems = type(inv) == 'table' and (inv.items or inv) or {}
            for _, item in pairs(invItems) do
                if type(item) == 'table' and item.name then
                    if item.name == bandageItem then bandageCount = bandageCount + (item.count or 1) end
                    if item.name == medkitItem  then medkitCount  = medkitCount  + (item.count or 1) end
                end
            end
        end
    end

    -- ── METHOD 3: Direct MySQL query on ox_inventory data ──
    if bandageCount == 0 and medkitCount == 0 then
        -- ox_inventory stores stash data in `ox_inventory` table
        local dbRow = MySQL.single.await(
            'SELECT `data` FROM `ox_inventory` WHERE `owner` = ? LIMIT 1', {stashId}
        )
        if dbRow and dbRow.data then
            local ok3, parsed = pcall(json.decode, dbRow.data)
            if ok3 and parsed then
                for _, item in pairs(parsed) do
                    if type(item) == 'table' and item.name then
                        if item.name == bandageItem then bandageCount = bandageCount + (item.count or 1) end
                        if item.name == medkitItem  then medkitCount  = medkitCount  + (item.count or 1) end
                    end
                end
            end
        end
    end

    print(('[RDE-BG] SelfHeal BG %d (%s): bandage=%d medkit=%d (stash=%s)'):format(
        bgId, bg.name, bandageCount, medkitCount, stashId))

    -- Smart item choice based on priority
    local useItem  = nil
    local healPct  = 0
    local woundClr = 0
    local hasBandage = bandageCount > 0
    local hasMedkit  = medkitCount  > 0

    if itemPriority == 'medkit_or_bandage' then
        if hasMedkit then
            useItem = medkitItem;  healPct = Config.SelfHeal and Config.SelfHeal.medkitHealPct or 0.55;  woundClr = Config.SelfHeal and Config.SelfHeal.medkitWoundClear or 2
        elseif hasBandage then
            useItem = bandageItem; healPct = Config.SelfHeal and Config.SelfHeal.bandageHealPct or 0.25; woundClr = Config.SelfHeal and Config.SelfHeal.bandageWoundClear or 1
        end
    elseif itemPriority == 'bandage_or_medkit' then
        if hasBandage then
            useItem = bandageItem; healPct = Config.SelfHeal and Config.SelfHeal.bandageHealPct or 0.25; woundClr = Config.SelfHeal and Config.SelfHeal.bandageWoundClear or 1
        elseif hasMedkit then
            useItem = medkitItem;  healPct = Config.SelfHeal and Config.SelfHeal.medkitHealPct or 0.55;  woundClr = Config.SelfHeal and Config.SelfHeal.medkitWoundClear or 2
        end
    else
        if hasMedkit then
            useItem = medkitItem;  healPct = Config.SelfHeal and Config.SelfHeal.medkitHealPct or 0.55;  woundClr = Config.SelfHeal and Config.SelfHeal.medkitWoundClear or 2
        elseif hasBandage then
            useItem = bandageItem; healPct = Config.SelfHeal and Config.SelfHeal.bandageHealPct or 0.25; woundClr = Config.SelfHeal and Config.SelfHeal.bandageWoundClear or 1
        end
    end

    if not useItem then
        return {ok=false, msg='No bandage or medkit in gear'}
    end

    -- Remove item from stash — try multiple methods
    local removed = false

    -- Try 1: ox_inventory RemoveItem with stash ID
    local okR1, resR1 = pcall(function()
        return exports.ox_inventory:RemoveItem(stashId, useItem, 1)
    end)
    if okR1 and resR1 then
        removed = true
    end

    -- Try 2: Direct MySQL update if RemoveItem failed
    if not removed then
        local dbRow = MySQL.single.await(
            'SELECT `data` FROM `ox_inventory` WHERE `owner` = ? LIMIT 1', {stashId}
        )
        if dbRow and dbRow.data then
            local ok3, parsed = pcall(json.decode, dbRow.data)
            if ok3 and parsed then
                local modified = false
                for i, item in pairs(parsed) do
                    if type(item) == 'table' and item.name == useItem then
                        if (item.count or 1) > 1 then
                            parsed[i].count = item.count - 1
                        else
                            parsed[i] = nil
                        end
                        modified = true
                        break
                    end
                end
                if modified then
                    -- Compact the array (remove nil gaps)
                    local compacted = {}
                    for _, v in pairs(parsed) do
                        if v then table.insert(compacted, v) end
                    end
                    MySQL.update.await(
                        'UPDATE `ox_inventory` SET `data` = ? WHERE `owner` = ?',
                        {json.encode(compacted), stashId}
                    )
                    removed = true
                    print(('[RDE-BG] SelfHeal: removed %s via direct MySQL for BG %d'):format(useItem, bgId))
                end
            end
        end
    end

    if not removed then
        print(('[RDE-BG] SelfHeal FAILED: could not remove %s from stash %s'):format(useItem, stashId))
        return {ok=false, msg='Failed to consume ' .. useItem}
    end

    print(('[RDE-BG] SelfHeal SUCCESS: BG %d used %s'):format(bgId, useItem))

    return {
        ok         = true,
        itemUsed   = useItem == medkitItem and 'medkit' or 'bandage',
        healPct    = healPct,
        woundClear = woundClr,
    }
end)

print('^2[RDE-BG]^7 Events v5.0 loaded ✓ (Self-Heal System)')