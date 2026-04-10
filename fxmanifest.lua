fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'RDE | Ultimate Bodyguard System'
author      'RDE | SerpentsByte [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽]'
version     '2.0.0'
description 'Next-Gen AI Bodyguard System — FULL ox_target COMMANDS · SELF-HEAL · BUDDY HEAL · WEAPON SELECT · HOLSTER · ATTACK ORDERS · ADRENALINE · TACTICAL COVER · LAST STAND · NETWORKED ENTITIES · ox_inventory · StateBag Sync · Production Ready'

dependencies {
    '/server:7290',
    'oxmysql',
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'locales/en.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sync.lua',
    'server/main.lua',
    'server/events.lua',
}

client_scripts {
    'client/effects.lua',
    'client/spawn.lua',
    'client/bond.lua',
    'client/sync.lua',
    'client/performance.lua',
    'client/main.lua',
    'client/ai.lua',
    'client/menu.lua',
    'client/hud.lua',
}

files {
    'html/hud.html',
}

ui_page 'html/hud.html'
