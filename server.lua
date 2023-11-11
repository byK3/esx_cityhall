-- DATABASE STUFF & FUNCTIONS
function InitializeDatabase()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `k3_cityhall_social` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(255) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `identifier` (`identifier`)
        );
    ]], {}, function(rowsChanged)
        print("[CITYHALL] - Database initialized")
    end)

    MySQL.Async.execute([[
        ALTER TABLE users 
        ADD IF NOT EXISTS playtime INT NOT NULL DEFAULT 0,
        ADD IF NOT EXISTS kills INT NOT NULL DEFAULT 0,
        ADD IF NOT EXISTS deaths INT NOT NULL DEFAULT 0,
        ADD IF NOT EXISTS kd_ratio FLOAT(5,2) NOT NULL DEFAULT 0.00;
    ]], {}, function(rowsChanged)
        print("[CITYHALL] - 'users' table initialized")
    end)
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `k3_cityhall_marriage` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `player1` VARCHAR(255) NOT NULL,
            `player2` VARCHAR(255) NOT NULL,
            `married_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        );
    ]], {}, function(rowsChanged)
        print("[CITYHALL] - 'k3_cityhall_marriage' table initialized")
    end)

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `k3_playtime_rewards` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(255) NOT NULL,
            `playtime_rewarded` INT NOT NULL,
            `reward_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        );
    ]], {}, function(rowsChanged)
        print("[CITYHALL] - 'k3_playtime_rewards' table initialized")
    end)

    print ("[CITYHALL] - All tables initialized - Ready to go!")
end




CreateThread(function()
    InitializeDatabase()
end)

AddEventHandler('onResourceStart', function(resourceName) --if the script restarts for some reason it should start the timer again
    if resourceName == GetCurrentResourceName() then
        StartAllPlayersPlaytimeTracker()
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.identifier

    if Config.SocialMoney.enable then
        IsPlayerEligibleForSocialMoney(playerId, function(isEligible)
            if isEligible then
                StartSocialMoneyTimer(playerId)
            end
        end)
    end

    StartPlaytimeTracker(playerId, identifier)
    
end)


function hasAppliedForSocialMoney(identifier, cb)
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM k3_cityhall_social WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(count)
        cb(count > 0)
    end)
end


function addRecipientToDatabase(identifier)
    MySQL.Async.execute('INSERT INTO k3_cityhall_social (identifier) VALUES (@identifier)', {
        ['@identifier'] = identifier
    })
end

function removeRecipientFromDatabase(identifier, callback)
    MySQL.Async.execute('DELETE FROM k3_cityhall_social WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(rowsChanged)
        if rowsChanged > 0 then
            callback(true)
        else
            callback(false)
        end
    end)
end


function isJobAllowed(job)
    for _, allowedJob in ipairs(Config.SocialMoney.allowedJobs) do
        if job == allowedJob then
            return true
        end
    end
    return false
end



-- SOCIAL MONEY FUNC / CHECKS

AddEventHandler('esx:setJob', function(playerId, job, lastJob)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local identifier = xPlayer.identifier

    if not isJobAllowed(job.name, Config.SocialMoney.allowedJobs) then
        removeRecipientFromDatabase(identifier, function(removed)
            if removed then
                serverNotify (xPlayer.source, "You are no longer eligible for social money!")
            end
        end)
    end
end)

ESX.RegisterServerCallback('k3_cityhall:checkJobForSocialMoney', function(source, callback)
    local xPlayer = ESX.GetPlayerFromId(source)
    local playerJob = xPlayer.job.name

    if isJobAllowed(playerJob) then
        callback(true)
    else
        callback(false)
    end
end)

function IsPlayerEligibleForSocialMoney(playerId, callback)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local identifier = xPlayer.identifier
    local playerJob = xPlayer.job.name
    local allowedJobs = Config.SocialMoney.allowedJobs

    if isJobAllowed(playerJob, allowedJobs) then
        hasAppliedForSocialMoney(identifier, function(hasApplied)
            callback(hasApplied)
        end)
    else
        removeRecipientFromDatabase(identifier, function(removed)
            if removed then
                callback(false)
            else
                callback(true)
            end
        end)
    end
