--[[
    gc-section8 | server/snap_shop.lua
    PIN management and SNAP purchase validation.
]]

-- ─────────────────────────────────────────────────
--  PIN UTILITIES
-- ─────────────────────────────────────────────────

local function hashPin(pin, citizenid)
    local salt   = citizenid:sub(-4)
    local result = ''
    for i = 1, #pin do
        local p = pin:sub(i, i):byte()
        local s = salt:sub(((i - 1) % #salt) + 1, ((i - 1) % #salt) + 1):byte()
        result  = result .. string.format('%02x', p ~ s)
    end
    return result
end

-- ─────────────────────────────────────────────────
--  VERIFY CARD
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:verifyCard', function(storeId, storeLabel)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    local citizenid = Bridge_GetCitizenId(player)
    local hasCard   = Bridge_GetItemWithMeta(src, Config.SNAP.Item)

    if not hasCard or (hasCard.count or 0) == 0 then
        TriggerClientEvent('gc-section8:client:snapDenied', src, 'You do not have a Link Card. Apply at the Section 8 office.')
        return
    end

    MySQL.query('SELECT balance, pin_hash FROM gc_section8_snap WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'No SNAP account found. Contact the Section 8 office.')
            return
        end
        local isFirstTime = (result[1].pin_hash == nil or result[1].pin_hash == '')
        TriggerClientEvent('gc-section8:client:snapPinPrompt', src, storeId, storeLabel, isFirstTime)
    end)
end)

-- ─────────────────────────────────────────────────
--  SET PIN (first time)
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:setPin', function(pin, storeId, storeLabel)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    if not pin or not pin:match('^%d%d%d%d$') then
        TriggerClientEvent('gc-section8:client:snapDenied', src, 'Invalid PIN format.')
        return
    end

    local citizenid = Bridge_GetCitizenId(player)
    local hashed    = hashPin(pin, citizenid)

    MySQL.update('UPDATE gc_section8_snap SET pin_hash = ? WHERE citizenid = ?', { hashed, citizenid }, function(rows)
        if rows and rows > 0 then
            MySQL.query('SELECT balance FROM gc_section8_snap WHERE citizenid = ?', { citizenid }, function(result)
                if result and result[1] then
                    TriggerClientEvent('gc-section8:client:openSnapMenu', src, result[1].balance, storeLabel)
                end
            end)
        else
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'Error saving PIN. Try again.')
        end
    end)
end)

-- ─────────────────────────────────────────────────
--  VERIFY PIN
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:verifyPin', function(pin, storeId, storeLabel)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    if not pin or not pin:match('^%d%d%d%d$') then
        TriggerClientEvent('gc-section8:client:snapDenied', src, 'Invalid PIN format.')
        return
    end

    local citizenid = Bridge_GetCitizenId(player)
    local hashed    = hashPin(pin, citizenid)

    MySQL.query('SELECT balance, pin_hash, pin_attempts FROM gc_section8_snap WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'SNAP account not found.')
            return
        end

        local record = result[1]

        if (record.pin_attempts or 0) >= 5 then
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'Card locked — too many failed attempts. Visit the Section 8 office.')
            return
        end

        if record.pin_hash ~= hashed then
            local attempts  = (record.pin_attempts or 0) + 1
            local remaining = 5 - attempts
            MySQL.update('UPDATE gc_section8_snap SET pin_attempts = ? WHERE citizenid = ?', { attempts, citizenid })
            TriggerClientEvent('gc-section8:client:snapDenied', src, ('Incorrect PIN. %s attempt(s) remaining.'):format(remaining))
            return
        end

        MySQL.update('UPDATE gc_section8_snap SET pin_attempts = 0 WHERE citizenid = ?', { citizenid })
        TriggerClientEvent('gc-section8:client:openSnapMenu', src, record.balance, storeLabel)
    end)
end)

