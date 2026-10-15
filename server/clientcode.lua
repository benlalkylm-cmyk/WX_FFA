RegisterServerEvent('mind_ffa:getclient')
AddEventHandler('mind_ffa:getclient', function()
    local _source = source
    local text = [[
        local ffa = false
        local kills = 0
        local tode = 0
        local PlayerZone = nil
        local deadPlayer = false

        local function round(value, decimals)
            if qbx and qbx.math and qbx.math.round then
                return qbx.math.round(value, decimals)
            end

            local multiplier = 10 ^ (decimals or 0)
            return math.floor(value * multiplier + 0.5) / multiplier
        end

        local function getKd(killCount, deathCount)
            return Config.GetKd(killCount)
        end

        local function notify(message, notifyType)
            exports.qbx_core:Notify({
                text = message,
                caption = 'FFA-SYSTEM'
            }, notifyType or 'inform')
        end

        local function setFullVitals()
            local ped = PlayerPedId()
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            SetPedArmour(ped, 100)
        end

        local function setFfaInventoryLocked(locked)
            LocalPlayer.state.invBusy = locked
            LocalPlayer.state.invHotkeys = not locked
        end

        local isTextUiOpen = false
        local FFAPed = nil

        local function loadModel(model)
            local hash = GetHashKey(model)
            RequestModel(hash)
            while not HasModelLoaded(hash) do
                Wait(0)
            end
            return hash
        end

        local function pushHudStats()
            SendNUIMessage({
                stats = true,
                kills = kills,
                tode = tode,
                kd = getKd(kills, tode),
                alwaysShow = Config.AlwaysShowHud == true
            })
        end

        local function pushLeaderboard(force)
            local board = lib.callback.await('mind_ffa:getLeaderboard', false, force == true)
            SendNUIMessage({
                action = 'leaderboard',
                players = board or {},
            })
        end

        local function pushProfile(k, d)
            local rankInfo = Config.GetRankProgress(Config.GetRating(k, d))
            SendNUIMessage({
                action = 'profile',
                kills = k,
                tode = d,
                kd = getKd(k, d),
                rating = rankInfo.rating,
                rankName = rankInfo.name,
                rankIcon = rankInfo.icon,
                rankColor = rankInfo.color,
                rankProgress = rankInfo.progress,
                nextRank = rankInfo.nextName,
                season = Config.Season and Config.Season.label or nil,
            })
        end

        local function openFfaMenu()
            local zoneData = lib.callback.await('mind_ffa:getZoneData', false)

            for k, v in pairs(Config.Zones) do
                for k1, v1 in pairs(zoneData) do
                    if v1.zone == k then
                        local mode = "kein Modus"
                        if v.customMode.enabled == true then
                            mode = v.customMode.label
                        end
                        SendNUIMessage({
                            type = 'add',
                            label = k,
                            picture = v.image,
                            player = v1.players.."/"..v.maxPlayers,
                            modus = mode,
                        })
                    end
                end
            end

            local pKills, pDeaths = lib.callback.await('mind_ffa:getStats', false)
            pushProfile(pKills, pDeaths)

            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openMenu',
                status = true,
            })

            pushLeaderboard()
        end


        local function spawnFFAPed()
            if not Config.FFAPed or not Config.FFAPed.model then
                return
            end

            local modelHash = loadModel(Config.FFAPed.model)
            if DoesEntityExist(FFAPed) then
                DeleteEntity(FFAPed)
            end

            FFAPed = CreatePed(4, modelHash, Config.FFA.x, Config.FFA.y, Config.FFA.z - 1.0, Config.FFAPed.heading or 0.0, false, true)
            SetEntityAsMissionEntity(FFAPed, true, true)
            SetEntityInvincible(FFAPed, true)
            SetBlockingOfNonTemporaryEvents(FFAPed, true)
            FreezeEntityPosition(FFAPed, true)
            SetPedCanRagdollFromPlayerImpact(FFAPed, false)
            SetPedCanRagdoll(FFAPed, false)
            SetPedFleeAttributes(FFAPed, 0, false)
            SetPedKeepTask(FFAPed, true)
            TaskStartScenarioInPlace(FFAPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

        end

        local function showEnterPrompt()
            if isTextUiOpen then return end

            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Open Deathmatch Menu')
            EndTextCommandDisplayHelp(0, false, true, -1)
            isTextUiOpen = true
        end

        local function hideEnterPrompt()
            if not isTextUiOpen then return end

            ClearAllHelpMessages()
            isTextUiOpen = false
        end

        exports('getFFAStatus', function()
            return ffa
        end)

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            Wait(100)
            local status = lib.callback.await('mind_ffa:checkPlayerData', false)

            if status then
                SetEntityCoords(PlayerPedId(), Config.FFA.x, Config.FFA.y, Config.FFA.z)
                setFullVitals()
            end
        end)

        Citizen.CreateThread(function()
            local blip = AddBlipForCoord(Config.FFA.x, Config.FFA.y, Config.FFA.z)
            SetBlipSprite(blip, 429)
            SetBlipScale(blip, 0.8)
            SetBlipColour(blip, 30)
            SetBlipDisplay(blip, 4)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("WarX-Deathmatch")
            EndTextCommandSetBlipName(blip)
            spawnFFAPed()
        end)

        RegisterNUICallback("close", function(data, cb)
            SetNuiFocus(false, false)
            cb({})
        end)

        RegisterNUICallback("refreshLeaderboard", function(data, cb)
            pushLeaderboard(true)
            cb({})
        end)

        Citizen.CreateThread(function()
            while true do
                Wait(0)
                local found = false
                local coords = GetEntityCoords(PlayerPedId())
                local dist = GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), Config.FFA)	  
                if dist <= 25 then
                        if not ffa then
                        found = true
                                if dist <= 2.5 then
                            showEnterPrompt()
                            if IsControlJustReleased(0, 38) then
                                openFfaMenu()
                            end
                        else
                            hideEnterPrompt()
                        end
                    end
                end
                if not found then
                    hideEnterPrompt()
                    Wait(500)
                end
            end
        end)

        RegisterNUICallback('select', function(data, cb)
            for k, v in pairs(Config.Zones) do
                if k == data.label then
                    -- The server checks room, location and puts the player in the arena's dimension.
                    local joined, reason = lib.callback.await('mind_ffa:joinZone', false, k)
                    if not joined then
                        notify(reason or "You can't join this arena right now.", 'error')
                    else
                        ffa = true
                        PlayerZone = data.label
                        setFfaInventoryLocked(true)
                        kills, tode = lib.callback.await('mind_ffa:getStats', false)

                        SendNUIMessage({
                            type = "ui",
                            display = true
                        })
                        SetNuiFocus(false, false)
                        SendNUIMessage({
                            action = 'openMenu',
                            status = false,
                        })
                        SendNUIMessage({
                            stats = true,
                            kills = kills,
                            tode = tode,
                            kd = getKd(kills, tode),
                            alwaysShow = Config.AlwaysShowHud == true
                        })
                        Wait(500)
                        SpawnRandom(PlayerZone)
                        Wait(500)
                        TriggerEvent('weapontrigger3')
                        setFullVitals()
                        local mode = "kein Modus"
                        if v.customMode.enabled == true then
                            mode = v.customMode.label
                        end
                        if mode ~= "kein Modus" then
                            RemoveAllPedWeapons(PlayerPedId(), true)
                            for k1, k2 in pairs(v.customMode.weapons) do
                                TriggerEvent('weapontrigger')
                                GiveWeaponToPed(PlayerPedId(), GetHashKey(k2), 1000, false, false)
                            end
                            Wait(100)
                            SetCurrentPedWeapon(PlayerPedId(), GetHashKey(v.customMode.weapons[1]), true)
                        end
                        notify("You have entered the WarX TDM")
                        TriggerEvent('chat:addMessage', { color = { 47, 128, 200 }, multiline = true, args = {"You have joined Deathmatch. Use command /quitdm to exit." }})
                    end
                end
            end

            cb({})
        end)

        -- Picks the spawn farthest from the nearest living enemy, choosing randomly among
        -- the best few so spawns stay hard to predict. Random when nobody else is around.
        local function pickSpawn(zone)
            local spawns = zone.spawns
            local enemies = {}
            local me = PlayerId()

            for _, playerId in ipairs(GetActivePlayers()) do
                if playerId ~= me then
                    local enemyPed = GetPlayerPed(playerId)
                    if DoesEntityExist(enemyPed) and not IsEntityDead(enemyPed) then
                        enemies[#enemies + 1] = GetEntityCoords(enemyPed)
                    end
                end
            end

            if #enemies == 0 then
                return spawns[math.random(1, #spawns)]
            end

            local scored = {}
            for _, spawn in ipairs(spawns) do
                local nearest = math.huge
                for _, enemy in ipairs(enemies) do
                    nearest = math.min(nearest, #(spawn - enemy))
                end
                scored[#scored + 1] = { coords = spawn, nearest = nearest }
            end
            table.sort(scored, function(a, b) return a.nearest > b.nearest end)

            return scored[math.random(1, math.min(3, #scored))].coords
        end

        -- Face the middle of the arena after spawning.
        local function headingToCentre(zone, coords)
            local d = zone.markermiddle - coords
            return GetHeadingFromVector_2d(d.x, d.y)
        end

        local function applyLoadout(zone)
            setFullVitals()
            exports['ox_inventory']:weaponWheel(true)
            TriggerEvent('rx_rprevive:inmatchlobby', "deathmatch", true)
            setFfaInventoryLocked(true)
            local mode = "kein Modus"
            if zone.customMode.enabled == true then
                mode = zone.customMode.label
            end
            if mode ~= "kein Modus" then
                RemoveAllPedWeapons(PlayerPedId(), true)
                for k1, k2 in pairs(zone.customMode.weapons) do
                    TriggerEvent('weapontrigger')
                    GiveWeaponToPed(PlayerPedId(), GetHashKey(k2), 1000, false, false)
                    SetCurrentPedWeapon(PlayerPedId(), GetHashKey(k2), true)
                end
            end
        end

        function SpawnRandom(PlayerZone)
            local zone = Config.Zones[PlayerZone]
            if not zone then return end

            local spawn = pickSpawn(zone)
            local ped = PlayerPedId()
            SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
            SetEntityHeading(ped, headingToCentre(zone, spawn))
            if ffa then
                applyLoadout(zone)
            end
        end

        -- Brings the player back to life at a spawn point. FFA does this itself so it
        -- doesn't depend on the server's death/revive script.
        local function respawnInZone()
            local zone = Config.Zones[PlayerZone]
            if not zone then return end

            local cleanupEvent = Config.Respawn and Config.Respawn.cleanupEvent
            if cleanupEvent then
                TriggerEvent(cleanupEvent)
                Wait(100)
            end

            local spawn = pickSpawn(zone)
            NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, headingToCentre(zone, spawn), true, false)
            local ped = PlayerPedId()
            ClearPedTasksImmediately(ped)
            ClearPedBloodDamage(ped)
            TriggerEvent('weapontrigger3')
            applyLoadout(zone)
        end

        local function drawRespawnCountdown(secondsLeft)
            SetTextFont(4)
            SetTextScale(0.0, 0.7)
            SetTextColour(255, 255, 255, 230)
            SetTextOutline()
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('RESPAWNING IN %d'):format(secondsLeft))
            EndTextCommandDisplayText(0.5, 0.42)
        end

        Citizen.CreateThread(function()
            while true do
                if ffa then
                    Wait(0)
                    DisableControlAction(0, 289, true)
                    DisableControlAction(0, 74, true)
                    DisableControlAction(0, 74, true)
                    RestorePlayerStamina(PlayerId(), 1.0)
                    for k, v in pairs(Config.Zones) do
                        if k == PlayerZone then
                            DrawMarker(28, v.markermiddle.x, v.markermiddle.y, v.markermiddle.z, 0, 0, 0, 0, 0, 0, v.markersize, v.markersize, v.markersize, 190, 0, 0, 60, 0, 0, 0, 0)
                        end
                    end
                    if GetSelectedPedWeapon(PlayerPedId()) == GetHashKey("WEAPON_MARKSMANRIFLE") then
                        SetCurrentPedWeapon(PlayerPedId(), GetHashKey("weapon_unarmed"), 1)
                        notify("Marksman banned in FFA", 'error')
                    end
                else
                    Wait(2500)
                end
            end
        end)

        Citizen.CreateThread(function()
            while true do
                if ffa then
                    Wait(1000)  
                    found = false
                    for k, v in pairs(Config.Zones) do
                        if k == PlayerZone then
                            local dist = GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), vector3(v.markermiddle.x, v.markermiddle.y, v.markermiddle.z))
                            if dist >= v.markersize and not deadPlayer then
                                SpawnRandom(PlayerZone)
                                notify("You are not allowed to leave the zone!", 'warning')
                            end
                        end
                    end
                else
                    Wait(2500)
                end
            end
        end)


        RegisterCommand('+ffaScoreboard', function()
            if not ffa then return end
            local matchPlayers = lib.callback.await('mind_ffa:getZonePlayers', false, PlayerZone) or {}
            local rankInfo = Config.GetRankProgress(Config.GetRating(kills, tode))

            SendNUIMessage({
                action = 'showScoreboard',
                visible = true,
                kills = kills,
                tode = tode,
                kd = getKd(kills, tode),
                zone = PlayerZone or 'Deathmatch Arena',
                rankName = rankInfo.name,
                rankIcon = rankInfo.icon,
                rankColor = rankInfo.color,
                rating = rankInfo.rating,
                players = matchPlayers
            })
        end, false)

        RegisterCommand('-ffaScoreboard', function()
            SendNUIMessage({
                action = 'showScoreboard',
                visible = false
            })
        end, false)

        RegisterKeyMapping('+ffaScoreboard', 'Hold to show TDM Scoreboard', 'keyboard', Config.ScoreboardKey or 'TAB')

        RegisterCommand('quitdm', function()
            if ffa then
                ffa = false
                if IsEntityDead(PlayerPedId()) then
                    NetworkResurrectLocalPlayer(Config.FFA.x, Config.FFA.y, Config.FFA.z, 0.0, true, false)
                end
                deadPlayer = false
                ped = PlayerPedId()
                RemoveAllPedWeapons(ped)
                TriggerEvent("rxRevive:revivePlayerClient")
                TriggerEvent('rx_rprevive:inmatchlobby', "deathmatch", false)
                TriggerServerEvent("mind_ffa:removePlayer", PlayerZone)
                SetEntityCoords(PlayerPedId(), Config.FFA.x,Config.FFA.y,Config.FFA.z)
                PlayerZone = nil
                notify("You have left the WarX TDM", 'success')
                Wait(1000)
                TriggerServerEvent('mind_ffa:saveStats')
                TriggerServerEvent('mind_ffa:setDimension', 0)
                SendNUIMessage({action = 'showScoreboard', visible = false})
                SendNUIMessage({type = "ui", display = false})
                setFullVitals()
                exports['ox_inventory']:weaponWheel(false)
               
                setFfaInventoryLocked(false)
            end
        end)

        local function onFfaDeath(attacker)
            if deadPlayer or not ffa then return end
            deadPlayer = true

            local killerServerId
            if attacker and attacker ~= 0 and DoesEntityExist(attacker) and IsEntityAPed(attacker) and IsPedAPlayer(attacker) then
                local killerPlayer = NetworkGetPlayerIndexFromPed(attacker)
                if killerPlayer ~= -1 then
                    killerServerId = GetPlayerServerId(killerPlayer)
                end
            end

            -- The server counts the death and decides whether the killer gets credit.
            TriggerServerEvent('mind_ffa:killed', killerServerId)

            CreateThread(function()
                local delayMs = math.floor(((Config.Respawn and Config.Respawn.delay) or 3) * 1000)
                local respawnAt = GetGameTimer() + delayMs
                while ffa and GetGameTimer() < respawnAt do
                    drawRespawnCountdown(math.ceil((respawnAt - GetGameTimer()) / 1000))
                    Wait(0)
                end

                if ffa then
                    respawnInZone()
                end
                deadPlayer = false
            end)
        end

        AddEventHandler('gameEventTriggered', function(eventName, data)
            if eventName ~= 'CEventNetworkEntityDamage' or not ffa then return end
            if data[1] ~= PlayerPedId() or not IsEntityDead(data[1]) then return end
            onFfaDeath(data[2])
        end)

        -- Backup: catches deaths that don't come with a damage event (drowning, scripts, /kill).
        CreateThread(function()
            while true do
                Wait(500)
                if ffa and not deadPlayer then
                    local ped = PlayerPedId()
                    if IsEntityDead(ped) then
                        onFfaDeath(GetPedSourceOfDeath(ped))
                    end
                end
            end
        end)

        RegisterNetEvent('mind_ffa:setStats')
        AddEventHandler('mind_ffa:setStats', function(serverKills, serverDeaths)
            kills = tonumber(serverKills) or kills
            tode = tonumber(serverDeaths) or tode
            if ffa then
                pushHudStats()
            end
        end)

        RegisterNetEvent('mind_ffa:addKill')
        AddEventHandler('mind_ffa:addKill', function()
            TriggerEvent('weapontrigger3')
            setFullVitals()
            TriggerEvent('weapontrigger2')
            Citizen.Wait(200)
            setFullVitals()
        end) 
    ]]
    TriggerClientEvent('mind_ffa:getclient', _source, text)
end)