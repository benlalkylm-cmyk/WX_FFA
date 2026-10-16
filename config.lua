
Config = {}

Config.Leaderboard = {
    limit      = 25,
    minKills   = 1,
    autoRefresh = 60,
}

-- Keybind to hold for opening the transparent Kills & Deaths Scoreboard UI while in match (default: TAB)
Config.ScoreboardKey = 'TAB'
-- If set to false, HUD only appears when holding ScoreboardKey. If true, HUD is permanently visible.
Config.AlwaysShowHud = false

Config.Season = {
    current = 1,
    label   = 'Season 1',
}

-- Configurable cash reward per kill
Config.KillReward = {
    enabled = true,   -- Enable/disable cash reward per kill
    amount  = 500,    -- Configurable cash amount per kill
    account = 'cash', -- Account type ('cash' or 'bank')
    notify  = true,   -- Show notification when cash reward is received
}

-- Money taken from a player each time they die in FFA (counted once per life, on the server)
Config.DeathPenalty = {
    enabled = true,   -- Enable/disable losing money on death
    amount  = 250,    -- Amount removed per death
    account = 'cash', -- Account type ('cash' or 'bank')
    notify  = true,   -- Show notification when money is removed
}

-- Respawn inside an arena (handled by FFA itself, no revive script needed)
Config.Respawn = {
    delay = 3, -- seconds dead before respawning, with an on-screen countdown
    -- Client event fired just before respawning. Tiger EMS answers it during a match (clears limp/blood
    -- effects). Harmless if nothing listens to it. Set to false to disable.
    cleanupEvent = 'rxRevive:revivePlayerClient',
}

-- Server-side checks a kill must pass before it counts and pays the reward.
Config.KillValidation = {
    deathCooldownMs = 1500,  -- a player can only die once in this window (respawn takes ~2s)
    extraDistance   = 50.0,  -- killer may be at most (arena size * 2 + this) metres from the victim
}

-- RR gained per kill. Deaths do not affect rating.
Config.Rating = {
    perKill = 1,
}

-- Kill/death ratio: kills divided by deaths, rounded to 2 decimals.
-- With no deaths yet, K/D equals the number of kills (e.g. 5 kills, 0 deaths = 5.00).
function Config.GetKd(kills, deaths)
    kills = math.max(0, tonumber(kills) or 0)
    deaths = math.max(0, tonumber(deaths) or 0)
    local ratio = deaths > 0 and (kills / deaths) or kills
    return math.floor(ratio * 100 + 0.5) / 100
end

-- Rank tiers, ordered low -> high. `min` is the RR (= kills * perKill) needed to reach it.
-- Tune these numbers freely to make ranks faster or slower.
Config.Ranks = {
    { name = 'Recruit',    icon = 'R',  color = '#8ea0cc', min = 0 },
    { name = 'Bronze I',   icon = 'B1', color = '#cd7f32', min = 500 },
    { name = 'Bronze II',  icon = 'B2', color = '#cd7f32', min = 1000 },
    { name = 'Bronze III', icon = 'B3', color = '#cd7f32', min = 1500 },
    { name = 'Silver I',   icon = 'S1', color = '#c0d0e8', min = 2200 },
    { name = 'Silver II',  icon = 'S2', color = '#c0d0e8', min = 2900 },
    { name = 'Silver III', icon = 'S3', color = '#c0d0e8', min = 3600 },
    { name = 'Gold I',     icon = 'G1', color = '#ffcf5c', min = 4500 },
    { name = 'Gold II',    icon = 'G2', color = '#ffcf5c', min = 5400 },
    { name = 'Gold III',   icon = 'G3', color = '#ffcf5c', min = 6300 },
    { name = 'Platinum',   icon = 'PL', color = '#37e0ff', min = 7500 },
    { name = 'Diamond',    icon = 'DI', color = '#5cc8ff', min = 9000 },
    { name = 'Master',     icon = 'MA', color = '#8a5cff', min = 11000 },
    { name = 'Champion',   icon = 'CH', color = '#ff5c7a', min = 14000 },
    { name = 'WarX Elite', icon = 'WX', color = '#37e0a0', min = 18000 },
}

function Config.GetRating(kills, deaths)
    return math.max(0, math.floor((tonumber(kills) or 0) * (Config.Rating.perKill or 1)))
end

function Config.GetRankProgress(rating)
    rating = tonumber(rating) or 0
    local current, nextRank = Config.Ranks[1], nil

    for i = 1, #Config.Ranks do
        if rating >= Config.Ranks[i].min then
            current = Config.Ranks[i]
            nextRank = Config.Ranks[i + 1]
        else
            break
        end
    end

    local progress = 100
    if nextRank then
        local span = nextRank.min - current.min
        progress = span > 0 and math.floor(((rating - current.min) / span) * 100 + 0.5) or 0
        progress = math.max(0, math.min(100, progress))
    end

    return {
        name = current.name,
        icon = current.icon,
        color = current.color,
        rating = rating,
        progress = progress,
        nextName = nextRank and nextRank.name or nil,
        nextAt = nextRank and nextRank.min or nil,
    }
