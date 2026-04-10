-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.0  —  client/menu.lua
-- Menus + NPC-based recruitment zone with ox_target & ox_lib input
-- ============================================================

local function rarityColor(key) return Config.GetRarity(key).color end
local function rarityLabel(key) return Config.GetRarity(key).label end

local function skillBar(val, max)
    max = max or 100
    local f = math.floor((val / max) * 10)
    return string.rep('█', f) .. string.rep('░', 10-f) .. '  ' .. val .. '/' .. max
end

-- ────────────────────────────────────────────────────────────
-- MAIN COMMAND + KEYBIND
-- ────────────────────────────────────────────────────────────
-- Client-side command registration (NOT lib.addCommand which is server-only)
RegisterCommand('bg', function() openMainMenu() end, false)
RegisterKeyMapping('bg', 'Open Bodyguard Menu', 'keyboard', 'F6')

function openMainMenu()
    local activeCount = 0
    local activeBGList = {}
    for bgId, bg in pairs(activeBodyguards) do
        if not bg.networked then
            activeCount = activeCount + 1
            table.insert(activeBGList, { id = bgId, name = bg.name })
        end
    end

    local options = {
        {title='🎯 Recruit Operative', description='Visit the broker — see /bgrecruit', icon='user-plus', iconColor='#10b981', onSelect=function()
            lib.notify({title='📍 Recruitment Broker', description='Head to the blue marker on your map.', type='inform', duration=5000, icon='map-pin'})
            openRecruitBrokerBlip()
        end},
        {title='👥 Roster  ['..activeCount..' Active]', icon='users', iconColor='#3b82f6', onSelect=openRosterMenu},
    }

    -- v5.1: Quick Orders for ALL active BGs (remote control!)
    if activeCount > 0 then
        table.insert(options, {title='── Quick Orders (All BGs) ──', icon='terminal', iconColor='#475569', disabled=true})
        table.insert(options, {title='🚶 All: Follow Me', icon='person-walking', iconColor='#60a5fa', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderFollow(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🛑 All: Stay Here', icon='location-dot', iconColor='#f59e0b', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderGuard(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🔄 All: Patrol', icon='route', iconColor='#22d3ee', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderPatrol(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🔥 All: Attack Hostiles', icon='skull-crossbones', iconColor='#ef4444', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderAttackAll(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='☮️ All: Peaceful', icon='dove', iconColor='#34d399', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderPeaceful(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🩹 All: Heal', icon='kit-medical', iconColor='#22c55e', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderHeal(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🔒 All: Holster', icon='hand', iconColor='#94a3b8', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderHolster(bgId) end end
            lib.hideContext()
        end})
        table.insert(options, {title='🔓 All: Draw Weapon', icon='gun', iconColor='#818cf8', onSelect=function()
            for bgId, bg in pairs(activeBodyguards) do if not bg.networked then orderUnholster(bgId) end end
            lib.hideContext()
        end})

        -- Per-BG quick orders
        if activeCount > 0 then
            table.insert(options, {title='── Individual Orders ──', icon='user', iconColor='#475569', disabled=true})
            for _, bgInfo in ipairs(activeBGList) do
                table.insert(options, {
                    title = '📋 ' .. bgInfo.name .. ' — Orders',
                    icon = 'shield', iconColor = '#3b82f6',
                    onSelect = function() openQuickOrderMenu(bgInfo.id) end,
                })
            end
        end
    end

    table.insert(options, {title='🏆 Leaderboard', icon='trophy', iconColor='#fbbf24', onSelect=function() openLeaderboard('level') end})
    table.insert(options, {title='🎁 Daily Reward', description='Claim XP for active BGs', icon='gift', iconColor='#ec4899', onSelect=function() TriggerServerEvent('rde_bg:claimDaily') end})
    table.insert(options, {title='📐 Formation: '..playerFormation:upper(), icon='layer-group', iconColor='#8b5cf6', onSelect=openFormationMenu})

    lib.registerContext({
        id='rde_bg_main',
        title='🛡️ Bodyguard Command Center',
        options=options,
    })
    lib.showContext('rde_bg_main')
end

-- ────────────────────────────────────────────────────────────
-- v5.1: QUICK ORDER MENU (per BG — accessible from main menu)
-- Full remote control: no need to walk to the BG!
-- ────────────────────────────────────────────────────────────
function openQuickOrderMenu(bgId)
    local bg = activeBodyguards[bgId]
    if not bg then lib.notify({title='❌', description='BG not active', type='error'}); return end

    local wInfo = Config.Wounds.types[bg.wound or 'none'] or Config.Wounds.types.none
    local mTier = Config.GetMoraleTier(bg.morale or 75)
    local hp    = DoesEntityExist(bg.ped) and GetEntityHealth(bg.ped) or 0
    local hpPct = math.floor(hp / math.max(bg.maxHealth or 200, 1) * 100)

    lib.registerContext({
        id = 'rde_bg_quickorder_' .. bgId,
        title = '📋 ' .. bg.name .. ' — Lv.' .. bg.level .. ' · HP:' .. hpPct .. '% · ' .. wInfo.label,
        menu = 'rde_bg_main',
        options = {
            {title='🚶 Follow Me',        icon='person-walking',             iconColor='#60a5fa', onSelect=function() orderFollow(bgId); lib.hideContext() end},
            {title='🛑 Stay / Guard',      icon='location-dot',              iconColor='#f59e0b', onSelect=function() orderGuard(bgId); lib.hideContext() end},
            {title='🔄 Patrol Area',       icon='route',                     iconColor='#22d3ee', onSelect=function() orderPatrol(bgId); lib.hideContext() end},
            {title='🎯 Kill My Target',    description='Aim at a ped first', icon='crosshairs',   iconColor='#ef4444', onSelect=function() orderAttackTarget(bgId); lib.hideContext() end},
            {title='🔥 Attack All',        icon='skull-crossbones',          iconColor='#dc2626', onSelect=function() orderAttackAll(bgId); lib.hideContext() end},
            {title='☮️ Peaceful Mode',     icon='dove',                      iconColor='#34d399', onSelect=function() orderPeaceful(bgId); lib.hideContext() end},
            {title='😤 Aggressive Mode',   icon='shield-halved',             iconColor='#f97316', onSelect=function() orderAggressive(bgId); lib.hideContext() end},
            {title='🩹 Heal (Use Item)',   description=wInfo.label .. ' · ' .. mTier.label, icon='kit-medical', iconColor='#22c55e', onSelect=function() orderHeal(bgId); lib.hideContext() end},
            {title='🔒 Holster Weapon',    icon='hand',                      iconColor='#94a3b8', onSelect=function() orderHolster(bgId); lib.hideContext() end},
            {title='🔓 Draw Weapon',       icon='gun',                       iconColor='#818cf8', onSelect=function() orderUnholster(bgId); lib.hideContext() end},
            {title='🔫 Choose Weapon',     icon='wand-magic-sparkles',       iconColor='#a78bfa', onSelect=function() orderWeaponSelect(bgId) end},
            {title='💼 Manage Gear',       icon='box-open',                  iconColor='#6366f1', onSelect=function()
                lib.callback('rde_bg:openInventory', false, function(res)
                    if not res or not res.ok then lib.notify({title='❌', description='Failed.', type='error'}) end
                end, bgId)
            end},
            {title='👋 Dismiss',           icon='person-walking-arrow-right', iconColor='#f43f5e', onSelect=function() despawnBodyguard(bgId); lib.hideContext() end},
            {title='← Back', icon='arrow-left', onSelect=openMainMenu},
        },
    })
    lib.showContext('rde_bg_quickorder_' .. bgId)
end

-- ────────────────────────────────────────────────────────────
-- RECRUITMENT BROKER NPC
-- Spawns a fixer NPC at a fixed location in the world.
-- Player walks up, ox_target triggers the hiring flow.
-- Much more immersive than a phone menu.
-- ────────────────────────────────────────────────────────────
local brokerLocations = {
    { coords=vector4(-576.51, 292.14, 79.17, 235.27),  label='Eclipse Blvd. Broker', model='a_m_m_mlcrisis_01' },
    { coords=vector4(-808.44, 179.57, 72.0, 303.5),   label='Vinewood Broker',  model='s_m_m_fibsec_01'  },
    { coords=vector4(1155.68, -321.36, 69.21, 251.4), label='East LS Broker',  model='mp_m_exarmy_01'   },
}

local brokerPeds  = {}
local brokerBlips = {}
local recruitCooldowns = {}  -- prevent spam

local function spawnBrokerNPCs()
    for i, loc in ipairs(brokerLocations) do
        CreateThread(function()
            local model = GetHashKey(loc.model)
            lib.requestModel(model, 5000)

            local ped = CreatePed(26, model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.coords.w, false, false)
            SetModelAsNoLongerNeeded(model)

            if not DoesEntityExist(ped) then return end

            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            SetPedCanRagdoll(ped, false)
            SetPedFleeAttributes(ped, 0, false)

            -- Use TaskStartScenarioInPlace which doesn't need requestAnimDict
            -- 'WORLD_HUMAN_STAND_MOBILE' is a valid GTA scenario name
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

            brokerPeds[i] = ped

            -- ox_target on broker
            exports.ox_target:addLocalEntity(ped, {
                {
                    name     = 'rde_broker_recruit_' .. i,
                    label    = '💼 ' .. loc.label,
                    icon     = 'fa-solid fa-briefcase',
                    iconColor= '#fbbf24',
                    distance = 3.0,
                    onSelect = function() openBrokerMenu(i) end,
                },
            })

            -- Blip
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, 280)
            SetBlipColour(blip, 5)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('🎯 ' .. loc.label)
            EndTextCommandSetBlipName(blip)
            brokerBlips[i] = blip
        end)
    end