end


--- SOCIAL MONEY EVENTS

RegisterServerEvent('k3_cityhall:applyForSocialMoney')
AddEventHandler('k3_cityhall:applyForSocialMoney', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local playerJob = xPlayer.job.name
    local identifier = xPlayer.identifier

    if isJobAllowed(playerJob) then
        hasAppliedForSocialMoney(identifier, function(hasApplied)
            if not hasApplied then
                addRecipientToDatabase(identifier)
                serverNotify(xPlayer.source, "You have successfully applied for social money!")
                StartSocialMoneyTimer(xPlayer.source)
            else
                serverNotify(xPlayer.source, "You have already applied for social money!")
            end
        end)
    else
        serverNotify(xPlayer.source, "You are not allowed to use this service!")
    end
end)



RegisterServerEvent('k3_cityhall:collectStoredSocialMoney')
AddEventHandler('k3_cityhall:collectStoredSocialMoney', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    if Config.SocialMoney.money.automaticMode then
        serverNotify(xPlayer.source, string.format("The social money is automatically collected every ~g~%s~s~ minutes.", Config.SocialMoney.money.paymentSchedule))
    else
        if pendingSocialMoney[identifier] and pendingSocialMoney[identifier] > 0 then
            local amount = pendingSocialMoney[identifier]
            xPlayer.addMoney(amount)
            pendingSocialMoney[identifier] = nil

            serverNotify(xPlayer.source, string.format("You collected ~g~$%s~s~ from your social money.", amount))
        else
            serverNotify(xPlayer.source, "You don't have any pending social money.")
        end
    end
end)

RegisterServerEvent('k3_cityhall:endSocialMoney')
AddEventHandler('k3_cityhall:endSocialMoney', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    removeRecipientFromDatabase(identifier, function(hasRemoved)
        if hasRemoved then
            serverNotify(xPlayer.source, "You have successfully ended your social money.")
        else
            serverNotify(xPlayer.source, "You don't have social money.")
        end
    end)
end)




-- SOCIAL MONEY TIMER & MONEY SAVING FUNCTION

local pendingSocialMoney = {}

function StorePendingSocialMoney(identifier, amount)
    pendingSocialMoney[identifier] = (pendingSocialMoney[identifier] or 0) + amount
    serverNotify(source, string.format("You can collect now ~g~$%s~s~ from your social money in CITYHALL", pendingSocialMoney[identifier]))
end


local timers = {}

function StartSocialMoneyTimer(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end 

    local identifier = xPlayer.identifier
    local elapsedTime = 0
    local continueLoop = true

    timers[identifier] = elapsedTime

    CreateThread(function()
        while continueLoop do
            Wait(1000)
            elapsedTime = elapsedTime + 1
            timers[identifier] = elapsedTime

            if elapsedTime >= Config.SocialMoney.money.paymentSchedule * 60 then
                hasAppliedForSocialMoney(identifier, function(hasApplied)
                    if hasApplied then
                        if Config.SocialMoney.money.automaticMode then
                            xPlayer.addAccountMoney('bank', Config.SocialMoney.money.payment)
                            serverNotify(xPlayer.source, string.format("You received ~g~$%s~s~ from your social money.", Config.SocialMoney.money.payment))
                        else
                            StorePendingSocialMoney(identifier, Config.SocialMoney.money.payment)
                            while pendingSocialMoney[identifier] do
                                Wait(5000)
                            end
                        end
                        elapsedTime = 0
                    else
                        continueLoop = false
                    end
                end)
            end
        end
    end)
end

function getRemainingTimeForPlayer(identifier)
    local elapsedTime = timers[identifier] or 0
    local remainingTime = Config.SocialMoney.money.paymentSchedule * 60 - elapsedTime
    return remainingTime
end

function getRemainingTimeFromDatabase(identifier)
    return getRemainingTimeForPlayer(identifier)
end

RegisterServerEvent('k3_cityhall:getRemainingTime')
AddEventHandler('k3_cityhall:getRemainingTime', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    local remainingTime = getRemainingTimeFromDatabase(identifier) 

    TriggerClientEvent('k3_cityhall:receiveRemainingTime', xPlayer.source, remainingTime)
end)




-- NAMECHANGE FUNCTIONS


ESX.RegisterServerCallback('k3_cityhall:getCurrentName', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result and result[1] then
            local firstName = result[1].firstname
            local lastName = result[1].lastname
            cb(firstName, lastName)
        else
            cb(nil, nil)
        end
    end)
end)

