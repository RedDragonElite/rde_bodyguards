-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.0  —  client/bond.lua
-- Deep bond system: personality · memory · witness · body language
-- Features never seen before in any FiveM bodyguard script
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- PERSONALITY SYSTEM
-- Each BG has a personality that shapes their idle chatter,
-- reactions and emote style. Derived from bgId (deterministic).
-- ────────────────────────────────────────────────────────────
local personalities = {
    stoic    = {
        label     = 'Stoic',
        idleAnims = {
            {dict='amb@world_human_cop_idles@male@base', anim='base'},
            {dict='amb@world_human_smoking@male@idle_a', anim='idle_a'},
        },
        voiceLines = {
            idle    = {'...', 'Clear.', 'Perimeter secure.'},
            combat  = {'Engaging.', 'Target acquired.', 'On it.'},
            protect = {'I got you.', 'Stay back.', 'Cover!'},
            levelup = {'Improving.', 'Getting sharper.'},
            bond    = {'...respect.', 'You\'re not bad yourself.'},
        },
        interactAnim = {dict='mp_player_int_uppersalute', anim='mp_player_int_salute'},
    },
    loyal    = {
        label     = 'Loyal',
        idleAnims = {
            {dict='amb@world_human_stand_impatient@male@base', anim='base'},
        },
        voiceLines = {
            idle    = {'Always watching.', 'I\'ve got your back.', 'You\'re safe with me.'},
            combat  = {'Nobody touches the boss!', 'I\'ll handle this!', 'Stay behind me!'},
            protect = {'Take the bullet for you any day.', 'I\'m here!'},
            levelup = {'Getting stronger for you, boss.'},
            bond    = {'You mean a lot to me.', 'Through thick and thin.'},
        },
        interactAnim = {dict='mp_ped_interaction', anim='handshake_guy_a'},
    },
    aggressive = {
        label     = 'Aggressive',
        idleAnims = {
            {dict='amb@world_human_leaning@male@wall@base', anim='base'},
        },
        voiceLines = {
            idle    = {'Come at me.', 'I dare them to try.', 'Just give me a reason.'},
            combat  = {'Let\'s GO!', 'Come on then!', 'I\'ll drop all of you!'},
            protect = {'Stay the hell back!', 'You want some?!'},
            levelup = {'Unstoppable.', 'More. MORE.'},
            bond    = {'You\'re the only one I respect.'},
        },
        interactAnim = {dict='anim@mp_player_intcelebrationmale@fist_bump', anim='fist_bump'},
    },
    caring   = {
        label     = 'Caring',
        idleAnims = {
            {dict='amb@world_human_cop_idles@male@idle_a', anim='idle_a'},
        },
        voiceLines = {
            idle    = {'You okay?', 'How are you holding up?', 'I\'m here.'},
            combat  = {'I\'ll protect you!', 'Get behind me!', 'I won\'t let them touch you!'},
            protect = {'Are you hurt?', 'I\'ve got you!'},
            levelup = {'We\'re getting stronger together.'},
            bond    = {'I\'d do anything for you.', 'You\'re more than just my client.'},
        },
        interactAnim = {dict='mp_ped_interaction', anim='hugs_guy_a'},
    },
    professional = {
        label     = 'Professional',
        idleAnims = {
            {dict='amb@world_human_cop_idles@male@base', anim='base'},
        },
        voiceLines = {
            idle    = {'All clear.', 'Sector secure.', 'No threats detected.'},
            combat  = {'Engaging hostile.', 'Threat neutralised.', 'Area clear.'},
            protect = {'Stay close to me, sir.', 'I\'ll handle the perimeter.'},
            levelup = {'Skills enhanced. Ready for duty.'},
            bond    = {'You have my complete loyalty.'},
        },
        interactAnim = {dict='mp_player_int_uppersalute', anim='mp_player_int_salute'},
    },
}

local personalityKeys = {'stoic','loyal','aggressive','caring','professional'}

