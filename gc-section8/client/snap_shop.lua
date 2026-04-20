--[[
    gc-section8 | client/snap_shop.lua
    SNAP store NPCs, PIN setup, shop menus.
]]

local spawnedNPCs = {}

-- ─────────────────────────────────────────────────
--  SPAWN STORE NPCs
-- ─────────────────────────────────────────────────

local function spawnStoreNPCs()
    for _, store in ipairs(SnapShopConfig.Stores) do
        local coords = store.coords
        if coords.x == 0.0 and coords.y == 0.0 then goto continue end

        local model = GetHashKey(store.npcModel)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(100) end

        local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        SetModelAsNoLongerNeeded(model)

        spawnedNPCs[#spawnedNPCs + 1] = ped

        if store.blip and store.blip.enabled then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, store.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, store.blip.scale)
            SetBlipColour(blip, store.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(store.blip.label)
            EndTextCommandSetBlipName(blip)
        end

        local storeId    = store.id
        local storeLabel = store.label

        Bridge_AddTargetEntity(ped, {
            {
                name     = 'snap_shop_' .. storeId,
                label    = '🛒 Shop with Link Card',
                icon     = 'fas fa-shopping-cart',
                distance = 2.5,
                onSelect = function()
                    TriggerServerEvent('gc-section8:snap:verifyCard', storeId, storeLabel)
                end,
            },
        })

        ::continue::
    end
end

-- ─────────────────────────────────────────────────
--  PIN PROMPT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:snapPinPrompt', function(storeId, storeLabel, isFirstTime)
    if isFirstTime then
        local input = Bridge_InputDialog('🔐 Set Your EBT PIN', {
            { type = 'input', label = 'Create a 4-digit PIN', placeholder = '----', required = true, min = 4, max = 4 },
            { type = 'input', label = 'Confirm PIN',          placeholder = '----', required = true, min = 4, max = 4 },
        })
        if not input then return end

        if input[1] ~= input[2] then
            Bridge_Notify('Link Card', 'PINs do not match. Try again.', 'error')
            return
        end
        if not input[1]:match('^%d%d%d%d$') then
            Bridge_Notify('Link Card', 'PIN must be exactly 4 numbers.', 'error')
            return
        end
        TriggerServerEvent('gc-section8:snap:setPin', input[1], storeId, storeLabel)
    else
        local input = Bridge_InputDialog('🔐 Enter EBT PIN', {
            { type = 'input', label = 'Enter your 4-digit PIN', placeholder = '----', required = true, min = 4, max = 4, password = true },
        })
        if not input then return end
        TriggerServerEvent('gc-section8:snap:verifyPin', input[1], storeId, storeLabel)
    end
end)

-- ─────────────────────────────────────────────────
--  OPEN SHOP MENU
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:openSnapMenu', function(balance, storeLabel)
    local options = {
        {
            title    = '💳 Balance: $' .. balance,
            description = 'SNAP EBT / Link Card',
            disabled = true,
            icon     = 'fas fa-wallet',
        },
        {
            title    = '🔑 Change PIN',
            description = 'Update your EBT card PIN',
            icon     = 'fas fa-key',
            onSelect = function() promptChangePin() end,
        },
        { title = '──────────────────', disabled = true },
    }

    for _, shopItem in ipairs(SnapShopConfig.Items) do
        local item = shopItem
        options[#options + 1] = {
            title       = item.label,
            description = '💵 $' .. item.price .. ' SNAP',
            icon        = 'fas fa-shopping-basket',
            onSelect    = function() promptBuyItem(item, balance, storeLabel) end,
        }
    end

    Bridge_RegisterContext({ id = 'snap_shop_menu', title = '🛒 ' .. storeLabel, options = options })
    Bridge_ShowContext('snap_shop_menu')
end)

-- ─────────────────────────────────────────────────
--  BUY ITEM
-- ─────────────────────────────────────────────────

function promptBuyItem(item, balance, storeLabel)
    local maxQty = math.floor(balance / item.price)
    if maxQty < 1 then
        Bridge_Notify('💳 Link Card',
            ('Insufficient balance. Need $%s, have $%s.'):format(item.price, balance), 'error')
        return
    end

    local input = Bridge_InputDialog('🛒 ' .. item.label, {
        {
            type     = 'number', label = ('Quantity (max %s, $%s each)'):format(maxQty, item.price),
            default  = 1, min = 1, max = maxQty, required = true,
        },
    })
    if not input then Bridge_ShowContext('snap_shop_menu') return end

    local qty   = tonumber(input[1]) or 1
    local total = qty * item.price

    local pinInput = Bridge_InputDialog('🔐 Confirm Purchase', {
        {
            type = 'input', label = ('Total: $%s — Enter 4-digit EBT PIN'):format(total),
            placeholder = '----', required = true, min = 4, max = 4, password = true,
        },
    })
    if not pinInput then Bridge_ShowContext('snap_shop_menu') return end

    TriggerServerEvent('gc-section8:snap:purchaseWithPin', item.item, item.label, qty, total, pinInput[1])
end

-- ─────────────────────────────────────────────────
--  CHANGE PIN
-- ─────────────────────────────────────────────────

function promptChangePin()
    local input = Bridge_InputDialog('🔑 Change EBT PIN', {
        { type = 'input', label = 'Current PIN',     placeholder = '----', required = true, min = 4, max = 4, password = true },
        { type = 'input', label = 'New PIN',         placeholder = '----', required = true, min = 4, max = 4 },
        { type = 'input', label = 'Confirm New PIN', placeholder = '----', required = true, min = 4, max = 4 },
    })
    if not input then return end

    if input[2] ~= input[3] then
        Bridge_Notify('Link Card', 'New PINs do not match.', 'error')
        return
    end
    if not input[2]:match('^%d%d%d%d$') then
        Bridge_Notify('Link Card', 'PIN must be 4 digits.', 'error')
        return
    end
    TriggerServerEvent('gc-section8:snap:changePin', input[1], input[2])
end

-- ─────────────────────────────────────────────────
--  PURCHASE RESULT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:snapPurchaseResult', function(success, itemLabel, qty, newBalance, reason)
    if success then
        Bridge_Notify('🛒 Purchase Complete',
            ('Bought %sx %s\nBalance: $%s'):format(qty, itemLabel, newBalance), 'success', 6000)
    else
        Bridge_Notify('💳 Transaction Declined', reason or 'Unable to process.', 'error', 6000)
    end
end)

-- ─────────────────────────────────────────────────
--  PIN CHANGE RESULT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:pinChangeResult', function(success, msg)
    Bridge_Notify('🔑 Link Card', msg, success and 'success' or 'error', 5000)
end)

-- ─────────────────────────────────────────────────
--  COMMANDS
-- ─────────────────────────────────────────────────

RegisterCommand('ebtbalance', function()
    TriggerServerEvent('gc-section8:snap:checkBalance')
end, false)

RegisterCommand('snapshoppos', function()
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    Bridge_Notify('SNAP Shop Position',
        ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading),
        'inform', 20000)
end, false)

-- ─────────────────────────────────────────────────
--  INIT / CLEANUP
-- ─────────────────────────────────────────────────

Bridge_OnPlayerLoaded(function()
    Wait(1500)
    spawnStoreNPCs()
end)

CreateThread(function()
    Wait(2000)
    if Bridge_IsLoggedIn() then
        spawnStoreNPCs()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(spawnedNPCs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