RegisterServerEvent('k3_cityhall:changeName')
AddEventHandler('k3_cityhall:changeName', function(newFirstName, newLastName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    local playerMoney = xPlayer.getMoney()

    if playerMoney < Config.Namechange.price then
        serverNotify(xPlayer.source, "You don't have enough money!")
        return
    end

    if Config.Namechange.item.needItem then
        local hasItem = xPlayer.getInventoryItem(Config.Namechange.item.itemName).count > 0
        local itemLabel = Config.Namechange.item.itemLabel
        if not hasItem then
            serverNotify(xPlayer.source, "You also need item: " .. itemLabel)
            return
        end
        xPlayer.removeInventoryItem(Config.Namechange.item.itemName, 1)
    end

    xPlayer.removeMoney(Config.Namechange.price)

    if newFirstName then
        MySQL.Async.execute('UPDATE users SET firstname = @firstname WHERE identifier = @identifier', {
            ['@firstname'] = newFirstName,
            ['@identifier'] = identifier
        })
    end

    if newLastName then
        MySQL.Async.execute('UPDATE users SET lastname = @lastname WHERE identifier = @identifier', {
            ['@lastname'] = newLastName,
            ['@identifier'] = identifier
        })
    end

    serverNotify(xPlayer.source, "You have successfully changed your name. You are now: " .. newFirstName .. " " .. newLastName)
end)




--- PLAYTIME TRACKER & REWARDS

local playerPlaytimes = {}

function StartPlaytimeTracker(playerId, identifier)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    if playerPlaytimes[identifier] then
        playerPlaytimes[identifier].tracking = false
        Wait(100) -- Small delay to ensure the tracking loop exits
    end

    MySQL.Async.fetchScalar('SELECT playtime FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(playtime)
        local tracking = true
        local currentPlaytime = playtime or 0

        playerPlaytimes[identifier] = {
            tracking = tracking,
            playtime = currentPlaytime
        }

        CreateThread(function()
            while tracking do
                Wait(60000)
                currentPlaytime = currentPlaytime + 1

                -- Update in-memory playtime
                playerPlaytimes[identifier].playtime = currentPlaytime

                MySQL.Async.execute('UPDATE users SET playtime = @newPlaytime WHERE identifier = @identifier', {
                    ['@newPlaytime'] = currentPlaytime,
                    ['@identifier'] = identifier
                }, function(rowsChanged)
                    if rowsChanged == 0 then
                        print("Failed to update playtime for: " .. identifier)
                    end
                end)
                
                if Config.PlaytimeRewards.enable then
                    CheckAndGiveRewards(xPlayer.source, identifier)
                end
            end
        end)
    end)
end

function StartAllPlayersPlaytimeTracker()
    local players = ESX.GetExtendedPlayers()

    for _, player in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(player.source)
        local identifier = xPlayer.identifier
        StartPlaytimeTracker(player.source, identifier)
    end
end

AddEventHandler('playerDropped', function(reason)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    
    if xPlayer and playerPlaytimes[xPlayer.identifier] then
        playerPlaytimes[xPlayer.identifier].tracking = false
    end
end)

function CheckAndGiveRewards(playerId, identifier)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playtimeMinutes = playerPlaytimes[identifier] and playerPlaytimes[identifier].playtime or 0

    if not xPlayer then return end

    local rewardedHoursSet = {}

    MySQL.Async.fetchAll('SELECT playtime_rewarded FROM k3_playtime_rewards WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(rewardedPlaytimes)
        for _, row in ipairs(rewardedPlaytimes) do
            rewardedHoursSet[row.playtime_rewarded] = true
        end

        for _, reward in ipairs(Config.PlaytimeRewards.rewards) do
            if playtimeMinutes >= reward.playtime and not rewardedHoursSet[reward.playtime] then
                if reward.type == 'money' then
                    if reward.subtype == 'cash' then
                        xPlayer.addMoney(reward.value)
                        serverNotify(xPlayer.source, "You got rewarded for: " .. reward.playtime .. " minutes. You got: $ " .. reward.value .. " cash")
                    elseif reward.subtype == 'bank' then
                        xPlayer.addAccountMoney('bank', reward.value)
                        serverNotify(xPlayer.source, "You got rewarded for: " .. reward.playtime .. " minutes. You got: $ " .. reward.value .. " bank")
                    elseif reward.subtype == 'black_money' then
                        xPlayer.addAccountMoney('black_money', reward.value)
                        serverNotify(xPlayer.source, "You got rewarded for: " .. reward.playtime .. " minutes. You got: $ " .. reward.value .. " black money")
                    end
                elseif reward.type == 'item' then
                    xPlayer.addInventoryItem(reward.value, reward.count)
                    serverNotify(xPlayer.source, "You got rewarded for: " .. reward.playtime .. " minutes. You got: " .. reward.count .. "x " .. reward.value)
                elseif reward.type == 'weapon' then
                    xPlayer.addWeapon(reward.value, reward.ammo)
                    serverNotify(xPlayer.source, "You got rewarded for: " .. reward.playtime .. " minutes. You got: " .. reward.value .. " with " .. reward.ammo .. " ammo")
                end

                MySQL.Async.execute('INSERT INTO k3_playtime_rewards (identifier, playtime_rewarded) VALUES (@identifier, @playtime)', {
                    ['@identifier'] = identifier,
                    ['@playtime'] = reward.playtime
                })
            end
        end
    end)
end






-- STATS

ESX.RegisterServerCallback('k3_cityhall:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT firstname, lastname, sex, dateofbirth, playtime, kills, deaths, kd_ratio, phone_number, height FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local data = result[1]
            local stats = {
                firstname = data.firstname,
                lastname = data.lastname,
                sex = data.sex,
                dateofbirth = data.dateofbirth,
                height = data.height,
                phone_number = data.phone_number,
                job = xPlayer.job.name,
                job_grade = xPlayer.job.grade_label,
                money = xPlayer.getMoney(),
                bank = xPlayer.getAccount('bank').money,
                black_money = xPlayer.getAccount('black_money').money,
                total_money = xPlayer.getMoney() + xPlayer.getAccount('bank').money + xPlayer.getAccount('black_money').money,
                playtime = data.playtime,
                kills = data.kills,
                deaths = data.deaths,
                kd_ratio = data.kd_ratio,
            }

            checkVehicleOwnership(identifier, function(vehicleCount)
                stats.vehicles = vehicleCount

                checkHouseOwnership(identifier, function(houseCount)
                    stats.houses = houseCount

                    checkMarriageStatus(identifier, function(isMarried, spouseName)
                        stats.isMarried = isMarried
                        stats.spouse = spouseName or "Not married"
                        cb(stats)
                    end)
                end)
            end)
        else
            cb(nil)
        end
    end)
end)

