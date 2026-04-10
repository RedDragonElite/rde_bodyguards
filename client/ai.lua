-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v5.0  —  client/ai.lua
-- AI: follow/guard/patrol/combat/avenge + SELF-HEAL + BUDDY HEAL
--     + ADRENALINE + TACTICAL COVER + LAST STAND + WEAPON EQUIP
--     + ENVIRONMENTAL AWARENESS
-- v5.0: Production-ready ultra-immersive AI
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- THREAT DETECTION  (multi-layer — verhindert Ghost-Enemies)
-- ────────────────────────────────────────────────────────────
local threatConfirm = {}

local function clearThreatConfirm(ped)
    threatConfirm[ped] = nil
end

local function isRealThreat(ped, playerPed)
    if not DoesEntityExist(ped)      then return false end
    if not DoesEntityExist(playerPed) then return false end
    if IsEntityDead(ped)             then return false end
    if IsEntityDead(playerPed)       then return false end
    if IsPedAPlayer(ped)             then return false end
    if IsPedInAnyVehicle(ped, true)  then return false end

    local attackingPlayer = IsPedInCombat(ped, playerPed)
    local relGroup   = GetRelationshipBetweenPeds(ped, playerPed)
    local isEnemy    = relGroup == 5
    local _, weapHash = GetCurrentPedWeapon(ped)
    local hasWeapon   = weapHash ~= GetHashKey('WEAPON_UNARMED')
    local aimsAtPlayer = IsPedArmed(ped, 1) and
                         #(GetEntityCoords(ped) - GetEntityCoords(playerPed)) < 4.0

    local shootingAtPlayer = false
    if hasWeapon and IsEntityInAir(ped) == false then
        local pedH     = GetEntityHeading(ped)
        local toPlayer = GetEntityCoords(playerPed) - GetEntityCoords(ped)
        local pedFwd   = vector3(math.cos(math.rad(-pedH + 90)), math.sin(math.rad(-pedH + 90)), 0)
        local dot      = pedFwd.x * toPlayer.x + pedFwd.y * toPlayer.y
        shootingAtPlayer = dot > 0 and IsPedShootingInArea(ped,
            GetEntityCoords(playerPed).x - 2.0, GetEntityCoords(playerPed).y - 2.0,
            GetEntityCoords(playerPed).z - 2.0,
            GetEntityCoords(playerPed).x + 2.0, GetEntityCoords(playerPed).y + 2.0,
            GetEntityCoords(playerPed).z + 2.0, false, false)
    end

    local score = (attackingPlayer  and 2 or 0)
                + (isEnemy          and 1 or 0)
                + (hasWeapon        and 1 or 0)
                + (shootingAtPlayer and 2 or 0)
                + (aimsAtPlayer     and 1 or 0)

    return score >= 3
end

local function isConfirmedThreat(ped, playerPed)
    if not isRealThreat(ped, playerPed) then
        threatConfirm[ped] = nil
        return false
    end
    threatConfirm[ped] = (threatConfirm[ped] or 0) + 1
    return threatConfirm[ped] >= 3
end

local function scanThreats(fromCoords, radius, playerPed)
    local threats  = {}
    local nearby   = lib.getNearbyPeds(fromCoords, radius) or {}

    for _, data in ipairs(nearby) do
        local p = data.ped
        if p and p ~= playerPed then
            if isConfirmedThreat(p, playerPed) then
                table.insert(threats, { ped = p, dist = data.distance or 0.0 })
            end
        end
    end

    table.sort(threats, function(a, b) return (a.dist or 0.0) < (b.dist or 0.0) end)
    return threats
end

-- ────────────────────────────────────────────────────────────
-- FORMATION POSITION
-- ────────────────────────────────────────────────────────────
local function getFormationPos(slot, playerCoords, playerHeading)
    local fData    = Config.Formations[playerFormation] or Config.Formations.follow
    local slotData = fData.slots[slot] or fData.slots[1]
    local rad      = math.rad(playerHeading + slotData.angle)
    local pos      = vector3(
        playerCoords.x + math.cos(rad) * slotData.dist,
        playerCoords.y + math.sin(rad) * slotData.dist,
        playerCoords.z
    )
    local ok, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
    if ok then pos = vector3(pos.x, pos.y, gz) end
    return pos
end

-- ────────────────────────────────────────────────────────────
-- v5.0: ENVIRONMENTAL MODIFIERS
-- Night/weather affects accuracy and alertness
-- ────────────────────────────────────────────────────────────
local function getEnvironmentMult(bg)
    if not Config.Environment or not Config.Environment.enabled then return 1.0 end

    local mult = 1.0
    local h = GetClockHours()
    local isNight = h >= 22 or h < 6

    if isNight then
        local nightPenalty = Config.Environment.nightAccuracyMult or 0.82
        local tacticsBonus = (bg.skills.tactics or 0) * (Config.Environment.nightTacticsBonus or 0.005)
        mult = mult * math.min(1.0, nightPenalty + tacticsBonus)
    end

    -- Rain check
    if GetRainLevel and GetRainLevel() > 0.3 then
        mult = mult * (Config.Environment.rainAccuracyMult or 0.90)
    end

    return mult
end

-- ────────────────────────────────────────────────────────────
-- v5.0: ADRENALINE STATE
-- Temporary combat buff system
-- ────────────────────────────────────────────────────────────
adrenalineState = {}   -- [bgId] = { active, startTime, cooldownEnd }

local function triggerAdrenaline(bgId)
    if not Config.Adrenaline or not Config.Adrenaline.enabled then return end
    local state = adrenalineState[bgId] or {}
    local now = GetGameTimer()

    if state.cooldownEnd and now < state.cooldownEnd then return end

    adrenalineState[bgId] = {
        active      = true,
        startTime   = now,
        cooldownEnd = now + Config.Adrenaline.durationMs + Config.Adrenaline.cooldownMs,
    }

    local bg = activeBodyguards[bgId]
    if bg and DoesEntityExist(bg.ped) then
        -- Visual feedback: brief red flash on ped
        SetPedMoveRateOverride(bg.ped, Config.Adrenaline.speedBoost or 1.15)

        if addMemory then addMemory(bgId, 'Adrenaline rush — fighting at peak performance!') end
        playVoiceLine(bg.ped, 'combat')
    end
