-- =============================================
-- gc-section8 | client/decor.lua
-- Decoration placement tool for tenants
-- =============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- decorId -> local entity handle
local spawnedDecor = {}

-- =============================================
-- LOAD ALL DECOR ON SPAWN/START
-- =============================================
RegisterNetEvent('gc-section8:client:loadDecor', function(decorList)
    for _, ent in pairs(spawnedDecor) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    spawnedDecor = {}
    for _, d in ipairs(decorList) do
        local prop = d
        CreateThread(function() spawnDecorProp(prop) end)
    end
end)

-- =============================================
-- SINGLE PROP SPAWNED (broadcast after placement)
-- =============================================
RegisterNetEvent('gc-section8:client:spawnDecorProp', function(d)
    CreateThread(function() spawnDecorProp(d) end)
end)

-- =============================================
-- REMOVE A PROP
-- =============================================
RegisterNetEvent('gc-section8:client:removeDecorProp', function(decorId)
    local ent = spawnedDecor[decorId]
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    spawnedDecor[decorId] = nil
end)

-- =============================================
-- CLEAR ALL DECOR
-- =============================================
RegisterNetEvent('gc-section8:client:clearUnitDecor', function()
    for _, ent in pairs(spawnedDecor) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    spawnedDecor = {}
end)

-- =============================================
-- UPDATE PROP POSITION (after edit/move)
-- =============================================
RegisterNetEvent('gc-section8:client:updateDecorProp', function(decorId, x, y, z, heading)
    local ent = spawnedDecor[decorId]
    if ent and DoesEntityExist(ent) then
        SetEntityCoordsNoOffset(ent, x, y, z, false, false, false)
        SetEntityHeading(ent, heading)
        FreezeEntityPosition(ent, true)
    end
end)

-- =============================================
-- INTERNAL: SPAWN A PROP (networked, frozen)
-- =============================================
function spawnDecorProp(d)
    local model = GetHashKey(d.model)
    RequestModel(model)
    local timer = 0
    while not HasModelLoaded(model) do
        Wait(50)
        timer = timer + 50
        if timer > 5000 then
            print('^1[gc-section8] decor model failed to load: ' .. tostring(d.model) .. '^7')
            return
        end
    end
    local prop = CreateObjectNoOffset(model, d.x, d.y, d.z, true, false, true)
    SetEntityHeading(prop, d.heading or 0.0)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(model)
    spawnedDecor[d.id] = prop
end

-- =============================================
-- PLACEMENT TOOL
-- Prop appears 1.5m in front of the player.
-- Player walks around to position it.
-- Raycast downward finds the floor so it sits properly.
--
-- Controls (no conflicts in this mode):
--   Q  / LB (21)  → rotate left
--   E  / RB (22)  → rotate right
--   F  / A  (191) → confirm
--   X  / B  (177) → cancel
-- =============================================
local isPlacing = false