function checkVehicleOwnership(identifier, cb)
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM ' .. Config.Stats.vehicles.tableName .. ' WHERE ' .. Config.Stats.vehicles.ownerColumn .. ' = @identifier', {
        ['@identifier'] = identifier
    }, function(vehicleCount)
        cb(vehicleCount)
    end)
end

function checkHouseOwnership(identifier, cb)
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM ' .. Config.Stats.house.tableName .. ' WHERE ' .. Config.Stats.house.ownerColumn .. ' = @identifier', {
        ['@identifier'] = identifier
    }, function(houseCount)
        cb(houseCount)
    end)
end

function checkMarriageStatus(identifier, cb)
    MySQL.Async.fetchAll('SELECT player1, player2 FROM k3_cityhall_marriage WHERE player1 = @identifier OR player2 = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local spouseIdentifier = (result[1].player1 == identifier) and result[1].player2 or result[1].player1
            MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) as fullname FROM users WHERE identifier = @spouseIdentifier', {
                ['@spouseIdentifier'] = spouseIdentifier
            }, function(spouseName)
                cb(true, spouseName)
            end)
        else
            cb(false)
        end
    end)
end


RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    local victim = ESX.GetPlayerFromId(source)

    if victim then
        AddDeathForPlayer(victim.identifier)
        UpdateKDForPlayer(victim.identifier)
    end

    if data.killedByPlayer then
        local killer = ESX.GetPlayerFromId(data.killerServerId)
        if killer then
            AddKillForPlayer(killer.identifier)
            UpdateKDForPlayer(killer.identifier)
        end
    end
