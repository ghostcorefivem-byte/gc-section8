local QBCore = exports['qb-core']:GetCoreObject()

-- Toggle NPC mode (admin only)
QBCore.Commands.Add('section8npcmode', 'Toggle Section 8 NPC auto-approve mode (Admin)', {}, false, function(source)
    TriggerEvent('gc-section8:server:toggleNPCMode')
    -- re-trigger as net event from same source
    TriggerNetEvent('gc-section8:server:toggleNPCMode')
end, 'admin')

-- Fix: use RegisterNetEvent path instead
RegisterCommand('section8npcmode', function(source, args)
    if source == 0 then return end
    local QBP = QBCore.Functions.GetPlayer(source)
    if not QBP then return end
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('gc-section8:client:notify', source, 'No permission.', 'error')
        return
    end
    TriggerNetEvent('gc-section8:server:toggleNPCMode')
end, false)

-- Set NPC position to your current location
RegisterCommand('section8npcpos', function(source, args)
    if source == 0 then return end
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('gc-section8:client:notify', source, 'No permission.', 'error')
        return
    end
    TriggerClientEvent('gc-section8:client:getNPCPos', source)
end, false)

-- Evict by citizenid (staff/admin)
RegisterCommand('section8evict', function(source, args)
    if source == 0 then return end
    local QBP = QBCore.Functions.GetPlayer(source)
    if not QBP then return end
    local job = QBP.PlayerData.job
    local isStaff = job and job.name == Config.Section8Job
    local isAdmin = QBCore.Functions.HasPermission(source, 'admin')
    if not isStaff and not isAdmin then
        TriggerClientEvent('gc-section8:client:notify', source, 'No permission.', 'error')
        return
    end
    if not args[1] then
        TriggerClientEvent('gc-section8:client:notify', source, 'Usage: /section8evict [citizenid]', 'error')
        return
    end
    TriggerNetEvent('gc-section8:server:evictTenant', args[1])
end, false)

-- View all pending applications (staff/admin)
RegisterCommand('section8apps', function(source, args)
    if source == 0 then return end
    TriggerNetEvent('gc-section8:server:getApplications')
end, false)

-- View all tenants (staff/admin)
RegisterCommand('section8tenants', function(source, args)
    if source == 0 then return end
    TriggerNetEvent('gc-section8:server:getTenants')
end, false)

-- Admin: open unit placement tool
RegisterCommand('section8tool', function(source, args)
    if source == 0 then return end
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('gc-section8:client:notify', source, 'No permission.', 'error')
        return
    end
    TriggerClientEvent('gc-section8:client:openAdminTool', source)
end, false)