end

function openRecruitBrokerBlip()
    -- Point player to nearest broker
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDist = brokerLocations[1], 999999
    for _, loc in ipairs(brokerLocations) do
        local d = #(vector3(loc.coords.x, loc.coords.y, loc.coords.z) - playerCoords)
        if d < nearestDist then nearest, nearestDist = loc, d end
    end
    SetNewWaypoint(nearest.coords.x, nearest.coords.y)
    lib.notify({title='📍 '..nearest.label, description='Waypoint set.', type='inform', duration=3000})
end

-- ────────────────────────────────────────────────────────────
-- BROKER MENU  (the immersive hiring flow)
-- Shows 3 candidates with personality + rarity preview
-- Uses lib.inputDialog for negotiation feel
-- ────────────────────────────────────────────────────────────
function openBrokerMenu(brokerIdx)
    -- Cooldown per player
    if recruitCooldowns[brokerIdx] and GetGameTimer() < recruitCooldowns[brokerIdx] then
        lib.notify({title='⏳ Busy', description='The broker is currently occupied.', type='warning'})
        return
    end

    -- Face the broker NPC — use a fixed duration, NEVER -1 (infinite)
    -- -1 leaves an uncleared task on the player ped that blocks movement permanently
    local broker = brokerPeds[brokerIdx]
    if broker and DoesEntityExist(broker) then
        local playerPed = PlayerPedId()
        TaskTurnPedToFaceEntity(playerPed, broker, 800)
        Wait(850)
        -- Explicit clear so no task residue remains regardless of timing
        ClearPedTasksImmediately(playerPed)
    end

    -- Generate 3 unique candidates
    local candidates = {}
    local usedNames  = {}
    for _ = 1, 3 do
        local rarityKey = Config.RollRarity()
        local gender    = math.random(2) == 1 and 'male' or 'female'
        local rData     = Config.GetRarity(rarityKey)
        local pKey, pData = getBGPersonality(math.random(9999))  -- preview personality

        local pedPool = Config.Peds[gender] or Config.Peds.male
        local model   = pedPool[math.random(#pedPool)]

        -- Generate preview skills
        local previewSkills = {}
        local topSkill, topVal = '', 0
        for k, _ in pairs(Config.Skills) do
            local v = math.random(10, 45) + (rData.skillBonus or 0)
            previewSkills[k] = v
            if v > topVal then topVal = v; topSkill = k end
        end

        -- Estimated price
        local total = 0
        for _, v in pairs(previewSkills) do total = total + v end
        local estPrice = math.floor(
            math.random(Config.Pricing.base.min, Config.Pricing.base.max)
            + total * Config.Pricing.perSkillPt
            + (Config.Pricing.rarityBonus[rarityKey] or 0)
        )

        table.insert(candidates, {
            rarity      = rarityKey,
            rData       = rData,
            gender      = gender,
            model       = model,
            personality = pKey,
            pLabel      = pData and pData.label or 'Unknown',
            topSkill    = Config.Skills[topSkill] and Config.Skills[topSkill].label or topSkill,
            topVal      = topVal,
            estPrice    = estPrice,
        })
    end

    -- Build context menu options
    local options = {}

    for i, c in ipairs(candidates) do
        local stars = string.rep('★', math.floor((c.rData.skillBonus or 0) / 25) + 1)
        table.insert(options, {
            title       = stars .. ' ' .. c.rData.label .. ' · ' .. c.gender:upper() .. ' · ' .. c.pLabel,
            description = 'Top skill: ' .. c.topSkill .. ' (' .. c.topVal .. ')  ·  ~$' .. c.estPrice,
            icon        = c.gender == 'female' and 'user' or 'user-tie',
            iconColor   = c.rData.color,
            metadata    = {
                {label='Rarity',      value=c.rData.label},
                {label='Personality', value=c.pLabel},
                {label='Top Skill',   value=c.topSkill .. ' — ' .. c.topVal .. '/100'},
                {label='Est. Price',  value='~$' .. c.estPrice},
                {label='Gender',      value=c.gender:upper()},
            },
            onSelect = function()
                -- IMPORTANT: close the context menu FIRST before opening alertDialog
                -- otherwise ox_lib's NUI focus management gets confused and blocks movement
                lib.hideContext()
                Wait(50)

                local alert = lib.alertDialog({
                    header  = '💼 Hire ' .. c.rData.label .. ' Operative?',
                    content = 'Est. cost: ~$' .. c.estPrice ..
                              '\nPersonality: ' .. c.pLabel ..
                              '\nTop skill: ' .. c.topSkill ..
                              '\n\nArrives by: ' ..
                              (math.random(100) <= 70 and 'vehicle' or 'foot') .. '.',
                    centered= true,
                    cancel  = true,
                    labels  = {cancel='Walk Away', confirm='Hire — $'..c.estPrice},
                })

                -- Always release NUI focus explicitly after any dialog
                SetNuiFocus(false, false)

                if alert == 'confirm' then
                    recruitCooldowns[brokerIdx] = GetGameTimer() + 8000

                    -- Use await (synchronous) so we stay in the thread — no dangling coroutine
                    local res = lib.callback.await('rde_bg:recruit', false, c.gender, c.rarity)

                    -- Always release NUI focus AFTER the server callback too,
                    -- in case the await re-enters a context that re-grabbed focus
                    SetNuiFocus(false, false)

                    if res and res.ok then
                        lib.notify({
                            title       = '✅ Hired: ' .. res.name,
                            description = res.rarity:upper() .. ' · ' .. c.pLabel .. ' — On their way.',
                            type        = 'success', duration=6000,
                            icon        = 'user-shield',
                            iconColor   = rarityColor(res.rarity),
                        })
                    else
                        lib.notify({title='❌ Hire Failed', description=res and res.msg or 'Error', type='error'})
                    end
                else
                    -- User cancelled — make absolutely sure focus is released
                    SetNuiFocus(false, false)
                end
            end,
        })
    end

    table.insert(options, {title='← Leave', icon='arrow-left', onSelect=function() lib.hideContext() end})

    lib.registerContext({
        id      = 'rde_broker_'..brokerIdx,
        title   = '💼 ' .. brokerLocations[brokerIdx].label,
        options = options,
    })
    lib.showContext('rde_broker_'..brokerIdx)
end

-- ────────────────────────────────────────────────────────────
-- ROSTER MENU
-- ────────────────────────────────────────────────────────────
function openRosterMenu()
    lib.callback('rde_bg:getAll', false, function(bodyguards)
        if not bodyguards or #bodyguards == 0 then
            lib.notify({title='📭 No Operatives', description='Visit a broker to hire.', type='inform'})
            return
        end

        local options = {}
        for _, bg in ipairs(bodyguards) do
            local stIcon, stColor
            if     bg.is_dead   == 1 then stIcon, stColor = 'skull',      '#ef4444'
            elseif bg.is_active == 1 then stIcon, stColor = 'circle-dot', '#10b981'
            else                          stIcon, stColor = 'circle',      '#6b7280' end

            local rel = Config.GetRelTier(bg.relation_level or 1)
            local mor = Config.GetMoraleTier(bg.morale or 75)
            local _, pData = getBGPersonality(bg.id)
            local pLabel = pData and pData.label or '?'

            table.insert(options, {
                title       = bg.name .. '   Lv.' .. bg.level .. (bg.prestige>0 and '  ✦P'..bg.prestige or ''),
                description = rarityLabel(bg.rarity) .. ' · ' .. pLabel .. ' · ' .. rel.name,
                icon        = stIcon, iconColor=stColor,
                metadata    = {
                    {label='Rarity',      value=rarityLabel(bg.rarity)},
                    {label='Personality', value=pLabel},
                    {label='Wound',       value=(Config.Wounds.types[bg.wound or 'none'] or Config.Wounds.types.none).label},
                    {label='Morale',      value=mor.label..' ('..bg.morale..')'},
                    {label='Bond',        value=rel.name..' ('..bg.affection..')'},
                    {label='Kills',       value=bg.total_kills or 0},
                    {label='Prestige',    value=bg.prestige or 0},
                },
                onSelect=function() openBGMenu(bg) end,
            })
        end
        table.insert(options, {title='← Back', icon='arrow-left', onSelect=openMainMenu})

        lib.registerContext({id='rde_bg_roster', title='👥 Operative Roster', options=options})
        lib.showContext('rde_bg_roster')
    end)
end

-- ────────────────────────────────────────────────────────────
-- INDIVIDUAL BG MENU
-- ────────────────────────────────────────────────────────────
function openBGMenu(bg)
    local isActive    = activeBodyguards[bg.id] ~= nil
    local isDead      = bg.is_dead == 1
    local canPrestige = bg.level >= Config.MaxLevel and (bg.prestige or 0) < Config.MaxPrestige
    local options     = {}

    -- Deploy / Despawn / Revive
    if isDead then
        local cost = Config.Death.reviveBaseCost + (bg.level or 1) * Config.Death.reviveCostPerLvl
        table.insert(options, {title='💊 Revive ($'..cost..')', icon='heart-pulse', iconColor='#22c55e', onSelect=function()
            lib.callback('rde_bg:revive', false, function(res)
                if res and res.ok then lib.notify({title='💊 Revived', description=bg.name, type='success'}); openRosterMenu()
                else lib.notify({title='❌', description=res and res.msg or '', type='error'}) end
            end, bg.id)
        end})
    elseif isActive then
        table.insert(options, {title='🔴 Dismiss', icon='person-walking-arrow-right', iconColor='#f59e0b',
            onSelect=function() despawnBodyguard(bg.id); openRosterMenu() end})
    else
        table.insert(options, {title='🟢 Deploy', icon='person-walking-arrow-loop-left', iconColor='#10b981',
            onSelect=function()
                lib.callback('rde_bg:spawn', false, function(res)
                    if res and res.ok then
                        -- pcall so a crash inside activateBodyguard is caught,
                        -- reported, and does NOT leave the player NUI-frozen
                        local ok, err = pcall(activateBodyguard, res.bodyguard)
                        if not ok then
                            lib.notify({title='❌ Spawn Error', description=tostring(err), type='error'})
                        end
                        SetNuiFocus(false, false)
                        openRosterMenu()
                    else
                        SetNuiFocus(false, false)
                        lib.notify({title='❌ Deploy Failed', description=res and res.msg or '', type='error'})
                    end
                end, bg.id)
            end})
    end

    table.insert(options, {title='📊 Stats & Memories', icon='chart-bar', iconColor='#3b82f6', onSelect=function() openStatsMenu(bg.id) end})

    if not isDead then
        table.insert(options, {title='🎓 Train Skills', icon='graduation-cap', iconColor='#8b5cf6', onSelect=function() openTrainMenu(bg) end})
    end

    if canPrestige then
        table.insert(options, {title='🌟 PRESTIGE', description='Lv1 reset — skills +10', icon='crown', iconColor='#fbbf24',
            onSelect=function()
                lib.hideContext()
                Wait(50)
                local btn = lib.alertDialog({
                    header='🌟 Prestige '..bg.name..'?',
                    content='Reset to Level 1. All skills +10.',
                    centered=true, cancel=true,
                    labels={cancel='Cancel', confirm='Prestige!'},
                })
                SetNuiFocus(false, false)
                if btn == 'confirm' then
                    local res = lib.callback.await('rde_bg:prestige', false, bg.id)
                    if res and res.ok then lib.notify({title='🌟 Prestige '..res.prestige, type='success'})
                    else lib.notify({title='❌', description=res and res.msg or '', type='error'}) end
                end
            end})
    end

    if isActive and not isDead then
        table.insert(options, {title='💼 Manage Gear', icon='box-open', iconColor='#6366f1',
            onSelect=function()
                lib.callback('rde_bg:openInventory', false, function(res)
                    if not res or not res.ok then lib.notify({title='❌', description='Failed.', type='error'}) end
                end, bg.id)
            end})
    end

    table.insert(options, {title='← Back', icon='arrow-left', onSelect=openRosterMenu})

    lib.registerContext({id='rde_bg_individual', title=bg.name..'  ·  Lv.'..bg.level, options=options})
    lib.showContext('rde_bg_individual')
end

-- ────────────────────────────────────────────────────────────
-- STATS MENU  (includes session memories — unique feature)
-- ────────────────────────────────────────────────────────────
function openStatsMenu(bgId)
    lib.callback('rde_bg:getAll', false, function(bodyguards)
        local bg
        for _, b in ipairs(bodyguards) do if b.id == bgId then bg = b; break end end
        if not bg then lib.notify({title='❌', description='Not found', type='error'}); return end

        local _, pData   = getBGPersonality(bg.id)
        local relTier    = Config.GetRelTier(bg.relation_level or 1)
        local morTier    = Config.GetMoraleTier(bg.morale or 75)
        local wInfo      = Config.Wounds.types[bg.wound or 'none'] or Config.Wounds.types.none
        local fatigue    = getFatiguePenalty and getFatiguePenalty(bgId) or 0
        local memories   = bgMemories and bgMemories[bgId] or {}

        local options = {
            -- Header card
            {title=bg.name, description=rarityLabel(bg.rarity)..' · '..(pData and pData.label or '?')..' · '..bg.gender:upper(),
             icon='user-shield', iconColor=rarityColor(bg.rarity), disabled=true,
             metadata={
                {label='Level',    value=bg.level..'/'..Config.MaxLevel},
                {label='Prestige', value=bg.prestige or 0},
                {label='XP',       value=(bg.xp or 0)..'/'..Config.XPForLevel(bg.level)},
                {label='Health',   value=bg.health},
                {label='Wound',    value=wInfo.label},
                {label='Morale',   value=morTier.label..' ('..bg.morale..')'},
                {label='Fatigue',  value=fatigue..'/40 pts'},
                {label='Bond',     value=relTier.name..' ('..bg.affection..' pts)'},
                {label='Kills',    value=bg.total_kills or 0},
                {label='Protects', value=bg.total_protects or 0},
             }},
        }

        -- Skills
        local skillList = {}
        for k, v in pairs(Config.Skills) do table.insert(skillList, {key=k, cfg=v, val=(bg.skills and bg.skills[k]) or 0}) end
        table.sort(skillList, function(a,b) return a.cfg.label < b.cfg.label end)
        for _, s in ipairs(skillList) do
            table.insert(options, {title=s.cfg.label, description=skillBar(s.val, s.cfg.max), icon=s.cfg.icon, iconColor=s.cfg.color, disabled=true})
        end

        -- Memories section (unique feature)
        if #memories > 0 then
            table.insert(options, {title='📖 Session Memories', icon='book', iconColor='#94a3b8', disabled=true})
            for _, mem in ipairs(memories) do
                table.insert(options, {
                    title       = '[' .. mem.time .. '] ' .. mem.text,
                    icon        = 'clock',
                    iconColor   = '#475569',
                    disabled    = true,
                })
            end
        else
            table.insert(options, {title='📖 No memories yet this session', icon='book', iconColor='#334155', disabled=true})
        end

        table.insert(options, {title='← Back', icon='arrow-left', onSelect=function() openBGMenu(bg) end})

        lib.registerContext({id='rde_bg_stats', title='📊 '..bg.name..' — Stats', options=options})
        lib.showContext('rde_bg_stats')
    end)
end

-- ────────────────────────────────────────────────────────────
-- TRAIN MENU
-- ────────────────────────────────────────────────────────────
function openTrainMenu(bg)
    local options = {}
    local skillList = {}
    for k, v in pairs(Config.Skills) do table.insert(skillList, {key=k, cfg=v, val=(bg.skills and bg.skills[k]) or 0}) end
    table.sort(skillList, function(a,b) return a.cfg.label < b.cfg.label end)

    for _, s in ipairs(skillList) do
        local maxed = s.val >= s.cfg.max
        table.insert(options, {
            title=s.cfg.label, description=maxed and '✅ MAXED' or ('$'..s.cfg.trainCost..'  ·  +1~3 pts'),
            icon=s.cfg.icon, iconColor=maxed and '#6b7280' or s.cfg.color, disabled=maxed,
            metadata={{label='Current', value=skillBar(s.val, s.cfg.max)}, {label='Cost', value='$'..s.cfg.trainCost}},
            onSelect=function()
                lib.callback('rde_bg:trainSkill', false, function(res)
                    if res and res.ok then
                        lib.notify({title='🎓 Trained!', description=s.cfg.label..' → '..res.newValue..' (+'..res.gain..')',
                            type='success', duration=4000, icon=s.cfg.icon, iconColor=s.cfg.color})
                        if bg.skills then bg.skills[s.key] = res.newValue end
                    else
                        lib.notify({title='❌', description=res and res.msg or 'Error', type='error'})
                    end
                end, bg.id, s.key)
            end,
        })
    end
    table.insert(options, {title='← Back', icon='arrow-left', onSelect=function() openBGMenu(bg) end})
    lib.registerContext({id='rde_bg_train', title='🎓 Train '..bg.name, options=options})
    lib.showContext('rde_bg_train')
end

-- ────────────────────────────────────────────────────────────
-- FORMATION MENU
-- ────────────────────────────────────────────────────────────
function openFormationMenu()
    local function set(name)
        playerFormation = name
        lib.notify({title='📐 Formation', description=name:upper(), type='inform', duration=2000})
        openMainMenu()
    end
    local function ac(name) return playerFormation==name and '#10b981' or '#6b7280' end

    lib.registerContext({id='rde_bg_formation', title='📐 Formation', options={
        {title='Follow',  description='Trail behind you',    icon='person-walking', iconColor=ac('follow'),  onSelect=function() set('follow')  end},
        {title='Diamond', description='360° coverage',       icon='gem',            iconColor=ac('diamond'), onSelect=function() set('diamond') end},
        {title='Wedge',   description='Forward assault',     icon='angles-up',      iconColor=ac('wedge'),   onSelect=function() set('wedge')   end},
        {title='Stack',   description='Single file column',  icon='layer-group',    iconColor=ac('stack'),   onSelect=function() set('stack')   end},
        {title='← Back', icon='arrow-left', onSelect=openMainMenu},
    }})
    lib.showContext('rde_bg_formation')
end

-- ────────────────────────────────────────────────────────────
-- LEADERBOARD
-- ────────────────────────────────────────────────────────────
function openLeaderboard(category)
    lib.callback('rde_bg:leaderboard', false, function(rows)
        local catTitle = {level='🏅 By Level', kills='💀 By Kills', bond='💖 By Bond'}
        local options  = {}
        for _, cat in ipairs({'level','kills','bond'}) do
            table.insert(options, {title=catTitle[cat], icon=cat=='level' and 'medal' or (cat=='kills' and 'skull' or 'heart'),
                iconColor=category==cat and '#10b981' or '#6b7280', onSelect=function() openLeaderboard(cat) end})
        end
        for i, row in ipairs(rows or {}) do
            local medal = i==1 and '🥇 ' or i==2 and '🥈 ' or i==3 and '🥉 ' or i..'.  '
            local desc
            if     category=='kills' then desc=(row.total_kills or 0)..' kills · Lv.'..(row.level or 1)
            elseif category=='bond'  then desc='Affection: '..(row.affection or 0)..' · Rel.'..(row.relation_level or 1)
            else                          desc='Lv.'..(row.level or 1)..((row.prestige or 0)>0 and ' ✦P'..row.prestige or '')..' · '..(row.total_kills or 0)..' kills' end
            table.insert(options, {title=medal..(row.name or '?'), description=desc,
                icon=i<=3 and 'medal' or 'user', iconColor=i==1 and '#fbbf24' or i==2 and '#9ca3af' or i==3 and '#b45309' or '#475569', disabled=true})
        end
        table.insert(options, {title='← Back', icon='arrow-left', onSelect=openMainMenu})
        lib.registerContext({id='rde_bg_lb', title=catTitle[category] or '🏅 Leaderboard', options=options})
        lib.showContext('rde_bg_lb')
    end, category)
end

-- ────────────────────────────────────────────────────────────
-- SPAWN BROKER NPCS ON RESOURCE START
-- ────────────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(3000)
    spawnBrokerNPCs()
end)

print('^2[RDE-BG]^7 Menu v4.0 loaded ✓')