end)


function AddKillForPlayer(identifier)
    MySQL.Async.execute('UPDATE users SET kills = kills + 1 WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
end

function AddDeathForPlayer(identifier)
    MySQL.Async.execute('UPDATE users SET deaths = deaths + 1 WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
end

function UpdateKDForPlayer(identifier)
    MySQL.Async.fetchAll('SELECT kills, deaths FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local kills = result[1].kills
            local deaths = result[1].deaths
            local kd = (deaths == 0) and kills or (kills / deaths)
            
            MySQL.Async.execute('UPDATE users SET kd_ratio = @kd WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
                ['@kd'] = kd
            })
        end
    end)
end

RegisterServerEvent('k3_cityhall:addDeath')
AddEventHandler('k3_cityhall:addDeath', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        AddDeathForPlayer(xPlayer.identifier)
        UpdateKDForPlayer(xPlayer.identifier)
    end
end)

RegisterServerEvent('k3_cityhall:addKill')
AddEventHandler('k3_cityhall:addKill', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        AddKillForPlayer(xPlayer.identifier)
        UpdateKDForPlayer(xPlayer.identifier)
    end
end)



-- MARRIAGE 

function IsPlayerAlreadyMarried(playerIdentifier, callback)
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM k3_cityhall_marriage WHERE player1 = @player OR player2 = @player', {
        ['@player'] = playerIdentifier
    }, function(count)
        callback(count > 0)
    end)
end

function AddMarriageToDatabase(player1, player2, callback)
    MySQL.Async.execute('INSERT INTO k3_cityhall_marriage (player1, player2) VALUES (@player1, @player2)', {
        ['@player1'] = player1,
        ['@player2'] = player2
    }, function(rowsChanged)
        callback(rowsChanged > 0)
    end)
end

function RemoveMarriage(identifier, cb)
    MySQL.Async.execute('DELETE FROM k3_cityhall_marriage WHERE player1 = @identifier OR player2 = @identifier', {
        ['@identifier'] = identifier
    }, function(rowsChanged)
        cb(rowsChanged > 0)
    end)
end

function GetSpouse(identifier, cb)
    MySQL.Async.fetchScalar('SELECT player1 FROM k3_cityhall_marriage WHERE player2 = @identifier UNION SELECT player2 FROM k3_cityhall_marriage WHERE player1 = @identifier', {
        ['@identifier'] = identifier
    }, function(spouseIdentifier)
        cb(spouseIdentifier)
    end)
end


