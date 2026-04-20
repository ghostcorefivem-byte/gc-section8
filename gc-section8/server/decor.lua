-- =============================================
-- gc-section8 | server/decor.lua
-- Server-authoritative decoration system
-- Place → broadcast → prompt payment → confirm or rollback
-- =============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Pending payments: decorId -> { src, price, citizenid }
-- Saved here between placeDecor and confirmDecorPayment
local pendingPayments = {}

-- =============================================
-- HELPER: GET TENANT UNIT
-- =============================================
local function getTenantUnit(citizenid, cb)
    MySQL.query(
        'SELECT u.id, u.label FROM gc_section8_units u INNER JOIN gc_section8_rent r ON r.unit_id = u.id WHERE r.citizenid = ? LIMIT 1',
        { citizenid },
        function(result)
            cb(result and result[1] or nil)
        end
    )
end

-- =============================================
-- HELPER: GET DECOR COUNT FOR UNIT
-- =============================================
local function getDecorCount(unitId, cb)
    MySQL.query('SELECT COUNT(*) as cnt FROM gc_section8_decor WHERE unit_id = ? AND pending = 0', { unitId }, function(result)
        cb(result and result[1] and result[1].cnt or 0)
    end)
end

-- =============================================
-- HELPER: VALIDATE COORDS
-- =============================================
local function validCoords(x, y, z)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return false end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 1000 then return false end
    return true
end

-- =============================================
-- OPEN DECOR MENU
-- =============================================
RegisterNetEvent('gc-section8:server:openDecorMenu', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    getTenantUnit(Player.PlayerData.citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Section 8', description = 'You must be a tenant to decorate.', type = 'error' })
            return
        end
        getDecorCount(unit.id, function(count)
            TriggerClientEvent('gc-section8:client:openDecorMenu', src, {
                props        = Config.DecorProps,
                currentCount = count,
                maxProps     = Config.DecorMaxProps,
            })
        end)
    end)
end)

-- =============================================
-- PLACE DECOR
-- Saves with pending=1, broadcasts to all clients,
-- then asks client to pay. No money taken yet.
-- =============================================
RegisterNetEvent('gc-section8:server:placeDecor', function(data)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    -- Validate model is in config
    local validProp = nil
    for _, p in ipairs(Config.DecorProps) do
        if p.model == data.model then validProp = p break end
    end
    if not validProp then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Invalid prop.', type = 'error' })
        return
    end

    -- Validate coords
    if not validCoords(data.x, data.y, data.z) then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Invalid placement.', type = 'error' })
        return
    end

    getTenantUnit(citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Not a Section 8 tenant.', type = 'error' })
            return
        end

        getDecorCount(unit.id, function(count)
            if count >= Config.DecorMaxProps then
                TriggerClientEvent('ox_lib:notify', src, {
                    title       = 'Decor',
                    description = ('Prop limit reached (%s/%s). Remove something first.'):format(count, Config.DecorMaxProps),
                    type        = 'error'
                })
                return
            end

            -- Save as pending (pending=1 means not yet paid, excluded from count/load)
            MySQL.insert(
                'INSERT INTO gc_section8_decor (unit_id, citizenid, model, x, y, z, heading, pending) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
                { unit.id, citizenid, data.model, data.x, data.y, data.z, data.heading or 0.0 },
                function(insertId)
                    if not insertId then
                        TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Database error. Try again.', type = 'error' })
                        return
                    end

                    -- Track pending payment
                    pendingPayments[insertId] = {
                        src        = src,
                        price      = validProp.price,
                        citizenid  = citizenid,
                        label      = validProp.label,
                    }

                    -- Broadcast prop to all clients so they see it immediately
                    local decorData = {
                        id      = insertId,
                        unit_id = unit.id,
                        model   = data.model,
                        x       = data.x,
                        y       = data.y,
                        z       = data.z,
                        heading = data.heading or 0.0,
                    }
                    TriggerClientEvent('gc-section8:client:spawnDecorProp', -1, decorData)

                    -- Ask client to pay
                    TriggerClientEvent('gc-section8:client:promptPayment', src, insertId, validProp.label, validProp.price)
                end
            )
        end)
    end)
end)

-- =============================================
-- CONFIRM PAYMENT (client chose bank or cash)
-- =============================================
RegisterNetEvent('gc-section8:server:confirmDecorPayment', function(decorId, payMethod)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(decorId) ~= 'number' then return end
    if payMethod ~= 'bank' and payMethod ~= 'cash' then return end

    local pending = pendingPayments[decorId]
    if not pending or pending.src ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'No pending payment found.', type = 'error' })
        return
    end

    -- Check player actually has the money
    local money = Player.PlayerData.money[payMethod]
    if money < pending.price then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Decor',
            description = ('Not enough %s. Need $%s. Placement removed.'):format(payMethod, pending.price),
            type        = 'error'
        })
        -- Remove the pending prop since they can't pay
        MySQL.update('DELETE FROM gc_section8_decor WHERE id = ?', { decorId })
        TriggerClientEvent('gc-section8:client:removeDecorProp', -1, decorId)
        pendingPayments[decorId] = nil
        return
    end

    -- Charge and confirm
    Player.Functions.RemoveMoney(payMethod, pending.price, 'section8-decor')
    MySQL.update('UPDATE gc_section8_decor SET pending = 0 WHERE id = ?', { decorId }, function()
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Decor',
            description = ('$%s charged from %s. Enjoy your %s!'):format(pending.price, payMethod, pending.label),
            type        = 'success'
        })
        pendingPayments[decorId] = nil
    end)
