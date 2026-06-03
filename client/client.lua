local RSGCore = exports['rsg-core']:GetCoreObject()

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────

-- bodyCooldowns[entityNetId] = game-time (seconds) when the cooldown expires
local bodyCooldowns = {}

-- rateLimiter[source] = { count = n, windowStart = os.time() }
local rateLimiter = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function log(msg)
    print(('[^5LmZa_Looting^7] %s'):format(msg))
end

-- Weighted random pick from a table of { item, weight } entries
local function weightedRandom(tbl)
    local total = 0
    for _, entry in ipairs(tbl) do
        total = total + entry.weight
    end
    local roll = math.random(1, total)
    local cumulative = 0
    for _, entry in ipairs(tbl) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end
    return tbl[#tbl].item -- fallback
end

-- Returns true if this source has exceeded the rate limit
local function isRateLimited(src)
    local now = os.time()
    local record = rateLimiter[src]
    if not record or (now - record.windowStart) >= Config.RateLimitWindow then
        rateLimiter[src] = { count = 1, windowStart = now }
        return false
    end
    record.count = record.count + 1
    if record.count > Config.RateLimitMax then
        log(('RATE LIMIT hit by source %d (^1possible exploit^7)'):format(src))
        return true
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Loot reward callback (called by client only after the native confirms looted)
-- ─────────────────────────────────────────────────────────────────────────────

RSGCore.Functions.CreateCallback('LmZa_Looting:server:requestLoot', function(source, cb, entityNetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    -- 1. Player must exist
    if not Player then
        log(('Unknown player src=%d tried to loot'):format(src))
        cb(false, 'invalid_player')
        return
    end

    -- 2. Rate limit
    if isRateLimited(src) then
        cb(false, 'rate_limited')
        return
    end

    -- 3. Body cooldown – keyed on the network entity ID supplied by the client
    if entityNetId then
        local now = os.time()
        local expiry = bodyCooldowns[entityNetId]
        if expiry and now < expiry then
            cb(false, 'already_looted')
            return
        end
        -- Stamp the cooldown immediately so concurrent requests from other players are also blocked
        bodyCooldowns[entityNetId] = now + Config.BodyCooldown
    end

    -- 4. Build reward
    local isRare  = math.random(1, 100) <= Config.RareChance
    local pool    = isRare and Config.RareItems or Config.CommonItems
    local cashCfg = isRare and Config.RareCash   or Config.CommonCash
    local item    = weightedRandom(pool)
    local cash    = math.random(cashCfg.min, cashCfg.max)

    -- 5. Grant reward
    Player.Functions.AddItem(item, 1)
    Player.Functions.AddMoney('cash', cash, 'looting-reward')

    -- 6. Notify inventory UI
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add')

    -- 7. Log
    local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local tier = isRare and 'RARE' or 'common'
    TriggerEvent('rsg-log:server:CreateLog', 'loot', 'looted 🌟', 'orange',
        ('%s found %s (%s) + $%d'):format(name, item, tier, cash))

    log(('%s looted %s (%s) +$%d'):format(name, item, tier, cash))

    cb(true, item, cash, isRare)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Cleanup stale cooldown entries periodically (every 5 min)
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for netId, expiry in pairs(bodyCooldowns) do
            if now >= expiry then
                bodyCooldowns[netId] = nil
            end
        end
        for src, record in pairs(rateLimiter) do
            if (now - record.windowStart) >= Config.RateLimitWindow * 2 then
                rateLimiter[src] = nil
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Cleanup player rate-limit entry on disconnect
-- ─────────────────────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    rateLimiter[source] = nil
end)