RegisterServerEvent("k3_cityhall:sendMarriageRequest")
AddEventHandler("k3_cityhall:sendMarriageRequest", function(target)
    local sourcePlayer = source
    local xPlayer = ESX.GetPlayerFromId(sourcePlayer)
    local xTarget = ESX.GetPlayerFromId(target)

    if not xTarget or xTarget == -1 then
        print ("[CITYHALL] - Player not found")
        return
    end

    if xPlayer == xTarget then
        serverNotify(xPlayer.source, "You can't marry yourself!")
        return
    end

    IsPlayerAlreadyMarried(xPlayer.identifier, function(isMarried)
        if isMarried then
            serverNotify(xPlayer.source, "You are already married!")
            return
        end

        IsPlayerAlreadyMarried(xTarget.identifier, function(isMarried)
            if isMarried then
                serverNotify(xPlayer.source, "This player is already married!")
                return
            end

            MySQL.Async.fetchAll('SELECT identifier, sex FROM users WHERE identifier IN (@sourceIdentifier, @targetIdentifier)', {
                ['@sourceIdentifier'] = xPlayer.identifier,
                ['@targetIdentifier'] = xTarget.identifier
            }, function(result)
                local sourceSex, targetSex
                for _, row in ipairs(result) do
                    if row.identifier == xPlayer.identifier then
                        sourceSex = row.sex
                    else
                        targetSex = row.sex
                    end
                end

                if not Config.Marriage.general.allowSameGender and sourceSex == targetSex then
                    serverNotify(xPlayer.source, "Same-sex marriages are not allowed.")
                    return
                end

                if Config.Marriage.item.needItem then
                    local itemName = Config.Marriage.item.itemName
                    local item = xPlayer.getInventoryItem(itemName)

                    if not item or item.count <= 0 then
                        serverNotify(xPlayer.source, "You need a " .. Config.Marriage.item.itemLabel .. " to get married.")
                        return
                    end
                end

                TriggerClientEvent('k3_cityhall:receiveMarriageRequest', xTarget.source, xPlayer.source, xPlayer.getName())

            end)
        end)
    end)
end)


RegisterServerEvent('k3_cityhall:acceptMarriage')
AddEventHandler('k3_cityhall:acceptMarriage', function(requesterId)
    local sourcePlayer = source
    local xPlayer = ESX.GetPlayerFromId(sourcePlayer)
    local xRequester = ESX.GetPlayerFromId(requesterId)

    if not xRequester then
        serverNotify(xPlayer.source, "The player who proposed is no longer online.")
        return
    end

    IsPlayerAlreadyMarried(xRequester.identifier, function(isRequesterMarried)
        if isRequesterMarried then
            serverNotify(xRequester.source, "You are already married!")
            return
        end

        IsPlayerAlreadyMarried(xPlayer.identifier, function(isTargetMarried)
            if isTargetMarried then
                serverNotify(xPlayer.source, "You are already married!")
                return
            end

            local canProceed = true

            -- item check
            if Config.Marriage.item.needItem then
                local itemName = Config.Marriage.item.itemName
                local item = xRequester.getInventoryItem(itemName)

                if not item or item.count <= 0 then
                    serverNotify(xRequester.source, "You no longer have the " .. Config.Marriage.item.itemLabel .. " required for marriage.")
                    canProceed = false
                end
            end

            -- money check
            local marriagePrice = Config.Marriage.cost.marriagePrice
            if xRequester.getMoney() < marriagePrice then
                serverNotify(xRequester.source, "You don't have enough money to get married.")
                canProceed = false
            end

            -- proceed
            if canProceed then
                AddMarriageToDatabase(xRequester.identifier, xPlayer.identifier, function(success)
                    if success then
                        if Config.Marriage.item.needItem then
                            xRequester.removeInventoryItem(Config.Marriage.item.itemName, 1)
                        end
                        xRequester.removeMoney(marriagePrice)
                        serverNotify(xRequester.source, "Congratulations! You are now married to " .. xPlayer.getName() .. ".")
                        serverNotify(xPlayer.source, "Congratulations! You are now married to " .. xRequester.getName() .. ".")

                        if Config.Marriage.notifyAll then
                            local message = string.format(Config.Marriage.notifyAllmsg, xRequester.getName(), xPlayer.getName())
                            serverNotify(-1, message)
                        end
                    else
                        serverNotify(xRequester.source, "There was an error processing the marriage. Please try again.")
                        serverNotify(xPlayer.source, "There was an error processing the marriage. Please try again.")
                        print ("[CITYHALL] - Error processing marriage between " .. xRequester.getName() .. " and " .. xPlayer.getName() .. " || Contact the developer!")
                    end
                end)
            end
        end)
    end)
end)


RegisterServerEvent('k3_cityhall:declineMarriage')
AddEventHandler('k3_cityhall:declineMarriage', function(requesterId)
    local sourcePlayer = source
    local xPlayer = ESX.GetPlayerFromId(sourcePlayer)
    local xRequester = ESX.GetPlayerFromId(requesterId)
    serverNotify(xRequester.source, xPlayer.getName() .. " declined your marriage request.")
end)