end

Config.FFA = vector3(220.40, -932.24, 30.13)
-- Players must be within this many metres of Config.FFA (the Deathmatch NPC) to join an arena.
Config.JoinDistance = 15.0
Config.FFAPed = {
    model = "s_m_y_swat_01",
    heading = 340.0,
}

Config.Zones = {
    ["La Fuente Blance"] = {
        maxPlayers = 25,
        markermiddle = vector3(1431.7786, 1116.8463, 114.2386),
        markersize = 100.0,
        image = "https://i.ibb.co/pj2FMpw6/image.png",
        dimension = 1,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(1373.0570, 1176.4424, 113.7555),
            vector3(1422.6158, 1172.8842, 114.3296),
            vector3(1366.8857, 1147.0676, 113.7582),
            vector3(1416.6302, 1203.3854, 112.8900),
            vector3(1463.4930, 1179.2893, 114.2196),
            vector3(1496.5150, 1147.3048, 114.1581),
            vector3(1503.8906, 1106.0175, 114.2473),
            vector3(1478.5874, 1099.0420, 114.3345),
            vector3(1424.5273, 1062.6290, 114.3252),
            vector3(1341.3896, 1145.2383, 112.9754),
            vector3(1390.3596, 1152.5831, 114.3269),
            vector3(1411.7557, 1141.5918, 114.3351),
            vector3(1451.9457, 1147.0884, 114.2921),
            vector3(1463.3219, 1129.4637, 114.3327),
        }
    },
    ["RED GARAGE"] = {
        maxPlayers = 25,
        markermiddle = vector3(-315.6684, -754.9106, 53.2414),
        markersize = 90.0,
        image = "https://i.ibb.co/ytcx01m/redgarage.png",
        dimension = 2,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(-310.1740, -737.2032, 53.2467), 
            vector3(-342.5219, -813.5298, 50.7392),
            vector3(-285.3699, -776.2827, 48.4333),
            vector3(-357.0859, -726.0471, 48.4242),
            vector3(-333.9429, -716.8351, 52.6707),
            vector3(-321.9351, -774.6743, 53.2449),
            vector3(-277.7025, -775.4517, 53.2465),
        }
    },
    ["Alamosee Dorf"] = {
        maxPlayers = 25,
        markermiddle = vector3(1351.6528, 4353.1377, 43.7265),
        markersize = 75.0,
        image = "https://i.ibb.co/0yncY4SY/Alamosee-Dorf.png",
        dimension = 3,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(1333.4318, 4378.0381, 44.0765),
            vector3(1342.6733, 4307.2813, 38.9192),
            vector3(1372.7843, 4325.2197, 40.1338),
            vector3(1335.6176, 4340.8330, 38.6044),
            vector3(1310.4430, 4318.4912, 38.0205),
            vector3(1362.8141, 4380.6016, 44.3383),

        }
    },
    ["SANDY"] = {
        maxPlayers = 25,
        markermiddle = vector3(2712.8621, 4034.3528, 56.2959),
        markersize = 175.0,
        image = "https://i.ibb.co/7NKy8n9w/sandy.png",
        dimension = 4,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(2690.5923, 4027.5847, 53.0014),
            vector3(2706.5662, 4067.3923, 50.9993),
            vector3(2574.9312, 3930.5530, 62.7659),
            vector3(2736.5020, 4046.1890, 60.8590),
            vector3(2796.8069, 4047.2405, 56.8995),
            vector3(2733.7285, 3973.4744, 53.3062),
            vector3(2741.1404, 3958.9421, 50.2598),
            vector3(2643.3333, 3940.8235, 48.6278),
            vector3(2749.0671, 4042.3135, 60.0832),
            vector3(2706.9871, 4133.6714, 43.9121),
            vector3(2744.7358, 4005.8479, 54.5304),
            vector3(2748.6975, 4004.1484, 52.8798),
            vector3(2736.3569, 4091.2979, 51.6288),


        }
    },
    ["Burito Camp"] = {
        maxPlayers = 25,
        markermiddle = vector3(2343.5923, 2557.9976, 46.6604),
        markersize = 90.0,
        image = "https://i.ibb.co/chGDWqJF/burito-camp.png",
        dimension = 5,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(2334.6289, 2499.0315, 47.9936),
            vector3(2307.6841, 2520.6001, 46.6636),
            vector3(2325.4397, 2562.5188, 46.6676),
            vector3(2345.2878, 2553.4661, 46.6666),
            vector3(2337.2546, 2508.8845, 46.6645),
            vector3(2362.0278, 2530.9143, 46.6948),
            vector3(2349.5630, 2596.0208, 46.6785),
            vector3(2334.9663, 2585.8560, 46.5508),
            vector3(2377.2222, 2574.2976, 46.7904),
        }
    },
    ["G FACTORY"] = {
        maxPlayers = 25,
        markermiddle = vector3(2908.5269, 4441.0972, 48.1764),
        markersize = 150.0,
        image = "https://i.ibb.co/0RpzffJK/g-factory.png",
        dimension = 6,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(2946.3735, 4431.5430, 49.2496),
            vector3(3000.4680, 4401.7080, 69.9720),
            vector3(2891.1692, 4401.3496, 50.2554),
            vector3(2871.9299, 4464.7251, 48.4052),
            vector3(2912.0828, 4504.6680, 48.2773),
            vector3(2882.7693, 4458.1055, 48.5748),
            vector3(2856.4875, 4467.3911, 48.4849),
            vector3(2879.7068, 4514.1460, 47.6317),
            vector3(2844.6296, 4507.8696, 48.6428),
            vector3(2975.6541, 4413.9531, 57.9465),
            vector3(3011.4197, 4421.9141, 62.2529),
            vector3(2867.8379, 4364.9639, 49.2453),
            vector3(2908.8132, 4347.1782, 50.2990),
            vector3(2879.2310, 4386.9639, 50.4096),
            vector3(2879.2310, 4386.9639, 50.4096),


        }
    },
    ["Rednecks"] = {
        maxPlayers = 25,
        markermiddle = vector3(2431.6218, 4985.3608, 45.7601),
        markersize = 90.0,
        image = "https://i.ibb.co/Qj3vfLGb/rednecks.png",
        dimension = 7,
        customMode = {
            enabled = true,
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(2506.0789, 4973.1553, 44.5159),
            vector3(2491.8110, 4946.7954, 44.2973),
            vector3(2460.4438, 4915.0566, 46.9848),
            vector3(2428.7837, 4910.0776, 41.6881),
            vector3(2397.7100, 4921.1489, 42.7758),
            vector3(2378.6682, 4944.2217, 42.9979),
            vector3(2395.3914, 4952.4790, 43.4007),
            vector3(2413.9358, 4990.5620, 46.2025),
            vector3(2422.4661, 5017.8462, 46.7491),
            vector3(2402.8472, 5028.4678, 45.9931),
            vector3(2375.2849, 5030.7861, 45.8512),
            vector3(2449.0830, 5024.2705, 46.2411),
            vector3(2465.4106, 4998.4795, 46.4162),
            vector3(2495.0327, 5031.2324, 47.2217),
            vector3(2448.8074, 4960.3394, 45.4054),

        }
    },
    ["Clock Tower"] = {
        maxPlayers = 25,
        markermiddle = vector3(-3240.96, 4912.73, 103.45),
        markersize = 150.0,
        image = "https://i.ibb.co/5XPY4xZP/sandy-motel.png",
        dimension = 9,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(-3236.81, 4937.87, 101.22),
            vector3(-3216.09, 5000.70, 98.13),
            vector3(-3287.77, 4961.00, 97.53),
            vector3(-3231.52, 4956.22, 106.96),
            vector3(-3188.51, 4938.71, 98.06),
            vector3(-3183.01, 4910.34, 103.49),
            vector3(-3193.51, 4852.67, 98.70),
            vector3(-3260.63, 4860.83, 102.45),
            vector3(-3287.29, 4867.60, 100.82),
            vector3(-3258.09, 4833.07, 99.70),
            vector3(-3220.64, 4892.38, 97.55),
            vector3(-3277.97, 4897.40, 104.85),
        }
        
    },
    ["Factory New"] = {
        maxPlayers = 25,
        markermiddle = vector3(-3236.27, 4662.75, 75.15),
        markersize = 150.0,
        image = "https://i.ibb.co/5XPY4xZP/sandy-motel.png",
        dimension = 10,
        customMode = {
            enabled = true,
            label = "Carbine",
            weapons = {
                "WEAPON_CARBINERIFLE",
            }
        },
        spawns = {
            vector3(-3236.27, 4662.75, 75.15),
            vector3(-3281.67, 4686.75, 72.23),
            vector3(-3264.39, 4722.82, 71.48),
            vector3(-3237.98, 4712.58, 76.11),
            vector3(-3209.08, 4691.49, 74.07),
            vector3(-3183.77, 4677.96, 73.14),
            vector3(-3162.67, 4640.31, 72.39),
            vector3(-3174.77, 4610.41, 71.75),
            vector3(-3211.32, 4593.79, 71.54),
            vector3(-3280.91, 4613.40, 72.08),
            vector3(-3267.64, 4615.83, 71.56),
            vector3(-3316.21, 4661.41, 71.61),
        }
        
    },
}