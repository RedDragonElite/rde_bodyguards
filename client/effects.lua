-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.0  —  client/effects.lua
-- Loads FIRST — provides Draw3DText, particle FX, spawn/death effects
-- All functions defined here are global so ai.lua / main.lua can call them
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- DRAW 3D TEXT  (world-space label above peds)
-- ────────────────────────────────────────────────────────────
function Draw3DText(x, y, z, text, scale, r, g, b, a)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoord()
    local dist      = #(vector3(x, y, z) - camCoords)
    if dist > 20.0 then return end

    -- Fixed pixel size: scale stays constant regardless of distance/FOV
    -- Use a small fixed value instead of distance-based calculation
    local s = 0.28 * scale

    SetTextScale(s, s)
    SetTextFont(7)   -- Font 7 = Chalet (clean, no emoji rendering issues)
    SetTextColour(r or 255, g or 255, b or 255, a or 235)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- ────────────────────────────────────────────────────────────
-- SPAWN PARTICLE EFFECT
-- ────────────────────────────────────────────────────────────
function playSpawnEffect(coords)
    CreateThread(function()
        lib.requestNamedPtfxAsset('scr_rcbarry1', 4000)
        UseParticleFxAsset('scr_rcbarry1')
        local p = StartParticleFxLoopedAtCoord(
            'scr_alien_teleport',
            coords.x, coords.y, coords.z,
            0.0, 0.0, 0.0, 1.2, false, false, false, false
        )
        PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
        Wait(1800)
        StopParticleFxLooped(p, false)
    end)
end

-- ────────────────────────────────────────────────────────────
-- LEVEL UP PARTICLE EFFECT
-- ────────────────────────────────────────────────────────────
function playLevelUpEffect(ped)
    CreateThread(function()
        if not DoesEntityExist(ped) then return end
        local coords = GetEntityCoords(ped)
        lib.requestNamedPtfxAsset('scr_rcbarry2', 4000)
        UseParticleFxAsset('scr_rcbarry2')
        local p = StartParticleFxLoopedAtCoord(
            'scr_clown_appears',
            coords.x, coords.y, coords.z - 1.0,
            0.0, 0.0, 0.0, 1.5, false, false, false, false
        )
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
        Wait(2500)
        StopParticleFxLooped(p, false)
    end)
end

-- ────────────────────────────────────────────────────────────
-- DEATH EFFECT
-- ────────────────────────────────────────────────────────────
function playDeathEffect(coords)
    CreateThread(function()
        lib.requestNamedPtfxAsset('scr_solomon3', 4000)
        UseParticleFxAsset('scr_solomon3')
        StartParticleFxNonLoopedAtCoord(
            'scr_solomon3_ghost',
            coords.x, coords.y, coords.z + 0.5,
            0.0, 0.0, 0.0, 1.0, false, false, false
        )
        PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)
    end)
end