-- onDone(confirmed, x, y, z, heading)
function RunPlacementTool(propModel, onDone)
    if isPlacing then
        lib.notify({ title = 'Decor', description = 'Already in placement mode.', type = 'error' })
        return
    end
    isPlacing = true

    CreateThread(function()
        -- Load model
        local model = GetHashKey(propModel)
        RequestModel(model)
        local timer = 0
        while not HasModelLoaded(model) do
            Wait(50)
            timer = timer + 50
            if timer > 5000 then
                lib.notify({ title = 'Decor', description = 'Failed to load prop model.', type = 'error' })
                isPlacing = false
                onDone(false, 0, 0, 0, 0)
                return
            end
        end

        -- Ghost prop: local only, transparent, no collision
        local ghost = CreateObjectNoOffset(model, 0.0, 0.0, 0.0, false, false, false)
        SetEntityAlpha(ghost, 175, false)
        SetEntityCollision(ghost, false, false)
        FreezeEntityPosition(ghost, true)
        SetModelAsNoLongerNeeded(model)

        -- Start heading matches player facing
        local heading  = GetEntityHeading(PlayerPedId())
        local rotTimer = 0
        local done     = false
        local confirmed = false

        while not done do
            Wait(0)

            local ped       = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local pedHdg    = GetEntityHeading(ped)

            -- Position ghost 1.5m in front of the player
            local angle = math.rad(pedHdg)
            local fwdX  = pedCoords.x - math.sin(angle) * 1.5
            local fwdY  = pedCoords.y + math.cos(angle) * 1.5

            -- Raycast straight down to find floor
            local ray = StartShapeTestRay(
                fwdX, fwdY, pedCoords.z + 2.0,
                fwdX, fwdY, pedCoords.z - 1.5,
                1 + 16, ghost, 0
            )
            local _, hit, hitCoords = GetShapeTestResult(ray)

            if hit == 1 then
                SetEntityCoordsNoOffset(ghost, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false)
            else
                SetEntityCoordsNoOffset(ghost, fwdX, fwdY, pedCoords.z, false, false, false)
                PlaceObjectOnGroundProperly(ghost)
            end

            SetEntityHeading(ghost, heading)

            -- Rotation with cooldown so it doesn't spin too fast
            local now = GetGameTimer()
            if now > rotTimer then
                if IsControlPressed(0, 174) then   -- Left arrow / LB: rotate left
                    heading = (heading + 5.0) % 360.0
                    rotTimer = now + 60
                elseif IsControlPressed(0, 175) then -- Right arrow / RB: rotate right
                    heading = (heading - 5.0) % 360.0
                    rotTimer = now + 60
                end
            end

            -- Confirm: E key (38 = INPUT_PICKUP) or gamepad A (191)
            if IsControlJustPressed(0, 38) or IsControlJustPressed(0, 191) then
                confirmed = true
                done = true
            end

            -- Cancel: Backspace (200) or gamepad B (177)
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                confirmed = false
                done = true
            end

            -- Draw hint above ghost
            local gc = GetEntityCoords(ghost)
            DrawHint3D(
                gc.x, gc.y, gc.z + 0.9,
                '~g~[E / A]~w~ Confirm   ~r~[BACK / B]~w~ Cancel   ~y~[LEFT]~w~ / ~y~[RIGHT]~w~ Rotate'
            )
        end

        -- Read final position BEFORE deleting ghost
        local finalCoords  = GetEntityCoords(ghost)
        local finalHeading = GetEntityHeading(ghost)
        local fx, fy, fz   = finalCoords.x, finalCoords.y, finalCoords.z

        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        isPlacing = false

        onDone(confirmed, fx, fy, fz, finalHeading)
    end)
end

-- =============================================
-- HELPER: 3D hint text above prop
-- =============================================
function DrawHint3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, 0.30)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- =============================================
-- SERVER → CLIENT: PROMPT PAYMENT AFTER PLACING
-- Prop is already saved to DB pending payment.
-- Player picks bank/cash or cancels (prop removed, no charge).
-- =============================================
RegisterNetEvent('gc-section8:client:promptPayment', function(decorId, propLabel, price)
    Wait(400) -- let prop appear visually first

    local choice = lib.alertDialog({
        header   = '💳 Pay for ' .. propLabel,
        content  = ('**%s** placed!\nCost: **$%s** — pay from?'):format(propLabel, price),
        centered = true,
        cancel   = true,
        labels   = { confirm = 'Bank', cancel = 'Cash' },
    })

    if choice == 'confirm' then
        TriggerServerEvent('gc-section8:server:confirmDecorPayment', decorId, 'bank')
    elseif choice == 'cancel' then
        TriggerServerEvent('gc-section8:server:confirmDecorPayment', decorId, 'cash')
    else
        -- Dismissed dialog — cancel the whole placement, no charge
        TriggerServerEvent('gc-section8:server:cancelDecorPayment', decorId)
        lib.notify({ title = 'Decor', description = 'Placement cancelled — no charge.', type = 'inform' })
    end
end)

-- =============================================
-- COMMAND: /sec8decor
-- =============================================
RegisterCommand('sec8decor', function()
    TriggerServerEvent('gc-section8:server:openDecorMenu')
end, false)

