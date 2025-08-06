local role = "none"
local vehicle = nil
local health = 100.0
local displayedHealth = 100.0
local isGameActive = false
local dropoff = vector3(-25.35, 6458.86, 30.82)
local endLocation = vector4(432.84, -981.72, 30.71, 90.57)
local lastVehicleHealth = 1000.0
local blip = nil
local arrestProgress = 0.0
local isArresting = false

RegisterNetEvent("copsrobber:assignRole", function(r)
    role = r
end)

RegisterNetEvent("copsrobber:startGame", function(robberNetId)
    isGameActive = true
    local ped = PlayerPedId()

    if role == "cop" then
        local spawnPoints = {
            vector4(-227.19, -2411.1, 5.61, 325.8),
            vector4(-281.13, -2408.65, 5.61, 326.06)
        }
        local copIndex = (GetPlayerServerId(PlayerId()) % #spawnPoints) + 1
        local pos = spawnPoints[copIndex]

        RequestModel("polgauntlet") while not HasModelLoaded("polgauntlet") do Wait(0) end
        vehicle = CreateVehicle("polgauntlet", pos.xyz, pos.w, true, false)
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
        FreezeEntityPosition(vehicle, true)

        ShowSubtitle("~g~The Robber~s~ has stolen the car!", 10000)
        Wait(5000)
        FreezeEntityPosition(vehicle, false)
        ShowSubtitle("Go and arrest the ~g~Robber~s~", 10000)

    elseif role == "robber" then
        local pos = vector4(-174.62, -2392.03, 6, 234.63)
        RequestModel("sultan3") while not HasModelLoaded("sultan3") do Wait(0) end
        vehicle = CreateVehicle("sultan3", pos.xyz, pos.w, true, false)
        TaskWarpPedIntoVehicle(ped, vehicle, -1)

        -- Light green GTA Online-style waypoint
        SetNewWaypoint(dropoff.x, dropoff.y)
        ShowSubtitle("Go to the ~p~Dropoff~s~ location", 30000)
    end

    lastVehicleHealth = GetEntityHealth(vehicle)
    health = 100.0
    displayedHealth = 100.0

    StartGameLoop()
end)

function ShowSubtitle(text, duration)
    ClearPrints()
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(duration, true)
end

function StartGameLoop()
    CreateThread(function()
        while isGameActive do
            Wait(100)

            if role == "robber" and vehicle and DoesEntityExist(vehicle) then
                local currentHealth = GetEntityHealth(vehicle)
                if currentHealth < lastVehicleHealth then
                    local damage = lastVehicleHealth - currentHealth
                    health = health - (damage > 20 and 5 or 2)
                    if health < 0 then health = 0 end
                    TriggerServerEvent("copsrobber:updateHealth", health)

                    if health <= 0 then
                        -- Protect the robber from explosion
                        SetEntityInvincible(PlayerPedId(), true)
                        Wait(200)
                        AddExplosion(GetEntityCoords(vehicle), 2, 5.0, true, false, 0.0)
                        Wait(1500)
                        SetEntityInvincible(PlayerPedId(), false)

                        TriggerServerEvent("copsrobber:vehicleDestroyed")
                    end
                end
                lastVehicleHealth = currentHealth

                local coords = GetEntityCoords(vehicle)
                if #(coords - dropoff) < 10.0 then
                    TriggerServerEvent("copsrobber:robberDelivered")
                end
            end

            if role == "cop" and vehicle then
                if IsControlPressed(0, 20) then -- Z
                    local targetServerId = GetClosestPlayer()
                    if targetServerId and IsPlayerNear(targetServerId, 3.0) then
                        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
                        if not IsEntityDead(targetPed) then
                            isArresting = true
                            arrestProgress = math.min(arrestProgress + 2, 100)
                            if arrestProgress >= 100 then
                                TriggerServerEvent("copsrobber:robberArrested")
                                isArresting = false
                                arrestProgress = 0
                            end
                        else
                            isArresting = false
                            arrestProgress = 0
                        end
                    else
                        isArresting = false
                        arrestProgress = 0
                    end
                else
                    isArresting = false
                    arrestProgress = 0
                end
            end

            if role == "robber" and IsEntityDead(PlayerPedId()) then
                TriggerServerEvent("copsrobber:robberDied")
            end
        end
    end)
end

RegisterNetEvent("copsrobber:endGame", function(winner)
    isGameActive = false
    local ped = PlayerPedId()

    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsNoLongerNeeded(vehicle)
        DeleteVehicle(vehicle)
        vehicle = nil
    end

    if blip then
        RemoveBlip(blip)
        blip = nil
    end

    ClearGpsMultiRoute()
    ClearGpsPlayerWaypoint()

    isArresting = false
    arrestProgress = 0.0
    displayedHealth = 100.0
    health = 100.0
    role = "none"

    SetEntityCoords(ped, endLocation.x, endLocation.y, endLocation.z)
    SetEntityHeading(ped, endLocation.w)

    ShowSubtitle("Game Over. Winner: " .. winner, 10000)
end)

RegisterNetEvent("copsrobber:pingRobber", function(robberNetId)
    if role == "cop" then
        local ped = NetToPed(robberNetId)
        if DoesEntityExist(ped) then
            if blip then RemoveBlip(blip) end
            blip = AddBlipForEntity(ped)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, false)
            SetBlipCategory(blip, 7)
            SetBlipPriority(blip, 10)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Robber")
            EndTextCommandSetBlipName(blip)

            CreateThread(function()
                Wait(20000)
                if blip then
                    RemoveBlip(blip)
                    blip = nil
                end
            end)
        end
    end
end)

