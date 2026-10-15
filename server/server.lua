local FFA = {}
local ZonePlayers = {}
local SessionStats = {}
local LeaderboardCache = { data = {}, built = 0 }
local LastDeath = {}
local DeadState = {}  -- true from a counted death until the server sees the player alive again
local LastHit = {}    -- last weapon hit each FFA player took: { attacker, time, willKill }

-- Ensure tables + leaderboard columns exist on start (MySQL + MariaDB safe).
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ffa` (
            `identifier` char(50) NOT NULL,
            `kills` int(11) DEFAULT 0,
            `deaths` int(11) DEFAULT 0,
            `name` varchar(100) DEFAULT NULL,
            `discord` varchar(50) DEFAULT NULL,
            `lastplayed` int(11) DEFAULT 0,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `data_ffa` (
            `identifier` char(50) NOT NULL,
            `zoneID` varchar(100) NOT NULL,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
    ]])

    local existing = MySQL.query.await([[
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ffa'
    ]]) or {}

    local have = {}
    for _, col in ipairs(existing) do
        have[(col.COLUMN_NAME or col.column_name or ''):lower()] = true
    end

    if not have.name then
        MySQL.query.await("ALTER TABLE `ffa` ADD COLUMN `name` varchar(100) DEFAULT NULL")
    end
    if not have.discord then
        MySQL.query.await("ALTER TABLE `ffa` ADD COLUMN `discord` varchar(50) DEFAULT NULL")
    end
    if not have.lastplayed then
        MySQL.query.await("ALTER TABLE `ffa` ADD COLUMN `lastplayed` int(11) DEFAULT 0")
    end

    print('[wx_ffa] Database schema verified.')
end)

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getIdentifier(source)
    local player = getPlayer(source)
    return player and player.PlayerData and player.PlayerData.citizenid
end

local function getPlayerName(source)
    local player = getPlayer(source)
    local charinfo = player and player.PlayerData and player.PlayerData.charinfo

    if charinfo then
        local firstName = charinfo.firstname or charinfo.firstName
        local lastName = charinfo.lastname or charinfo.lastName

        if firstName and lastName then
            return ('%s %s'):format(firstName, lastName)
        end
    end

    return GetPlayerName(source) or ('ID %s'):format(source)
end

local function getFfaEntry(playerSource)
    for _, data in pairs(FFA) do
        if data.source == playerSource then
            return data
        end
    end
end

local function getZoneCount(zone)
    for _, zoneData in pairs(ZonePlayers) do
        if zoneData.zone == zone then
            return zoneData.players
        end
    end
    return 0
end

local function addZonePlayer(zone)
    for _, zoneData in pairs(ZonePlayers) do
        if zoneData.zone == zone then
            zoneData.players = zoneData.players + 1
            return
        end
    end
end

local function removeZonePlayer(zone)
    for _, zoneData in pairs(ZonePlayers) do
        if zoneData.zone == zone then
            zoneData.players = math.max(zoneData.players - 1, 0)
            return
        end
    end
end

local function keepNeedsFull(source)
    if not getPlayer(source) then return end

    exports.qbx_core:SetMetadata(source, 'hunger', 100)
    exports.qbx_core:SetMetadata(source, 'thirst', 100)
end

for zone in pairs(Config.Zones) do
    table.insert(ZonePlayers, { zone = zone, players = 0 })
end

CreateThread(function()
    while true do
        Wait(30000)

        for _, data in pairs(FFA) do
            keepNeedsFull(data.source)
        end
    end
end)

lib.callback.register('mind_ffa:getZoneData', function()
    return ZonePlayers
end)

lib.callback.register('mind_ffa:getZonePlayers', function(source, zoneName)
    local players = {}
    for _, data in pairs(FFA) do
        if not zoneName or data.zoneID == zoneName then
            local pSource = data.source
            local session = SessionStats[pSource]
            local kills = session and session.kills or 0
            local deaths = session and session.deaths or 0

            if not session then
                local result = MySQL.single.await('SELECT kills, deaths FROM ffa WHERE identifier = ?', { data.identifier })
                if result then
                    kills = tonumber(result.kills) or 0
                    deaths = tonumber(result.deaths) or 0
                end
            end

            local rankInfo = Config.GetRankProgress(Config.GetRating(kills, deaths))
            table.insert(players, {
                id = pSource,
                name = getPlayerName(pSource),
                kills = kills,
                deaths = deaths,
                kd = Config.GetKd(kills, deaths),
                rankName = rankInfo.name,
                rankColor = rankInfo.color,
                isSelf = (pSource == source)
            })
        end
    end

    table.sort(players, function(a, b)
        if a.kills == b.kills then
            return a.deaths < b.deaths
        end
        return a.kills > b.kills
    end)

    return players
end)

lib.callback.register('mind_ffa:checkPlayerData', function(source)
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local data = MySQL.single.await('SELECT identifier FROM data_ffa WHERE identifier = ?', { identifier })
    if not data then return false end

    MySQL.update.await('DELETE FROM data_ffa WHERE identifier = ?', { identifier })
    return true
end)

lib.callback.register('mind_ffa:getStats', function(source)
    local identifier = getIdentifier(source)
    if not identifier then return 0, 0 end

    local session = SessionStats[source]
    if session then
        return session.kills, session.deaths
    end

    local result = MySQL.single.await('SELECT kills, deaths FROM ffa WHERE identifier = ?', { identifier })
    if result then
        return tonumber(result.kills) or 0, tonumber(result.deaths) or 0
    end

    MySQL.insert.await('INSERT INTO ffa (identifier, kills, deaths) VALUES (?, ?, ?)', { identifier, 0, 0 })
    return 0, 0
end)

local function flushSession(playerSource, identifier)
    identifier = identifier or getIdentifier(playerSource)
    local session = SessionStats[playerSource]
    if not identifier or not session then return end

    MySQL.update('UPDATE ffa SET kills = ?, deaths = ?, lastplayed = ? WHERE identifier = ?', {
        tonumber(session.kills) or 0,
        tonumber(session.deaths) or 0,
        os.time(),
        identifier
    })
    LeaderboardCache.built = 0
end

AddEventHandler('playerDropped', function (reason)
    local playerSource = source
    local identifier

    for index, data in pairs(FFA) do
        if data.source == playerSource then
            identifier = data.identifier
            removeZonePlayer(data.zoneID)
            FFA[index] = nil
            break
        end
    end

    flushSession(playerSource, identifier)
    SessionStats[playerSource] = nil
    LastDeath[playerSource] = nil
    DeadState[playerSource] = nil
    LastHit[playerSource] = nil
end)

RegisterServerEvent('mind_ffa:removePlayer')
AddEventHandler('mind_ffa:removePlayer', function(zone)
    local playerSource = source
    local identifier = getIdentifier(playerSource)
    if not identifier then return end

    MySQL.update.await('DELETE FROM data_ffa WHERE identifier = ?', { identifier })

    local wasInFfa = false
    for index, data in pairs(FFA) do
        if data.identifier == identifier then
            removeZonePlayer(data.zoneID)
            FFA[index] = nil
            wasInFfa = true
            break
        end
    end

    if wasInFfa then
        exports.qbx_core:SetPlayerBucket(playerSource, 0)
    end
    DeadState[playerSource] = nil
    LastHit[playerSource] = nil

    flushSession(playerSource, identifier)
end)

-- Joining is decided here, not by the client: the arena must exist and have room,
-- the player must be at the Deathmatch NPC and not already in an arena.
lib.callback.register('mind_ffa:joinZone', function(source, zone)
    local playerSource = source
    local zoneConfig = Config.Zones[zone]
    if type(zone) ~= 'string' or not zoneConfig then
        return false, 'This arena does not exist.'
    end

    local identifier = getIdentifier(playerSource)
    if not identifier then
        return false, 'Your character is not loaded yet.'
    end

    for _, data in pairs(FFA) do
        if data.source == playerSource or data.identifier == identifier then
            return false, 'You are already in an arena.'
        end
    end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - Config.FFA) > (Config.JoinDistance or 15.0) then
        return false, 'Go to the Deathmatch NPC to join an arena.'
    end

    if getZoneCount(zone) >= zoneConfig.maxPlayers then
        return false, 'This arena is full!'
    end

    -- Reserve the slot before any database wait, so two players can't take the last one.
    addZonePlayer(zone)
    table.insert(FFA, { source = playerSource, zoneID = zone, identifier = identifier })
    exports.qbx_core:SetPlayerBucket(playerSource, zoneConfig.dimension)

    if not SessionStats[playerSource] then
        local row = MySQL.single.await('SELECT kills, deaths FROM ffa WHERE identifier = ?', { identifier })
        SessionStats[playerSource] = {
            kills = row and tonumber(row.kills) or 0,
            deaths = row and tonumber(row.deaths) or 0,
        }
    end

    MySQL.update.await('INSERT INTO data_ffa (identifier, zoneID) VALUES (?, ?) ON DUPLICATE KEY UPDATE zoneID = VALUES(zoneID)', { identifier, zone })
    MySQL.update('UPDATE ffa SET name = ?, lastplayed = ? WHERE identifier = ?', {
        getPlayerName(playerSource), os.time(), identifier
    })

    keepNeedsFull(playerSource)
    return true
end)

RegisterServerEvent('mind_ffa:setDimension')
AddEventHandler('mind_ffa:setDimension', function(dimension)
    local playerSource = source
    dimension = tonumber(dimension)
    if not dimension then return end

    local entry = getFfaEntry(playerSource)

    -- Leaving the arena dimension is only allowed once the player has left FFA.
    if dimension == 0 then
        if entry then return end
        exports.qbx_core:SetPlayerBucket(playerSource, 0)
        return
    end

    -- Otherwise only the dimension of the arena the server put them in.
    local zoneConfig = entry and Config.Zones[entry.zoneID]
    if zoneConfig and zoneConfig.dimension == dimension then
        exports.qbx_core:SetPlayerBucket(playerSource, dimension)
    end
end)

RegisterServerEvent('mind_ffa:saveStats')
AddEventHandler('mind_ffa:saveStats', function()
    -- Client-sent numbers are ignored; the server-side session is the source of truth.
    flushSession(source)
end)

local function round(value, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * m + 0.5) / m
end

local function buildLeaderboard()
    local rows = MySQL.query.await(
        'SELECT identifier, name, kills, deaths FROM ffa WHERE kills >= ? ORDER BY kills DESC, deaths ASC LIMIT ?',
        { Config.Leaderboard.minKills or 1, Config.Leaderboard.limit or 25 }
    ) or {}

    local board = {}
    for i, row in ipairs(rows) do
        local kills = tonumber(row.kills) or 0
        local deaths = tonumber(row.deaths) or 0
        local kd = Config.GetKd(kills, deaths)
        local rankInfo = Config.GetRankProgress(Config.GetRating(kills, deaths))

        board[i] = {
            rank = i,
            name = row.name or 'Unknown Soldier',
            kills = kills,
            deaths = deaths,
            kd = kd,
            rating = rankInfo.rating,
            rankName = rankInfo.name,
            rankIcon = rankInfo.icon,
            rankColor = rankInfo.color,
            rankProgress = rankInfo.progress,
            nextRank = rankInfo.nextName,
        }
    end

    LeaderboardCache = { data = board, built = os.time() }
    return board
end

lib.callback.register('mind_ffa:getLeaderboard', function(source, force)
    if not force and (os.time() - LeaderboardCache.built) < (Config.Leaderboard.autoRefresh or 60) and #LeaderboardCache.data > 0 then
        return LeaderboardCache.data
    end

    return buildLeaderboard()
end)

local function addKillReward(playerSource)
    if not Config.KillReward or not Config.KillReward.enabled then return end
    local amount = tonumber(Config.KillReward.amount) or 0
    if amount <= 0 then return end

    local account = Config.KillReward.account or 'cash'

    local success = false
    if exports.qbx_core and exports.qbx_core.AddMoney then
        pcall(function()
            exports.qbx_core:AddMoney(playerSource, account, amount, 'ffa-kill-reward')
            success = true
        end)
    end

    if not success then
        local player = getPlayer(playerSource)
        if player and player.Functions and player.Functions.AddMoney then
            player.Functions.AddMoney(account, amount, 'ffa-kill-reward')
        end
    end

    if Config.KillReward.notify ~= false then
        exports.qbx_core:Notify(playerSource, ('+$%s Cash for kill!'):format(amount), 'success', nil, 'FFA-System')
    end
end

-- Takes up to Config.DeathPenalty.amount; never pushes the balance below 0.
local function takeDeathPenalty(playerSource)
    local penalty = Config.DeathPenalty
    if not penalty or not penalty.enabled then return end
    local amount = tonumber(penalty.amount) or 0
    if amount <= 0 then return end

    local player = getPlayer(playerSource)
    if not player then return end

    local account = penalty.account or 'cash'
    local balance = tonumber(player.PlayerData.money and player.PlayerData.money[account]) or 0
    local toTake = math.min(amount, math.floor(balance))
    if toTake <= 0 then return end

    local removed = false
    if exports.qbx_core and exports.qbx_core.RemoveMoney then
        local ok, result = pcall(function()
            return exports.qbx_core:RemoveMoney(playerSource, account, toTake, 'ffa-death-penalty')
        end)
        removed = ok and result ~= false
    end

    if not removed and player.Functions and player.Functions.RemoveMoney then
        removed = player.Functions.RemoveMoney(account, toTake, 'ffa-death-penalty') ~= false
    end

    if removed and penalty.notify ~= false then
        exports.qbx_core:Notify(playerSource, ('-$%s for dying!'):format(toTake), 'error', nil, 'FFA-System')
    end
end

local function sendStats(playerSource)
    local session = SessionStats[playerSource]
    if not session then return end
    TriggerClientEvent('mind_ffa:setStats', playerSource, session.kills, session.deaths)
end

local function getFfaPlayerByPed(ped)
    if not ped or ped == 0 then return nil end
    for _, data in pairs(FFA) do
        if GetPlayerPed(data.source) == ped then
            return data.source
        end
    end
end

-- Counts a death once per life, takes the death penalty, and credits/pays the killer
-- only when the kill checks out. Called from the victim's report and from the server's
-- own death check, whichever sees the death first.
local function processDeath(victim, reportedKiller)
    local victimEntry = getFfaEntry(victim)
    if not victimEntry or not SessionStats[victim] or DeadState[victim] then return end

    local victimPed = GetPlayerPed(victim)
    if not victimPed or victimPed == 0 or GetEntityHealth(victimPed) > 100 then return end

    local now = GetGameTimer()
    if LastDeath[victim] and now - LastDeath[victim] < Config.KillValidation.deathCooldownMs then return end
    DeadState[victim] = true
    LastDeath[victim] = now

    SessionStats[victim].deaths = SessionStats[victim].deaths + 1
    sendStats(victim)
    takeDeathPenalty(victim)

    -- Who killed them: the game's recorded source of death first, then the victim's report,
    -- then the last player who hit them in the past 5 seconds.
    local deathSource = GetPedSourceOfDeath(victimPed)
    local killer = getFfaPlayerByPed(deathSource)
    if not killer then
        killer = tonumber(reportedKiller)
        local hit = LastHit[victim]
        if not killer and hit and now - hit.time < 5000 then
            killer = hit.attacker
        end
        -- If the game recorded a source of death, it must be the killer.
        if killer and deathSource and deathSource ~= 0 and deathSource ~= GetPlayerPed(killer) then
            killer = nil
        end
    end
    LastHit[victim] = nil

    if not killer or killer == victim then return end

    local killerEntry = getFfaEntry(killer)
    if not killerEntry or killerEntry.zoneID ~= victimEntry.zoneID or not SessionStats[killer] then return end
    if not getPlayer(victim) or not getPlayer(killer) then return end

    local killerPed = GetPlayerPed(killer)
    if not killerPed or killerPed == 0 then return end

    local zone = Config.Zones[victimEntry.zoneID]
    local maxDistance = (zone and zone.markersize or 150.0) * 2.0 + Config.KillValidation.extraDistance
    if #(GetEntityCoords(victimPed) - GetEntityCoords(killerPed)) > maxDistance then return end

    SessionStats[killer].kills = SessionStats[killer].kills + 1
    sendStats(killer)

    exports.qbx_core:Notify(killer, ('You killed %s!'):format(getPlayerName(victim)), 'inform', nil, 'FFA-System')
    exports.qbx_core:Notify(victim, ('You were killed by %s!'):format(getPlayerName(killer)), 'inform', nil, 'FFA-System')
    addKillReward(killer)
    TriggerClientEvent('mind_ffa:addKill', killer)
    TriggerEvent("leaderboard:playerKilled", killer, victim)
end

-- The victim's game reports its own death (fast path, includes who it thinks the killer is).
RegisterServerEvent('mind_ffa:killed')
AddEventHandler('mind_ffa:killed', function (killer)
    local victim = source
    if not getFfaEntry(victim) then return end

    -- Health is synced from the victim's game and can arrive slightly after the event.
    local victimPed = GetPlayerPed(victim)
    for _ = 1, 5 do
        if victimPed and victimPed ~= 0 and GetEntityHealth(victimPed) <= 100 then break end
        Wait(200)
        victimPed = GetPlayerPed(victim)
    end

    processDeath(victim, killer)
end)

-- Remember who hit whom, to name the killer when the victim doesn't report it
-- and to spot players who survive a lethal hit.
AddEventHandler('weaponDamageEvent', function(sender, data)
    local attacker = tonumber(sender)
    if not attacker or not getFfaEntry(attacker) or type(data) ~= 'table' then return end

    local hitIds = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(hitIds) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 then
            local owner = NetworkGetEntityOwner(entity)
            if owner and owner > 0 and owner ~= attacker and GetPlayerPed(owner) == entity and getFfaEntry(owner) then
                LastHit[owner] = { attacker = attacker, time = GetGameTimer(), willKill = data.willKill == true }
            end
        end
    end
end)

-- Server-side death check: counts deaths even if the victim's game never reports them,
-- so blocking the report no longer skips the death or the death penalty.
CreateThread(function()
    while true do
        Wait(500)
        local now = GetGameTimer()

        for _, data in pairs(FFA) do
            local playerSource = data.source
            local ped = GetPlayerPed(playerSource)

            if ped and ped ~= 0 then
                if GetEntityHealth(ped) <= 100 then
                    if not DeadState[playerSource] then
                        processDeath(playerSource, nil)
                    end
                else
                    DeadState[playerSource] = nil

                    -- A lethal hit 3+ seconds ago and still alive: likely godmode. Logged for admins.
                    local hit = LastHit[playerSource]
                    if hit and hit.willKill and now - hit.time > 3000 then
                        print(('[wx_ffa] Possible godmode: %s (ID %s) survived a lethal hit from %s (ID %s)'):format(
                            getPlayerName(playerSource), playerSource, getPlayerName(hit.attacker), hit.attacker))
                        LastHit[playerSource] = nil
                    end
                end
            end
        end
    end
end)

-- Wipe every player's FFA stats / leaderboard. Server console or admins only.
-- Usage: ffawipe            -> clears the whole leaderboard
--        ffawipe unnamed    -> clears only rows with no captured name
RegisterCommand('ffawipe', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.ffawipe') then
        return
    end

    if args[1] == 'unnamed' then
        MySQL.query.await('DELETE FROM ffa WHERE name IS NULL OR name = ?', { '' })
    else
        MySQL.query.await('TRUNCATE TABLE ffa')
        MySQL.query.await('TRUNCATE TABLE data_ffa')
    end

    LeaderboardCache = { data = {}, built = 0 }
    print('[wx_ffa] Leaderboard wiped.')
end, true)

