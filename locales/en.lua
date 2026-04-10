-- RDE | Bodyguard System — locales/en.lua
-- Per RDE Standards: centralized locale table, injected as global

Locale = {
    -- General
    success             = 'Success',
    error               = 'Error',
    warning             = 'Warning',

    -- Recruit
    recruited           = '%s recruited for $%s',
    recruit_fail_funds  = 'Insufficient funds. Required: $%s',
    recruit_fail_max    = 'You already own the maximum number of bodyguards (%s).',
    recruit_fail_db     = 'Database error during recruitment.',

    -- Deploy
    deployed            = '%s deployed.',
    deploy_fail_dead    = 'Revive this bodyguard first.',
    deploy_fail_max     = 'Maximum active bodyguards reached (%s).',

    -- Dismiss
    dismissed_all       = 'All bodyguards dismissed.',

    -- Orders
    order_follow        = '%s — Follow',
    order_guard         = '%s — Hold Position',
    order_patrol        = '%s — Patrol',

    -- Bond
    bond_deepened       = '%s — %s',
    bond_strengthened   = '+%s affection (%s)',

    -- Revive
    revived             = '%s is back — still wounded.',
    revive_fail_cost    = 'Need $%s to revive.',

    -- Death
    death_permanent     = '%s is gone forever.',
    death_revive        = '%s is down! Pay $%s to revive.',

    -- XP / Level
    level_up            = '%s is now Level %s!',

    -- Prestige
    prestige_done       = '%s reset to Level 1 — skills boosted!',
    prestige_fail_level = 'Bodyguard must be max level (%s).',
    prestige_fail_max   = 'Already at max prestige.',

    -- Skills
    skill_trained       = '%s → %s (+%s)',
    skill_maxed         = 'Already maxed!',
    skill_fail_funds    = 'Need $%s to train.',

    -- Daily
    daily_claimed       = 'All active bodyguards received %s total XP!',
    daily_too_early     = 'Come back in %sh for your daily reward.',
    daily_no_active     = 'Deploy at least one bodyguard first.',

    -- Wounds
    wound_critical_notif = '%s is critically wounded!',
    wound_self_healed    = '%s used %s — HP restored.',
    wound_buddy_healed   = '%s treated %s\'s wounds.',

    -- Adrenaline
    adrenaline_active    = '%s entered adrenaline rush!',
    last_stand_active    = '%s — LAST STAND! Fighting with everything!',

    -- Achievements
    achievement_unlocked = '%s — $%s reward!',

    -- Kill
    kill_confirmed      = '%s eliminated a threat.',

    -- Trade
    trade_offer         = '%s offered for $%s. Use /bg_accept %s to accept.',
    trade_complete_sell = 'Bodyguard sold for $%s.',
    trade_complete_buy  = 'Bodyguard is now yours!',

    -- UI labels
    menu_title          = 'Bodyguard Command Center',
    menu_recruit        = 'Recruit',
    menu_roster         = 'Roster',
    menu_leaderboard    = 'Leaderboard',
    menu_daily          = 'Daily Reward',
    menu_formation      = 'Formation',
    menu_deploy         = 'Deploy',
    menu_despawn        = 'Despawn',
    menu_stats          = 'View Stats',
    menu_train          = 'Train Skills',
    menu_prestige       = 'PRESTIGE',
    menu_gear           = 'Manage Gear',
    menu_revive         = 'Revive',
    menu_back           = '← Back',
    menu_dismiss        = 'Dismiss',
}

-- Helper: format locale string with args
function L(key, ...)
    local str = Locale[key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end