end

local function getAdrenalineMult(bgId)
    if not Config.Adrenaline or not Config.Adrenaline.enabled then return 1.0 end
    local state = adrenalineState[bgId]
    if not state or not state.active then return 1.0 end

    local now = GetGameTimer()
    local elapsed = now - state.startTime
    if elapsed > Config.Adrenaline.durationMs then
        state.active = false
        return 1.0
    end

    return Config.Adrenaline.accuracyBoost or 1.25
end

-- ────────────────────────────────────────────────────────────
-- v5.0: LAST STAND STATE
-- Critically wounded BGs fight with desperate intensity
-- ────────────────────────────────────────────────────────────
lastStandState = {}   -- [bgId] = { active, startTime, ticksRemaining }

local function checkLastStand(bg)
    if not Config.LastStand or not Config.LastStand.enabled then return end
    if not DoesEntityExist(bg.ped) then return end

    local hp  = GetEntityHealth(bg.ped)
    local pct = hp / math.max(bg.maxHealth or 200, 1)
    local state = lastStandState[bg.id]

    if pct <= (Config.LastStand.triggerHealthPct or 0.15) and (not state or not state.active) then
        lastStandState[bg.id] = {
            active         = true,
            startTime      = GetGameTimer(),
            ticksRemaining = Config.LastStand.invulnerableTicks or 3,
        }

        lib.notify({
            title       = '🔥 ' .. bg.name .. ' — LAST STAND!',
            description = 'Fighting with everything they have!',
            type        = 'warning',
            duration    = 4000,
            icon        = 'fire',
            iconColor   = '#ef4444',
        })

        if addMemory then addMemory(bg.id, 'Entered Last Stand — fought with desperate fury.') end
        playVoiceLine(bg.ped, 'combat')
    end
end

local function getLastStandMult(bgId)
    local state = lastStandState[bgId]
    if not state or not state.active then return 1.0 end

    local now = GetGameTimer()
    if now - state.startTime > (Config.LastStand.durationMs or 10000) then
        state.active = false
        return 1.0
    end

    return Config.LastStand.accuracyBoost or 1.40
end

-- ────────────────────────────────────────────────────────────
-- MODIFIERS (wound + morale + fatigue + environment + adrenaline + bond)
-- ────────────────────────────────────────────────────────────
local function applyModifiers(bg)
    if not DoesEntityExist(bg.ped) then return end

    local wData    = Config.Wounds.types[bg.wound or 'none'] or Config.Wounds.types.none
    local mTier    = Config.GetMoraleTier(bg.morale or 75)
    local fatigue  = getFatiguePenalty and getFatiguePenalty(bg.id) or 0
    local envMult  = getEnvironmentMult(bg)
    local adrMult  = getAdrenalineMult(bg.id)
    local lsMult   = getLastStandMult(bg.id)

    -- v5.0: Bond tier combat bonus
    local bondBonus = 1.0
    if Config.Relationship.combatBonusPerTier then
        bondBonus = 1.0 + ((bg.relation_level or 1) - 1) * Config.Relationship.combatBonusPerTier
    end

    local combined = wData.speedMult * mTier.combatMult * (1.0 - fatigue * 0.01)
                     * envMult * adrMult * lsMult * bondBonus

    local baseAcc  = 0.30 + (bg.skills.shooting or 0) * 0.006
    local finalAcc = math.max(5, math.min(90, math.floor(baseAcc * combined * 100)))
    SetPedAccuracy(bg.ped, finalAcc)

    SetPedCombatAbility(bg.ped, math.floor(combined * 100))

    -- Speed override (respects adrenaline + last stand)
    local speedMult = wData.speedMult
    if adrenalineState[bg.id] and adrenalineState[bg.id].active then
        speedMult = math.min(1.3, speedMult * (Config.Adrenaline.speedBoost or 1.15))
    end
    if lastStandState[bg.id] and lastStandState[bg.id].active then
        speedMult = math.min(1.3, speedMult * (Config.LastStand.speedBoost or 1.10))
    end

    if speedMult < 0.6 then
        SetPedMoveRateOverride(bg.ped, 0.55)
    elseif speedMult < 0.9 then
        SetPedMoveRateOverride(bg.ped, 0.80)
    elseif speedMult > 1.05 then
        SetPedMoveRateOverride(bg.ped, speedMult)
    else
        SetPedMoveRateOverride(bg.ped, 1.0)
    end

    -- v5.0: Last stand invulnerability ticks
    local lsState = lastStandState[bg.id]
    if lsState and lsState.active and lsState.ticksRemaining > 0 then
        lsState.ticksRemaining = lsState.ticksRemaining - 1
        SetEntityInvincible(bg.ped, true)
    else
        if lsState and lsState.ticksRemaining and lsState.ticksRemaining <= 0 then
            SetEntityInvincible(bg.ped, false)
        end
    end
end

-- ────────────────────────────────────────────────────────────
-- WOUND ESCALATION
-- ────────────────────────────────────────────────────────────
local function updateWound(bg)
    if not DoesEntityExist(bg.ped) then return end
    local hp  = GetEntityHealth(bg.ped)
    local pct = hp / math.max(bg.maxHealth or 200, 1)

    local newWound = pct < 0.15 and 'critical'
                  or pct < 0.40 and 'serious'
                  or pct < 0.70 and 'minor'
                  or 'none'

    local curIdx = Config.GetWoundIndex(bg.wound or 'none')
    local newIdx = Config.GetWoundIndex(newWound)
    if newIdx > curIdx then
        bg.wound = newWound
        TriggerServerEvent('rde_bg:setWound', bg.id, newWound)

        if newWound == 'critical' then
            lib.notify({
                title       = '🩸 ' .. bg.name .. ' Critical!',
                description = 'Critically wounded — needs immediate support!',
                type        = 'error',
                duration    = 4000,
                icon        = 'heart-crack',
            })
        end

        -- v5.0: Check last stand
        checkLastStand(bg)
    end
end

-- ────────────────────────────────────────────────────────────
-- v5.0: SELF-HEAL SYSTEM
-- BGs check their inventory for bandage/medkit and heal themselves
-- ────────────────────────────────────────────────────────────
selfHealCooldowns = {}   -- [bgId] = GetGameTimer() of next allowed heal

