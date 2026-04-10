-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.5  —  server/sync.lua
-- ENHANCED SERVER-SIDE SYNCHRONIZATION
-- Production-ready state management & broadcast optimization
-- ============================================================

local activeBags = {}  -- [bgId] = { src, charId, lastUpdate, data }
local pendingBroadcasts = {}
local broadcastQueue = {}

-- ────────────────────────────────────────────────────────────
-- THROTTLED STATE BAG UPDATES
-- ────────────────────────────────────────────────────────────
local function pushStateBag(bgId, data)
    GlobalState['rde_bg_' .. bgId] = json.encode(data)
end

local function clearStateBag(bgId)
    GlobalState['rde_bg_' .. bgId] = nil
    activeBags[bgId] = nil
end

-- ────────────────────────────────────────────────────────────
-- OPTIMIZED STATE UPDATE
-- ────────────────────────────────────────────────────────────
function updateBGState(bgId, changes, skipBroadcast)
    if not activeBags[bgId] then
        return false
    end

    local bag = activeBags[bgId]
    local now = os.time()
    
    -- Merge changes into current state
    for k, v in pairs(changes) do
        bag.data[k] = v
    end
    
    bag.lastUpdate = now

    -- Update database (async)
    local dbUpdates = {}
    local dbFields = {
        morale = true,
        wound = true,
        level = true,
        xp = true,
        prestige = true,
        health = true,
        relation_level = true,
        total_kills = true,
        total_protects = true,
    }

    for k, v in pairs(changes) do
        if dbFields[k] then
            dbUpdates[k] = v
        end
    end

    if next(dbUpdates) then
        -- Build UPDATE query dynamically
        local sets = {}
        local params = {}
        for field, value in pairs(dbUpdates) do
            table.insert(sets, '`' .. field .. '` = ?')
            table.insert(params, value)
        end
        table.insert(params, bgId)
        
        MySQL.update.await(
            'UPDATE `rde_bodyguards` SET ' .. table.concat(sets, ', ') .. ' WHERE `id` = ?',
            params
        )
    end

    -- Broadcast to owner client (throttled)
    if not skipBroadcast then
        if not pendingBroadcasts[bgId] then
            pendingBroadcasts[bgId] = {}
        end
        for k, v in pairs(changes) do
            pendingBroadcasts[bgId][k] = v
        end
    end

    return true
end

-- ────────────────────────────────────────────────────────────
-- BATCH BROADCAST THREAD
-- ────────────────────────────────────────────────────────────
if Config.Sync and Config.Sync.batchSync then
    CreateThread(function()
        while true do
            Wait(Config.Sync.stateBagUpdateMs or 300)
            
            for bgId, changes in pairs(pendingBroadcasts) do
                if activeBags[bgId] then
                    -- Send update to owner
                    pushStateBag(bgId, activeBags[bgId].data)
                    
                    -- Force sync to all clients
                    TriggerClientEvent('rde_bg:forceSync', -1, bgId, activeBags[bgId].data)
                end
            end
            
            pendingBroadcasts = {}
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- REGISTER CALLBACKS
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:syncState', function(bgId, changes)
    local src = source
    if not activeBags[bgId] or activeBags[bgId].src ~= src then
        return
    end
    
    updateBGState(bgId, changes)
end)

RegisterNetEvent('rde_bg:updateHealth', function(bgId, health, maxHealth)
    local src = source
    if not activeBags[bgId] or activeBags[bgId].src ~= src then
        return
    end
    
    updateBGState(bgId, {
        health = health,
        maxHealth = maxHealth,
    })
end)

RegisterNetEvent('rde_bg:syncStats', function(bgId, stats)
    local src = source
    if not activeBags[bgId] or activeBags[bgId].src ~= src then
        return
    end
    
    updateBGState(bgId, stats)
end)

RegisterNetEvent('rde_bg:syncPosition', function(bgId, coords, heading)
    local src = source
    if not activeBags[bgId] or activeBags[bgId].src ~= src then
        return
    end
    
    -- Position sync is client-side only, don't persist to DB
    local bag = activeBags[bgId]
    bag.data.coords = coords
    bag.data.heading = heading
    bag.lastUpdate = os.time()
end)

-- ────────────────────────────────────────────────────────────
-- EXPORT FUNCTIONS
-- ────────────────────────────────────────────────────────────
function registerBG(bgId, src, charId, data)
    activeBags[bgId] = {
        src = src,
        charId = charId,
        data = data,
        lastUpdate = os.time(),
    }
    pushStateBag(bgId, data)
    
    -- Force broadcast to all clients
    TriggerClientEvent('rde_bg:forceSync', -1, bgId, data)
end

function unregisterBG(bgId)
    clearStateBag(bgId)
end

function getBGState(bgId)
    if not activeBags[bgId] then
        return nil
    end
    return activeBags[bgId].data
end

function getAllBGsForPlayer(src)
    local bgs = {}
    for bgId, bag in pairs(activeBags) do
        if bag.src == src then
            table.insert(bgs, {
                id = bgId,
                data = bag.data,
            })
        end
    end
    return bgs
end

-- ────────────────────────────────────────────────────────────
-- CLEANUP THREAD (Remove stale state bags)
-- ────────────────────────────────────────────────────────────
if Config.Performance and Config.Performance.cleanupIntervalMs then
    CreateThread(function()
        while true do
            Wait(Config.Performance.cleanupIntervalMs)
            
            local now = os.time()
            local staleThreshold = 300 -- 5 minutes
            
            for bgId, bag in pairs(activeBags) do
                if now - bag.lastUpdate > staleThreshold then
                    print('^3[RDE-BG]^7 Cleaning up stale state bag for BG ' .. bgId)
                    clearStateBag(bgId)
                end
            end
        end
    end)
end

print('^2[RDE-BG]^7 Server sync system loaded ✓')