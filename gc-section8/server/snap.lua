--[[
    gc-section8 | server/snap.lua
    SNAP / EBT benefit logic, card replacement system.
]]

local SNAP = Config.SNAP

-- ─────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────

local function calcSnapAmount(income, numKids)
    local amount = SNAP.BaseAmount + (numKids * SNAP.PerKid)

    if income > SNAP.IncomeThreshold then
        local over       = income - SNAP.IncomeThreshold
        local reductions = math.floor(over / 500)
        amount           = amount - (reductions * SNAP.IncomeReduction)
    end

    amount = math.max(SNAP.MinBenefit, math.min(SNAP.MaxBenefit, amount))
    return amount
end

-- ─────────────────────────────────────────────────
--  GRANT SNAP
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:snap:grant', function(citizenid, playerSrc, income, numKids, rentAmount)
    local snapAmount = calcSnapAmount(income, numKids or 0)
    local reloadDate = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (SNAP.ReloadDays * 86400))

    MySQL.insert(
        'INSERT INTO gc_section8_snap (citizenid, monthly_amount, balance, next_reload) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE monthly_amount = ?, balance = balance + ?, next_reload = ?',
        { citizenid, snapAmount, snapAmount, reloadDate, snapAmount, snapAmount, reloadDate },
        function()
            if playerSrc then
                local hasCard = Bridge_GetItemWithMeta(playerSrc, SNAP.Item)
                if not hasCard or (hasCard.count or 0) == 0 then
                    Bridge_AddItem(playerSrc, SNAP.Item, 1, { balance = snapAmount, citizenid = citizenid })
                end
                TriggerClientEvent('gc-section8:client:snapReloaded', playerSrc, snapAmount, snapAmount)
            end

            TriggerEvent('gc-section8:discord:log', 'snap_granted', { citizenid = citizenid, amount = snapAmount })
        end
    )
end)

-- ─────────────────────────────────────────────────
--  CHECK BALANCE
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:checkBalance', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    MySQL.query('SELECT balance FROM gc_section8_snap WHERE citizenid = ?', { Bridge_GetCitizenId(player) }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'No SNAP benefits on file for your account.')
            return
        end
        TriggerClientEvent('gc-section8:client:snapBalance', src, result[1].balance)
    end)
end)

-- ─────────────────────────────────────────────────
--  MONTHLY RELOAD CHECK (every 30 min)
-- ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1800000)
        local now = os.date('!%Y-%m-%d %H:%M:%S', os.time())

        MySQL.query('SELECT * FROM gc_section8_snap WHERE next_reload < ?', { now }, function(due)
            if not due then return end
            for _, record in ipairs(due) do
                local newReload = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (SNAP.ReloadDays * 86400))
                MySQL.update('UPDATE gc_section8_snap SET balance = balance + ?, next_reload = ? WHERE citizenid = ?',
                    { record.monthly_amount, newReload, record.citizenid })

                for _, pid in ipairs(Bridge_GetAllPlayers()) do
                    local p = Bridge_GetPlayer(pid)
                    if p and Bridge_GetCitizenId(p) == record.citizenid then
                        local newBal = (record.balance or 0) + record.monthly_amount
                        TriggerClientEvent('gc-section8:client:snapReloaded', pid, record.monthly_amount, newBal)
                        break
                    end
                end

                TriggerEvent('gc-section8:discord:log', 'snap_reload', {
                    citizenid = record.citizenid, amount = record.monthly_amount,
                })
            end
        end)
    end
end)

-- ─────────────────────────────────────────────────
--  REVOKE SNAP (on eviction)
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:snap:revoke', function(citizenid)
    MySQL.update('DELETE FROM gc_section8_snap WHERE citizenid = ?', { citizenid })
end)

-- ─────────────────────────────────────────────────
--  CARD REPLACEMENT
--  Player requests a replacement Link Card.
--  Requires: no card in inventory, has a SNAP record,
--  not in cooldown, and pays the replacement fee.
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:requestReplacement', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    local citizenid = Bridge_GetCitizenId(player)

    -- Check they have a SNAP account
    MySQL.query('SELECT balance, monthly_amount, replacement_at FROM gc_section8_snap WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:snapDenied', src, 'No SNAP account found. You must be an approved Section 8 tenant.')
            return
        end

        local record = result[1]

        -- Cooldown check
        if record.replacement_at then
            local lastReplace = record.replacement_at
            local cooldownSec = Config.SNAP.ReplacementCooldown * 3600
            -- Compare timestamps via MySQL epoch logic
            MySQL.query('SELECT TIMESTAMPDIFF(SECOND, ?, NOW()) as elapsed', { lastReplace }, function(ts)
                local elapsed = ts and ts[1] and ts[1].elapsed or 999999
                if elapsed < cooldownSec then
                    local hoursLeft = math.ceil((cooldownSec - elapsed) / 3600)
                    TriggerClientEvent('gc-section8:client:snapDenied', src,
                        ('You already requested a replacement recently. Try again in %s hour(s).'):format(hoursLeft))
                    return
                end
                doReplacement(src, player, citizenid, record)
            end)
            return
        end

        doReplacement(src, player, citizenid, record)
    end)
end)

function doReplacement(src, player, citizenid, snapRecord)
    -- Check they don't already have the card
    local hasCard = Bridge_GetItemWithMeta(src, Config.SNAP.Item)
    if hasCard and (hasCard.count or 0) > 0 then
        TriggerClientEvent('gc-section8:client:snapDenied', src, 'You still have your Link Card in your inventory.')
        return
    end

    local cost = Config.SNAP.ReplacementCost
    local bank = Bridge_GetBankMoney(player)

    if bank < cost then
        TriggerClientEvent('gc-section8:client:snapDenied', src,
            ('Replacement fee is $%s. You do not have enough bank funds.'):format(cost))
        return
    end

    -- Charge the fee
    Bridge_RemoveMoney(player, cost, 'snap-card-replacement')

    -- Issue new card
    Bridge_AddItem(src, Config.SNAP.Item, 1, { balance = snapRecord.balance, citizenid = citizenid })

    -- Log replacement timestamp
    MySQL.update('UPDATE gc_section8_snap SET replacement_at = NOW() WHERE citizenid = ?', { citizenid })

    TriggerClientEvent('gc-section8:client:cardReplaced', src, snapRecord.balance, cost)

    TriggerEvent('gc-section8:discord:log', 'snap_replacement', {
        citizenid = citizenid,
        fee       = cost,
        balance   = snapRecord.balance,
    })
end

-- ─────────────────────────────────────────────────
--  ADMIN: RESET LOCKED CARD / FORCE REPLACE
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:snap:adminReset', function(targetCitizenid)
    local src = source
    if not Bridge_HasPermission(src, 'admin') and not Bridge_HasPermission(src, 'god') then return end
    if not targetCitizenid then return end

    MySQL.update('UPDATE gc_section8_snap SET pin_attempts = 0, pin_hash = NULL, replacement_at = NULL WHERE citizenid = ?',
        { targetCitizenid },
        function(rows)
            local msg = (rows and rows > 0) and 'Card reset successfully.' or 'CitizenID not found.'
            TriggerClientEvent('gc-section8:client:notify', src, msg, rows and rows > 0 and 'success' or 'error')
        end
    )
end)

RegisterCommand('snapreset', function(source, args)
    if source == 0 then return end
    if not args[1] then
        TriggerClientEvent('gc-section8:client:notify', source, 'Usage: /snapreset [citizenid]', 'error')
        return
    end
    TriggerNetEvent('gc-section8:snap:adminReset', args[1])
end, false)
