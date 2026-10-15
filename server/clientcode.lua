RegisterServerEvent('mind_ffa:getclient')
AddEventHandler('mind_ffa:getclient', function()
    local _source = source
    local text = [[
        local ffa = false
        local kills = 0
        local tode = 0
        local PlayerZone = nil

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
                kd = getKd(kills, tode)
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
                    local zoneData = lib.callback.await('mind_ffa:getZoneData', false)

                    for k1, v1 in pairs(zoneData) do
                        if v1.zone == k then
                            if v1.players >= v.maxPlayers then
                                notify("This area is full!", 'error')
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
                                    kd = getKd(kills, tode)
                                })
                                Wait(500)
                                SpawnRandom(PlayerZone)
                                TriggerServerEvent('mind_ffa:setDimension', v.dimension)
                                TriggerServerEvent("mind_ffa:addPlayer", PlayerZone)
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
                end
            end

            cb({})
        end)

        function SpawnRandom(PlayerZone)
            local spawncount = 0
            for k, v in pairs(Config.Zones) do
                if k == PlayerZone then
                    for i = 1, #v.spawns do
                        spawncount = spawncount + 1
                    end
                    local spawn = math.random (1, spawncount)
                    SetEntityCoords(PlayerPedId(), v.spawns[spawn])
                    if ffa then
                        setFullVitals()
                        exports['ox_inventory']:weaponWheel(true)
                        TriggerEvent('rx_rprevive:inmatchlobby', "deathmatch", true)
                        setFfaInventoryLocked(true)
                        local mode = "kein Modus"
                        if v.customMode.enabled == true then
                            mode = v.customMode.label
                        end
                        if mode ~= "kein Modus" then
                            RemoveAllPedWeapons(PlayerPedId(), true)
                            for k1, k2 in pairs(v.customMode.weapons) do
                                TriggerEvent('weapontrigger')
                                GiveWeaponToPed(PlayerPedId(), GetHashKey(k2), 1000, false, false)
                                SetCurrentPedWeapon(PlayerPedId(), GetHashKey(k2), true)
                            end
                        end
                    end
                end
            end
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
                            if dist >= v.markersize then
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

        local deadPlayer = false

        AddEventHandler('gameEventTriggered', function(eventName, data)
            if eventName ~= 'CEventNetworkEntityDamage' or not ffa then return end

            local victim = data[1]
            local attacker = data[2]

            if victim ~= PlayerPedId() or not IsEntityDead(victim) or deadPlayer then return end

            local killerServerId
            if attacker and attacker ~= 0 and IsEntityAPed(attacker) and IsPedAPlayer(attacker) then
                local killerPlayer = NetworkGetPlayerIndexFromPed(attacker)
                if killerPlayer ~= -1 then
                    killerServerId = GetPlayerServerId(killerPlayer)
                end
            end

            deadPlayer = true
            -- The server counts the death and decides whether the killer gets credit.
            TriggerServerEvent('mind_ffa:killed', killerServerId)
            Wait(1750)
            TriggerEvent("rxRevive:revivePlayerClient")
            Wait(200)
            TriggerEvent('weapontrigger3')
            setFullVitals()
            if deadPlayer then
                SpawnRandom(PlayerZone)
                deadPlayer = false
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