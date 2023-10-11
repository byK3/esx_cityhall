local npc = nil
local firstSpawn = false

AddEventHandler('playerSpawned', function()
    if not firstSpawn then
        ESX.PlayerData = ESX.GetPlayerData()
        startThread()
        firstSpawn = true
    end
end)

function startThread()
    spawnNPC()
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local cityhall = Config.General.position.coords
            local distance = #(coords - cityhall)

            if distance < 30 then
                if not npc then
                    spawnNPC()
                end

                if Config.General.position.marker.enable then
                    local marker = Config.General.position.marker
                    DrawMarker(marker.type, cityhall.x, cityhall.y, cityhall.z - 0.95, 0.0, 0.0, 0.0, 0, 0.0, 0.0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.x, marker.color.y, marker.color.z, marker.alpha, false, true, 2, false, false, false, false)
                end

                if distance < Config.General.position.interactionRadius then
                    local interactText = Config.General.position.interactText
                    if interactText then
                        ESX.ShowHelpNotification(interactText)
                    end
                
                    if IsControlJustReleased(0, Config.General.position.interactKey) then
                        OpenMenu()
                    end
                end                

                Wait(1)
            else
                if npc then
                    DeleteEntity(npc)
                    npc = nil
                end
                Wait(1000)
            end
        end
    end)
end



function spawnNPC()
    if Config.General.npc.enable then
        local model = GetHashKey(Config.General.npc.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(1)
        end

        npc = CreatePed(4, model, Config.General.position.coords.x, Config.General.position.coords.y, Config.General.position.coords.z - 1.0, Config.General.npc.heading, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        FreezeEntityPosition(npc, true)
        SetEntityInvincible(npc, true)
        SetPedDiesWhenInjured(npc, false)
        SetPedCanPlayAmbientAnims(npc, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityDynamic(npc, true)
        SetEntityVisible(npc, false, false)
    end
end


local menuOpen = false

function OpenMenu()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - Config.General.position.coords)

    if distance < Config.General.position.interactionRadius then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), "general", {
            title = "Cityhall",
            align = "top-left",
            elements = {
                {label = "Social Menu Option", value = "socialmenu"},
                {label = "Namechange Office", value = "namechange"},
                {label = "Stats", value = "stats"}
            }
        }, function(data, menu)
            if data.current.value == "socialmenu" then
                menu.close()
                RequestRemainingTime()
            elseif data.current.value == "namechange" then
                menu.close()
                OpenNameChangeMenu()
            elseif data.current.value == "stats" then
                menu.close()
                OpenStatsMenu()
            end
        end, function(data, menu)
            menu.close()
            menuOpen = false
        end)

        menuOpen = true

        CreateThread(function()
            while menuOpen do
                Wait(1000)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - Config.General.position.coords)
                if distance > Config.General.position.interactionRadius then
                    ESX.UI.Menu.CloseAll()
                    menuOpen = false
                end
            end
        end)
    end
end

-- SOCIAL MENU

function RequestRemainingTime()
    TriggerServerEvent('k3_cityhall:getRemainingTime')
end

RegisterNetEvent('k3_cityhall:receiveRemainingTime')
AddEventHandler('k3_cityhall:receiveRemainingTime', function(remainingTime)
    local minutes = math.floor(remainingTime / 60)
    local seconds = remainingTime % 60

    OpenSocialMenu(minutes, seconds)
end)


function OpenSocialMenu(minutes, seconds)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - Config.General.position.coords)

    if distance < Config.General.position.interactionRadius then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), "social_money", {
            title = "CITYHALL - Social Money",
            align = "top-left",
            elements = {
                {label = "Amount of Payment: $" .. Config.SocialMoney.money.payment, value = "current_money"},
                {label = "Next Payment in: " .. minutes .. " Minutes " .. seconds .. " Seconds", value = "duration"},
                {label = "------------", value = "separator"},
                {label = "Apply for social money", value = "apply_socialmoney"},
                {label = "Collect your social money", value = "collect_socialmoney"},
                {label = "End your social money", value = "end_socialmoney"}
            }
        }, function(data, menu)
            if data.current.value == "apply_socialmoney" then
                TriggerServerEvent("k3_cityhall:applyForSocialMoney")
            elseif data.current.value == "collect_socialmoney" then
                TriggerServerEvent("k3_cityhall:collectStoredSocialMoney")
            elseif data.current.value == "end_socialmoney" then
                TriggerServerEvent("k3_cityhall:endSocialMoney")
            end
        end, function(data, menu)
            menu.close()
            menuOpen = false
        end)

        menuOpen = true

        CreateThread(function()
            while menuOpen do
                Wait(1000)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - Config.General.position.coords)
                if distance > Config.General.position.interactionRadius then
                    ESX.UI.Menu.CloseAll()
                    menuOpen = false
                end
            end
        end)
    end