-- =============================================
-- SERVER → CLIENT: OPEN MAIN DECOR MENU
-- =============================================
RegisterNetEvent('gc-section8:client:openDecorMenu', function(data)
    -- data: { props, currentCount, maxProps }

    local propOptions = {}
    for _, prop in ipairs(data.props) do
        local p = prop
        propOptions[#propOptions+1] = {
            title       = p.label,
            description = ('$%s — you pay after placing'):format(p.price),
            icon        = 'fas fa-couch',
            onSelect    = function()
                RunPlacementTool(p.model, function(confirmed, x, y, z, hdg)
                    if not confirmed then
                        lib.notify({ title = 'Decor', description = 'Placement cancelled.', type = 'inform' })
                        return
                    end
                    TriggerServerEvent('gc-section8:server:placeDecor', {
                        model   = p.model,
                        x       = x,
                        y       = y,
                        z       = z,
                        heading = hdg,
                    })
                end)
            end,
        }
    end

    lib.registerContext({
        id      = 'sec8_decor_place',
        title   = '🛋️ Choose Furniture',
        options = propOptions,
        onBack  = function() lib.showContext('sec8_decor_main') end,
    })

    lib.registerContext({
        id      = 'sec8_decor_main',
        title   = '🏠 Unit Decoration',
        options = {
            {
                title       = ('🛋️ Place Furniture (%s/%s used)'):format(data.currentCount, data.maxProps),
                description = 'Choose furniture to place — pay after',
                icon        = 'fas fa-plus',
                menu        = 'sec8_decor_place',
            },
            {
                title       = '✏️ Move / Remove Furniture',
                description = 'Reposition or remove placed items',
                icon        = 'fas fa-edit',
                onSelect    = function()
                    TriggerServerEvent('gc-section8:server:getMyDecor')
                end,
            },
        },
    })

    lib.showContext('sec8_decor_main')
end)

-- =============================================
-- SERVER → CLIENT: MANAGE PLACED DECOR
-- =============================================
RegisterNetEvent('gc-section8:client:receiveMyDecor', function(placed, props)
    if not placed or #placed == 0 then
        lib.notify({ title = 'Decor', description = 'No furniture placed yet.', type = 'inform' })
        return
    end

    local labelMap = {}
    for _, p in ipairs(props) do labelMap[p.model] = p.label end

    local options = {
        {
            title       = '🗑️ Remove ALL Furniture',
            description = 'Clears everything — no refunds',
            icon        = 'fas fa-trash-alt',
            onSelect    = function()
                local ok = lib.alertDialog({
                    header   = 'Remove All Furniture?',
                    content  = 'This removes **all** placed furniture. No refunds.',
                    centered = true,
                    cancel   = true,
                    labels   = { confirm = 'Yes, Clear It', cancel = 'Cancel' },
                })
                if ok == 'confirm' then
                    TriggerServerEvent('gc-section8:server:clearAllDecor')
                end
            end,
        },
    }

    for _, d in ipairs(placed) do
        local item = d
        local lbl  = labelMap[d.model] or d.model

        -- Move/reposition
        options[#options+1] = {
            title       = '✏️ Move: ' .. lbl,
            description = 'Reposition this item — no extra charge',
            icon        = 'fas fa-arrows-alt',
            onSelect    = function()
                RunPlacementTool(item.model, function(confirmed, x, y, z, hdg)
                    if not confirmed then
                        lib.notify({ title = 'Decor', description = 'Edit cancelled — item stays put.', type = 'inform' })
                        return
                    end
                    TriggerServerEvent('gc-section8:server:editDecor', item.id, x, y, z, hdg)
                end)
            end,
        }

        -- Remove
        options[#options+1] = {
            title       = '❌ Remove: ' .. lbl,
            description = 'Permanently remove — no refund',
            icon        = 'fas fa-times',
            onSelect    = function()
                TriggerServerEvent('gc-section8:server:removeDecor', item.id)
            end,
        }
    end

    lib.registerContext({
        id      = 'sec8_decor_manage',
        title   = '✏️ Manage Furniture',
        options = options,
    })
    lib.showContext('sec8_decor_manage')
end)

-- =============================================
-- CLEANUP ON RESOURCE STOP
-- =============================================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ent in pairs(spawnedDecor) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    spawnedDecor = {}
end)

-- =============================================
-- LOAD DECOR AFTER PLAYER LOADS
-- =============================================
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    TriggerServerEvent('gc-section8:server:requestDecorLoad')
end)

-- =============================================
-- LOAD DECOR ON RESOURCE RESTART
-- =============================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(2000)
    TriggerServerEvent('gc-section8:server:requestDecorLoad')
end)