ESX.RegisterServerCallback('k3_cityhall:getSpouseName', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT player1, player2 FROM k3_cityhall_marriage WHERE player1 = @identifier OR player2 = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local spouseIdentifier = (result[1].player1 == identifier) and result[1].player2 or result[1].player1

            MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) as fullname FROM users WHERE identifier = @spouseIdentifier', {
                ['@spouseIdentifier'] = spouseIdentifier
            }, function(spouseName)
                if spouseName then
                    cb(spouseName)
                else
                    cb(nil)
                end
            end)
        else
            cb(nil)
        end
    end)
end)


RegisterServerEvent('k3_cityhall:requestDivorce')
AddEventHandler('k3_cityhall:requestDivorce', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    IsPlayerAlreadyMarried(identifier, function(isMarried)
        if isMarried then
            GetSpouse(identifier, function(spouseIdentifier)
                RemoveMarriage(identifier, function(success)
                    if success then
                        serverNotify(xPlayer.source, "You have divorced your partner.")
                        
                        local xSpouse = ESX.GetPlayerFromIdentifier(spouseIdentifier)
                        if xSpouse then
                            serverNotify(xSpouse.source, "Your partner has divorced you.")
                        end
                    else
                        print ("[CITYHALL] - Error processing divorce between " .. xPlayer.getName() .. " and " .. xSpouse.getName() .. " || Contact the developer!")
                        serverNotify(xPlayer.source, "There was an error processing the divorce. Please try again.")
                    end
                end)
            end)
        else
            serverNotify(xPlayer.source, "You are not married.")
        end
    end)
end)

RegisterServerEvent('k3_cityhall:getMarriageInfo')
AddEventHandler('k3_cityhall:getMarriageInfo', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT player1, player2, DATE_FORMAT(married_at, "%d-%m-%Y") as marriedDate FROM k3_cityhall_marriage WHERE player1 = @identifier OR player2 = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local spouseIdentifier = (result[1].player1 == identifier) and result[1].player2 or result[1].player1
            local marriedDate = result[1].marriedDate

            MySQL.Async.fetchScalar('SELECT CONCAT(firstname, " ", lastname) as fullname FROM users WHERE identifier = @identifier', {
                ['@identifier'] = spouseIdentifier
            }, function(spouseName)
                if spouseName then
                    serverNotify (xPlayer.source, "You are married to " .. spouseName .. " since " .. marriedDate .. ".")
                else
                    print ("[CITYHALL] - Error fetching spouse's name for " .. xPlayer.getName() .. " || Contact the developer!")
                    serverNotify (xPlayer.source, "Error fetching spouse's name - Try again later.")
                end
            end)
        else
            serverNotify (xPlayer.source, "You are not married.")
        end
    end)
end)


-- LEADERBOARD

ESX.RegisterServerCallback('k3_cityhall:getTopRichest', function(source, cb)
    if Config.Leaderboard.enable then
        local limit = Config.Leaderboard.leaderboard.limit
        local sortBy = Config.Leaderboard.leaderboard.sortBy
        local query = ''

        if Config.Leaderboard.ignoreList.richestPlayers then
            local ignoredIdentifiers = "'" .. table.concat(Config.Leaderboard.ignoreIdentifiers, "','") .. "'"

            if sortBy == "bank" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.bank")) AS bank FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.bank")) AS UNSIGNED) DESC LIMIT @limit'
            elseif sortBy == "money" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.money")) AS money FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.money")) AS UNSIGNED) DESC LIMIT @limit'
            elseif sortBy == "black_money" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.black_money")) AS black_money FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.black_money")) AS UNSIGNED) DESC LIMIT @limit'
            end
        else
            if sortBy == "bank" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.bank")) AS bank FROM users ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.bank")) AS UNSIGNED) DESC LIMIT @limit'
            elseif sortBy == "money" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.money")) AS money FROM users ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.money")) AS UNSIGNED) DESC LIMIT @limit'
            elseif sortBy == "black_money" then
                query = 'SELECT firstname, lastname, JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.black_money")) AS black_money FROM users ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(accounts, "$.black_money")) AS UNSIGNED) DESC LIMIT @limit'
            end
        end

        if query ~= '' then
            MySQL.Async.fetchAll(query, {
                ['@limit'] = limit
            }, function(result)
                cb(result)
            end)
        else
            cb(nil)
        end
    else
        cb(nil)
    end
