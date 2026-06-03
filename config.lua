Config = {}

-- How long the player must hold the key to loot (ms)
Config.LootHoldTime = 500

-- Radius (metres) around the player to scan for a lootable body
Config.LootRadius = 2.0

-- Seconds before the same body can be looted again by anyone (server-side cooldown)
Config.BodyCooldown = 60

-- Per-player loot event rate-limit: max fires allowed within the window
Config.RateLimitMax    = 3
Config.RateLimitWindow = 10  -- seconds

-- Lawman alert toggle
Config.TriggerLawman = true

-- ─────────────────────────────────────────────────────────────────────────────
-- Loot tables
-- Each entry:  { item = "itemName", weight = <relative weight> }
-- Higher weight = appears more often relative to others in the same tier.
-- Items MUST exist in your shared RSGCore items list.
-- ─────────────────────────────────────────────────────────────────────────────

Config.CommonItems = {
    { item = "bread",           weight = 20 },
    { item = "water",           weight = 20 },
    { item = "bandage",         weight = 15 },
    { item = "herbal_remedy",   weight = 12 },
    { item = "tobacco",         weight = 10 },
    { item = "matches",         weight = 10 },
    { item = "chewing_tobacco", weight = 8  },
    { item = "jerky",           weight = 5  },
}

Config.RareItems = {
    { item = "goldnugget",      weight = 25 },
    { item = "valuablejewelry", weight = 20 },
    { item = "gemstone",        weight = 15 },
    { item = "silver_earring",  weight = 15 },
    { item = "pocket_watch",    weight = 15 },
    { item = "family_heirloom", weight = 10 },
}

-- Cash reward ranges  { min, max }
Config.CommonCash = { min = 1,  max = 5  }
Config.RareCash   = { min = 10, max = 25 }

-- Chance (0–100) of getting a rare roll instead of common
Config.RareChance = 5