local function attemptSelfHeal(bg)
    if not Config.SelfHeal or not Config.SelfHeal.enabled then return end
    if not DoesEntityExist(bg.ped) then return end

    local now = GetGameTimer()
    if selfHealCooldowns[bg.id] and now < selfHealCooldowns[bg.id] then return end

    -- Check if BG needs healing
    local hp  = GetEntityHealth(bg.ped)
    local pct = hp / math.max(bg.maxHealth or 200, 1)
    if pct >= (Config.SelfHeal.minHealthPct or 0.70) then return end

    -- Determine which item to use (smart choice based on wound severity)
    local woundIdx = Config.GetWoundIndex(bg.wound or 'none')
    local itemToUse = nil

    if Config.SelfHeal.smartItemChoice then
        -- Critical/Serious → prefer medkit, fallback bandage
        -- Minor → prefer bandage
        if woundIdx >= 3 then
            itemToUse = 'medkit_or_bandage'  -- server picks best available
        else
            itemToUse = 'bandage_or_medkit'
        end
    else
        itemToUse = 'any'
    end

    -- Set cooldown immediately to prevent spam
    selfHealCooldowns[bg.id] = now + (Config.SelfHeal.cooldownMs or 30000)

    -- Ask server to consume heal item from BG's stash
    lib.callback('rde_bg:selfHeal', false, function(res)
        if not res or not res.ok then return end
        if not activeBodyguards[bg.id] or not DoesEntityExist(bg.ped) then return end

        local bgRef = activeBodyguards[bg.id]

        -- Play healing animation
        CreateThread(function()
            local healDict = 'anim@heists@narcotics@funding@gang_idle'
            local healAnim = 'idle_a'

            -- If not in combat, play full animation
            if bgRef.state ~= 'combat' and bgRef.state ~= 'avenge' then
                ClearPedTasks(bgRef.ped)

                local ok = lib.requestAnimDict(healDict, 3000)
                if ok and DoesEntityExist(bgRef.ped) then
                    TaskPlayAnim(bgRef.ped, healDict, healAnim,
                        4.0, -4.0, Config.SelfHeal.animDurationMs or 3500,
                        1, 0, false, false, false)
                    Wait(Config.SelfHeal.animDurationMs or 3500)
                end
            else
                -- In combat: reduced animation, combat heal penalty
                Wait(1500)
            end

            if not DoesEntityExist(bgRef.ped) then return end

            -- Calculate heal amount
            local healPct = res.healPct or 0.25
            local medBonus = 1.0

            -- Medical skill bonus
            if Config.SelfHeal.medicalSkillBonus then
                medBonus = 1.0 + (bgRef.skills.medical or 0) * (Config.SelfHeal.medicalBonusPer or 0.005)
            end

            -- Combat penalty
            if bgRef.state == 'combat' or bgRef.state == 'avenge' then
                medBonus = medBonus * (Config.SelfHeal.combatHealPenalty or 0.50)
            end

            local healAmount = math.floor(bgRef.maxHealth * healPct * medBonus)
            local newHp = math.min(bgRef.maxHealth, GetEntityHealth(bgRef.ped) + healAmount)
            SetEntityHealth(bgRef.ped, newHp)

            -- Reduce wound level
            local woundReduction = res.woundClear or 1
            local curWoundIdx = Config.GetWoundIndex(bgRef.wound or 'none')
            local newWoundIdx = math.max(1, curWoundIdx - woundReduction)
            local newWound = Config.GetWoundByIndex(newWoundIdx)
            bgRef.wound = newWound
            TriggerServerEvent('rde_bg:setWound', bgRef.id, newWound)

            -- Morale boost
            TriggerServerEvent('rde_bg:updateMorale', bgRef.id, Config.Morale.gainOnSelfHeal or 3)
            bgRef.morale = math.min(100, (bgRef.morale or 75) + (Config.Morale.gainOnSelfHeal or 3))

            -- XP
            TriggerServerEvent('rde_bg:addXP', bgRef.id, 'heal_self')

            -- Memory + notification
            local itemLabel = res.itemUsed == 'medkit' and 'Medkit' or 'Bandage'
            if addMemory then
                addMemory(bgRef.id, 'Used ' .. itemLabel .. ' to treat wounds. HP restored.')
            end

            lib.notify({
                title       = '🩹 ' .. bgRef.name .. ' — Self-Healed',
                description = itemLabel .. ' used · +' .. healAmount .. ' HP · ' ..
                              (Config.Wounds.types[newWound] or {label='?'}).label,
                type        = 'success',
                duration    = 3500,
                icon        = 'kit-medical',
                iconColor   = '#22c55e',
            })

            -- Healing particle effect
            if DoesEntityExist(bgRef.ped) then
                local coords = GetEntityCoords(bgRef.ped)
                lib.requestNamedPtfxAsset('core', 2000)
                UseParticleFxAsset('core')
                StartParticleFxNonLoopedAtCoord(
                    'ent_dst_elec_fire_sp',
                    coords.x, coords.y, coords.z + 0.3,
                    0.0, 0.0, 0.0, 0.3, false, false, false
                )
            end
        end)
    end, bg.id, itemToUse)
end

-- ────────────────────────────────────────────────────────────
-- v5.0: BUDDY HEAL SYSTEM
-- BGs with medical skill heal nearby wounded BGs
-- ────────────────────────────────────────────────────────────
local buddyHealCooldowns = {}   -- [healerBgId] = GetGameTimer()

