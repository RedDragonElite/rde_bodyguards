-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.5  —  client/sync.lua
-- ENHANCED SYNCHRONIZATION & STATE MANAGEMENT
-- Production-ready cross-client sync with optimizations
-- ============================================================

local lastStateBagUpdate = {}
local lastGlobalStateUpdate = {}
local pendingUpdates = {}
local syncThreadActive = false

-- ────────────────────────────────────────────────────────────
-- THROTTLED STATE BAG UPDATES
-- ────────────────────────────────────────────────────────────
function syncBGState(bgId, changes)
    if not Config.Sync or not Config.Sync.throttleUpdates then
        TriggerServerEvent('rde_bg:syncState', bgId, changes)
        return
    end

    local now = GetGameTimer()
    local lastUpdate = lastStateBagUpdate[bgId] or 0
    local throttleMs = Config.Sync.stateBagUpdateMs or 300

    if now - lastUpdate < throttleMs then
        -- Queue update for batch processing
        pendingUpdates[bgId] = pendingUpdates[bgId] or {}
        for k, v in pairs(changes) do
            pendingUpdates[bgId][k] = v
        end
        return
    end

    lastStateBagUpdate[bgId] = now
    TriggerServerEvent('rde_bg:syncState', bgId, changes)
end

-- ────────────────────────────────────────────────────────────
-- BATCH SYNC THREAD
-- ────────────────────────────────────────────────────────────
if Config.Sync and Config.Sync.batchSync then
    CreateThread(function()
        while true do
            Wait(Config.Sync.stateBagUpdateMs or 300)
            
            if next(pendingUpdates) then
                for bgId, changes in pairs(pendingUpdates) do
                    TriggerServerEvent('rde_bg:syncState', bgId, changes)
                    lastStateBagUpdate[bgId] = GetGameTimer()
                end
                pendingUpdates = {}
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- HEALTH SYNC (Optimized)
-- ────────────────────────────────────────────────────────────
local lastHealthSync = {}

function syncBGHealth(bgId, health, maxHealth)
    if not Config.Sync then
        TriggerServerEvent('rde_bg:updateHealth', bgId, health, maxHealth)
        return
    end

    local now = GetGameTimer()
    local lastSync = lastHealthSync[bgId] or 0
    local syncMs = Config.Sync.healthSyncMs or 1000

    -- Always sync critical health immediately
    local healthPct = health / math.max(maxHealth, 1)
    if healthPct < 0.2 then
        TriggerServerEvent('rde_bg:updateHealth', bgId, health, maxHealth)
        lastHealthSync[bgId] = now
        return
    end

    -- Throttle normal health updates
    if now - lastSync >= syncMs then
        TriggerServerEvent('rde_bg:updateHealth', bgId, health, maxHealth)
        lastHealthSync[bgId] = now
    end
end

-- ────────────────────────────────────────────────────────────
-- STATS SYNC (Morale, Wounds, etc)
-- ────────────────────────────────────────────────────────────
local lastStatsSync = {}

function syncBGStats(bgId, stats)
    if not Config.Sync then
        TriggerServerEvent('rde_bg:syncStats', bgId, stats)
        return
    end

    local now = GetGameTimer()
    local lastSync = lastStatsSync[bgId] or 0
    local syncMs = Config.Sync.statsSyncMs or 2000

    if now - lastSync >= syncMs then
        TriggerServerEvent('rde_bg:syncStats', bgId, stats)
        lastStatsSync[bgId] = now
    end
end

-- ────────────────────────────────────────────────────────────
-- POSITION SYNC (for cinematic arrivals/departures)
-- ────────────────────────────────────────────────────────────
local lastPositionSync = {}

function syncBGPosition(bgId, coords, heading)
    if not Config.Sync then
        return
    end

    local now = GetGameTimer()
    local lastSync = lastPositionSync[bgId] or 0
    local syncMs = Config.Sync.positionSyncMs or 250

    if now - lastSync >= syncMs then
        TriggerServerEvent('rde_bg:syncPosition', bgId, coords, heading)
        lastPositionSync[bgId] = now
    end
end

-- ────────────────────────────────────────────────────────────
-- DATA COMPRESSION (for reduced bandwidth)
-- ────────────────────────────────────────────────────────────
function compressStateData(data, level)
    if not level or level == 0 then
        return data
    end

    local compressed = {}
    
    -- Level 1: Remove unchanged values (delta compression)
    if level >= 1 then
        -- Only include changed values
        -- (Implementation would compare to last known state)
        compressed = data
    end

    -- Level 2: Round floating point values
    if level >= 2 then
        for k, v in pairs(data) do
            if type(v) == 'number' and not math.floor(v) == v then
                compressed[k] = math.floor(v * 100) / 100
            else
                compressed[k] = v
            end
        end
    end

    -- Level 3: Use abbreviated keys
    if level >= 3 then
        local abbrev = {
            morale = 'mor',
            health = 'hp',
            wound = 'wnd',
            state = 'st',
            level = 'lvl',
            prestige = 'prs',
        }
        local result = {}
        for k, v in pairs(compressed) do
            result[abbrev[k] or k] = v
        end
        compressed = result
    end

    return compressed
end

-- ────────────────────────────────────────────────────────────
-- SMART SYNC (Only sync when needed)
-- ────────────────────────────────────────────────────────────
local lastKnownState = {}

function smartSync(bgId, newState)
    local lastState = lastKnownState[bgId]
    
    if not lastState then
        lastKnownState[bgId] = newState
        syncBGState(bgId, newState)
        return
    end

    -- Only sync changed values
    local changes = {}
    for k, v in pairs(newState) do
        if lastState[k] ~= v then
            changes[k] = v
            lastState[k] = v
        end
    end

    if next(changes) then
        local compressionLevel = (Config.Sync and Config.Sync.compressionLevel) or 0
        local compressed = compressStateData(changes, compressionLevel)
        syncBGState(bgId, compressed)
    end
end

-- ────────────────────────────────────────────────────────────
-- CLEANUP ON DESPAWN
-- ────────────────────────────────────────────────────────────
function cleanupSyncData(bgId)
    lastStateBagUpdate[bgId] = nil
    lastGlobalStateUpdate[bgId] = nil
    pendingUpdates[bgId] = nil
    lastHealthSync[bgId] = nil
    lastStatsSync[bgId] = nil
    lastPositionSync[bgId] = nil
    lastKnownState[bgId] = nil
end

-- ────────────────────────────────────────────────────────────
-- GLOBAL CLEANUP THREAD
-- ────────────────────────────────────────────────────────────
if Config.Performance and Config.Performance.cleanupIntervalMs then
    CreateThread(function()
        while true do
            Wait(Config.Performance.cleanupIntervalMs)
            
            -- Clean up data for bodyguards that no longer exist
            for bgId in pairs(lastKnownState) do
                if not activeBodyguards[bgId] then
                    cleanupSyncData(bgId)
                end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- STATEBAG LISTENER — Cross-Player Sync (CRITICAL!)
-- ────────────────────────────────────────────────────────────
AddStateBagChangeHandler('rde_bg_', nil, function(bagName, key, value, reserved)
    -- Extract bgId from bagName: "rde_bg_123" → 123
    local bgId = tonumber(bagName:match('rde_bg_(%d+)'))
    if not bgId then return end

    -- value is JSON-encoded string from server
    local data = value and json.decode(value) or nil
    
    if not data then
        -- BG was despawned/deleted
        if activeBodyguards[bgId] then
            local bg = activeBodyguards[bgId]
            if DoesEntityExist(bg.ped) then
                -- Fade out and delete for other players
                CreateThread(function()
                    for i = 255, 0, -25 do
                        if DoesEntityExist(bg.ped) then
                            SetEntityAlpha(bg.ped, i, false)
                        end
                        Wait(50)
                    end
                    if DoesEntityExist(bg.ped) then
                        DeletePed(bg.ped)
                    end
                end)
            end
            if bg.blip and DoesBlipExist(bg.blip) then
                RemoveBlip(bg.blip)
            end
            activeBodyguards[bgId] = nil
        end
        return
    end

    -- Skip if this is our own BG (we spawn it locally via activateBodyguard)
    if data.owner_src == GetPlayerServerId(PlayerId()) then
        return
    end

    -- This is ANOTHER player's BG — get the networked entity
    if not activeBodyguards[bgId] then
        -- Wait for network ID to be available
        if not data.network_id then
            return  -- Network ID not yet synced, wait for next update
        end
        
        CreateThread(function()
            -- Try to get the networked entity
            local timeout = GetGameTimer() + 5000
            local ped = nil
            
            while GetGameTimer() < timeout do
                if NetworkDoesNetworkIdExist(data.network_id) then
                    ped = NetworkGetEntityFromNetworkId(data.network_id)
                    if DoesEntityExist(ped) then
                        break
                    end
                end
                Wait(100)
            end
            
            if not ped or not DoesEntityExist(ped) then
                print('^3[RDE-BG]^7 Failed to get networked entity for BG', bgId, 'netId', data.network_id)
                return
            end

            -- Basic setup for networked ped
            SetEntityAsMissionEntity(ped, true, true)
            SetPedCanRagdoll(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, false)
            SetPedRelationshipGroupHash(ped, GetHashKey('BODYGUARD'))

            -- NO BLIP for other players' bodyguards!
            -- This prevents minimap clutter

            -- Store in activeBodyguards (marked as networked)
            activeBodyguards[bgId] = {
                id         = bgId,
                ped        = ped,
                blip       = nil,  -- NO BLIP for networked BGs
                name       = data.name,
                model      = data.model,
                gender     = data.gender,
                rarity     = data.rarity,
                level      = data.level,
                health     = data.health,
                maxHealth  = data.health,
                morale     = data.morale,
                wound      = data.wound,
                networked  = true,  -- Flag: this is another player's BG
                owner_src  = data.owner_src,
            }

            print('^3[RDE-BG]^7 Synced networked BG:', bgId, data.name, 'for player', data.owner_src, 'netId', data.network_id)
        end)
    else
        -- BG already exists, update data
        local bg = activeBodyguards[bgId]
        bg.health    = data.health
        bg.morale    = data.morale
        bg.wound     = data.wound
        bg.level     = data.level
        
        -- Update health on ped
        if DoesEntityExist(bg.ped) then
            local maxHp = data.health or bg.maxHealth
            SetEntityMaxHealth(bg.ped, maxHp)
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- FORCE SYNC EVENT — ensures all clients get the update
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:forceSync', function(bgId, data)
    -- This triggers the same logic as statebag change
    -- but ensures it happens even if statebag listener missed it
    if not data then return end
    
    -- Skip if this is our own BG
    if data.owner_src == GetPlayerServerId(PlayerId()) then
        return
    end
    
    -- If we already have this BG, just update data
    if activeBodyguards[bgId] then
        local bg = activeBodyguards[bgId]
        bg.health = data.health
        bg.morale = data.morale
        bg.wound  = data.wound
        bg.level  = data.level
        return
    end
    
    -- Otherwise, spawn the networked entity (same logic as statebag handler)
    if not data.network_id then return end
    
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        local ped = nil
        
        while GetGameTimer() < timeout do
            if NetworkDoesNetworkIdExist(data.network_id) then
                ped = NetworkGetEntityFromNetworkId(data.network_id)
                if DoesEntityExist(ped) then
                    break
                end
            end
            Wait(100)
        end
        
        if not ped or not DoesEntityExist(ped) then
            print('^3[RDE-BG]^7 Force sync failed for BG', bgId, 'netId', data.network_id)
            return
        end

        -- Basic setup
        SetEntityAsMissionEntity(ped, true, true)
        SetPedCanRagdoll(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, false)
        SetPedRelationshipGroupHash(ped, GetHashKey('BODYGUARD'))

        -- NO BLIP for other players' bodyguards

        -- Store
        activeBodyguards[bgId] = {
            id         = bgId,
            ped        = ped,
            blip       = nil,  -- NO BLIP
            name       = data.name,
            model      = data.model,
            gender     = data.gender,
            rarity     = data.rarity,
            level      = data.level,
            health     = data.health,
            maxHealth  = data.health,
            morale     = data.morale,
            wound      = data.wound,
            networked  = true,
            owner_src  = data.owner_src,
        }

        print('^2[RDE-BG]^7 Force synced networked BG:', bgId, data.name)
    end)
end)

print('^2[RDE-BG]^7 Enhanced sync system loaded ✓ (STATEBAG LISTENER ACTIVE!)')