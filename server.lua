local cops = {}
local robber = nil
local gameStarted = false

RegisterCommand("copsandrobbers", function(source)
    if gameStarted then
        TriggerClientEvent("chat:addMessage", source, { args = { "System", "Game already started." } })
        return
    end

    local players = GetPlayers()
    if #players < 2 then
        TriggerClientEvent("chat:addMessage", source, { args = { "System", "Need at least 2 players." } })
        return
    end

    gameStarted = true
    local shuffled = {}
    for _, p in ipairs(players) do table.insert(shuffled, p) end
    math.randomseed(os.time())
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    robber = shuffled[1]
    cops = {}
    for i = 2, #shuffled do table.insert(cops, shuffled[i]) end

    TriggerClientEvent("copsrobber:assignRole", robber, "robber")
    for _, cop in ipairs(cops) do
        TriggerClientEvent("copsrobber:assignRole", cop, "cop")
    end

    for _, p in ipairs(players) do
        local ped = GetPlayerPed(robber)
        local netId = NetworkGetNetworkIdFromEntity(ped)
        TriggerClientEvent("copsrobber:startGame", p, netId)
    end

    CreateThread(function()
        while gameStarted do
            Wait(45000)
            if robber and gameStarted then
                local ped = GetPlayerPed(robber)
                local netId = NetworkGetNetworkIdFromEntity(ped)
                TriggerClientEvent("copsrobber:pingRobber", -1, netId)
            end
        end
    end)
end)

RegisterCommand("endgame", function(source)
    if not gameStarted then
        TriggerClientEvent("chat:addMessage", source, { args = { "System", "No game running." } })
        return
    end
    EndGame("Game Ended")
end)

RegisterNetEvent("copsrobber:updateHealth", function(newHealth)
    if newHealth <= 0 and gameStarted then
        TriggerClientEvent("copsrobber:vehicleDestroyed", -1)
        EndGame("Cops Win! Robber's vehicle destroyed.")
    else
        for _, p in ipairs(GetPlayers()) do
            TriggerClientEvent("copsrobber:syncHealth", p, newHealth)
        end
    end
end)

RegisterNetEvent("copsrobber:robberArrested", function()
    EndGame("Cops Win! Robber Arrested.")
end)

RegisterNetEvent("copsrobber:robberDied", function()
    EndGame("Cops Win! Robber Died.")
end)

RegisterNetEvent("copsrobber:vehicleDestroyed", function()
    EndGame("Cops Win! Vehicle Destroyed.")
end)

RegisterNetEvent("copsrobber:robberDelivered", function()
    EndGame("Robber Wins! Escaped Successfully.")
end)

function EndGame(message)
    gameStarted = false
    for _, p in ipairs(GetPlayers()) do
        TriggerClientEvent("copsrobber:endGame", p, message)
    end
    robber = nil
    cops = {}
end