local function attemptBuddyHeal(bg)
    if not Config.BuddyHeal or not Config.BuddyHeal.enabled then return end
    if not DoesEntityExist(bg.ped) then return end
    if (bg.skills.medical or 0) < (Config.BuddyHeal.minMedicalSkill or 40) then return end
    if bg.state == 'combat' or bg.state == 'avenge' then return end

    local now = GetGameTimer()
    if buddyHealCooldowns[bg.id] and now < buddyHealCooldowns[bg.id] then return end

    local bgCoords = GetEntityCoords(bg.ped)
    local scanRadius = Config.BuddyHeal.scanRadiusM or 8.0

    -- Find most wounded nearby buddy
    local worstBuddy = nil
    local worstIdx   = 0

    for otherId, other in pairs(activeBodyguards) do
        if otherId ~= bg.id and DoesEntityExist(other.ped) and not other.networked then
            local dist = #(GetEntityCoords(other.ped) - bgCoords)
            if dist <= scanRadius then
                local wIdx = Config.GetWoundIndex(other.wound or 'none')
                if wIdx > 1 and wIdx > worstIdx then
                    worstIdx   = wIdx
                    worstBuddy = other
                end
            end
        end
    end

    if not worstBuddy then return end

    buddyHealCooldowns[bg.id] = now + (Config.BuddyHeal.cooldownMs or 45000)

    -- Walk to buddy and heal
    CreateThread(function()
        local targetPed = worstBuddy.ped
        if not DoesEntityExist(targetPed) then return end

        -- Walk to buddy
        local tc = GetEntityCoords(targetPed)
        TaskGoStraightToCoord(bg.ped, tc.x, tc.y, tc.z, 1.5, 5000, 0.0, 1.0)

        -- Wait to arrive
        local timeout = GetGameTimer() + 5000
        while GetGameTimer() < timeout do
            Wait(300)
            if not DoesEntityExist(bg.ped) or not DoesEntityExist(targetPed) then return end
            if #(GetEntityCoords(bg.ped) - GetEntityCoords(targetPed)) < 2.0 then break end
        end

        if not DoesEntityExist(bg.ped) or not DoesEntityExist(targetPed) then return end

        -- Face buddy
        TaskTurnPedToFaceEntity(bg.ped, targetPed, -1)
        Wait(400)

        -- Heal animation (kneel and treat)
        local healDict = 'mini@cpr@char_a@cpr_str'
        local healAnim = 'cpr_pumpchest'
        local ok = lib.requestAnimDict(healDict, 3000)
        if ok and DoesEntityExist(bg.ped) then
            TaskPlayAnim(bg.ped, healDict, healAnim, 4.0, -4.0, 3000, 0, 0, false, false, false)
            Wait(3000)
        end

        if not DoesEntityExist(targetPed) then return end
        if not activeBodyguards[worstBuddy.id] then return end

        -- Apply heal
        local healPct    = Config.BuddyHeal.healPct or 0.20
        local medBonus   = 1.0 + (bg.skills.medical or 0) * 0.003
        local healAmount = math.floor((worstBuddy.maxHealth or 200) * healPct * medBonus)
        local newHp      = math.min(worstBuddy.maxHealth or 200, GetEntityHealth(targetPed) + healAmount)
        SetEntityHealth(targetPed, newHp)

        -- Reduce wound
        local curIdx = Config.GetWoundIndex(worstBuddy.wound or 'none')
        local newIdx = math.max(1, curIdx - 1)
        local newWound = Config.GetWoundByIndex(newIdx)
        worstBuddy.wound = newWound
        TriggerServerEvent('rde_bg:setWound', worstBuddy.id, newWound)

        -- XP + morale for healer
        TriggerServerEvent('rde_bg:addXP', bg.id, 'heal_buddy')
        TriggerServerEvent('rde_bg:updateMorale', bg.id, Config.Morale.gainOnBuddyHeal or 6)
        bg.morale = math.min(100, (bg.morale or 75) + (Config.Morale.gainOnBuddyHeal or 6))

        if addMemory then
            addMemory(bg.id, 'Treated ' .. worstBuddy.name .. '\'s wounds in the field.')
            addMemory(worstBuddy.id, bg.name .. ' patched me up. Grateful.')
        end

        lib.notify({
            title       = '🏥 ' .. bg.name .. ' → ' .. worstBuddy.name,
            description = 'Field medic treated wounds · +' .. healAmount .. ' HP',
            type        = 'success',
            duration    = 3500,
            icon        = 'user-nurse',
            iconColor   = '#22c55e',
        })
    end)
end

-- ────────────────────────────────────────────────────────────
-- v5.0: WEAPON AUTO-EQUIP
-- Equip best weapon from BG's stash inventory
-- ────────────────────────────────────────────────────────────
local weaponEquipCache = {}   -- [bgId] = { weaponHash, lastCheck }