RegisterNetEvent("copsrobber:syncHealth", function(newHealth)
    displayedHealth = newHealth
end)

function GetClosestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest = nil
    local dist = 999.0

    for _, p in pairs(players) do
        local tgt = GetPlayerPed(p)
        if tgt ~= ped then
            local c = GetEntityCoords(tgt)
            local d = #(coords - c)
            if d < dist then
                dist = d
                closest = GetPlayerServerId(p)
            end
        end
    end
    return closest
end

function IsPlayerNear(serverId, range)
    local p = GetPlayerFromServerId(serverId)
    if not NetworkIsPlayerActive(p) then return false end
    local ped = PlayerPedId()
    local tgt = GetPlayerPed(p)
    return #(GetEntityCoords(ped) - GetEntityCoords(tgt)) < range
end

-- HUD Drawing
CreateThread(function()
    while true do
        Wait(0)
        if isGameActive then
            local screenW, screenH = GetScreenResolution()
            local barWidth = 0.25
            local barHeight = 0.02
            local posX = 0.5 - barWidth / 2
            local posY = 0.87

            DrawRect(posX + barWidth/2, posY + barHeight/2, barWidth, barHeight, 0, 0, 0, 180)
            DrawRect(posX + (barWidth * (displayedHealth/100)) / 2, posY + barHeight/2, barWidth * (displayedHealth/100), barHeight, 255, 255, 0, 200)

            if isArresting then
                local arrestW = 0.15
                local arrestH = 0.015
                local arrestX = 0.5 - arrestW / 2
                local arrestY = posY - 0.035

                DrawRect(arrestX + arrestW/2, arrestY + arrestH/2, arrestW, arrestH, 0, 0, 0, 180)
                DrawRect(arrestX + (arrestW * (arrestProgress/100)) / 2, arrestY + arrestH/2, arrestW * (arrestProgress/100), arrestH, 0, 120, 255, 200)

                SetTextFont(0)
                SetTextScale(0.3, 0.3)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("Arresting...")
                DrawText(0.5, arrestY - 0.02)
            end
        else
            Wait(500)
        end
    end
end)