end)

-- =============================================
-- CANCEL PAYMENT (player dismissed dialog)
-- Removes the prop from DB and all clients
-- =============================================
RegisterNetEvent('gc-section8:server:cancelDecorPayment', function(decorId)
    local src = source
    if type(decorId) ~= 'number' then return end

    local pending = pendingPayments[decorId]
    if not pending or pending.src ~= src then return end

    MySQL.update('DELETE FROM gc_section8_decor WHERE id = ? AND pending = 1', { decorId }, function()
        TriggerClientEvent('gc-section8:client:removeDecorProp', -1, decorId)
        pendingPayments[decorId] = nil
    end)
end)

-- =============================================
-- EDIT / REPOSITION DECOR
-- No extra charge — just updates coords
-- =============================================
RegisterNetEvent('gc-section8:server:editDecor', function(decorId, x, y, z, heading)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if type(decorId) ~= 'number' then return end
    if not validCoords(x, y, z) then return end

    getTenantUnit(citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Not a tenant.', type = 'error' })
            return
        end

        -- Make sure this decor belongs to this unit and is not pending
        MySQL.query('SELECT id FROM gc_section8_decor WHERE id = ? AND unit_id = ? AND pending = 0', { decorId, unit.id }, function(result)
            if not result or not result[1] then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Item not found in your unit.', type = 'error' })
                return
            end

            MySQL.update('UPDATE gc_section8_decor SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?',
                { x, y, z, heading or 0.0, decorId },
                function()
                    TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Furniture repositioned!', type = 'success' })
                    -- Update prop position for all clients
                    TriggerClientEvent('gc-section8:client:updateDecorProp', -1, decorId, x, y, z, heading or 0.0)
                end
            )
        end)
    end)
end)

-- =============================================
-- REMOVE SINGLE DECOR ITEM
-- =============================================
RegisterNetEvent('gc-section8:server:removeDecor', function(decorId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if type(decorId) ~= 'number' then return end

    getTenantUnit(citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Not a tenant.', type = 'error' })
            return
        end

        MySQL.query('SELECT id FROM gc_section8_decor WHERE id = ? AND unit_id = ? AND pending = 0', { decorId, unit.id }, function(result)
            if not result or not result[1] then
                TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Item not found.', type = 'error' })
                return
            end

            MySQL.update('DELETE FROM gc_section8_decor WHERE id = ?', { decorId }, function()
                TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Furniture removed.', type = 'success' })
                TriggerClientEvent('gc-section8:client:removeDecorProp', -1, decorId)
            end)
        end)
    end)
end)

-- =============================================
-- CLEAR ALL DECOR FOR TENANT'S UNIT
-- =============================================
RegisterNetEvent('gc-section8:server:clearAllDecor', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    getTenantUnit(citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Not a tenant.', type = 'error' })
            return
        end

        MySQL.update('DELETE FROM gc_section8_decor WHERE unit_id = ? AND pending = 0', { unit.id }, function()
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'All furniture cleared.', type = 'success' })
            TriggerClientEvent('gc-section8:client:clearUnitDecor', -1)
        end)
    end)
end)

-- =============================================
-- CLIENT REQUESTS DECOR LOAD (on join / restart)
-- Only loads confirmed (non-pending) props
-- =============================================
RegisterNetEvent('gc-section8:server:requestDecorLoad', function()
    local src = source
    MySQL.query('SELECT * FROM gc_section8_decor WHERE pending = 0 ORDER BY unit_id ASC', {}, function(result)
        TriggerClientEvent('gc-section8:client:loadDecor', src, result or {})
    end)
end)

-- =============================================
-- GET MY DECOR (for manage menu)
-- =============================================
RegisterNetEvent('gc-section8:server:getMyDecor', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    getTenantUnit(citizenid, function(unit)
        if not unit then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Decor', description = 'Not a tenant.', type = 'error' })
            return
        end

        MySQL.query('SELECT * FROM gc_section8_decor WHERE unit_id = ? AND pending = 0', { unit.id }, function(result)
            TriggerClientEvent('gc-section8:client:receiveMyDecor', src, result or {}, Config.DecorProps)
        end)
    end)
end)

-- =============================================
-- BROADCAST ALL CONFIRMED DECOR
-- =============================================
local function broadcastAllDecor()
    MySQL.query('SELECT * FROM gc_section8_decor WHERE pending = 0 ORDER BY unit_id ASC', {}, function(result)
        TriggerClientEvent('gc-section8:client:loadDecor', -1, result or {})
    end)
end

-- =============================================
-- ON RESOURCE START
-- =============================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Clean up any props that were left pending from a previous session
    MySQL.update('DELETE FROM gc_section8_decor WHERE pending = 1', {})
    SetTimeout(8000, function()
        broadcastAllDecor()
    end)
end)

-- =============================================
-- EVICTION HOOK: CLEAR DECOR WHEN TENANT EVICTED
-- Call TriggerEvent('gc-section8:server:evictionClearDecor', unitId) from sv_main
-- =============================================
AddEventHandler('gc-section8:server:evictionClearDecor', function(unitId)
    if not unitId then return end
    MySQL.update('DELETE FROM gc_section8_decor WHERE unit_id = ?', { unitId }, function()
        broadcastAllDecor()
    end)
end)
