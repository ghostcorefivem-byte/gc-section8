--[[
    gc-section8 | server/bridge.lua
    Server-side wrappers for multi-framework / multi-inventory support
]]

local fw = GCBridge.Framework()
local inv = GCBridge.Inventory()

-- ─────────────────────────────────────────────────
--  FRAMEWORK WRAPPERS
-- ─────────────────────────────────────────────────

function Bridge_GetPlayer(source)
    if fw == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayer(source)
    elseif fw == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        return ESX.GetPlayerFromId(source)
    end
end

function Bridge_GetCitizenId(player)
    if fw == 'qbcore' then
        return player.PlayerData.citizenid
    elseif fw == 'esx' then
        return player.identifier
    end
end

function Bridge_GetFullName(player)
    if fw == 'qbcore' then
        local c = player.PlayerData.charinfo
        return c.firstname .. ' ' .. c.lastname
    elseif fw == 'esx' then
        return player.getName()
    end
end

function Bridge_GetJob(player)
    if fw == 'qbcore' then
        return player.PlayerData.job and player.PlayerData.job.name or 'unemployed'
    elseif fw == 'esx' then
        return player.job and player.job.name or 'unemployed'
    end
end

function Bridge_GetJobOnDuty(player)
    if fw == 'qbcore' then
        return player.PlayerData.job and player.PlayerData.job.onduty or false
    elseif fw == 'esx' then
        return true -- ESX has no duty toggle natively
    end
end

function Bridge_GetBankMoney(player)
    if fw == 'qbcore' then
        return player.PlayerData.money['bank'] or 0
    elseif fw == 'esx' then
        return player.getAccount('bank').money or 0
    end
end

function Bridge_RemoveMoney(player, amount, reason)
    if fw == 'qbcore' then
        player.Functions.RemoveMoney('bank', amount, reason or 'gc-section8')
    elseif fw == 'esx' then
        player.removeAccountMoney('bank', amount)
    end
end

function Bridge_HasPermission(source, perm)
    if fw == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.HasPermission(source, perm)
    elseif fw == 'esx' then
        return IsPlayerAceAllowed(source, perm)
    end
end

function Bridge_GetAllPlayers()
    if fw == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayers()
    elseif fw == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        local players = ESX.GetPlayers()
        return players
    end
end

-- ─────────────────────────────────────────────────
--  INVENTORY WRAPPERS
-- ─────────────────────────────────────────────────

function Bridge_GetItem(source, itemName)
    if inv == 'ox_inventory' then
        local item = exports['ox_inventory']:GetItem(source, itemName, nil, false)
        return item and item.count and item.count > 0
    elseif inv == 'qb-inventory' then
        local player = Bridge_GetPlayer(source)
        if not player then return false end
        local item = player.Functions.GetItemByName(itemName)
        return item and item.amount and item.amount > 0
    end
    return false
end

function Bridge_GetItemWithMeta(source, itemName)
    if inv == 'ox_inventory' then
        return exports['ox_inventory']:GetItem(source, itemName, nil, false)
    elseif inv == 'qb-inventory' then
        local player = Bridge_GetPlayer(source)
        if not player then return nil end
        return player.Functions.GetItemByName(itemName)
    end
    return nil
end

function Bridge_AddItem(source, itemName, count, metadata)
    if inv == 'ox_inventory' then
        return exports['ox_inventory']:AddItem(source, itemName, count, metadata)
    elseif inv == 'qb-inventory' then
        local player = Bridge_GetPlayer(source)
        if not player then return false end
        return player.Functions.AddItem(itemName, count, false, metadata)
    end
    return false
end

function Bridge_RemoveItem(source, itemName, count)
    if inv == 'ox_inventory' then
        return exports['ox_inventory']:RemoveItem(source, itemName, count)
    elseif inv == 'qb-inventory' then
        local player = Bridge_GetPlayer(source)
        if not player then return false end
        return player.Functions.RemoveItem(itemName, count)
    end
    return false
end
