-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.5  —  client/performance.lua
-- PERFORMANCE OPTIMIZATIONS: LOD, Distance Culling, Thread Management
-- ============================================================

local activeThreads = 0
local maxThreads = Config.Performance and Config.Performance.maxActiveThreads or 3
local lodCache = {}

-- ────────────────────────────────────────────────────────────
-- LOD (Level of Detail) SYSTEM
-- ────────────────────────────────────────────────────────────
function getLODLevel(distance)
    if not Config.Performance or not Config.Performance.enableLOD then
        return 'full'
    end

    local near = Config.Performance.lodNearDistance or 50.0
    local mid  = Config.Performance.lodMidDistance  or 150.0
    local far  = Config.Performance.lodFarDistance  or 300.0

    if distance <= near then
        return 'full'
    elseif distance <= mid then
        return 'medium'
    elseif distance <= far then
        return 'low'
    else
        return 'culled'
    end
end

function applyLOD(bg, level)
    if not DoesEntityExist(bg.ped) then return end

    -- Cache LOD level to avoid redundant updates
    if lodCache[bg.id] == level then return end
    lodCache[bg.id] = level

    if level == 'full' then
        -- Full detail - all features enabled
        SetEntityVisible(bg.ped, true, false)
        SetEntityAlpha(bg.ped, 255, false)
        SetPedCanRagdoll(bg.ped, true)
        
    elseif level == 'medium' then
        -- Medium detail - reduced complexity
        SetEntityVisible(bg.ped, true, false)
        SetEntityAlpha(bg.ped, 255, false)
        SetPedCanRagdoll(bg.ped, false) -- Disable ragdoll physics
        
    elseif level == 'low' then
        -- Low detail - minimal processing
        SetEntityVisible(bg.ped, true, false)
        SetEntityAlpha(bg.ped, 200, false) -- Slight transparency
        SetPedCanRagdoll(bg.ped, false)
        
    elseif level == 'culled' then
        -- Beyond render distance - invisible but tracked
        SetEntityVisible(bg.ped, false, false)
        SetEntityAlpha(bg.ped, 0, false)
        SetPedCanRagdoll(bg.ped, false)
    end
end

-- ────────────────────────────────────────────────────────────
-- DISTANCE CULLING
-- ────────────────────────────────────────────────────────────
function shouldCullBG(bg, playerCoords)
    if not Config.Performance then return false end

    local bgCoords = GetEntityCoords(bg.ped)
    local distance = #(playerCoords - bgCoords)
    
    local maxDist = Config.Performance.maxRenderDistance or 500.0
    
    return distance > maxDist
end

function shouldFadeOut(bg, playerCoords)
    if not Config.Performance then return false end

    local bgCoords = GetEntityCoords(bg.ped)
    local distance = #(playerCoords - bgCoords)
    
    local fadeStart = Config.Performance.fadeOutDistance or 450.0
    local maxDist   = Config.Performance.maxRenderDistance or 500.0
    
    if distance > fadeStart and distance <= maxDist then
        return true, (distance - fadeStart) / (maxDist - fadeStart)
    end
    
    return false, 0
end

-- ────────────────────────────────────────────────────────────
-- THREAD POOL MANAGEMENT
-- ────────────────────────────────────────────────────────────
function canSpawnThread()
    return activeThreads < maxThreads
end

function registerThread()
    activeThreads = activeThreads + 1
end

function unregisterThread()
    activeThreads = math.max(0, activeThreads - 1)
end

function getThreadCount()
    return activeThreads
end

-- ────────────────────────────────────────────────────────────
-- SMART UPDATE SCHEDULER
-- ────────────────────────────────────────────────────────────
local updatePriority = {}

function getUpdatePriority(bg, playerCoords)
    local bgCoords = GetEntityCoords(bg.ped)
    local distance = #(playerCoords - bgCoords)
    
    -- Priority factors:
    -- 1. Distance (closer = higher priority)
    -- 2. Combat state (combat = highest priority)
    -- 3. Health (low health = higher priority)
    
    local priority = 1000 - distance -- Base priority on distance
    
    if bg.state == 'combat' or bg.state == 'avenge' then
        priority = priority + 500 -- Combat boost
    end
    
    local healthPct = (bg.health or 200) / (bg.maxHealth or 200)
    if healthPct < 0.3 then
        priority = priority + 300 -- Low health boost
    end
    
    return priority
end

function sortBGsByPriority(bgs, playerCoords)
    local sorted = {}
    for bgId, bg in pairs(bgs) do
        if DoesEntityExist(bg.ped) then
            table.insert(sorted, {
                id = bgId,
                bg = bg,
                priority = getUpdatePriority(bg, playerCoords)
            })
        end
    end
    
    table.sort(sorted, function(a, b)
        return a.priority > b.priority
    end)
    
    return sorted
end

-- ────────────────────────────────────────────────────────────
-- PERFORMANCE MONITORING
-- ────────────────────────────────────────────────────────────
local perfStats = {
    frameTime = 0,
    bgCount = 0,
    threadsActive = 0,
    lastUpdate = 0,
}

function updatePerfStats()
    local now = GetGameTimer()
    if now - perfStats.lastUpdate < 1000 then return end
    
    perfStats.lastUpdate = now
    perfStats.frameTime = GetFrameTime() * 1000 -- ms
    perfStats.bgCount = 0
    perfStats.threadsActive = activeThreads
    
    for _ in pairs(activeBodyguards) do
        perfStats.bgCount = perfStats.bgCount + 1
    end
end

function getPerfStats()
    return perfStats
end

-- ────────────────────────────────────────────────────────────
-- ADAPTIVE UPDATE RATES
-- ────────────────────────────────────────────────────────────
function getAdaptiveUpdateRate(baseRate, loadFactor)
    -- Increase update intervals when system is under load
    if loadFactor > 0.8 then
        return baseRate * 2 -- Slow down by 2x
    elseif loadFactor > 0.6 then
        return baseRate * 1.5 -- Slow down by 1.5x
    else
        return baseRate -- Normal speed
    end
end

function getSystemLoadFactor()
    local frameTime = GetFrameTime() * 1000 -- ms
    local targetFrameTime = 16.67 -- 60 FPS = ~16.67ms per frame
    
    return math.min(1.0, frameTime / targetFrameTime)
end

-- ────────────────────────────────────────────────────────────
-- CLEANUP ON DESPAWN
-- ────────────────────────────────────────────────────────────
function cleanupLODCache(bgId)
    lodCache[bgId] = nil
    updatePriority[bgId] = nil
end

-- ────────────────────────────────────────────────────────────
-- DEBUG OVERLAY (if Config.Debug enabled)
-- ────────────────────────────────────────────────────────────
if Config.Debug then
    CreateThread(function()
        while true do
            Wait(100)
            updatePerfStats()
            
            local stats = getPerfStats()
            local text = string.format(
                "~b~RDE BG Performance~w~\n" ..
                "Frame Time: ~y~%.2fms~w~\n" ..
                "Active BGs: ~g~%d~w~\n" ..
                "Threads: ~c~%d/%d~w~\n" ..
                "Load: ~r~%.1f%%~w~",
                stats.frameTime,
                stats.bgCount,
                stats.threadsActive, maxThreads,
                getSystemLoadFactor() * 100
            )
            
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.35)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentString(text)
            DrawText(0.85, 0.05)
        end
    end)
end

print('^2[RDE-BG]^7 Performance optimizations loaded ✓')