function equipBestWeapon(bgId)
    if not Config.Weapons.useInventoryWeapons then return end

    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    lib.callback('rde_bg:getWeapons', false, function(weapons)
        if not weapons or #weapons == 0 then
            -- No weapons in inventory — use fists
            if Config.Weapons.defaultMelee then
                weaponEquipCache[bgId] = { weaponHash = GetHashKey('WEAPON_UNARMED'), lastCheck = GetGameTimer() }
            end
            return
        end

        local bg = activeBodyguards[bgId]
        if not bg or not DoesEntityExist(bg.ped) then return end

        -- Remove all existing weapons first
        RemoveAllPedWeapons(bg.ped, true)

        -- Give best weapon (sorted by priority from server)
        local bestWeapon = weapons[1]
        local weapHash   = GetHashKey(bestWeapon.name:upper())
        local ammo       = bestWeapon.ammo or 250

        if Config.Weapons.unlimitedAmmo then
            ammo = 9999
        end

        GiveWeaponToPed(bg.ped, weapHash, ammo, false, true)
        SetCurrentPedWeapon(bg.ped, weapHash, true)

        -- Also give secondary weapons if available
        for i = 2, math.min(#weapons, 3) do
            local w = weapons[i]
            local wh = GetHashKey(w.name:upper())
            GiveWeaponToPed(bg.ped, wh, w.ammo or 100, false, false)
        end

        weaponEquipCache[bgId] = { weaponHash = weapHash, lastCheck = GetGameTimer() }

        if addMemory then
            addMemory(bgId, 'Equipped ' .. bestWeapon.name:gsub('WEAPON_', ''):gsub('_', ' ') .. '.')
        end
    end, bgId)
end

-- ────────────────────────────────────────────────────────────
-- v5.0: TACTICAL COVER SYSTEM
-- BGs seek cover during combat when health is low
-- ────────────────────────────────────────────────────────────
local coverState = {}   -- [bgId] = { inCover, lastCoverTime }

local function seekCover(bg)
    if not Config.TacticalCover or not Config.TacticalCover.enabled then return false end
    if (bg.skills.tactics or 0) < (Config.TacticalCover.minTacticsSkill or 20) then return false end
    if not DoesEntityExist(bg.ped) then return false end

    local hp  = GetEntityHealth(bg.ped)
    local pct = hp / math.max(bg.maxHealth or 200, 1)

    if pct > (Config.TacticalCover.seekCoverHealthPct or 0.50) then return false end

    local state = coverState[bg.id] or {}
    local now   = GetGameTimer()

    if state.inCover and now - (state.lastCoverTime or 0) < (Config.TacticalCover.coverDurationMs or 4000) then
        return true  -- Already in cover, wait it out
    end

    -- Find nearby cover
    local bgCoords = GetEntityCoords(bg.ped)
    local coverX, coverY, coverZ = bgCoords.x, bgCoords.y, bgCoords.z

    if bg.target and DoesEntityExist(bg.target) then
        local tgtCoords = GetEntityCoords(bg.target)
        -- Seek cover AWAY from enemy
        local dir = bgCoords - tgtCoords
        local len = #dir
        if len > 0.1 then
            dir = dir / len
            coverX = bgCoords.x + dir.x * 5.0
            coverY = bgCoords.y + dir.y * 5.0
        end
    end

    -- Use TaskSeekCoverFromPed for realistic cover behavior
    if bg.target and DoesEntityExist(bg.target) then
        TaskSeekCoverFromPed(bg.ped, bg.target, -1, false)
    else
        TaskSeekCoverFromPos(bg.ped, coverX, coverY, coverZ, -1, false)
    end

    coverState[bg.id] = { inCover = true, lastCoverTime = now }

    return true
end

-- ────────────────────────────────────────────────────────────
-- FOLLOW STATE
-- ────────────────────────────────────────────────────────────
local function handleFollow(bg)
    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHead   = GetEntityHeading(playerPed)
    local pedCoords    = GetEntityCoords(bg.ped)
    local dist         = #(pedCoords - playerCoords)

    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    if playerVeh ~= 0 then
        if IsPedInVehicle(bg.ped, playerVeh, true) then return end
        local taskStatus = GetScriptTaskStatus(bg.ped, 0x8DC7710E)
        if taskStatus == 1 then return end

        local maxSeats = GetVehicleMaxNumberOfPassengers(playerVeh)
        local preferredSeat = (bg.slot or 1) - 1

        local chosenSeat = -2
        if preferredSeat <= maxSeats and IsVehicleSeatFree(playerVeh, preferredSeat) then
            chosenSeat = preferredSeat
        else
            for seat = 0, maxSeats do
                if IsVehicleSeatFree(playerVeh, seat) then
                    chosenSeat = seat
                    break
                end
            end
        end

        if chosenSeat >= 0 then
            TaskEnterVehicle(bg.ped, playerVeh, 10000, chosenSeat, 1.0, 1, 0)
        end
        return
    end

    if playerVeh == 0 and IsPedInAnyVehicle(bg.ped, false) then
        local bgVeh = GetVehiclePedIsIn(bg.ped, false)
        if bgVeh ~= 0 then
            TaskLeaveVehicle(bg.ped, bgVeh, 0)
            return
        end
    end

    if dist > 40.0 then
        local tp = vector3(
            playerCoords.x + math.cos(math.rad(playerHead + 180)) * 4.0,
            playerCoords.y + math.sin(math.rad(playerHead + 180)) * 4.0,
            playerCoords.z
        )
        SetEntityCoords(bg.ped, tp.x, tp.y, tp.z, false, false, false, false)
        bg._lastFollowTask = nil
        return
    end

    if dist > 3.0 then
        local targetPos = getFormationPos(bg.slot, playerCoords, playerHead)
        local speed     = dist > 15.0 and 3.0 or (dist > 8.0 and 2.2 or 1.6)

        local taskInterval = dist > 10.0 and 500 or 1000
        if not bg._lastFollowTask or GetGameTimer() - bg._lastFollowTask > taskInterval then
            bg._lastFollowTask = GetGameTimer()
            TaskFollowNavMeshToCoord(
                bg.ped,
                targetPos.x, targetPos.y, targetPos.z,
                speed, 5000, 0.5, false, 0.0
            )
        end
    else
        if not bg._facingPlayer or GetGameTimer() - bg._facingPlayer > 4000 then
            bg._facingPlayer = GetGameTimer()
            TaskTurnPedToFaceEntity(bg.ped, playerPed, -1)
        end
    end
end

-- ────────────────────────────────────────────────────────────
-- GUARD STATE
-- ────────────────────────────────────────────────────────────
local function handleGuard(bg)
    if not bg.guardPos then bg.guardPos = GetEntityCoords(bg.ped) end

    local dist = #(GetEntityCoords(bg.ped) - bg.guardPos)

    if dist > 2.5 then
        if not bg._guardReturnTime or GetGameTimer() - bg._guardReturnTime > 1200 then
            bg._guardReturnTime = GetGameTimer()
            TaskGoStraightToCoord(bg.ped, bg.guardPos.x, bg.guardPos.y, bg.guardPos.z,
                1.5, 8000, 0.0, 0.5)
        end
    else
        if not bg._guardTaskIssued then
            bg._guardTaskIssued = true
            TaskGuardCurrentPosition(bg.ped, 8.0, 8.0, true)
        end

        if not bg._lastScan or GetGameTimer() - bg._lastScan > 2000 then
            bg._lastScan = GetGameTimer()
            local angle = math.random(360)
            local scanX = bg.guardPos.x + math.cos(math.rad(angle)) * 10.0
            local scanY = bg.guardPos.y + math.sin(math.rad(angle)) * 10.0
            TaskLookAtCoord(bg.ped, scanX, scanY, bg.guardPos.z, 1800, 0, 2)
        end
    end
end

local function onGuardStateExit(bg)
    bg._guardTaskIssued = false
    bg._guardReturnTime = nil
    bg._lastScan        = nil
end

-- ────────────────────────────────────────────────────────────
-- PATROL STATE
-- ────────────────────────────────────────────────────────────
local function handlePatrol(bg)
    if not bg.patrolCenter then bg.patrolCenter = GetEntityCoords(bg.ped) end

    local now     = GetGameTimer()
    local elapsed = now - (bg.lastPatrolMv or 0)
    local wait    = math.random(Config.AI.patrolWaitMs.min, Config.AI.patrolWaitMs.max)

    local pedStopped = IsPedStopped(bg.ped)

    if pedStopped and elapsed > wait then
        bg.lastPatrolMv = now

        local r     = Config.AI.patrolRadius
        local angle = math.random(360)
        local dDist = math.random(math.floor(r * 0.3), math.floor(r))
        local dest  = vector3(
            bg.patrolCenter.x + math.cos(math.rad(angle)) * dDist,
            bg.patrolCenter.y + math.sin(math.rad(angle)) * dDist,
            bg.patrolCenter.z
        )
        local ok, gz = GetGroundZFor_3dCoord(dest.x, dest.y, dest.z + 5.0, false)
        if ok then dest = vector3(dest.x, dest.y, gz) end

        TaskGoStraightToCoord(bg.ped, dest.x, dest.y, dest.z, 1.1, 20000, 0.0, 1.0)

        if now - (bg.lastXPTick or 0) > 60000 then
            bg.lastXPTick = now
            TriggerServerEvent('rde_bg:addXP', bg.id, 'patrol_tick')
        end
    end
end

-- ────────────────────────────────────────────────────────────
-- COMBAT STATE (with tactical cover + adrenaline integration)
-- ────────────────────────────────────────────────────────────
local function handleCombat(bg)
    if not bg.target or not DoesEntityExist(bg.target) or IsEntityDead(bg.target) then
        local _oldTarget = bg.target
        onGuardStateExit(bg)
        bg.state  = 'follow'
        bg.target = nil
        if _oldTarget then clearThreatConfirm(_oldTarget) end
        ClearPedTasks(bg.ped)
        coverState[bg.id] = nil
        return
    end

    local bgCoords  = GetEntityCoords(bg.ped)
    local tgtCoords = GetEntityCoords(bg.target)
    local dist      = #(bgCoords - tgtCoords)

    if dist > 100.0 then
        onGuardStateExit(bg)
        bg.state  = 'follow'
        bg.target = nil
        ClearPedTasks(bg.ped)
        coverState[bg.id] = nil
        return
    end

    -- Re-verify target every 3s
    if not bg._lastHostileVerify or GetGameTimer() - bg._lastHostileVerify > 3000 then
        bg._lastHostileVerify = GetGameTimer()
        local playerPed = PlayerPedId()
        if not isRealThreat(bg.target, playerPed) then
            local _oldTarget = bg.target
            onGuardStateExit(bg)
            bg.state  = 'follow'
            bg.target = nil
            if _oldTarget then clearThreatConfirm(_oldTarget) end
            ClearPedTasks(bg.ped)
            coverState[bg.id] = nil
            return
        end
    end

    -- v5.0: Tactical cover when health is low
    if seekCover(bg) then
        -- In cover — don't issue new combat tasks, let cover play out
        -- But still shoot from cover if possible
        if not bg._coverShootTime or GetGameTimer() - bg._coverShootTime > 2000 then
            bg._coverShootTime = GetGameTimer()
            if bg.target and DoesEntityExist(bg.target) then
                TaskShootAtEntity(bg.ped, bg.target, -1, GetHashKey('FIRING_PATTERN_BURST_FIRE_PISTOL'))
            end
        end
        return
    end

    -- Tactical movement for skilled BGs
    if dist > 25.0 and (bg.skills.tactics or 0) > 50 then
        if not bg._combatMoveTime or GetGameTimer() - bg._combatMoveTime > 1500 then
            bg._combatMoveTime = GetGameTimer()
            TaskGoToEntityWhileAimingAtEntity(bg.ped, bg.target, bg.target,
                3.0, true, 0x41200000, 0x41200000, false, false, 512)
        end
    else
        if not bg._combatTaskTime or GetGameTimer() - bg._combatTaskTime > 2000 then
            bg._combatTaskTime = GetGameTimer()
            TaskCombatPed(bg.ped, bg.target, 0, 16)
        end
    end

    -- Suppressive Fire
    if Config.AI.suppressiveFire
    and (bg.skills.tactics or 0) > 70
    and math.random(100) <= 8
    and (not bg._suppressTime or GetGameTimer() - bg._suppressTime > 4000)
    then
        bg._suppressTime = GetGameTimer()
        local tc = GetEntityCoords(bg.target)
        ShootSingleBulletBetweenCoords(
            tc.x + math.random(-2, 2), tc.y + math.random(-2, 2), tc.z,
            tc.x, tc.y, tc.z,
            100, true, GetCurrentPedWeapon(bg.ped), bg.ped, true, false, 200.0
        )
    end
end

-- ────────────────────────────────────────────────────────────
-- AVENGE STATE
-- ────────────────────────────────────────────────────────────
local function handleAvenge(bg)
    local playerPed = PlayerPedId()
    if not bg.target or not DoesEntityExist(bg.target) or IsEntityDead(bg.target) then
        local threats = scanThreats(GetEntityCoords(bg.ped), 60.0, playerPed)
        if #threats > 0 then
            bg.target = threats[1].ped
        else
            bg.state  = 'follow'
            bg.avenge = false
            bg.target = nil
            return
        end
    end

    if bg.target and DoesEntityExist(bg.target) then
        TaskCombatPed(bg.ped, bg.target, 0, 16)
        SetPedFleeAttributes(bg.ped, 0, false)
        SetPedCombatAttributes(bg.ped, 46, false)
        SetPedCombatAttributes(bg.ped, 5, true)
    end

    if not bg._avengeVoice or GetGameTimer() - bg._avengeVoice > 8000 then
        bg._avengeVoice = GetGameTimer()
        playVoiceLine(bg.ped, 'combat')
    end
end

-- ────────────────────────────────────────────────────────────
-- THREAT ENGAGEMENT
-- ────────────────────────────────────────────────────────────
local function engageThreats(bg)
    if bg.state == 'combat' or bg.state == 'arriving' or bg.state == 'avenge' then return end

    local playerPed = PlayerPedId()
    local threats   = scanThreats(GetEntityCoords(bg.ped), Config.AI.engageRange, playerPed)
    if #threats == 0 then return end

    if bg.state == 'guard' then onGuardStateExit(bg) end

    bg.state  = 'combat'
    bg.target = threats[1].ped
    bg._lastHostileVerify = GetGameTimer()
    bg._combatMoveTime    = nil
    bg._suppressTime      = nil

    TaskCombatPed(bg.ped, bg.target, 0, 16)

    -- v5.0: Trigger adrenaline on combat start
    triggerAdrenaline(bg.id)

    -- Flanking
    if Config.AI.flanking and (bg.skills.tactics or 0) > 65 then
        local tc  = GetEntityCoords(bg.target)
        local bgC = GetEntityCoords(bg.ped)
        local d   = #(bgC - tc)
        if d > 10.0 then
            local fa = math.random(60, 120) + (math.random(2) == 1 and 180 or 0)
            local fp = vector3(
                tc.x + math.cos(math.rad(fa)) * 10.0,
                tc.y + math.sin(math.rad(fa)) * 10.0,
                tc.z
            )
            TaskGoToCoordAnyMeans(bg.ped, fp.x, fp.y, fp.z, 3.5, 0, false, 786603, 0.0)
            Wait(1200)
        end
    end

    playVoiceLine(bg.ped, 'combat')
end

-- ────────────────────────────────────────────────────────────
-- KILL DETECTION
-- ────────────────────────────────────────────────────────────
local function checkKill(bg)
    if bg.target and DoesEntityExist(bg.target) and IsEntityDead(bg.target) then
        TriggerServerEvent('rde_bg:kill',         bg.id)
        TriggerServerEvent('rde_bg:addXP',        bg.id, 'kill_ped')
        TriggerServerEvent('rde_bg:updateMorale', bg.id, Config.Morale.gainOnKill)
        bg.morale = math.min(100, (bg.morale or 75) + Config.Morale.gainOnKill)

        -- v5.0: Adrenaline on kill
        if Config.Adrenaline and Config.Adrenaline.triggerOnKill then
            triggerAdrenaline(bg.id)
        end

        clearThreatConfirm(bg.target)
        onGuardStateExit(bg)
        bg.state             = 'follow'
        bg.target            = nil
        bg._lastHostileVerify = nil
        coverState[bg.id]    = nil

        if addMemory then addMemory(bg.id, 'Eliminated a threat.') end
        playVoiceLine(bg.ped, 'combat')

        lib.notify({
            title       = '💀 ' .. bg.name,
            description = 'Threat eliminated.',
            type        = 'success',
            duration    = 2500,
            icon        = 'skull',
        })
    end
end

-- ────────────────────────────────────────────────────────────
-- PROTECT DETECTION (Spieler nimmt Schaden → BG reagiert)
-- ────────────────────────────────────────────────────────────
local lastPlayerHP = 200
CreateThread(function()
    while true do
        Wait(500)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then Wait(1500); goto pSkip end

        local playerPed    = PlayerPedId()
        local hp           = GetEntityHealth(playerPed)
        local playerCoords = GetEntityCoords(playerPed)

        if hp < lastPlayerHP then
            for bgId, bg in pairs(activeBodyguards) do
                if bg.state ~= 'arriving' and DoesEntityExist(bg.ped) then
                    if #(GetEntityCoords(bg.ped) - playerCoords) < 9.0 then
                        TriggerServerEvent('rde_bg:protect',      bgId)
                        TriggerServerEvent('rde_bg:addXP',        bgId, 'protect')
                        TriggerServerEvent('rde_bg:updateMorale', bgId, Config.Morale.gainOnProtect)
                        bg.morale = math.min(100, (bg.morale or 75) + Config.Morale.gainOnProtect)
                        playVoiceLine(bg.ped, 'protect')
                        if addMemory then addMemory(bgId, 'Protected you from harm.') end

                        -- v5.0: Adrenaline when player takes damage
                        if Config.Adrenaline and Config.Adrenaline.triggerOnPlayerHit then
                            triggerAdrenaline(bgId)
                        end
                    end
                end
            end
        end
        lastPlayerHP = hp
        ::pSkip::
    end
end)

-- Guard XP tick
CreateThread(function()
    while true do
        Wait(60000)
        for bgId, bg in pairs(activeBodyguards) do
            if bg.state == 'guard' then
                TriggerServerEvent('rde_bg:addXP', bgId, 'guard_tick')
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- v5.0: SELF-HEAL CHECK THREAD
-- Runs independently from main AI loop for all active BGs
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.SelfHeal and Config.SelfHeal.checkIntervalMs or 5000)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then goto healSkip end

        for bgId, bg in pairs(activeBodyguards) do
            if not bg.networked and DoesEntityExist(bg.ped)
            and bg.state ~= 'arriving' and not IsEntityDead(bg.ped) then
                attemptSelfHeal(bg)
            end
        end
        ::healSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- v5.0: BUDDY HEAL CHECK THREAD
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.BuddyHeal and Config.BuddyHeal.checkIntervalMs or 8000)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then goto bhSkip end

        for bgId, bg in pairs(activeBodyguards) do
            if not bg.networked and DoesEntityExist(bg.ped)
            and bg.state ~= 'arriving' and bg.state ~= 'combat'
            and not IsEntityDead(bg.ped) then
                attemptBuddyHeal(bg)
            end
        end
        ::bhSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- v5.0: WEAPON RE-EQUIP THREAD
