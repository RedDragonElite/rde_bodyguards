-- ============================================================
-- RDE | ULTIMATE BODYGUARD SYSTEM v4.1.1  —  client/hud.lua
-- FIX v4.1.1: CreateDui/SendDuiMessage ersetzt durch SendNUIMessage.
--   CreateDui erstellt nur eine unsichtbare Off-Screen-Textur — nie
--   auf dem Bildschirm gezeichnet. ui_page in fxmanifest registriert
--   hud.html als NUI-Overlay → SendNUIMessage ist der korrekte Weg.
--   ResizeObserver-Spam wird bereits in hud.html (window.onerror)
--   unterdrückt, sodass kein DUI-Workaround nötig ist.
-- ============================================================

local hudReady   = false
local lastHash   = ''   -- nur pushen wenn Daten wirklich geändert

-- ────────────────────────────────────────────────────────────
-- FIX #1: activeBodyguards-Guard
-- activeBodyguards wird in client/main.lua deklariert und ist beim
-- ersten Tick von hud.lua noch nil (Ladereihenfolge client_scripts).
-- ────────────────────────────────────────────────────────────
local function safeBGs()
    -- Prüft ob activeBodyguards als globale Table existiert.
    -- Falls nicht (z.B. während des Ladens), sicher leere Table zurückgeben.
    if type(activeBodyguards) ~= 'table' then return {} end
    return activeBodyguards
end

-- ────────────────────────────────────────────────────────────
-- Payload für HUD erstellen
-- ────────────────────────────────────────────────────────────
local function buildPayload()
    local bgs = {}
    for bgId, bg in pairs(safeBGs()) do
        -- CRITICAL FIX: Nur eigene Bodyguards anzeigen!
        -- Networked = true bedeutet es ist der BG eines anderen Spielers
        if not bg.networked and DoesEntityExist(bg.ped) then
            local hp     = GetEntityHealth(bg.ped)
            local maxHp  = math.max(bg.maxHealth or 200, 1)
            local pct    = math.max(0.0, math.min(1.0, hp / maxHp))

            -- FIX #2: GetRarity/GetMoraleTier/GetRelTier können nil
            -- zurückgeben wenn Config noch nicht vollständig geladen ist.
            local rData   = Config.GetRarity(bg.rarity)
            local mTier   = Config.GetMoraleTier(bg.morale or 75)
            local relTier = Config.GetRelTier(bg.relation_level or 1)
            local woundKey = bg.wound or 'none'
            local wInfo    = (Config.Wounds.types[woundKey]) or Config.Wounds.types['none']
            local wColor   = woundKey == 'critical' and '#ef4444'
                          or woundKey == 'serious'  and '#f97316'
                          or woundKey == 'minor'    and '#fbbf24'
                          or '#10b981'

            table.insert(bgs, {
                id         = bgId,
                name       = bg.name,
                level      = bg.level,
                prestige   = bg.prestige or 0,
                hpPct      = pct,
                morale     = bg.morale or 75,
                moraleLabel= mTier.label,
                moraleColor= mTier.color,
                wound      = woundKey,
                woundLabel = wInfo.label,
                woundColor = wColor,
                state      = bg.state or 'follow',
                rarityColor= rData.color,
                rarityLabel= rData.label,
                relTier    = relTier.name,
                relColor   = relTier.color,
                gender     = bg.gender or 'male',
                -- v5.0: Extra status flags
                adrenaline = type(adrenalineState) == 'table' and adrenalineState[bgId] and adrenalineState[bgId].active or false,
                lastStand  = type(lastStandState) == 'table' and lastStandState[bgId] and lastStandState[bgId].active or false,
            })
        end
    end
    table.sort(bgs, function(a, b) return a.id < b.id end)
    return { type = 'rde_hud_update', visible = #bgs > 0, bgs = bgs }
end

-- ────────────────────────────────────────────────────────────
-- HUD-Tick  (SendNUIMessage → hud.html window.addEventListener)
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    -- FIX #3: Warten bis NUI-Kontext bereit ist.
    -- ox_lib und andere Resources initialisieren NUI in den ersten Sekunden.
    -- 2s reichen aus und sind weniger als der alte 3s-DUI-Wait.
    Wait(2000)
    hudReady = true

    while true do
        Wait(Config.HUD and Config.HUD.updateRateMs or 500)

        if not hudReady or not (Config.HUD and Config.HUD.enabled) then
            Wait(2000)
            goto hudSkip
        end

        local payload = buildPayload()
        -- json.encode für Vergleich (lastHash) — SendNUIMessage nimmt direkt die Table
        local encoded = json.encode(payload)

        -- Nur pushen wenn sich Daten geändert haben
        if encoded ~= lastHash then
            lastHash = encoded
            -- FIX HAUPT-BUG: SendNUIMessage statt SendDuiMessage/CreateDui.
            -- SendNUIMessage sendet an den ui_page-Overlay (hud.html als NUI).
            -- hud.html empfängt dies über window.addEventListener('message', ...).
            SendNUIMessage(payload)
        end

        ::hudSkip::
    end
end)

-- ────────────────────────────────────────────────────────────
-- NUI-Callback  (Klick auf BG-Karte → öffnet BG-Menü)
-- FIX #4: Callback ist korrekt mit dem ui_page-NUI registriert.
-- Funktioniert nur wenn hud.html als NUI-Overlay läuft (nicht als DUI).
-- ────────────────────────────────────────────────────────────
RegisterNUICallback('bgCardClick', function(data, cb)
    local bgId = tonumber(data and data.bgId)
    if bgId then
        lib.callback('rde_bg:getAll', false, function(bgs)
            for _, bg in ipairs(bgs or {}) do
                if bg.id == bgId then
                    -- openBGMenu ist global in client/menu.lua definiert
                    openBGMenu(bg)
                    break
                end
            end
        end)
    end
    cb({ ok = true })
end)

-- HUD verstecken wenn Resource gestoppt wird
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SendNUIMessage({ type = 'rde_hud_update', visible = false, bgs = {} })
    end
end)

print('^2[RDE-BG]^7 HUD v5.1 loaded ✓')