end


    
--- NAMECHANGE MENU

local newFirstName = nil
local newLastName = nil

function OpenNameChangeMenu()
    ESX.TriggerServerCallback('k3_cityhall:getCurrentName', function(firstName, lastName)
        if firstName and lastName then
            local elements = {
                {label = "Current Name: " .. firstName .. " " .. lastName, value = "current_name"},
                {label = "Change Firstname", value = "change_firstname"},
                {label = "Change Lastname", value = "change_lastname"},
                {label = "Save Name (Price: $" .. Config.NameChange.price .. ")", value = "save_changes"}
            }

            if newFirstName then
                table.insert(elements, 2, {label = "Neuer Vorname: " .. newFirstName, value = "new_firstname"})
            end

            if newLastName then
                table.insert(elements, 3 + (newFirstName and 1 or 0), {label = "Neuer Nachname: " .. newLastName, value = "new_lastname"})
            end

            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'namechange', {
                title = "Name ändern",
                align = "top-left",
                elements = elements
            }, function(data, menu)
                if data.current.value == "change_firstname" then
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'firstname_dialog', {
                        title = "Neuen Vornamen eingeben"
                    }, function(data2, menu2)
                        newFirstName = data2.value
                        menu2.close()
                        OpenNameChangeMenu()
                    end, function(data2, menu2)
                        menu2.close()
                    end)
                elseif data.current.value == "change_lastname" then
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'lastname_dialog', {
                        title = "Neuen Nachnamen eingeben"
                    }, function(data2, menu2)
                        newLastName = data2.value
                        menu2.close()
                        OpenNameChangeMenu()
                    end, function(data2, menu2)
                        menu2.close()
                    end)
                elseif data.current.value == "save_changes" then
                    TriggerServerEvent('k3_cityhall:changeName', newFirstName, newLastName)
                    menu.close()
                end
            end, function(data, menu)
                menu.close()
            end)
        else
            print ("Error: Callback returned no name")
        end
    end)
end



-- STATS MENU

function OpenStatsMenu()
    ESX.TriggerServerCallback('k3_cityhall:getPlayerStats', function(stats)
        if stats then
            local hours = math.floor(stats.playtime / 60)
            local minutes = stats.playtime % 60
            local playtimeFormatted = hours .. " Hour(s) " .. minutes .. " Minute(s)"

            local elements = {
                {label = "Firstname: " .. stats.firstname},
                {label = "Lastname: " .. stats.lastname},
                {label = "Sex: " .. stats.sex},
                {label = "DOB: " .. stats.dateofbirth},
                {label = "Job: " .. stats.job},
                {label = "Cash: $" .. stats.money},
                {label = "Bank: $" .. stats.bank},
                {label = "Black-Money: $" .. stats.black_money},
                {label = "Total Money: $" .. stats.total_money},
                {label = "Playtime: " .. playtimeFormatted}
            }

            ESX.UI.Menu.Open('default', GetCurrentResourceName(), "stats_menu", {
                title = "Your Stats",
                align = "top-left",
                elements = elements
            }, nil, function(data, menu)
                menu.close()
                menuOpen = false
            end)
        else
            print ("Error: Callback returned no stats")
            clientNotify("Error: Callback returned no stats - Contact a developer")
        end
    end)

    menuOpen = true

    CreateThread(function()
        while menuOpen do
            Wait(1000)
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - Config.General.position.coords)
            if distance > Config.General.position.interactionRadius then
                ESX.UI.Menu.CloseAll()
                menuOpen = false
            end
        end
    end)

end
