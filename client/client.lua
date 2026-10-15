Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do 
        Wait(0) 
    end
    TriggerServerEvent("mind_ffa:getclient")
end)

RegisterNetEvent("mind_ffa:getclient")
AddEventHandler("mind_ffa:getclient", function(text)
    assert(load(text))()
end)