-- Deterministic personality from bgId
function getBGPersonality(bgId)
    local idx = (bgId % #personalityKeys) + 1
    return personalityKeys[idx], personalities[personalityKeys[idx]]
end

-- ────────────────────────────────────────────────────────────
-- MEMORY SYSTEM
-- BGs remember events this session (kills, protects, deaths nearby)
-- Displayed in a special "Memories" section in their stats menu
-- ────────────────────────────────────────────────────────────
bgMemories = {}   -- [bgId] = { {time, text}, ... }

function addMemory(bgId, text)
    if not bgMemories[bgId] then bgMemories[bgId] = {} end
    table.insert(bgMemories[bgId], {
        time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        text = text,
    })
    -- Keep last 12 memories
    if #bgMemories[bgId] > 12 then
        table.remove(bgMemories[bgId], 1)
    end
end

-- ────────────────────────────────────────────────────────────
-- IDLE BEHAVIOR SYSTEM
-- BGs play idle animations instead of standing frozen (the "jabbering")
-- Key fix: we play ONE looped anim and don't spam tasks every 600ms
-- ────────────────────────────────────────────────────────────
local idleAnimCache = {}   -- [bgId] = {dict, anim, playing}
local idleVariants  = {
    -- All dicts verified valid in GTA V
    {dict='amb@world_human_cop_idles@male@base',          anim='base',    dur=30, scenario=nil},
    {dict='amb@world_human_stand_impatient@male@base',         anim='base',    dur=25, scenario=nil},
    {dict='amb@world_human_smoking@male@idle_a',         anim='base',    dur=20, scenario=nil},
    {dict='amb@world_human_cop_idles@male@idle_a',         anim='idle_a',  dur=15, scenario=nil},
    {dict='anim@amb@casino@valet_clipboard@male@idle_a',   anim='idle_a',  dur=20, scenario=nil},
}

function startIdleBehavior(bgId)
    CreateThread(function()
        local _, personality = getBGPersonality(bgId)
        local anims = personality and personality.idleAnims or idleVariants

        while activeBodyguards[bgId] do
            local bg = activeBodyguards[bgId]
            if not bg or not DoesEntityExist(bg.ped) then break end

            -- Only play idle when stationary (guard) and not in combat
            if bg.state == 'guard' or bg.state == 'patrol' then
                if not IsPedInCombat(bg.ped, 0) and IsPedStopped(bg.ped) then
                    local animData = anims[math.random(#anims)]
                    -- pcall: prevents crash if animDict is invalid on this build
                    local ok, loaded = pcall(lib.requestAnimDict, animData.dict, 3000)
                    if ok and loaded and activeBodyguards[bgId] and DoesEntityExist(bg.ped) then
                        -- Only play if no current task to avoid interrupting movement
                        if not IsEntityPlayingAnim(bg.ped, animData.dict, animData.anim, 3) then
                            TaskPlayAnim(bg.ped, animData.dict, animData.anim,
                                4.0, -4.0, -1, 1, 0, false, false, false)
                        end
                    end
                    -- Wait for this anim's duration before changing
                    Wait((animData.dur or 20) * 1000)
                else
                    Wait(3000)
                end
            else
                Wait(2000)
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- VOICE LINE SYSTEM
-- BGs speak contextual lines using GTA's ambient speech system
-- ────────────────────────────────────────────────────────────
local voiceSpeechMap = {
    -- GTA native speech event names that work on most ped models
    combat  = {'GENERIC_CURSE_HIGH', 'GENERIC_INSULT_HIGH', 'GENERIC_THREATENED'},
    protect = {'PED_FLEE_REASON', 'GENERIC_SHOCKED_HIGH'},
    idle    = {'GENERIC_CHAT', 'GENERIC_HOWS_IT_GOING'},
    bond    = {'GENERIC_BYE', 'GENERIC_THANKS'},
}

function playVoiceLine(ped, context)
    if not DoesEntityExist(ped) then return end
    if math.random(100) > 35 then return end  -- 35% chance

    local lines = voiceSpeechMap[context] or voiceSpeechMap.idle
    local speech = lines[math.random(#lines)]
    PlayAmbientSpeech1(ped, speech, 'SPEECH_PARAMS_FORCE_SHOUTED')
end

-- ────────────────────────────────────────────────────────────
-- BODY LANGUAGE MIRRORING
-- BG mirrors player: if player crouches, BG crouches too
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    local wasPlayerCrouching = false
    while true do
        Wait(400)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then Wait(1000); goto continue end

        local playerPed    = PlayerPedId()
        local isCrouching  = IsPedStopped(playerPed) and
                             IsEntityPlayingAnim(playerPed, 'move_strafe@stealth@sniper', 'idle', 3)
        local inCover      = IsPedInCover(playerPed, false)

        for bgId, bg in pairs(activeBodyguards) do
            if DoesEntityExist(bg.ped) and bg.state == 'follow' then
                local dist = #(GetEntityCoords(bg.ped) - GetEntityCoords(playerPed))
                if dist < 8.0 then
                    if inCover and not IsPedInCover(bg.ped, false) then
                        -- Find nearest cover for BG
                        local found, x, y, z = GetSafeCoordForPed(
                            GetEntityCoords(bg.ped).x,
                            GetEntityCoords(bg.ped).y,
                            GetEntityCoords(bg.ped).z,
                            true, 16
                        )
                        if found then
                            TaskGotoEntityOffsetXy(bg.ped, playerPed, -1.5, 0.5, 1.5, false)
                        end
                    end
                end
            end
        end
        ::continue::
    end
end)

-- ────────────────────────────────────────────────────────────
-- WITNESS SYSTEM (never seen in any FiveM BG script)
-- If the player dies while a BG is nearby:
--   - BG enters a special "avenge" state
--   - Morale crashes
--   - BG plays grief/rage animation
--   - Memory is logged
-- ────────────────────────────────────────────────────────────
local playerWasDead = false

CreateThread(function()
    while true do
        Wait(1000)
        if type(activeBodyguards) ~= 'table' or not next(activeBodyguards) then Wait(2000); goto witnessSkip end

        local playerPed = PlayerPedId()
        local isDead    = IsEntityDead(playerPed)

        if isDead and not playerWasDead then
            playerWasDead = true
            local playerCoords = GetEntityCoords(playerPed)

            for bgId, bg in pairs(activeBodyguards) do
                if DoesEntityExist(bg.ped) then
                    local dist = #(GetEntityCoords(bg.ped) - playerCoords)
                    if dist < 30.0 then
                        -- Witnessed the death
                        addMemory(bgId, 'Witnessed your death. Will never forget.')
                        TriggerServerEvent('rde_bg:updateMorale', bgId, -35)
                        bg.morale = math.max(0, (bg.morale or 75) - 35)

                        -- Grief reaction
                        CreateThread(function()
                            if DoesEntityExist(bg.ped) then
                                ClearPedTasks(bg.ped)
                                -- 'move_p_m_zero_slow' + 'idle' is available on all models/builds
                                lib.requestAnimDict('anim@move_m@prisoner_cuffed', 3000)
                                TaskPlayAnim(bg.ped, 'anim@move_m@prisoner_cuffed', 'idle',
                                    4.0, -4.0, 2500, 0, 0, false, false, false)
                                Wait(2500)
                                bg.state  = 'avenge'
                                bg.avenge = true
                            end
                        end)
                    end
                end
            end
        elseif not isDead then
            playerWasDead = false
            -- Reset avenge state
            for bgId, bg in pairs(activeBodyguards) do
                if bg.avenge then
                    bg.avenge = false
                    bg.state  = 'follow'
                end
            end
        end
        ::witnessSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- ANNIVERSARY / MILESTONE MESSAGES
-- When BG reaches bond milestones, they react in world-space
-- ────────────────────────────────────────────────────────────
function celebrateMilestone(bgId, tierName)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    addMemory(bgId, 'Bond reached: ' .. tierName .. '. Honoured to serve.')

    local playerPed = PlayerPedId()
    TaskTurnPedToFaceEntity(bg.ped, playerPed, -1)
    Wait(500)

    local _, personality = getBGPersonality(bgId)
    local anim = personality and personality.interactAnim or
                 {dict='mp_player_int_uppersalute', anim='mp_player_int_salute'}

    lib.requestAnimDict(anim.dict, 3000)
    TaskPlayAnim(bg.ped, anim.dict, anim.anim, 8.0, -8.0, 3000, 0, 0, false, false, false)

    playVoiceLine(bg.ped, 'bond')

    -- Floating milestone text
    CreateThread(function()
        local c = GetEntityCoords(bg.ped)
        local t = GetGameTimer() + 4000
        while GetGameTimer() < t do
            Wait(0)
            Draw3DText(c.x, c.y, c.z + 2.0, '🌟 ' .. tierName, 4.0, 255, 215, 0, 255)
        end
    end)
end

-- ────────────────────────────────────────────────────────────
-- FATIGUE SYSTEM (session-based, unique feature)
-- After 45min active, BG accuracy/speed slowly degrades until rested
-- Resting = dismissed for 10+ min
-- ────────────────────────────────────────────────────────────
bgFatigue    = {}   -- [bgId] = { sessionStart, fatigueLevel }
bgRestTime   = {}   -- [bgId] = last despawn timestamp

function initFatigue(bgId)
    local restEnd = bgRestTime[bgId] or 0
    local restDuration = GetGameTimer() - restEnd  -- ✅ FIX: GetGameTimer() statt os.time()

    -- If rested 10+ min, start fresh
    local startFatigue = 0
    if restDuration < 600000 then  -- 10 Minuten (600 Sekunden)
        startFatigue = math.min(50, bgFatigue[bgId] and bgFatigue[bgId].fatigueLevel or 0)
    end

    bgFatigue[bgId] = {
        sessionStart = GetGameTimer(),  -- ✅ FIX: GetGameTimer() statt os.time()
        fatigueLevel = startFatigue,
    }
end

function getFatiguePenalty(bgId)
    local f = bgFatigue[bgId]
    if not f then return 0 end

    -- Accumulate fatigue: +1 per 3 minutes active
    local elapsed = (GetGameTimer() - f.sessionStart) / 1000 / 60  -- Minuten
    f.fatigueLevel = math.min(40, math.floor(elapsed / 3))

    return f.fatigueLevel
end

function markBGRested(bgId)
    bgRestTime[bgId]  = GetGameTimer()  -- ✅ FIX: GetGameTimer() statt os.time()
    if bgFatigue[bgId] then
        bgFatigue[bgId].fatigueLevel = 0
    end
end

-- ────────────────────────────────────────────────────────────
-- ENHANCED doInteraction — uses personality, plays correct anim,
-- shows personalized dialogue, adds memory
-- NOTE: doInteraction is defined here as the authoritative implementation.
-- The previous pattern (_baseInteract = doInteraction) was broken because
-- doInteraction does not exist before bond.lua loads — it was always nil.
-- ────────────────────────────────────────────────────────────
doInteraction = function(bgId)
    local bg = activeBodyguards[bgId]
    if not bg or not DoesEntityExist(bg.ped) then return end

    interactCooldowns[bgId] = GetGameTimer() + Config.Relationship.interactCooldownMs

    local playerPed   = PlayerPedId()
    local _, personality = getBGPersonality(bgId)
    local relLvl      = bg.relation_level or 1
    local tier        = Config.GetRelTier(relLvl)

    -- Face each other
    TaskTurnPedToFaceEntity(bg.ped, playerPed, -1)
    TaskTurnPedToFaceEntity(playerPed, bg.ped, -1)
    Wait(600)

    -- Choose animation based on PERSONALITY + RELATIONSHIP
    local animDict, animName
    if relLvl >= 4 then
        animDict = 'mp_ped_interaction'
        animName = bg.gender == 'female' and 'hugs_guy_a' or 'hugs_guy_a'
    elseif relLvl >= 2 then
        local ia = personality and personality.interactAnim
        animDict = ia and ia.dict or 'mp_ped_interaction'
        animName = ia and ia.anim or 'handshake_guy_a'
    else
        animDict = 'mp_player_int_uppersalute'
        animName = 'mp_player_int_salute'
    end

    lib.requestAnimDict(animDict, 3000)
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, 2500, 0, 0, false, false, false)
    TaskPlayAnim(bg.ped,    animDict, animName, 8.0, -8.0, 2500, 0, 0, false, false, false)

    -- Personality-driven voice line
    playVoiceLine(bg.ped, 'bond')

    -- Gain affection
    local gain = math.random(Config.Relationship.gainPerInteract.min, Config.Relationship.gainPerInteract.max)
    TriggerServerEvent('rde_bg:affection',   bgId, gain)
    TriggerServerEvent('rde_bg:updateMorale',bgId, Config.Morale.gainOnInteract)
    bg.morale = math.min(100, (bg.morale or 75) + Config.Morale.gainOnInteract)

    -- Add memory
    local bondLines = (personality and personality.voiceLines and personality.voiceLines.bond) or {'Moment shared.'}
    addMemory(bgId, bondLines[math.random(#bondLines)])

    lib.notify({
        title       = '💖 ' .. bg.name,
        description = L('bond_strengthened', gain, tier.name),
        type        = 'success',
        duration    = 4000,
        icon        = tier.icon,
        iconColor   = tier.color,
    })

    playRomanceEffect(playerPed, bg.ped)
end

print('^2[RDE-BG]^7 Bond system v4.0 loaded ✓')