-- ─────────────────────────────────────────────────
--  CHANGE PIN
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:changePin', function(oldPin, newPin)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    if not oldPin or not oldPin:match('^%d%d%d%d$') then
        TriggerClientEvent('gc-section8:client:pinChangeResult', src, false, 'Invalid PIN format.')
        return
    end
    if not newPin or not newPin:match('^%d%d%d%d$') then
        TriggerClientEvent('gc-section8:client:pinChangeResult', src, false, 'New PIN must be 4 digits.')
        return
    end

    local citizenid = Bridge_GetCitizenId(player)
    local oldHashed = hashPin(oldPin, citizenid)
    local newHashed = hashPin(newPin, citizenid)

    MySQL.query('SELECT pin_hash, pin_attempts FROM gc_section8_snap WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:pinChangeResult', src, false, 'SNAP account not found.')
            return
        end

        local record = result[1]

        if (record.pin_attempts or 0) >= 5 then
            TriggerClientEvent('gc-section8:client:pinChangeResult', src, false, 'Card is locked. Visit the Section 8 office.')
            return
        end

        if record.pin_hash ~= oldHashed then
            local attempts = (record.pin_attempts or 0) + 1
            MySQL.update('UPDATE gc_section8_snap SET pin_attempts = ? WHERE citizenid = ?', { attempts, citizenid })
            TriggerClientEvent('gc-section8:client:pinChangeResult', src, false, 'Current PIN is incorrect.')
            return
        end

        MySQL.update('UPDATE gc_section8_snap SET pin_hash = ?, pin_attempts = 0 WHERE citizenid = ?', { newHashed, citizenid })
        TriggerClientEvent('gc-section8:client:pinChangeResult', src, true, 'PIN updated successfully.')
    end)
end)

-- ─────────────────────────────────────────────────
--  PURCHASE WITH PIN
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:purchaseWithPin', function(itemName, itemLabel, qty, totalCost, pin)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    qty       = math.floor(tonumber(qty) or 0)
    totalCost = math.floor(tonumber(totalCost) or 0)

    if qty < 1 or qty > 100 then return end
    if totalCost < 1 or totalCost > 99999 then return end
    if not pin or not pin:match('^%d%d%d%d$') then
        TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, 0, 'Invalid PIN format.')
        return
    end

    -- Validate item and price server-side
    local validItem = false
    for _, shopItem in ipairs(SnapShopConfig.Items) do
        if shopItem.item == itemName and (qty * shopItem.price) == totalCost then
            validItem = true
            break
        end
    end
    if not validItem then
        TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, 0, 'Invalid item or price mismatch.')
        return
    end

    local hasCard = Bridge_GetItemWithMeta(src, Config.SNAP.Item)
    if not hasCard or (hasCard.count or 0) == 0 then
        TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, 0, 'No Link Card in inventory.')
        return
    end

    -- Determine account to charge (supports stolen-card RP)
    local cardMeta        = (hasCard.metadata or hasCard.info) or {}
    local cardCitizenid   = cardMeta.citizenid
    local myCitizenid     = Bridge_GetCitizenId(player)
    local targetCitizenid = (cardCitizenid and cardCitizenid ~= '') and cardCitizenid or myCitizenid
    local isStolen        = cardCitizenid and myCitizenid and cardCitizenid ~= myCitizenid

    local hashed = hashPin(pin, targetCitizenid)

    MySQL.query('SELECT balance, pin_hash, pin_attempts FROM gc_section8_snap WHERE citizenid = ?', { targetCitizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, 0, 'SNAP account not found.')
            return
        end

        local record = result[1]

        if (record.pin_attempts or 0) >= 5 then
            TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, 0, 'Card locked — too many failed PIN attempts.')
            return
        end

        if record.pin_hash ~= hashed then
            local attempts  = (record.pin_attempts or 0) + 1
            local remaining = 5 - attempts
            MySQL.update('UPDATE gc_section8_snap SET pin_attempts = ? WHERE citizenid = ?', { attempts, targetCitizenid })
            TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, record.balance,
                ('Incorrect PIN. %s attempt(s) remaining.'):format(remaining))
            return
        end

        MySQL.update('UPDATE gc_section8_snap SET pin_attempts = 0 WHERE citizenid = ?', { targetCitizenid })

        local balance = record.balance
        if balance < totalCost then
            TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, balance,
                ('Insufficient balance. Cost: $%s | Balance: $%s'):format(totalCost, balance))
            return
        end

        local newBalance = balance - totalCost
        MySQL.update('UPDATE gc_section8_snap SET balance = ? WHERE citizenid = ?', { newBalance, targetCitizenid }, function()
            local added = Bridge_AddItem(src, itemName, qty)
            if not added then
                MySQL.update('UPDATE gc_section8_snap SET balance = ? WHERE citizenid = ?', { balance, targetCitizenid })
                TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, false, itemLabel, qty, balance, 'Inventory full. Transaction refunded.')
                return
            end

            TriggerClientEvent('gc-section8:client:snapPurchaseResult', src, true, itemLabel, qty, newBalance, nil)

            if isStolen then
                TriggerEvent('gc-section8:discord:log', 'snap_stolen_use', {
                    thief = myCitizenid, owner = targetCitizenid,
                    item = itemLabel, qty = qty, cost = totalCost, balance = newBalance,
                })
            end

            TriggerEvent('gc-section8:discord:log', 'snap_purchase', {
                citizenid = targetCitizenid, item = itemLabel, qty = qty, cost = totalCost, balance = newBalance,
            })
        end)
    end)
end)