-- ────────────────────────────────────────────────────────────
-- INTERACTION / ROMANCE EFFECT
-- ────────────────────────────────────────────────────────────
function playRomanceEffect(ped1, ped2)
    CreateThread(function()
        if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then return end
        lib.requestNamedPtfxAsset('scr_indep_fireworks', 4000)
        UseParticleFxAsset('scr_indep_fireworks')
        local c1 = GetEntityCoords(ped1)
        local c2 = GetEntityCoords(ped2)
        for _ = 1, 4 do
            Wait(150)
            StartParticleFxNonLoopedAtCoord('scr_indep_firework_trailburst', c1.x, c1.y, c1.z + 1.0, 0.0, 0.0, 0.0, 0.3, false, false, false)
            StartParticleFxNonLoopedAtCoord('scr_indep_firework_trailburst', c2.x, c2.y, c2.z + 1.0, 0.0, 0.0, 0.0, 0.3, false, false, false)
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- WORLD-SPACE LABELS  (v5.2: Enhanced with status icons)
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        if type(activeBodyguards) ~= 'table' then
            Wait(1000)
            goto labelsSkip
        end

        local hasBGs = next(activeBodyguards) ~= nil

        if not hasBGs then
            Wait(1000)
        else
            Wait(0)
            for bgId, bg in pairs(activeBodyguards) do
                if DoesEntityExist(bg.ped) and not bg.networked then
                    local coords    = GetEntityCoords(bg.ped)
                    local camCoords = GetGameplayCamCoord()
                    local dist      = #(coords - camCoords)

                    if dist < 20.0 then
                        local yOff = 1.25

                        -- Name plate with level
                        local rData = Config.GetRarity(bg.rarity or 'common')
                        local r, g, b = 200, 200, 200
                        -- Parse hex color from rarity
                        if rData and rData.color then
                            local hex = rData.color:gsub('#', '')
                            r = tonumber(hex:sub(1,2), 16) or 200
                            g = tonumber(hex:sub(3,4), 16) or 200
                            b = tonumber(hex:sub(5,6), 16) or 200
                        end
                        Draw3DText(coords.x, coords.y, coords.z + yOff, bg.name .. '  Lv.' .. (bg.level or 1), 1.6, r, g, b, 240)
                        yOff = yOff + 0.13

                        -- Wound status with icon
                        if bg.wound and bg.wound ~= 'none' then
                            local wInfo = Config.Wounds.types[bg.wound]
                            if wInfo then
                                local wr, wg, wb = 255, 200, 0
                                local wIcon = '+'
                                if bg.wound == 'critical' then
                                    wr, wg, wb = 255, 50, 50
                                    wIcon = '!!'
                                elseif bg.wound == 'serious' then
                                    wr, wg, wb = 255, 120, 30
                                    wIcon = '!'
                                else
                                    wIcon = '*'
                                end
                                Draw3DText(coords.x, coords.y, coords.z + yOff,
                                    '['..wIcon..'] ' .. wInfo.label, 1.5, wr, wg, wb, 230)
                                yOff = yOff + 0.12
                            end
                        end

                        -- Morale warning
                        if (bg.morale or 75) < 30 then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '[!!] MORALE LOW', 1.4, 255, 80, 80, 200)
                            yOff = yOff + 0.12
                        elseif (bg.morale or 75) < 50 then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '[!] MORALE SHAKEN', 1.3, 245, 158, 11, 180)
                            yOff = yOff + 0.12
                        end

                        -- HP percentage when damaged
                        local hp  = GetEntityHealth(bg.ped)
                        local pct = math.floor(hp / math.max(bg.maxHealth or 200, 1) * 100)
                        if pct < 95 then
                            local hr, hg, hb = 34, 197, 94
                            if pct < 25 then hr, hg, hb = 239, 68, 68
                            elseif pct < 50 then hr, hg, hb = 249, 115, 22
                            elseif pct < 75 then hr, hg, hb = 234, 179, 8
                            end
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                'HP: ' .. pct .. '%', 1.3, hr, hg, hb, 200)
                            yOff = yOff + 0.12
                        end

                        -- State indicator
                        if bg.state == 'combat' then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '>> COMBAT <<', 1.5, 239, 68, 68, 255)
                            yOff = yOff + 0.12
                        elseif bg.state == 'avenge' then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '>> AVENGE <<', 1.5, 168, 85, 247, 255)
                            yOff = yOff + 0.12
                        elseif bg.state == 'guard' then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '[GUARDING]', 1.2, 245, 158, 11, 160)
                            yOff = yOff + 0.12
                        elseif bg.state == 'patrol' then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '[PATROL]', 1.2, 34, 211, 238, 160)
                            yOff = yOff + 0.12
                        end

                        -- Adrenaline
                        if type(adrenalineState) == 'table' and adrenalineState[bgId]
                        and adrenalineState[bgId].active then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '>> ADRENALINE <<', 1.4, 244, 114, 182, 255)
                            yOff = yOff + 0.12
                        end

                        -- Last Stand
                        if type(lastStandState) == 'table' and lastStandState[bgId]
                        and lastStandState[bgId].active then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '>> LAST STAND <<', 1.5, 255, 107, 53, 255)
                            yOff = yOff + 0.12
                        end

                        -- Holstered indicator
                        if bg._holstered then
                            Draw3DText(coords.x, coords.y, coords.z + yOff,
                                '[HOLSTERED]', 1.1, 148, 163, 184, 140)
                        end
                    end
                end
            end
        end
        ::labelsSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- v5.2: HEAL PARTICLE EFFECT
-- ────────────────────────────────────────────────────────────
function playHealEffect(ped)
    CreateThread(function()
        if not DoesEntityExist(ped) then return end
        local coords = GetEntityCoords(ped)
        lib.requestNamedPtfxAsset('core', 2000)
        UseParticleFxAsset('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_dst_elec_fire_sp',
            coords.x, coords.y, coords.z + 0.5,
            0.0, 0.0, 0.0, 0.4, false, false, false
        )
    end)
end

print('^2[RDE-BG]^7 Effects v5.2 loaded ✓')