end)

ESX.RegisterServerCallback('k3_cityhall:getTopPlaytime', function(source, cb)
    local limit = Config.Leaderboard.leaderboard.limit
    local query = ''

    if Config.Leaderboard.ignoreList.mostPlaytime then
        local ignoredIdentifiers = "'" .. table.concat(Config.Leaderboard.ignoreIdentifiers, "','") .. "'"
        query = 'SELECT firstname, lastname, playtime FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY playtime DESC LIMIT @limit'
    else
        query = 'SELECT firstname, lastname, playtime FROM users ORDER BY playtime DESC LIMIT @limit'
    end

    if query ~= '' then
        MySQL.Async.fetchAll(query, {
            ['@limit'] = limit
        }, function(results)
            cb(results)
        end)
    else
        cb(nil)
    end



end)

ESX.RegisterServerCallback('k3_cityhall:getTopKills', function(source, cb)
    local limit = Config.Leaderboard.leaderboard.limit
    local query = ''


    if Config.Leaderboard.ignoreList.mostKills then
        local ignoredIdentifiers = "'" .. table.concat(Config.Leaderboard.ignoreIdentifiers, "','") .. "'"
        query = 'SELECT firstname, lastname, kills FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY kills DESC LIMIT @limit'
    else
        query = 'SELECT firstname, lastname, kills FROM users ORDER BY kills DESC LIMIT @limit'
    end

    if query ~= '' then
        MySQL.Async.fetchAll(query, {
            ['@limit'] = limit
        }, function(results)
            cb(results)
        end)
    else
        cb(nil)
    end
end)

ESX.RegisterServerCallback('k3_cityhall:getTopDeaths', function(source, cb)
    local limit = Config.Leaderboard.leaderboard.limit
    local query = ''


    if Config.Leaderboard.ignoreList.mostDeaths then
        local ignoredIdentifiers = "'" .. table.concat(Config.Leaderboard.ignoreIdentifiers, "','") .. "'"
        query = 'SELECT firstname, lastname, deaths FROM users WHERE identifier NOT IN (' .. ignoredIdentifiers .. ') ORDER BY deaths DESC LIMIT @limit'
    else
        query = 'SELECT firstname, lastname, deaths FROM users ORDER BY deaths DESC LIMIT @limit'
    end


    if query ~= '' then
        MySQL.Async.fetchAll(query, {
            ['@limit'] = limit
        }, function(results)
            cb(results)
        end)
    else
        cb(nil)
    end

end)



--- EXPORTS

function GetPlayerKills(identifier)
    local kills = MySQL.Sync.fetchScalar('SELECT kills FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
    return kills or 0
end

function GetPlayerDeaths(identifier)
    local deaths = MySQL.Sync.fetchScalar('SELECT deaths FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
    return deaths or 0
end

function GetPlayerKDRatio(identifier)
    local kd_ratio = MySQL.Sync.fetchScalar('SELECT kd_ratio FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
    return kd_ratio or 0
end

function GetPlayerPlaytime(identifier)
    local playtime = MySQL.Sync.fetchScalar('SELECT playtime FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
    return playtime or 0
end

function ConverToKD(identifier)
    local kills = GetPlayerKills(identifier)
    local deaths = GetPlayerDeaths(identifier)
    local kd = (deaths == 0) and kills or (kills / deaths)

    return kd
end

exports('GetPlayerKills', GetPlayerKills)
exports('GetPlayerDeaths', GetPlayerDeaths)
exports('GetPlayerKDRatio', GetPlayerKDRatio)
exports('GetPlayerPlaytime', GetPlayerPlaytime)
exports('ConverToKD', ConverToKD)
