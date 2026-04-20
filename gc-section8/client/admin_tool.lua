-- =============================================
-- ADMIN UNIT PLACEMENT TOOL
-- /section8tool to open
-- =============================================

local placingUnit = false
local currentUnitData = {}

RegisterNetEvent('gc-section8:client:openAdminTool', function()
    lib.registerContext({
        id = 'section8_admin_tool',
        title = '🏢 Section 8 Admin Tool',
        options = {
            {
                title = 'Place New Unit',
                description = 'Walk to a door and set unit info',
                icon = 'fas fa-plus',
                onSelect = function()
                    openUnitSetupForm()
                end,
            },
            {
                title = 'View All Units',
                description = 'See all configured units',
                icon = 'fas fa-list',
                onSelect = function()
                    TriggerServerEvent('gc-section8:server:getUnits')
                end,
            },
            {
                title = 'Toggle NPC Mode',
                description = 'Switch between NPC auto-approve and staff review',
                icon = 'fas fa-robot',
                onSelect = function()
                    TriggerServerEvent('gc-section8:server:toggleNPCMode')
                end,
            },
            {
                title = 'Get My Coords',
                description = 'Print current position to use for NPC/unit placement',
                icon = 'fas fa-map-marker-alt',
                onSelect = function()
                    local ped = PlayerPedId()
                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    lib.notify({
                        title = 'Current Position',
                        description = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading),
                        type = 'inform',
                        duration = 20000,
                    })
                end,
            },
        }
    })
    lib.showContext('section8_admin_tool')
end)