-- Periodically check if BG has better weapons available
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.Weapons.reEquipIntervalMs or 30000)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then goto weSkip end

        for bgId, bg in pairs(activeBodyguards) do
            if not bg.networked and DoesEntityExist(bg.ped)
            and bg.state ~= 'arriving' and not IsEntityDead(bg.ped) then
                -- Only re-equip if BG has no weapon or is unarmed
                local _, curWeap = GetCurrentPedWeapon(bg.ped)
                if curWeap == GetHashKey('WEAPON_UNARMED') then
                    equipBestWeapon(bgId)
                end
            end
        end
        ::weSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- DEATH HANDLER
-- ────────────────────────────────────────────────────────────
local function handleDeath(bgId)
    local bg = activeBodyguards[bgId]
    if not bg then return end

    TriggerServerEvent('rde_bg:died',         bgId)
    TriggerServerEvent('rde_bg:updateMorale', bgId, -Config.Morale.penaltyOnDeath)

    playDeathEffect(GetEntityCoords(bg.ped))

    if DoesEntityExist(bg.ped) then
        exports.ox_target:removeLocalEntity(bg.ped)
    end

    CreateThread(function()
        for alpha = 255, 0, -20 do
            if DoesEntityExist(bg.ped) then SetEntityAlpha(bg.ped, alpha, false) end
            Wait(80)
        end
        if DoesEntityExist(bg.ped)            then DeletePed(bg.ped)   end
        if bg.blip and DoesBlipExist(bg.blip) then RemoveBlip(bg.blip) end
    end)

    -- Cleanup v5.0 state
    selfHealCooldowns[bgId] = nil
    buddyHealCooldowns[bgId] = nil
    adrenalineState[bgId]   = nil
    lastStandState[bgId]    = nil
    coverState[bgId]        = nil
    weaponEquipCache[bgId]  = nil

    activeBodyguards[bgId] = nil
    formationSlotMap[bgId] = nil
    buildRadialMenu()
