--[[
    gc-section8 | client/main.lua
    NPC spawning, UI callbacks, player event handlers.
]]

local npcHandle = nil
local npcMode   = true

-- ─────────────────────────────────────────────────
--  NPC SPAWN
-- ─────────────────────────────────────────────────

local function spawnNPC()
    if npcHandle and DoesEntityExist(npcHandle) then
        DeleteEntity(npcHandle)
        npcHandle = nil
    end

    local coords = Config.NPC.coords
    local model  = GetHashKey(Config.NPC.model)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end

    npcHandle = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    FreezeEntityPosition(npcHandle, true)
    SetEntityInvincible(npcHandle, true)
    SetBlockingOfNonTemporaryEvents(npcHandle, true)
    TaskStartScenarioInPlace(npcHandle, Config.NPC.scenario, 0, true)
    SetModelAsNoLongerNeeded(model)

    if Config.NPC.blip.enabled then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, Config.NPC.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.NPC.blip.scale)
        SetBlipColour(blip, Config.NPC.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.NPC.blip.label)
        EndTextCommandSetBlipName(blip)
    end

    Bridge_AddTargetEntity(npcHandle, {
        {
            name     = 'section8_apply',
            label    = 'Section 8 Application',
            icon     = 'fas fa-file-alt',
            distance = 2.5,
            onSelect = function()
                TriggerEvent('gc-section8:client:openApplication')
            end,
        },
        {
            name     = 'section8_status',
            label    = 'Check Application Status',
            icon     = 'fas fa-search',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('gc-section8:server:checkStatus')
            end,
        },
        {
            name     = 'section8_payrent',
            label    = 'Pay Rent',
            icon     = 'fas fa-dollar-sign',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('gc-section8:server:payRent')
            end,
        },
        {
            name     = 'section8_replace_card',
            label    = 'Replace Lost Link Card ($' .. Config.SNAP.ReplacementCost .. ')',
            icon     = 'fas fa-credit-card',
            distance = 2.5,
            onSelect = function()
                TriggerEvent('gc-section8:client:requestCardReplacement')
            end,
        },
    })
end

-- ─────────────────────────────────────────────────
--  INIT
-- ─────────────────────────────────────────────────

Bridge_OnPlayerLoaded(function()
    Wait(1000)
    spawnNPC()
    Wait(1000)
    TriggerServerEvent('gc-section8:server:getMyUnit')
    TriggerServerEvent('gc-section8:server:loginRentCheck')
end)

CreateThread(function()
    Wait(2000)
    if Bridge_IsLoggedIn() then
        spawnNPC()
    end
end)

-- ─────────────────────────────────────────────────
--  OPEN APPLICATION UI
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:client:openApplication', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openApplication', jobs = Config.Jobs })
end)

-- ─────────────────────────────────────────────────
--  CARD REPLACEMENT FLOW
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:client:requestCardReplacement', function()
    if not Bridge_RegisterContext then
        -- Fallback: direct confirm with a simple dialog
        TriggerServerEvent('gc-section8:snap:requestReplacement')
        return
    end

    Bridge_RegisterContext({
        id    = 'gc_card_replace_confirm',
        title = '💳 Link Card Replacement',
        options = {
            {
                title       = 'Confirm Replacement — $' .. Config.SNAP.ReplacementCost,
                description = 'A $' .. Config.SNAP.ReplacementCost .. ' fee will be deducted from your bank account. Only use this if your card is lost or stolen.',
                icon        = 'fas fa-credit-card',
                onSelect    = function()
                    TriggerServerEvent('gc-section8:snap:requestReplacement')
                end,
            },
            {
                title       = 'Cancel',
                icon        = 'fas fa-times',
                onSelect    = function() end,
            },
        },
    })
    Bridge_ShowContext('gc_card_replace_confirm')
end)

-- ─────────────────────────────────────────────────
--  NUI CALLBACKS
-- ─────────────────────────────────────────────────

