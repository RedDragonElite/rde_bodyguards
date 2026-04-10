-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.2  —  client/spawn.lua
-- CINEMATIC ARRIVAL & DEPARTURE SYSTEM
-- v4.2: Filmreife Ankunft — 5 Phasen — KEIN goto (FiveM-safe)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- LOOKUP-TABLES
-- ────────────────────────────────────────────────────────────
local arrivalVehicles = {
    common    = { 'baller3',      'dubsta2',       'granger',    'serrano'      },
    uncommon  = { 'xls',          'schafter5',     'baller3',    'serrano'      },
    rare      = { 'xls',          'cognoscenti2',  'schafter6',  'stretch'      },
    epic      = { 'cognoscenti2', 'schafter6',     'stretch2',   'supervolito2' },
    legendary = { 'schafter6',    'cognoscenti2',  'stretch2',   'supervolito2' },
}

local greetingAnims = {
    [1] = { dict='mp_player_int_uppersalute',                   anim='mp_player_int_salute', dur=2500 },
    [2] = { dict='mp_ped_interaction',                          anim='handshake_guy_a',      dur=2800 },
    [3] = { dict='anim@mp_player_intcelebrationmale@fist_bump', anim='fist_bump',            dur=2000 },
    [4] = { dict='mp_ped_interaction',                          anim='hugs_guy_a',           dur=3200 },
    [5] = { dict='mp_ped_interaction',                          anim='hugs_guy_a',           dur=3200 },
}

local vehicleChance = {
    common=45, uncommon=60, rare=72, epic=85, legendary=96,
}