end

-- ────────────────────────────────────────────────────────────
-- MAIN AI LOOP
-- ────────────────────────────────────────────────────────────
local function startAILoop(bgId)
    while not canSpawnThread() do
        Wait(100)
    end

    registerThread()

    CreateThread(function()
        local lastThreat = 0
        local lastWound  = 0
        local lastState  = ''
        local lastSync   = 0
        local lastLOD    = 0

        while activeBodyguards[bgId] do
            local bg = activeBodyguards[bgId]
            if not bg then break end

            local baseRate = Config.AI.followUpdateMs or 600
            local loadFactor = getSystemLoadFactor()
            local updateRate = getAdaptiveUpdateRate(baseRate, loadFactor)
            Wait(updateRate)

            if bg.state == 'arriving' then
                Wait(500); goto aiNext
            end

            if not DoesEntityExist(bg.ped) or IsEntityDead(bg.ped) then
                handleDeath(bgId)
                break
            end

            local now = GetGameTimer()
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- LOD & Distance Culling
            if now - lastLOD > 500 then
                lastLOD = now
                local bgCoords = GetEntityCoords(bg.ped)
                local distance = #(playerCoords - bgCoords)

                local lodLevel = getLODLevel(distance)
                applyLOD(bg, lodLevel)

                if lodLevel == 'culled' then
                    Wait(1000)
                    goto aiNext
                end

                local shouldFade, fadeAmount = shouldFadeOut(bg, playerCoords)
                if shouldFade then
                    local alpha = math.floor(255 * (1 - fadeAmount))
                    SetEntityAlpha(bg.ped, alpha, false)
                end
            end

            -- Threat scan
            if bg.state ~= 'combat' and bg.state ~= 'avenge' then
                local scanInterval = Config.AI.threatScanMs
                local lodLevel = getLODLevel(#(GetEntityCoords(bg.ped) - playerCoords))

                if lodLevel == 'low' then
                    scanInterval = scanInterval * 2
                elseif lodLevel == 'medium' then
                    scanInterval = scanInterval * 1.5
                end

                if now - lastThreat > scanInterval then
                    lastThreat = now
                    engageThreats(bg)
                end
            end

            -- Wound/modifier update
            if now - lastWound > Config.AI.healthCheckMs then
                lastWound = now
                updateWound(bg)
                applyModifiers(bg)

                if now - lastSync > 2000 then
                    lastSync = now
                    if syncBGHealth then
                        syncBGHealth(bgId, GetEntityHealth(bg.ped), bg.maxHealth or 200)
                    end
                end
            end

            checkKill(bg)

            if lastState == 'guard' and bg.state ~= 'guard' then
                onGuardStateExit(bg)
            end
            lastState = bg.state

            -- State machine
            local s = bg.state or 'follow'
            if     s == 'follow'  then handleFollow(bg)
            elseif s == 'guard'   then handleGuard(bg)
            elseif s == 'patrol'  then handlePatrol(bg)
            elseif s == 'combat'  then handleCombat(bg)
            elseif s == 'avenge'  then handleAvenge(bg)
            end

            -- Auto-Retreat
            if bg.state == 'combat' and bg.state ~= 'avenge' then
                local hp = GetEntityHealth(bg.ped)
                if hp < (bg.maxHealth or 200) * Config.AI.retreatHealthPct
                and (bg.skills.medical or 0) > 30 then
                    onGuardStateExit(bg)
                    bg.state  = 'follow'
                    bg.target = nil
                    coverState[bg.id] = nil
                    local pc  = GetEntityCoords(PlayerPedId())
                    TaskGoStraightToCoord(bg.ped, pc.x, pc.y, pc.z, 3.0, 5000, 0.0, 1.5)
                    lib.notify({
                        title       = '🏥 ' .. bg.name,
                        description = 'Retreating — critically low health!',
                        type        = 'warning',
                        duration    = 3000,
                    })
                end
            end

            ::aiNext::
        end

        -- Cleanup on exit
        cleanupLODCache(bgId)
        if cleanupSyncData then cleanupSyncData(bgId) end
        selfHealCooldowns[bgId]  = nil
        buddyHealCooldowns[bgId] = nil
        adrenalineState[bgId]    = nil
        lastStandState[bgId]     = nil
        coverState[bgId]         = nil
        weaponEquipCache[bgId]   = nil
        unregisterThread()
    end)
end

-- ────────────────────────────────────────────────────────────
-- HOOK: activateBodyguard → AI Loop + Weapon Equip
-- ────────────────────────────────────────────────────────────
local _orig = activateBodyguard
activateBodyguard = function(bgData)
    local ok, err = pcall(_orig, bgData)
    if not ok then
        lib.notify({
            title       = '❌ Bodyguard Error',
            description = tostring(err),
            type        = 'error',
            duration    = 6000,
        })
        return
    end
    CreateThread(function()
        Wait(800)
        startAILoop(bgData.id)

        -- v5.0: Auto-equip weapon after arrival
        if Config.Weapons.equipOnSpawn then
            -- Wait for arrival to complete
            local timeout = GetGameTimer() + 120000
            while GetGameTimer() < timeout do
                local bg = activeBodyguards[bgData.id]
                if not bg then return end
                if bg.state ~= 'arriving' then break end
                Wait(1000)
            end
            Wait(1500)  -- Brief delay after arrival
            equipBestWeapon(bgData.id)
        end
    end)
end

print('^2[RDE-BG]^7 AI v5.1 loaded ✓ (Self-Heal · Buddy Heal · Adrenaline · Cover · LastStand · WeaponEquip · EnvAwareness)')
