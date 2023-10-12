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
        ALTER TABLE users ADD IF NOT EXISTS playtime INT NOT NULL DEFAULT 0;
    ]], {}, function(rowsChanged)
        print("[CITYHALL] - Playtime column added to 'users' table")
    end)
end
CreateThread(function()
    InitializeDatabase()
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.identifier

    -- Social Money Check
    IsPlayerEligibleForSocialMoney(playerId, function(isEligible)
        if isEligible then
            StartSocialMoneyTimer(playerId)
        end
    end)

    StartPlaytimeTracker(playerId, xPlayer.identifier)
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
                TriggerClientEvent('esx:showNotification', playerId, "You are no longer eligible for social money.")
            else
                print ("[CITYHALL] - Error removing player from database || Name: " .. xPlayer.name .. " || Identifier: " .. identifier .. " || New Job: " .. job.name .. " || Last Job: " .. lastJob.name)
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
                print ("[CITYHALL] - Error removing player from database || Name: " .. xPlayer.name .. " || Identifier: " .. identifier .. " || Job: " .. playerJob)
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
        serverNotify(source, string.format("The social money is automatically collected every ~g~%s~s~ minutes.", Config.SocialMoney.money.paymentSchedule))
    else
        if pendingSocialMoney[identifier] and pendingSocialMoney[identifier] > 0 then
            local amount = pendingSocialMoney[identifier]
            xPlayer.addMoney(amount)
            pendingSocialMoney[identifier] = nil

            serverNotify(source, string.format("You collected ~g~$%s~s~ from your social money.", amount))
        else
            serverNotify(source, "You don't have any pending social money.")
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

    TriggerClientEvent('k3_cityhall:receiveRemainingTime', source, remainingTime)
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

ESX.RegisterServerCallback('k3_cityhall:canChangeName', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if Config.Namechange.item.needItem then
        local hasItem = xPlayer.getInventoryItem(Config.Namechange.item.itemName).count > 0
        cb(hasItem)
    else
        local playerMoney = xPlayer.getMoney()
        if playerMoney >= Config.Namechange.price then
            xPlayer.removeMoney(Config.Namechange.price)
            cb(true)
        else
            cb(false)
        end
    end
end)


RegisterServerEvent('k3_cityhall:changeName')
AddEventHandler('k3_cityhall:changeName', function(newFirstName, newLastName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    if Config.Namechange.item.needItem then
        local hasItem = xPlayer.getInventoryItem(Config.Namechange.item.itemName).count > 0
        local itemLabel = Config.Namechange.item.itemLabel
        if not hasItem then
            serverNotify(source, "You also need item: " .. itemLabel)
            return
        end
        xPlayer.removeInventoryItem(Config.Namechange.item.itemName, 1)
    else
        local playerMoney = xPlayer.getMoney()
        if playerMoney < Config.Namechange.price then
            serverNotify(source, "You don't have enough money!")
            return
        end
        xPlayer.removeMoney(Config.Namechange.price)
    end

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

    serverNotify(source, "You have successfully changed your name. You are now: " .. newFirstName .. " " .. newLastName)
end)



--- PLAYTIME TRACKER

local playerPlaytimes = {}
local playerTimers = {}

function StartPlaytimeTracker(playerId, identifier)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    if not playerTimers[identifier] then
        playerTimers[identifier] = true

        MySQL.Async.fetchScalar('SELECT playtime FROM users WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(playtime)
            playerPlaytimes[identifier] = playtime or 0

            CreateThread(function()
                while playerTimers[identifier] do
                    Wait(60000)
                    playerPlaytimes[identifier] = playerPlaytimes[identifier] + 1

                    MySQL.Async.execute('UPDATE users SET playtime = @newPlaytime WHERE identifier = @identifier', {
                        ['@newPlaytime'] = playerPlaytimes[identifier],
                        ['@identifier'] = identifier
                    })
                end
            end)
        end)
    end
end

AddEventHandler('playerDropped', function(reason)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        playerTimers[xPlayer.identifier] = nil
    end
end)


ESX.RegisterServerCallback('k3_cityhall:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT firstname, lastname, sex, dateofbirth, playtime FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local data = result[1]
            local stats = {
                firstname = data.firstname,
                lastname = data.lastname,
                sex = data.sex,
                dateofbirth = data.dateofbirth,
                job = xPlayer.job.name,
                money = xPlayer.getMoney(),
                bank = xPlayer.getAccount('bank').money,
                black_money = xPlayer.getAccount('black_money').money,
                total_money = xPlayer.getMoney() + xPlayer.getAccount('bank').money + xPlayer.getAccount('black_money').money,
                playtime = data.playtime,
            }
            cb(stats)
        else
            cb(nil)
        end
    end)
end)