-- ────────────────────────────────────────────────────────────
-- HELFER
-- ────────────────────────────────────────────────────────────
local function getArrivalVeh(rarity)
    local pool = arrivalVehicles[rarity] or arrivalVehicles.common
    return pool[math.random(#pool)]
end

local function safeNodeUnpack(found, a, b, c, d)
    if not found then return false, nil, nil, nil, nil end
    if type(a) == 'vector3' then
        return true, a.x, a.y, a.z, (type(b) == 'number' and b or 0.0)
    end
    if type(a) == 'number' and type(b) == 'number' and type(c) == 'number' then
        return true, a, b, c, (type(d) == 'number' and d or 0.0)
    end
    return false, nil, nil, nil, nil
end

-- ────────────────────────────────────────────────────────────
-- CALCULATE SPAWN POSITION (RDE CARSERVICE STYLE!)
-- Uses same robust approach as rde_carservice for realism
-- ────────────────────────────────────────────────────────────
local function calculateSpawnPosition(playerCoords)
    local attempts = 0
    local maxAttempts = 25
    local spawnDistance = 200  -- Same as carservice!
    local bestSpawnCoords = nil
    local bestHeading = 0.0

    while attempts < maxAttempts do
        local heading = math.random(0, 360)
        local rad = math.rad(heading)
        local distance = spawnDistance + math.random(-50, 50)  -- 150-250m variation

        local testCoords = vector3(
            playerCoords.x + math.cos(rad) * distance,
            playerCoords.y + math.sin(rad) * distance,
            playerCoords.z
        )

        -- Find closest road node (like carservice!)
        local roadFound, roadCoords, roadHeading = GetClosestVehicleNodeWithHeading(
            testCoords.x, testCoords.y, testCoords.z, 1, 3.0, 0
        )

        if roadFound then
            -- Check if position is occupied
            local occupied = IsPositionOccupied(
                roadCoords.x, roadCoords.y, roadCoords.z, 5.0,
                false, true, true, false, false, 0, false
            )

            if not occupied then
                -- Find proper ground Z
                local foundGround, groundZ = GetGroundZFor_3dCoord(
                    roadCoords.x, roadCoords.y, roadCoords.z + 100.0, false
                )

                if foundGround then
                    roadCoords = vector3(roadCoords.x, roadCoords.y, groundZ + 0.5)
                end

                return roadCoords, roadHeading
            end
        end

        -- Save first valid position as fallback
        if not bestSpawnCoords then
            local foundGround, groundZ = GetGroundZFor_3dCoord(
                testCoords.x, testCoords.y, testCoords.z + 500.0, false
            )

            if foundGround then
                bestSpawnCoords = vector3(testCoords.x, testCoords.y, groundZ + 1.0)
                bestHeading = heading
            end
        end

        attempts = attempts + 1
    end

    -- Use fallback if found
    if bestSpawnCoords then
        return bestSpawnCoords, bestHeading
    end

    -- Last resort fallback
    return vector3(playerCoords.x + 100.0, playerCoords.y + 100.0, playerCoords.z), 0.0
end

local function getVehicleSpawnPoint(playerCoords)
    -- Use rde_carservice approach!
    local spawnCoords, spawnHeading = calculateSpawnPosition(playerCoords)
    return spawnCoords
end

local function getParkPosition(playerCoords, playerPed)
    for _, sideAngle in ipairs({90, 0, 180, 270}) do
        local px = playerCoords.x + math.cos(math.rad(sideAngle)) * math.random(6, 10)
        local py = playerCoords.y + math.sin(math.rad(sideAngle)) * math.random(6, 10)
        local found, nx, ny, nz, nh = safeNodeUnpack(
            GetNthClosestVehicleNodeWithHeading(px, py, playerCoords.z, 0, 1, 3, 0)
        )
        if found and nx then
            return nx, ny, nz, nh
        end
    end
    return playerCoords.x + 8.0, playerCoords.y, playerCoords.z,
           GetEntityHeading(playerPed)
end

local function playGreeting(ped, playerPed, relLvl)
    local greetA = greetingAnims[math.min(relLvl or 1, 5)] or greetingAnims[1]
    TaskTurnPedToFaceEntity(ped, playerPed, -1)
    Wait(400)
    local ok = lib.requestAnimDict(greetA.dict, 3000)
    if ok and DoesEntityExist(ped) then
        TaskPlayAnim(ped,       greetA.dict, greetA.anim, 8.0, -8.0, greetA.dur, 0, 0, false, false, false)
        TaskPlayAnim(playerPed, greetA.dict, greetA.anim, 8.0, -8.0, greetA.dur, 0, 0, false, false, false)
        Wait(greetA.dur)
    end
end

-- ────────────────────────────────────────────────────────────
-- FORWARD DECLARATION — footArrival wird von vehicleArrival
-- als Fallback gerufen, ist aber erst danach definiert.
-- ────────────────────────────────────────────────────────────
local footArrival

-- ────────────────────────────────────────────────────────────
-- VEHICLE ARRIVAL — Cinematic 5-Phase Sequence
-- ────────────────────────────────────────────────────────────
local function vehicleArrival(bgData, ped, onArrived)
    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnPos     = getVehicleSpawnPoint(playerCoords)
    local vehModel     = getArrivalVeh(bgData.rarity)

    if not lib.requestModel(vehModel, 6000) then
        footArrival(bgData, ped, onArrived)
        return
    end

    -- isNetwork=true so other players can see the vehicle!
    local veh = CreateVehicle(vehModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    SetModelAsNoLongerNeeded(vehModel)

    if not DoesEntityExist(veh) then
        footArrival(bgData, ped, onArrived)
        return
    end

    -- Register vehicle as networked so all clients see it
    if NetworkGetEntityIsNetworked(veh) then
        local vehNetId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdExistsOnAllMachines(vehNetId, true)
        SetNetworkIdCanMigrate(vehNetId, false)
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, math.random(0, 2) * 0.1)
    SetVehicleNumberPlateText(veh, 'RDE ' .. tostring(bgData.id):sub(1, 4))

    if bgData.rarity == 'epic' or bgData.rarity == 'legendary' then
        SetVehicleWindowTint(veh, 1)
    end

    -- Fahrer-NPC (isNetwork=true)
    local driverModel = 'g_m_m_chicold_01'
    lib.requestModel(driverModel, 4000)
    local driver = CreatePedInsideVehicle(veh, 26, driverModel, -1, true, false)
    SetModelAsNoLongerNeeded(driverModel)
    if DoesEntityExist(driver) then
        SetEntityAsMissionEntity(driver, true, true)
        if NetworkGetEntityIsNetworked(driver) then
            SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(driver), true)
        end
    end

    -- BG im Beifahrersitz (unsichtbar bis zum Aussteigen)
    -- FIX: Move ped from temp location to vehicle!
    FreezeEntityPosition(ped, false)  -- Unfreeze from temp spawn
    SetEntityCollision(ped, true, true)  -- Re-enable collision
    SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
    SetPedIntoVehicle(ped, veh, 0)  -- Seat 0 = front passenger right
    SetEntityAlpha(ped, 0, false)  -- Keep invisible until arrival

    local parkX, parkY, parkZ, parkH = getParkPosition(GetEntityCoords(playerPed), playerPed)

    if DoesEntityExist(driver) then
        TaskVehicleDriveToCoordLongrange(driver, veh, parkX, parkY, parkZ, 18.0, 786603, 4.0)
    end

    lib.notify({
        title='🚗 ' .. bgData.name,
        description='Unterwegs zu deiner Position... (ETA: ' .. math.ceil(#(GetEntityCoords(veh) - GetEntityCoords(playerPed)) / 18.0 * 2.5) .. 's)',
        type='inform', duration=4000, icon='car',
    })

    CreateThread(function()
        local notifiedNear = false

        -- Phase 1: Fahrzeug wartet bis es nahe ist (WITH 50m notification like carservice!)
        -- INCREASED timeout to 120 seconds (traffic/detours need more time!)
        local t1 = GetGameTimer() + 120000  -- 2 minutes instead of 35 seconds
        local nearPlayer = false
        while GetGameTimer() < t1 do
            Wait(250)
            if not DoesEntityExist(veh) or not DoesEntityExist(ped) then break end
            
            local vehCoords = GetEntityCoords(veh)
            local dist = #(vehCoords - GetEntityCoords(playerPed))
            
            -- Notification at 50m (like carservice!)
            if dist < 50.0 and not notifiedNear then
                lib.notify({
                    title='🚗 ' .. bgData.name,
                    description='Ist gleich da!',
                    type='success',
                    icon='circle-check',
                    iconColor='#22c55e'
                })
                notifiedNear = true
            end
            
            if dist < 18.0 then
                nearPlayer = true
                break
            end
        end

        -- CRITICAL FIX: If timeout or failure, DON'T call onArrived!
        -- Just cleanup and notify - keep BG in 'arriving' state
        if not nearPlayer or not DoesEntityExist(veh) or not DoesEntityExist(ped) then
            if DoesEntityExist(veh)    then DeleteVehicle(veh)    end
            if DoesEntityExist(driver) then DeletePed(driver)     end
            if DoesEntityExist(ped)    then DeletePed(ped)        end
            
            -- Remove from activeBodyguards (arrival failed)
            activeBodyguards[bgData.id] = nil
            
            lib.notify({
                title='❌ ' .. bgData.name,
                description='Arrival failed - took too long or vehicle lost',
                type='error',
                icon='ban',
                duration=5000
            })
            
            -- DON'T call onArrived! Just return and cleanup
            return
        end

        -- Phase 2: Einparken
        if DoesEntityExist(driver) then
            TaskVehiclePark(driver, veh, parkX, parkY, parkZ, parkH, 1, 5.0, true)
        end
        Wait(2200)
        ShakeGameplayCam('HAND_SHAKE', 0.03)

        -- Phase 3: BG aussteigen
        SetEntityAlpha(ped, 255, false)
        TaskLeaveVehicle(ped, veh, 0)

        local t3 = GetGameTimer() + 5500
        while GetGameTimer() < t3 do
            Wait(200)
            if not DoesEntityExist(ped) then break end
            if not IsPedInAnyVehicle(ped, false) then break end
        end

        if not DoesEntityExist(ped) then
            if DoesEntityExist(veh)    then DeleteVehicle(veh)    end
            if DoesEntityExist(driver) then DeletePed(driver)     end
            onArrived(ped, nil)
            return
        end

        -- Phase 4: BG läuft zum Spieler
        local cp = GetEntityCoords(playerPed)
        TaskGoToCoordAnyMeans(ped, cp.x, cp.y, cp.z, 1.4, 0, false, 786603, 0.0)

        local t4 = GetGameTimer() + 14000
        while GetGameTimer() < t4 do
            Wait(300)
            if not DoesEntityExist(ped) then break end
            if #(GetEntityCoords(ped) - GetEntityCoords(playerPed)) < 3.5 then break end
            if GetGameTimer() % 3500 < 350 then
                local cp2 = GetEntityCoords(playerPed)
                TaskGoToCoordAnyMeans(ped, cp2.x, cp2.y, cp2.z, 1.4, 0, false, 786603, 0.0)
            end
        end

        if not DoesEntityExist(ped) then
            if DoesEntityExist(veh)    then DeleteVehicle(veh)    end
            if DoesEntityExist(driver) then DeletePed(driver)     end
            onArrived(ped, nil)
            return
        end

        ClearPedTasks(ped)

        -- Phase 5: Begrüßung + Subtle arrival effect (like carservice!)
        playGreeting(ped, playerPed, bgData.relation_level or 1)
        
        -- EXACT carservice arrival effect!
        CreateThread(function()
            lib.requestNamedPtfxAsset('core', 2000)
            UseParticleFxAsset('core')
            StartParticleFxNonLoopedAtCoord(
                'ent_dst_elec_fire_sp',
                GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z,
                0.0, 0.0, 0.0,
                0.5, false, false, false
            )
        end)

        lib.notify({
            title='✅ ' .. bgData.name,
            description='Arrived and ready.',
            type='success', duration=3500, icon='shield',
        })

        -- Fahrer fährt selbst weg
        CreateThread(function()
            Wait(math.random(8000, 14000))
            if DoesEntityExist(driver) and DoesEntityExist(veh) then
                SetVehicleEngineOn(veh, true, true, false)
                TaskVehicleDriveWander(driver, veh, 22.0, 786603)
                Wait(14000)
                if DoesEntityExist(veh)    then
                    SetEntityAsMissionEntity(veh,    false, true)
                    DeleteVehicle(veh)
                end
                if DoesEntityExist(driver) then
                    SetEntityAsMissionEntity(driver, false, true)
                    DeletePed(driver)
                end
            end
        end)

        onArrived(ped, veh)
    end)
end

-- ────────────────────────────────────────────────────────────
-- ON-FOOT ARRIVAL — BG läuft heran, telefoniert dabei
-- (Assigned to forward-declared variable)
-- ────────────────────────────────────────────────────────────
footArrival = function(bgData, ped, onArrived)
    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Find a valid pavement/road spawn point near the player but off-screen
    local spawnCoords = nil
    for attempt = 1, 20 do
        local angle = math.random(360)
        local dist  = math.random(80, 140)
        local tx    = playerCoords.x + math.cos(math.rad(angle)) * dist
        local ty    = playerCoords.y + math.sin(math.rad(angle)) * dist

        -- Try to snap to navmesh (sidewalk/road)
        local found, navCoords = GetClosestVehicleNodeWithHeading(tx, ty, playerCoords.z, 1, 3.0, 0)
        if found and navCoords then
            local ok, gz = GetGroundZFor_3dCoord(navCoords.x, navCoords.y, navCoords.z + 50.0, false)
            if ok then
                spawnCoords = vector3(navCoords.x, navCoords.y, gz + 0.5)
                break
            end
        end

        -- Fallback: just find ground Z
        local ok2, gz2 = GetGroundZFor_3dCoord(tx, ty, playerCoords.z + 100.0, false)
        if ok2 then
            spawnCoords = vector3(tx, ty, gz2 + 0.5)
            break
        end
        Wait(0)
    end

    -- Last resort: spawn directly behind player
    if not spawnCoords then
        local h = GetEntityHeading(playerPed)
        spawnCoords = vector3(
            playerCoords.x + math.cos(math.rad(h + 180)) * 100.0,
            playerCoords.y + math.sin(math.rad(h + 180)) * 100.0,
            playerCoords.z
        )
    end

    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
    SetEntityHeading(ped, math.deg(math.atan(
        playerCoords.y - spawnCoords.y,
        playerCoords.x - spawnCoords.x
    )) - 90.0)

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityAlpha(ped, 255, false)
    SetEntityInvincible(ped, true)

    lib.notify({
        title   = bgData.name,
        description = 'On their way...',
        type    = 'inform', duration = 4000, icon = 'person-walking',
    })

    -- Issue initial NavMesh path — most reliable pathfinding in GTA V
    local function issueNavPath(targetCoords, speed)
        -- TaskFollowNavMeshToCoord uses the navmesh so BGs don't get stuck
        -- sliding=false, loose=true (arg 6/7), timeout 90s
        TaskFollowNavMeshToCoord(
            ped,
            targetCoords.x, targetCoords.y, targetCoords.z,
            speed,
            90000,   -- timeout ms
            0.5,     -- stop-range
            false,   -- use final heading
            0.0      -- final heading (ignored if above is false)
        )
    end

    issueNavPath(playerCoords, 1.6)

    CreateThread(function()
        local timeout   = GetGameTimer() + 90000
        local lastRetry = GetGameTimer()
        local stuckPos  = nil
        local stuckTime = 0

        while GetGameTimer() < timeout do
            Wait(500)
            if not DoesEntityExist(ped) then
                activeBodyguards[bgData.id] = nil
                return
            end

            local pedCoords   = GetEntityCoords(ped)
            local curTarget   = GetEntityCoords(playerPed)
            local dist        = #(pedCoords - curTarget)

            if dist < 3.5 then break end  -- arrived!

            local now = GetGameTimer()

            -- Re-issue path every 4s towards moving player
            if now - lastRetry > 4000 then
                lastRetry = now
                local speed = dist > 30.0 and 2.6 or (dist > 12.0 and 2.0 or 1.5)
                issueNavPath(curTarget, speed)
            end

            -- Stuck detection: if barely moved in 6s, teleport closer
            if stuckPos then
                local moved = #(pedCoords - stuckPos)
                if moved < 0.8 and (now - stuckTime) > 6000 then
                    -- Snap to a navmesh point 30m behind player — unstuck
                    local ph = GetEntityHeading(playerPed)
                    local txS = curTarget.x + math.cos(math.rad(ph + 180)) * 30.0
                    local tyS = curTarget.y + math.sin(math.rad(ph + 180)) * 30.0
                    local okS, gzS = GetGroundZFor_3dCoord(txS, tyS, curTarget.z + 50.0, false)
                    if okS then
                        SetEntityCoords(ped, txS, tyS, gzS + 0.5, false, false, false, false)
                    end
                    stuckPos  = nil
                    lastRetry = 0  -- force re-path next tick
                end
            else
                stuckPos  = pedCoords
                stuckTime = now
            end
        end

        if not DoesEntityExist(ped) then
            activeBodyguards[bgData.id] = nil
            return
        end

        -- Hard teleport fallback if still far
        local finalDist = #(GetEntityCoords(ped) - GetEntityCoords(playerPed))
        if finalDist > 8.0 then
            local ph = GetEntityHeading(playerPed)
            local fp = GetEntityCoords(playerPed)
            SetEntityCoords(ped,
                fp.x + math.cos(math.rad(ph + 160)) * 3.0,
                fp.y + math.sin(math.rad(ph + 160)) * 3.0,
                fp.z, false, false, false, false)
        end
        
        -- SUCCESS - BG arrived!
        ClearPedTasks(ped)
        SetEntityInvincible(ped, false)  -- Wieder verwundbar nach Ankunft

        playGreeting(ped, playerPed, bgData.relation_level or 1)
        
        -- EXACT carservice arrival effect! (subtle electric spark, NOT alien teleport!)
        CreateThread(function()
            lib.requestNamedPtfxAsset('core', 2000)
            UseParticleFxAsset('core')
            StartParticleFxNonLoopedAtCoord(
                'ent_dst_elec_fire_sp',  -- Same as carservice!
                GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z,
                0.0, 0.0, 0.0,
                0.5,  -- Same scale as carservice!
                false, false, false
            )
        end)

        lib.notify({
            title='✅ ' .. bgData.name,
            description='Ready for duty.',
            type='success', duration=3500, icon='shield',
        })

        onArrived(ped, nil)
    end)
end

-- ────────────────────────────────────────────────────────────
-- GLOBAL: realisticArrival — wird von client/main.lua aufgerufen
-- ────────────────────────────────────────────────────────────
function realisticArrival(bgData, ped, onArrived)
    local chance = vehicleChance[bgData.rarity] or 50
    if math.random(100) <= chance then
        vehicleArrival(bgData, ped, onArrived)
    else
        footArrival(bgData, ped, onArrived)
    end
end

-- ────────────────────────────────────────────────────────────
-- GLOBAL: realisticDeparture — wird von client/main.lua aufgerufen
-- ────────────────────────────────────────────────────────────
function realisticDeparture(bg, onDone)
    if not DoesEntityExist(bg.ped) then
        if onDone then onDone() end
        return
    end

    exports.ox_target:removeLocalEntity(bg.ped)

    if bg.blip and DoesBlipExist(bg.blip) then
        RemoveBlip(bg.blip)
        bg.blip = nil
    end

    ClearPedTasks(bg.ped)
    SetPedFleeAttributes(bg.ped, 0, false)
    SetBlockingOfNonTemporaryEvents(bg.ped, true)

    local playerPed = PlayerPedId()

    TaskTurnPedToFaceEntity(bg.ped, playerPed, -1)
    Wait(500)

    local relLvl = bg.relation_level or 1
    local farewell
    if relLvl >= 4 then
        farewell = { dict='mp_ped_interaction',        anim='hugs_guy_a',           dur=2500 }
    elseif relLvl >= 2 then
        farewell = { dict='mp_ped_interaction',        anim='handshake_guy_a',       dur=2000 }
    else
        farewell = { dict='mp_player_int_uppersalute', anim='mp_player_int_salute',  dur=2000 }
    end

    local ok = lib.requestAnimDict(farewell.dict, 3000)
    if ok and DoesEntityExist(bg.ped) then
        TaskPlayAnim(bg.ped,    farewell.dict, farewell.anim, 8.0, -8.0, farewell.dur, 0, 0, false, false, false)
        TaskPlayAnim(playerPed, farewell.dict, farewell.anim, 8.0, -8.0, farewell.dur, 0, 0, false, false, false)
        Wait(farewell.dur)
    end

    local playerCoords = GetEntityCoords(playerPed)
    local awayAngle    = math.random(360)
    local awayX = playerCoords.x + math.cos(math.rad(awayAngle)) * math.random(80, 120)
    local awayY = playerCoords.y + math.sin(math.rad(awayAngle)) * math.random(80, 120)

    TaskGoStraightToCoord(bg.ped, awayX, awayY, playerCoords.z, 1.3, 25000, 0.0, 1.0)

    -- Letzter Gruß nach ~5m
    CreateThread(function()
        Wait(3500)
        if not DoesEntityExist(bg.ped) then return end
        local d = #(GetEntityCoords(bg.ped) - playerCoords)
        if d > 4.0 and d < 20.0 then
            TaskTurnPedToFaceEntity(bg.ped, playerPed, -1)
            Wait(700)
            local w = lib.requestAnimDict('mp_player_int_uppersalute', 2000)
            if w and DoesEntityExist(bg.ped) then
                TaskPlayAnim(bg.ped, 'mp_player_int_uppersalute', 'mp_player_int_salute',
                    8.0, -8.0, 1500, 0, 0, false, false, false)
                Wait(1500)
            end
            if DoesEntityExist(bg.ped) then
                TaskGoStraightToCoord(bg.ped, awayX, awayY, playerCoords.z, 1.3, 20000, 0.0, 1.0)
            end
        end
    end)

    -- Fade-out
    CreateThread(function()
        local timeout = GetGameTimer() + 22000
        while GetGameTimer() < timeout do
            Wait(500)
            if not DoesEntityExist(bg.ped) then break end
            if #(GetEntityCoords(bg.ped) - playerCoords) > 50.0 then break end
        end
        if DoesEntityExist(bg.ped) then
            for i = 255, 0, -15 do
                if DoesEntityExist(bg.ped) then SetEntityAlpha(bg.ped, i, false) end
                Wait(50)
            end
            if DoesEntityExist(bg.ped) then DeletePed(bg.ped) end
        end
        if onDone then onDone() end
    end)
end

print('^2[RDE-BG]^7 Spawn/Departure v4.2 (Cinematic) loaded ✓')