-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v5.1  —  client/main.lua
-- v5.1: FULL ox_target command system, weapon management,
--        manual heal, attack orders, holster toggle
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- GLOBALE STATE-TABLES
-- ────────────────────────────────────────────────────────────
activeBodyguards  = {}
interactCooldowns = {}
formationSlotMap  = {}
playerFormation   = 'follow'

-- ────────────────────────────────────────────────────────────
-- v5.1: GLOBAL COMMAND FUNCTIONS (called by ox_target + radial)
-- These set BG state and issue tasks directly
-- ────────────────────────────────────────────────────────────

-- Order: Follow player
function orderFollow(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    bg.state  = 'follow'
    bg.target = nil
    bg.guardPos = nil
    ClearPedTasks(bg.ped)
    TriggerServerEvent('rde_bg:syncState', bgId, { state = 'follow' })
    lib.notify({ title = '🚶 ' .. bg.name, description = 'Following you.', type = 'inform', duration = 2000, icon = 'person-walking' })
    if addMemory then addMemory(bgId, 'Ordered to follow.') end
end

-- Order: Stay / Guard position
function orderGuard(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    bg.state    = 'guard'
    bg.guardPos = GetEntityCoords(bg.ped)
    bg.target   = nil
    bg._guardTaskIssued = nil
    ClearPedTasks(bg.ped)
    TriggerServerEvent('rde_bg:syncState', bgId, { state = 'guard' })
    lib.notify({ title = '🛑 ' .. bg.name, description = 'Holding position.', type = 'inform', duration = 2000, icon = 'location-dot' })
    if addMemory then addMemory(bgId, 'Ordered to hold position.') end
end

-- Order: Patrol area
function orderPatrol(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    bg.state        = 'patrol'
    bg.patrolCenter = GetEntityCoords(bg.ped)
    bg.target       = nil
    bg.lastPatrolMv = 0
    ClearPedTasks(bg.ped)
    TriggerServerEvent('rde_bg:syncState', bgId, { state = 'patrol' })
    lib.notify({ title = '🔄 ' .. bg.name, description = 'Patrolling area.', type = 'inform', duration = 2000, icon = 'route' })
    if addMemory then addMemory(bgId, 'Ordered to patrol.') end
end

-- Order: Attack nearest target
function orderAttackNearest(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    -- Scan for any armed/hostile NPC nearby
    local bgCoords = GetEntityCoords(bg.ped)
    local playerPed = PlayerPedId()
    local nearby = lib.getNearbyPeds(bgCoords, 60.0) or {}
    local bestTarget = nil
    local bestDist   = 999.0

    for _, data in ipairs(nearby) do
        local p = data.ped
        if p and p ~= playerPed and p ~= bg.ped
        and DoesEntityExist(p) and not IsEntityDead(p)
        and not IsPedAPlayer(p) then
            -- Check if hostile or armed
            local _, weapHash = GetCurrentPedWeapon(p)
            local armed = weapHash ~= GetHashKey('WEAPON_UNARMED')
            local rel = GetRelationshipBetweenPeds(p, playerPed)
            local hostile = rel == 5 or IsPedInCombat(p, playerPed)

            if hostile or armed then
                local d = data.distance or #(GetEntityCoords(p) - bgCoords)
                if d < bestDist then
                    bestDist   = d
                    bestTarget = p
                end
            end
        end
    end

    if bestTarget then
        bg.state  = 'combat'
        bg.target = bestTarget
        ClearPedTasks(bg.ped)
        TaskCombatPed(bg.ped, bestTarget, 0, 16)
        lib.notify({ title = '⚔️ ' .. bg.name, description = 'Engaging nearest threat!', type = 'warning', duration = 2500, icon = 'crosshairs' })
        if addMemory then addMemory(bgId, 'Ordered to engage nearest threat.') end
    else
        lib.notify({ title = '❌ ' .. bg.name, description = 'No hostile targets found.', type = 'error', duration = 2000 })
    end
end

-- Order: Attack ALL hostiles in area
function orderAttackAll(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    bg.state = 'combat'
    -- Set to very aggressive mode
    SetPedCombatAttributes(bg.ped, 46, false)   -- Don't use cover
    SetPedCombatAttributes(bg.ped, 5, true)     -- Can fight armed
    SetPedFleeAttributes(bg.ped, 0, false)

    -- Find and engage the closest threat first
    orderAttackNearest(bgId)

    lib.notify({ title = '🔥 ' .. bg.name, description = 'Engaging all hostiles!', type = 'error', duration = 3000, icon = 'skull-crossbones' })
    if addMemory then addMemory(bgId, 'Ordered to eliminate all threats in area.') end
end

-- Order: Attack specific ped the player is aiming at
function orderAttackTarget(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    local playerPed = PlayerPedId()
    local _, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())

    if targetEntity and DoesEntityExist(targetEntity) and IsEntityAPed(targetEntity)
    and not IsPedAPlayer(targetEntity) and not IsEntityDead(targetEntity) then
        bg.state  = 'combat'
        bg.target = targetEntity
        ClearPedTasks(bg.ped)
        TaskCombatPed(bg.ped, targetEntity, 0, 16)
        lib.notify({ title = '🎯 ' .. bg.name, description = 'Attacking your target!', type = 'warning', duration = 2500, icon = 'crosshairs' })
        if addMemory then addMemory(bgId, 'Ordered to attack specific target.') end
    else
        lib.notify({ title = '❌ No Target', description = 'Aim at a ped first, then give the order.', type = 'error', duration = 3000 })
    end
end

-- Order: Set peaceful (no combat)
function orderPeaceful(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    bg.state  = 'follow'
    bg.target = nil
    ClearPedTasks(bg.ped)
    SetPedCombatAttributes(bg.ped, 46, true)    -- Use cover
    SetPedCombatAttributes(bg.ped, 1, true)     -- CAN flee (peaceful mode)
    SetBlockingOfNonTemporaryEvents(bg.ped, true) -- Ignore hostile events
    TriggerServerEvent('rde_bg:syncState', bgId, { state = 'follow' })
    lib.notify({ title = '☮️ ' .. bg.name, description = 'Peaceful mode — won\'t engage.', type = 'success', duration = 2500, icon = 'dove' })
    if addMemory then addMemory(bgId, 'Set to peaceful mode.') end
end

-- Order: Set aggressive (default combat mode)
function orderAggressive(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    SetPedCombatAttributes(bg.ped, 5, true)
    SetPedCombatAttributes(bg.ped, 46, true)
    SetPedCombatAttributes(bg.ped, 1, false)    -- No flee
    SetPedCombatAttributes(bg.ped, 52, true)
    SetBlockingOfNonTemporaryEvents(bg.ped, false)
    SetPedFleeAttributes(bg.ped, 0, false)
    lib.notify({ title = '😤 ' .. bg.name, description = 'Combat mode — will engage threats.', type = 'warning', duration = 2500, icon = 'shield' })
    if addMemory then addMemory(bgId, 'Set to aggressive/combat mode.') end
end

-- Order: Holster weapon
function orderHolster(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end
    SetCurrentPedWeapon(bg.ped, GetHashKey('WEAPON_UNARMED'), true)
    bg._holstered = true
    lib.notify({ title = '🔒 ' .. bg.name, description = 'Weapon holstered.', type = 'inform', duration = 2000, icon = 'hand' })
end

-- Order: Unholster / draw weapon
function orderUnholster(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    -- Re-equip last weapon or get from inventory
    if equipBestWeapon then
        equipBestWeapon(bgId)
    end
    bg._holstered = false
    lib.notify({ title = '🔓 ' .. bg.name, description = 'Weapon drawn.', type = 'inform', duration = 2000, icon = 'gun' })
end

-- Order: Manual heal (player tells BG to use heal item)
function orderHeal(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    local hp  = GetEntityHealth(bg.ped)
    local pct = hp / math.max(bg.maxHealth or 200, 1)

    if pct >= 0.95 then
        lib.notify({ title = '✅ ' .. bg.name, description = 'Already at full health.', type = 'inform', duration = 2000 })
        return
    end

    -- Force self-heal attempt (bypass cooldown for manual command)
    if selfHealCooldowns then selfHealCooldowns[bgId] = nil end

    lib.callback('rde_bg:selfHeal', false, function(res)
        if not res or not res.ok then
            lib.notify({ title = '❌ ' .. bg.name, description = res and res.msg or 'No bandage or medkit in gear!', type = 'error', duration = 3000, icon = 'kit-medical' })
            return
        end

        local bgRef = activeBodyguards[bgId]
        if not bgRef or not DoesEntityExist(bgRef.ped) then return end

        -- Play heal animation
        CreateThread(function()
            ClearPedTasks(bgRef.ped)
            local healDict = 'anim@heists@narcotics@funding@gang_idle'
            local ok = lib.requestAnimDict(healDict, 3000)
            if ok and DoesEntityExist(bgRef.ped) then
                TaskPlayAnim(bgRef.ped, healDict, 'idle_a', 4.0, -4.0, 3500, 1, 0, false, false, false)
                Wait(3500)
            end

            if not DoesEntityExist(bgRef.ped) then return end

            -- Apply heal
            local healPct  = res.healPct or 0.25
            local medBonus = 1.0 + (bgRef.skills.medical or 0) * 0.005
            local healAmt  = math.floor((bgRef.maxHealth or 200) * healPct * medBonus)
            local newHp    = math.min(bgRef.maxHealth or 200, GetEntityHealth(bgRef.ped) + healAmt)
            SetEntityHealth(bgRef.ped, newHp)

            -- Reduce wound
            local curIdx   = Config.GetWoundIndex(bgRef.wound or 'none')
            local newIdx   = math.max(1, curIdx - (res.woundClear or 1))
            local newWound = Config.GetWoundByIndex(newIdx)
            bgRef.wound = newWound
            TriggerServerEvent('rde_bg:setWound', bgRef.id, newWound)
            TriggerServerEvent('rde_bg:updateMorale', bgRef.id, Config.Morale.gainOnSelfHeal or 3)
            TriggerServerEvent('rde_bg:addXP', bgRef.id, 'heal_self')
            bgRef.morale = math.min(100, (bgRef.morale or 75) + (Config.Morale.gainOnSelfHeal or 3))

            local itemLabel = res.itemUsed == 'medkit' and 'Medkit' or 'Bandage'
            if addMemory then addMemory(bgRef.id, 'Used ' .. itemLabel .. ' on your order.') end

            lib.notify({
                title       = '🩹 ' .. bgRef.name .. ' — Healed!',
                description = itemLabel .. ' used · +' .. healAmt .. ' HP',
                type        = 'success', duration = 3500, icon = 'kit-medical', iconColor = '#22c55e',
            })

            -- Heal effect
            local coords = GetEntityCoords(bgRef.ped)
            lib.requestNamedPtfxAsset('core', 2000)
            UseParticleFxAsset('core')
            StartParticleFxNonLoopedAtCoord('ent_dst_elec_fire_sp', coords.x, coords.y, coords.z + 0.3, 0.0, 0.0, 0.0, 0.3, false, false, false)
        end)
    end, bgId, 'any')
end

-- Order: Open weapon selection from inventory
function orderWeaponSelect(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    lib.callback('rde_bg:getWeapons', false, function(weapons)
        if not weapons or #weapons == 0 then
            lib.notify({ title = '❌ No Weapons', description = 'Put weapons in ' .. (bg.name or 'BG') .. '\'s gear first.', type = 'error', duration = 3000 })
            return
        end

        local options = {}
        for _, w in ipairs(weapons) do
            local weapLabel = w.name:gsub('WEAPON_', ''):gsub('_', ' ')
            table.insert(options, {
                title       = weapLabel:upper(),
                description = 'Ammo: ' .. (w.ammo or 0),
                icon        = 'gun',
                iconColor   = '#60a5fa',
                onSelect    = function()
                    if not activeBodyguards[bgId] then return end
                    local bgRef = activeBodyguards[bgId]
                    if not DoesEntityExist(bgRef.ped) then return end

                    RemoveAllPedWeapons(bgRef.ped, true)
                    local hash = GetHashKey(w.name:upper())
                    GiveWeaponToPed(bgRef.ped, hash, w.ammo or 250, false, true)
                    SetCurrentPedWeapon(bgRef.ped, hash, true)
                    bgRef._holstered = false

                    lib.notify({ title = '🔫 ' .. bgRef.name, description = 'Equipped: ' .. weapLabel:upper(), type = 'success', duration = 2500 })
                    if addMemory then addMemory(bgId, 'Switched weapon to ' .. weapLabel .. '.') end
                end,
            })
        end

        -- Unarmed option
        table.insert(options, {
            title = 'UNARMED (Fists)', icon = 'hand-fist', iconColor = '#f59e0b',
            onSelect = function()
                local bgRef = activeBodyguards[bgId]
                if bgRef and DoesEntityExist(bgRef.ped) then
                    RemoveAllPedWeapons(bgRef.ped, true)
                    bgRef._holstered = true
                    lib.notify({ title = '👊 ' .. bgRef.name, description = 'Fighting unarmed.', type = 'inform', duration = 2000 })
                end
            end,
        })

        table.insert(options, { title = '← Back', icon = 'arrow-left', onSelect = function() lib.hideContext() end })

        lib.registerContext({ id = 'rde_bg_weapsel_' .. bgId, title = '🔫 ' .. bg.name .. ' — Weapon', options = options })
        lib.showContext('rde_bg_weapsel_' .. bgId)
    end, bgId)
end

-- ────────────────────────────────────────────────────────────
-- RADIAL MENU
-- ────────────────────────────────────────────────────────────
local currentRadialItems = {}

function buildRadialMenu()
    for itemId, _ in pairs(currentRadialItems) do
        lib.removeRadialItem(itemId)
        currentRadialItems[itemId] = nil
    end

    -- Per-BG quick command items
    for bgId, bg in pairs(activeBodyguards) do
        if not bg.networked then
            -- Main BG entry (opens full menu)
            local itemId = 'bg_order_' .. bgId
            lib.addRadialItem({
                id       = itemId,
                label    = bg.name or ('BG #' .. bgId),
                icon     = 'shield',
                onSelect = function()
                    openBGMenu({ id = bgId, name = bg.name, level = bg.level,
                                 rarity = bg.rarity, is_active = 1, is_dead = 0,
                                 skills = bg.skills, wound = bg.wound, morale = bg.morale,
                                 affection = bg.affection, relation_level = bg.relation_level,
                                 prestige = bg.prestige, gender = bg.gender })
                end,
            })
            currentRadialItems[itemId] = true

            -- Follow command
            local fId = 'bg_follow_' .. bgId
            lib.addRadialItem({
                id = fId, label = bg.name .. ': Follow', icon = 'person-walking',
                onSelect = function() orderFollow(bgId) end,
            })
            currentRadialItems[fId] = true

            -- Stay command
            local gId = 'bg_guard_' .. bgId
            lib.addRadialItem({
                id = gId, label = bg.name .. ': Stay', icon = 'location-dot',
                onSelect = function() orderGuard(bgId) end,
            })
            currentRadialItems[gId] = true

            -- Attack command
            local aId = 'bg_attack_' .. bgId
            lib.addRadialItem({
                id = aId, label = bg.name .. ': Attack All', icon = 'skull-crossbones',
                onSelect = function() orderAttackAll(bgId) end,
            })
            currentRadialItems[aId] = true

            -- Heal command
            local hId = 'bg_heal_' .. bgId
            lib.addRadialItem({
                id = hId, label = bg.name .. ': Heal', icon = 'kit-medical',
                onSelect = function() orderHeal(bgId) end,
            })
            currentRadialItems[hId] = true
        end
    end

    -- Global commands (all BGs at once)
    local allFollowId = 'bg_all_follow'
    lib.addRadialItem({
        id = allFollowId, label = 'All: Follow', icon = 'users',
        onSelect = function()
            for bgId, bg in pairs(activeBodyguards) do
                if not bg.networked then orderFollow(bgId) end
            end
        end,
    })
    currentRadialItems[allFollowId] = true

    local allGuardId = 'bg_all_guard'
    lib.addRadialItem({
        id = allGuardId, label = 'All: Stay', icon = 'location-crosshairs',
        onSelect = function()
            for bgId, bg in pairs(activeBodyguards) do
                if not bg.networked then orderGuard(bgId) end
            end
        end,
    })
    currentRadialItems[allGuardId] = true

    local allAttackId = 'bg_all_attack'
    lib.addRadialItem({
        id = allAttackId, label = 'All: Attack', icon = 'crosshairs',
        onSelect = function()
            for bgId, bg in pairs(activeBodyguards) do
                if not bg.networked then orderAttackAll(bgId) end
            end
        end,
    })
    currentRadialItems[allAttackId] = true

    -- Main menu
    local mainMenuId = 'bg_main_menu'
    lib.addRadialItem({
        id       = mainMenuId,
        label    = 'BG Menu',
        icon     = 'bars',
        onSelect = openMainMenu,
    })
    currentRadialItems[mainMenuId] = true
end

-- ────────────────────────────────────────────────────────────
-- ORDER COMMANDS
-- ────────────────────────────────────────────────────────────
local function setAllOrders(newState)
    for bgId, bg in pairs(activeBodyguards) do
        if not bg.networked then
            if newState == 'follow' then orderFollow(bgId)
            elseif newState == 'guard' then orderGuard(bgId)
            elseif newState == 'patrol' then orderPatrol(bgId)
            else
                bg.state = newState
                TriggerServerEvent('rde_bg:syncState', bgId, { state = newState })
            end
        end
    end
end

RegisterCommand('bg_follow',  function() setAllOrders('follow')  end, false)
RegisterCommand('bg_guard',   function() setAllOrders('guard')   end, false)
RegisterCommand('bg_patrol',  function() setAllOrders('patrol')  end, false)
RegisterCommand('bg_dismiss', function()
    TriggerServerEvent('rde_bg:dismissAll')
    for bgId, bg in pairs(activeBodyguards) do
        if DoesEntityExist(bg.ped)             then DeletePed(bg.ped)    end
        if bg.blip and DoesBlipExist(bg.blip)  then RemoveBlip(bg.blip) end
        if bg.ped then pcall(function() exports.ox_target:removeLocalEntity(bg.ped) end) end
        if markBGRested    then markBGRested(bgId)    end
        if cleanupLODCache then cleanupLODCache(bgId) end
        if cleanupSyncData then cleanupSyncData(bgId) end
    end
    activeBodyguards = {}
    formationSlotMap = {}
    buildRadialMenu()
    lib.notify({ title = '👋 All Dismissed', description = '', type = 'inform', duration = 3000 })
end, false)

-- ────────────────────────────────────────────────────────────
-- activateBodyguard — spawn ped + FULL ox_target command system
-- ────────────────────────────────────────────────────────────
function activateBodyguard(bgData)
    if not bgData then return end

    if activeBodyguards[bgData.id] then
        lib.notify({ title = '⚠️ Already Active', description = bgData.name, type = 'warning' })
        return
    end

    local active = 0
    for _ in pairs(activeBodyguards) do active = active + 1 end
    if active >= Config.MaxActive then
        lib.notify({ title = '❌ Max Active', description = L('deploy_fail_max', Config.MaxActive), type = 'error' })
        return
    end

    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local tempSpawnCoords = vector3(
        playerCoords.x + 500.0,
        playerCoords.y + 500.0,
        playerCoords.z - 100.0
    )

    lib.requestModel(bgData.model, 8000)
    local ped = CreatePed(
        4, GetHashKey(bgData.model),
        tempSpawnCoords.x, tempSpawnCoords.y, tempSpawnCoords.z,
        0.0, true, false
    )
    SetModelAsNoLongerNeeded(bgData.model)

    if NetworkGetEntityIsNetworked(ped) then
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(ped), true)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(ped), false)
    end

    if not DoesEntityExist(ped) then
        lib.notify({ title = '❌ Spawn failed', description = 'Could not create ped', type = 'error' })
        return
    end

    SetEntityAlpha(ped, 0, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)

    SetEntityAsMissionEntity(ped, true, true)
    SetPedCanRagdoll(ped, true)
    SetPedCombatAttributes(ped, 5,   true)
    SetPedCombatAttributes(ped, 46,  true)
    SetPedCombatAttributes(ped, 1,   false)
    SetPedCombatAttributes(ped, 52,  true)
    SetPedCombatRange(ped, 2)
    SetPedHearingRange(ped, 40.0)
    SetPedAlertness(ped, 3)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedRelationshipGroupHash(ped, GetHashKey('BODYGUARD'))
    SetRelationshipBetweenGroups(3, GetHashKey('BODYGUARD'), GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(3, GetHashKey('PLAYER'), GetHashKey('BODYGUARD'))

    local maxHp = bgData.health or 200
    SetEntityMaxHealth(ped, maxHp)
    SetEntityHealth(ped, maxHp)

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(bgData.name)
    EndTextCommandSetBlipName(blip)

    local slot = 1
    for k in pairs(activeBodyguards) do slot = slot + 1 end
    formationSlotMap[bgData.id] = slot

    activeBodyguards[bgData.id] = {
        id             = bgData.id,
        ped            = ped,
        blip           = blip,
        name           = bgData.name,
        model          = bgData.model,
        gender         = bgData.gender or 'male',
        rarity         = bgData.rarity or 'common',
        level          = bgData.level  or 1,
        prestige       = bgData.prestige or 0,
        health         = maxHp,
        maxHealth      = maxHp,
        skills         = bgData.skills or {},
        morale         = bgData.morale or Config.Morale.startValue,
        wound          = bgData.wound  or 'none',
        affection      = bgData.affection or 0,
        relation_level = bgData.relation_level or 1,
        state          = 'arriving',
        avenge         = false,
        slot           = slot,
        _holstered     = false,
    }

    -- ════════════════════════════════════════════════════════
    -- v5.1: FULL ox_target COMMAND SYSTEM on bodyguard ped
    -- ════════════════════════════════════════════════════════
    local bgId = bgData.id
    local rarityCol = Config.GetRarity(bgData.rarity).color

    exports.ox_target:addLocalEntity(ped, {
        -- ── Interact / Bond ──
        {
            name      = 'bg_interact_' .. bgId,
            label     = '💬 Interact',
            icon      = 'fa-solid fa-comments',
            iconColor = rarityCol,
            distance  = 2.5,
            onSelect  = function()
                local now = GetGameTimer()
                if (interactCooldowns[bgId] or 0) > now then
                    local rem = math.ceil(((interactCooldowns[bgId] or now) - now) / 1000)
                    lib.notify({ title = '⏳ Cooldown', description = rem .. 's', type = 'warning', duration = 2000 })
                    return
                end
                doInteraction(bgId)
            end,
        },
        -- ── Follow ──
        {
            name      = 'bg_cmd_follow_' .. bgId,
            label     = '🚶 Follow Me',
            icon      = 'fa-solid fa-person-walking',
            iconColor = '#60a5fa',
            distance  = 8.0,
            onSelect  = function() orderFollow(bgId) end,
        },
        -- ── Stay / Guard ──
        {
            name      = 'bg_cmd_guard_' .. bgId,
            label     = '🛑 Stay Here',
            icon      = 'fa-solid fa-location-dot',
            iconColor = '#f59e0b',
            distance  = 8.0,
            onSelect  = function() orderGuard(bgId) end,
        },
        -- ── Patrol ──
        {
            name      = 'bg_cmd_patrol_' .. bgId,
            label     = '🔄 Patrol Area',
            icon      = 'fa-solid fa-route',
            iconColor = '#22d3ee',
            distance  = 8.0,
            onSelect  = function() orderPatrol(bgId) end,
        },
        -- ── Attack Target (what you aim at) ──
        {
            name      = 'bg_cmd_killtarget_' .. bgId,
            label     = '🎯 Kill Target (Aim First)',
            icon      = 'fa-solid fa-crosshairs',
            iconColor = '#ef4444',
            distance  = 12.0,
            onSelect  = function() orderAttackTarget(bgId) end,
        },
        -- ── Attack All Hostiles ──
        {
            name      = 'bg_cmd_attackall_' .. bgId,
            label     = '🔥 Attack All Hostiles',
            icon      = 'fa-solid fa-skull-crossbones',
            iconColor = '#dc2626',
            distance  = 12.0,
            onSelect  = function() orderAttackAll(bgId) end,
        },
        -- ── Peaceful Mode ──
        {
            name      = 'bg_cmd_peaceful_' .. bgId,
            label     = '☮️ Peaceful (No Combat)',
            icon      = 'fa-solid fa-dove',
            iconColor = '#34d399',
            distance  = 8.0,
            onSelect  = function() orderPeaceful(bgId) end,
        },
        -- ── Aggressive Mode ──
        {
            name      = 'bg_cmd_aggressive_' .. bgId,
            label     = '😤 Aggressive (Combat)',
            icon      = 'fa-solid fa-shield-halved',
            iconColor = '#f97316',
            distance  = 8.0,
            onSelect  = function() orderAggressive(bgId) end,
        },
        -- ── Heal (use bandage/medkit) ──
        {
            name      = 'bg_cmd_heal_' .. bgId,
            label     = '🩹 Heal (Use Item)',
            icon      = 'fa-solid fa-kit-medical',
            iconColor = '#22c55e',
            distance  = 3.0,
            onSelect  = function() orderHeal(bgId) end,
        },
        -- ── Holster Weapon ──
        {
            name      = 'bg_cmd_holster_' .. bgId,
            label     = '🔒 Holster Weapon',
            icon      = 'fa-solid fa-hand',
            iconColor = '#94a3b8',
            distance  = 4.0,
            onSelect  = function() orderHolster(bgId) end,
        },
        -- ── Draw Weapon ──
        {
            name      = 'bg_cmd_unholster_' .. bgId,
            label     = '🔓 Draw Weapon',
            icon      = 'fa-solid fa-gun',
            iconColor = '#818cf8',
            distance  = 4.0,
            onSelect  = function() orderUnholster(bgId) end,
        },
        -- ── Choose Weapon ──
        {
            name      = 'bg_cmd_weapsel_' .. bgId,
            label     = '🔫 Choose Weapon',
            icon      = 'fa-solid fa-wand-magic-sparkles',
            iconColor = '#a78bfa',
            distance  = 3.0,
            onSelect  = function() orderWeaponSelect(bgId) end,
        },
        -- ── Manage Gear (Inventory) ──
        {
            name      = 'bg_cmd_gear_' .. bgId,
            label     = '💼 Manage Gear',
            icon      = 'fa-solid fa-box-open',
            iconColor = '#6366f1',
            distance  = 2.5,
            onSelect  = function()
                lib.callback('rde_bg:openInventory', false, function(res)
                    if not res or not res.ok then
                        lib.notify({ title = '❌', description = 'Failed to open inventory.', type = 'error' })
                    end
                end, bgId)
            end,
        },
        -- ── Dismiss ──
        {
            name      = 'bg_cmd_dismiss_' .. bgId,
            label     = '👋 Dismiss',
            icon      = 'fa-solid fa-person-walking-arrow-right',
            iconColor = '#f43f5e',
            distance  = 3.0,
            onSelect  = function() despawnBodyguard(bgId) end,
        },
        -- ── Full Menu ──
        {
            name      = 'bg_cmd_menu_' .. bgId,
            label     = '📋 Full Menu',
            icon      = 'fa-solid fa-bars',
            iconColor = '#e2e8f0',
            distance  = 3.0,
            onSelect  = function()
                lib.callback('rde_bg:getAll', false, function(bgs)
                    for _, b in ipairs(bgs or {}) do
                        if b.id == bgId then openBGMenu(b); break end
                    end
                end)
            end,
        },
    })

    -- Fatigue init (bond.lua)
    if initFatigue then initFatigue(bgData.id) end

    -- Idle behavior (bond.lua)
    if startIdleBehavior then startIdleBehavior(bgData.id) end

    buildRadialMenu()

    local netId = NetworkGetNetworkIdFromEntity(ped)
    TriggerServerEvent('rde_bg:syncNetworkId', bgData.id, netId)
    TriggerServerEvent('rde_bg:addXP', bgData.id, 'deploy')

    realisticArrival(bgData, ped, function(arrivedPed, arrivalVeh)
        if not activeBodyguards[bgData.id] then return end
        activeBodyguards[bgData.id].state = 'follow'
        lib.notify({
            title       = '✅ ' .. bgData.name,
            description = L('deployed', bgData.name),
            type        = 'success', duration = 3500, icon = 'shield',
        })
    end)
end

-- ────────────────────────────────────────────────────────────
-- despawnBodyguard
-- ────────────────────────────────────────────────────────────
function despawnBodyguard(bgId)
    local bg = activeBodyguards[bgId]
    if not bg then return end

    TriggerServerEvent('rde_bg:despawn', bgId)

    activeBodyguards[bgId] = nil
    formationSlotMap[bgId] = nil

    if markBGRested    then markBGRested(bgId)    end
    if cleanupLODCache then cleanupLODCache(bgId) end
    if cleanupSyncData then cleanupSyncData(bgId) end

    buildRadialMenu()

    realisticDeparture(bg, function() end)
end

-- ────────────────────────────────────────────────────────────
-- SERVER-READY SYNC
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:serverReady', function()
    Wait(1500)
    for bgId, bg in pairs(activeBodyguards) do
        if DoesEntityExist(bg.ped)           then DeletePed(bg.ped)    end
        if bg.blip and DoesBlipExist(bg.blip) then RemoveBlip(bg.blip) end
    end
    activeBodyguards = {}
    formationSlotMap = {}
    buildRadialMenu()
end)

-- ────────────────────────────────────────────────────────────
-- LEVEL-UP CLIENT EVENT
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:levelUp', function(bgId, newLevel)
    local bg = activeBodyguards[bgId]
    if not bg then return end
    bg.level = newLevel
    if playLevelUpEffect then playLevelUpEffect(bg.ped) end
    if addMemory then addMemory(bgId, 'Reached Level ' .. newLevel .. '!') end
end)

-- ────────────────────────────────────────────────────────────
-- BOND DEEPENED CLIENT EVENT
-- ────────────────────────────────────────────────────────────
RegisterNetEvent('rde_bg:bondDeepened', function(bgId, tierName)
    if celebrateMilestone then celebrateMilestone(bgId, tierName) end
end)

-- ────────────────────────────────────────────────────────────
-- CLEANUP ON RESOURCE STOP
-- ────────────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for bgId, bg in pairs(activeBodyguards) do
        if DoesEntityExist(bg.ped)           then DeletePed(bg.ped)    end
        if bg.blip and DoesBlipExist(bg.blip) then RemoveBlip(bg.blip) end
        if bg.ped then
            pcall(function() exports.ox_target:removeLocalEntity(bg.ped) end)
        end
    end
    activeBodyguards = {}
    formationSlotMap = {}
end)

print('^2[RDE-BG]^7 Client main v5.1 loaded ✓ (Full ox_target commands)')