RegisterNUICallback('submitApplication', function(data, cb)
    TriggerServerEvent('gc-section8:server:submitApplication', data)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('closeApplications', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('approveApplication', function(data, cb)
    TriggerServerEvent('gc-section8:server:staffApprove', data.appId)
    cb('ok')
end)

RegisterNUICallback('denyApplication', function(data, cb)
    TriggerServerEvent('gc-section8:server:staffDeny', data.appId, data.reason)
    cb('ok')
end)

RegisterNUICallback('evictTenant', function(data, cb)
    TriggerServerEvent('gc-section8:server:evictTenant', data.citizenid)
    cb('ok')
end)

-- ─────────────────────────────────────────────────
--  RECEIVE APPLICATION STATUS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:showStatus', function(app)
    local statusText = app.status:upper()
    local msg = ('Application #%s — Status: %s'):format(app.id, statusText)
    if app.status == 'approved' then
        msg = msg .. ('\nUnit: %s | Rent: $%s/mo'):format(app.unit_label or 'TBD', app.rent_amount or '?')
    end
    Bridge_Notify('Section 8 Status', msg, app.status == 'approved' and 'success' or 'inform', 8000)
end)

-- ─────────────────────────────────────────────────
--  APPROVED
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:approved', function(data)
    Bridge_Notify(
        '🏠 Section 8 Approved!',
        ('You have been assigned %s (%s).\nMonthly Rent: $%s\nYour key is now active.'):format(data.unitLabel, data.unitSize, data.rent),
        'success', 12000
    )

    if data.unitCoords then
        local homeBlip = AddBlipForCoord(data.unitCoords.x, data.unitCoords.y, data.unitCoords.z)
        SetBlipSprite(homeBlip, 40)
        SetBlipColour(homeBlip, 66)
        SetBlipScale(homeBlip, 0.8)
        SetBlipAsShortRange(homeBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('My Section 8 Unit')
        EndTextCommandSetBlipName(homeBlip)
    end
end)

-- ─────────────────────────────────────────────────
--  HOME BLIP RESTORE ON LOGIN
-- ─────────────────────────────────────────────────

local homeBlip = nil

RegisterNetEvent('gc-section8:client:receiveMyUnit', function(coords)
    if not coords then return end
    if homeBlip then RemoveBlip(homeBlip) end
    homeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(homeBlip, 40)
    SetBlipColour(homeBlip, 66)
    SetBlipScale(homeBlip, 0.8)
    SetBlipAsShortRange(homeBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('My Section 8 Unit')
    EndTextCommandSetBlipName(homeBlip)
end)

-- ─────────────────────────────────────────────────
--  EVICTION
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:evicted', function()
    if homeBlip then RemoveBlip(homeBlip) homeBlip = nil end
    Bridge_Notify('⚠️ Eviction Notice', 'You have been evicted. Your door access has been revoked.', 'error', 15000)
end)

-- ─────────────────────────────────────────────────
--  RENT WARNING
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:rentWarning', function(daysLeft)
    Bridge_Notify('⚠️ Rent Overdue',
        ('Your rent is past due! You have %s day(s) before eviction. Visit the Section 8 office to pay.'):format(daysLeft),
        'error', 15000)
end)

-- ─────────────────────────────────────────────────
--  STAFF ALERT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:staffAlert', function(applicantName, appId)
    Bridge_Notify('📋 New Section 8 Application',
        ('New application from %s (ID: %s). Use /section8apps to review.'):format(applicantName, appId),
        'inform', 10000)
end)

-- ─────────────────────────────────────────────────
--  GENERIC NOTIFY
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:notify', function(msg, msgType)
    Bridge_Notify('Section 8 Housing', msg, msgType or 'inform', 6000)
end)

-- ─────────────────────────────────────────────────
--  SYNC NPC MODE
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:syncNPCMode', function(mode)
    npcMode = mode
end)

-- ─────────────────────────────────────────────────
--  STAFF: RECEIVE APPLICATIONS / TENANTS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:receiveApplications', function(apps)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showApplications', apps = apps })
end)

RegisterNetEvent('gc-section8:client:receiveTenants', function(tenants)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showTenants', tenants = tenants })
end)

-- ─────────────────────────────────────────────────
--  FORCE CLOSE NUI
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:forceCloseNUI', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

-- ─────────────────────────────────────────────────
--  CARD REPLACED NOTIFICATION
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:cardReplaced', function(balance, fee)
    Bridge_Notify('💳 Card Replaced',
        ('Your Link Card has been reissued.\nBalance: $%s | Fee charged: $%s'):format(balance, fee),
        'success', 8000)
end)

-- ─────────────────────────────────────────────────
--  ADMIN: GET NPC POS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:client:getNPCPos', function()
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    Bridge_Notify('NPC Position',
        ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading),
        'inform', 15000)
end)

-- ─────────────────────────────────────────────────
--  CLEANUP
-- ─────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if npcHandle and DoesEntityExist(npcHandle) then
        DeleteEntity(npcHandle)
    end
end)