-- =============================================
-- UNIT SETUP FORM
-- =============================================
function openUnitSetupForm()
    local input = lib.inputDialog('Place Section 8 Unit', {
        {
            type = 'input',
            label = 'Unit ID (unique, no spaces)',
            placeholder = 'unit_1a',
            required = true,
            min = 2,
            max = 30,
        },
        {
            type = 'input',
            label = 'Unit Label',
            placeholder = 'Unit 1A - Studio',
            required = true,
            min = 2,
            max = 60,
        },
        {
            type = 'select',
            label = 'Unit Size',
            required = true,
            options = {
                { label = 'Studio',              value = 'studio' },
                { label = '1 Bedroom',           value = '1br' },
                { label = '2 Bedroom',           value = '2br' },
            },
        },
        {
            type = 'number',
            label = 'Max Occupants (soft limit)',
            default = 2,
            min = 1,
            max = 10,
        },
        {
            type = 'number',
            label = 'ox_doorlock Door ID (0 = none)',
            default = 0,
            min = 0,
            max = 9999,
        },
        {
            type = 'number',
            label = 'Base Rent Amount ($)',
            default = 300,
            min = 50,
            max = 9999,
        },
    })

    if not input then return end

    -- Validate unit ID
    local unitId = input[1]:lower():gsub('%s+', '_')
    if #unitId < 2 then
        lib.notify({ title = 'Error', description = 'Unit ID too short.', type = 'error' })
        return
    end

    -- Use player's current position as the unit "entrance" coords
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local doorId = tonumber(input[5]) or 0
    if doorId == 0 then doorId = nil end

    local unitData = {
        id = unitId,
        label = input[2],
        size = input[3],
        maxOccupants = tonumber(input[4]) or 2,
        doorId = doorId,
        rentBase = tonumber(input[6]) or 300,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }

    -- Confirm
    local confirmed = lib.alertDialog({
        header = 'Confirm Unit Placement',
        content = ('Place **%s** (%s) at your current position?\nDoor ID: %s | Max Occupants: %s | Rent: $%s'):format(
            unitData.label, unitData.size,
            unitData.doorId or 'None',
            unitData.maxOccupants,
            unitData.rentBase
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Save Unit', cancel = 'Cancel' },
    })
    if confirmed ~= 'confirm' then return end
    TriggerServerEvent('gc-section8:server:saveUnit', unitData)
end

-- =============================================
-- RECEIVE UNITS (display)
-- =============================================
RegisterNetEvent('gc-section8:client:receiveUnits', function(units)
    if not units or #units == 0 then
        lib.notify({ title = 'Section 8 Units', description = 'No units configured yet. Use /section8tool to add units.', type = 'inform' })
        return
    end

    local options = {}
    for _, unit in ipairs(units) do
        options[#options+1] = {
            title = unit.label,
            description = ('Size: %s | Occupants: %s | Rent: $%s | Occupied: %s'):format(
                unit.size, unit.max_occupants, unit.rent_base,
                unit.occupied == 1 and ('✅ ' .. (unit.tenant_name or '?')) or '❌ Vacant'
            ),
            icon = unit.occupied == 1 and 'fas fa-user' or 'fas fa-door-open',
        }
    end

    lib.registerContext({
        id = 'section8_units_list',
        title = '🏢 All Section 8 Units (' .. #units .. ')',
        options = options,
        onBack = function()
            lib.showContext('section8_admin_tool')
        end,
    })
    lib.showContext('section8_units_list')
end)

-- =============================================
-- STAFF PANEL: VIEW APPLICATIONS
-- =============================================
RegisterNetEvent('gc-section8:client:receiveApplications', function(apps)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showApplications', apps = apps or {} })
end)

-- =============================================
-- STAFF PANEL: VIEW TENANTS
-- =============================================
RegisterNetEvent('gc-section8:client:receiveTenants', function(tenants)
    if not tenants or #tenants == 0 then
        lib.notify({ title = 'Section 8', description = 'No active tenants.', type = 'inform' })
        return
    end

    local options = {}
    for _, t in ipairs(tenants) do
        options[#options+1] = {
            title = t.tenant_name or 'Unknown',
            description = ('Unit: %s | Rent: $%s | Warned: %s'):format(
                t.label, t.rent_amount or '?',
                t.warned == 1 and '⚠️ Yes' or 'No'
            ),
            icon = 'fas fa-user',
            menu = 'section8_tenant_' .. t.tenant_citizenid,
        }

        lib.registerContext({
            id = 'section8_tenant_' .. t.tenant_citizenid,
            title = t.tenant_name or 'Tenant Actions',
            options = {
                {
                    title = '🚫 Evict Tenant',
                    description = 'Revoke access and free the unit',
                    icon = 'fas fa-ban',
                    onSelect = function()
                        lib.alertDialog({
                            header = 'Confirm Eviction',
                            content = 'Are you sure you want to evict ' .. (t.tenant_name or 'this tenant') .. '?',
                            centered = true,
                            cancel = true,
                            labels = { confirm = 'Evict', cancel = 'Cancel' },
                        }, function(confirmed)
                            if confirmed then
                                TriggerServerEvent('gc-section8:server:evictTenant', t.tenant_citizenid)
                            end
                        end)
                    end,
                },
                {
                    title = '📋 Conduct Inspection',
                    description = 'RP check on property (visual only)',
                    icon = 'fas fa-clipboard-check',
                    onSelect = function()
                        lib.notify({ title = 'Inspection Started', description = 'Inspection of ' .. (t.label or 'unit') .. ' logged.', type = 'inform' })
                        -- Optional: trigger animation
                        local animDict = 'amb@world_human_clipboard@male@idle_a'
                        lib.requestAnimDict(animDict)
                        TaskPlayAnim(PlayerPedId(), animDict, 'idle_c', 8.0, -8.0, 3000, 0, 0, false, false, false)
                    end,
                },
            },
            onBack = function()
                lib.showContext('section8_tenants_list')
            end,
        })
    end

    lib.registerContext({
        id = 'section8_tenants_list',
        title = '👥 Current Tenants (' .. #tenants .. ')',
        options = options,
    })
    lib.showContext('section8_tenants_list')
end)
