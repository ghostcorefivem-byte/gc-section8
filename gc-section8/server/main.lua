CreateThread(function()
    Wait(500)
    print('\n^2╔════════════════════════════════════╗')
    print('^2║       👻  Ghost Core Scripts       ║')
    print('^2║          gc-section8  v1.0         ║')
    print('^2╚════════════════════════════════════╝^2\n')
end)

local npcMode = true

-- ─────────────────────────────────────────────────
--  STARTUP
-- ─────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.query('SELECT value FROM gc_section8_settings WHERE `key` = ?', { 'npc_mode' }, function(result)
        if result and result[1] then
            npcMode = result[1].value == '1'
        end
        TriggerClientEvent('gc-section8:client:syncNPCMode', -1, npcMode)
    end)
end)

-- ─────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────

local function isSection8Staff(source)
    local player = Bridge_GetPlayer(source)
    if not player then return false end
    return Bridge_GetJob(player) == Config.Section8Job
end

local function isAdmin(source)
    return Bridge_HasPermission(source, 'admin') or Bridge_HasPermission(source, 'god')
end

local function calculateRent(income)
    local rent = math.floor(income * Config.RentPercent)
    if rent < Config.MinRent then rent = Config.MinRent end
    if rent > Config.MaxRent then rent = Config.MaxRent end
    return rent
end

local function getAvailableUnit(cb)
    MySQL.query('SELECT * FROM gc_section8_units WHERE occupied = 0 LIMIT 1', {}, function(result)
        cb(result and result[1] or nil)
    end)
end

-- ─────────────────────────────────────────────────
--  SUBMIT APPLICATION
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:submitApplication', function(data)
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    local citizenid = Bridge_GetCitizenId(player)
    local name      = Bridge_GetFullName(player)

    local sex = (data.sex == 'female') and 'female' or 'male'

    if not data.jobType or not data.income or type(data.income) ~= 'number' then
        TriggerClientEvent('gc-section8:client:notify', src, 'Invalid application data.', 'error')
        return
    end

    if data.income < 0 or data.income > 999999 then
        TriggerClientEvent('gc-section8:client:notify', src, 'Invalid income amount.', 'error')
        return
    end

    MySQL.query('SELECT id, status FROM gc_section8_applications WHERE citizenid = ? AND status != ?',
        { citizenid, 'denied' },
        function(existing)
            if existing and existing[1] then
                local status = existing[1].status
                if status == 'approved' then
                    TriggerClientEvent('gc-section8:client:notify', src, 'You already have an approved Section 8 unit.', 'error')
                else
                    TriggerClientEvent('gc-section8:client:notify', src, 'You already have a pending application. Check back later.', 'error')
                end
                TriggerClientEvent('gc-section8:client:forceCloseNUI', src)
                return
            end

            local rentAmount      = calculateRent(data.income)
            local extraOccupants  = data.extraOccupants or ''

            MySQL.insert(
                'INSERT INTO gc_section8_applications (citizenid, player_name, job_type, monthly_income, has_kids, num_kids, extra_occupants, sex, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                { citizenid, name, data.jobType, data.income, data.hasKids and 1 or 0, data.numKids or 0, extraOccupants, sex, 'pending' },
                function(appId)
                    if not appId then
                        TriggerClientEvent('gc-section8:client:notify', src, 'Error submitting application. Try again.', 'error')
                        return
                    end

                    TriggerClientEvent('gc-section8:client:notify', src, 'Application submitted! You will be notified of the decision.', 'success')
                    TriggerEvent('gc-section8:discord:log', 'application', {
                        name = name, citizenid = citizenid, job = data.jobType,
                        income = data.income, rent = rentAmount, kids = data.hasKids, appId = appId,
                    })

                    if npcMode then
                        Wait(2000)
                        TriggerEvent('gc-section8:server:processApplication', appId, src, citizenid, name, rentAmount, 'Section 8 NPC')
                    else
                        for _, pid in ipairs(Bridge_GetAllPlayers()) do
                            local p = Bridge_GetPlayer(pid)
                            if p and Bridge_GetJob(p) == Config.Section8Job and Bridge_GetJobOnDuty(p) then
                                TriggerClientEvent('gc-section8:client:staffAlert', pid, name, appId)
                            end
                        end
                    end
                end
            )
        end
    )
end)

-- ─────────────────────────────────────────────────
--  PROCESS APPLICATION (approve + assign unit)
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:server:processApplication', function(appId, playerSrc, citizenid, playerName, rentAmount, approvedBy)
    getAvailableUnit(function(unit)
        if not unit then
            MySQL.update('UPDATE gc_section8_applications SET status = ?, approved_by = ?, reviewed_at = NOW() WHERE id = ?',
                { 'denied', 'No Units Available', appId })
            if playerSrc then
                TriggerClientEvent('gc-section8:client:notify', playerSrc, 'No units currently available. Check back later.', 'error')
            end
            TriggerEvent('gc-section8:discord:log', 'denied_no_unit', { name = playerName, citizenid = citizenid })
            return
        end

        MySQL.update('UPDATE gc_section8_units SET occupied = 1, tenant_citizenid = ?, tenant_name = ? WHERE id = ?',
            { citizenid, playerName, unit.id })

        MySQL.update('UPDATE gc_section8_applications SET status = ?, assigned_unit = ?, rent_amount = ?, approved_by = ?, reviewed_at = NOW() WHERE id = ?',
            { 'approved', unit.id, rentAmount, approvedBy, appId })

        local dueDate = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (Config.RentDueDays * 86400))
        MySQL.insert(
            'INSERT INTO gc_section8_rent (citizenid, unit_id, rent_amount, last_paid, due_date) VALUES (?, ?, ?, NOW(), ?) ON DUPLICATE KEY UPDATE unit_id = ?, rent_amount = ?, last_paid = NOW(), due_date = ?, warned = 0',
            { citizenid, unit.id, rentAmount, dueDate, unit.id, rentAmount, dueDate }
        )

        if unit.door_id then
            DoorlockGrant(unit.door_id, citizenid)
        end

        MySQL.query('SELECT has_kids, num_kids, monthly_income FROM gc_section8_applications WHERE id = ?', { appId }, function(appData)
            if appData and appData[1] then
                local app = appData[1]
                if app.monthly_income <= 3500 then
                    TriggerEvent('gc-section8:snap:grant', citizenid, playerSrc, app.monthly_income, app.num_kids, rentAmount)
                end
            end
        end)

        if playerSrc then
            TriggerClientEvent('gc-section8:client:approved', playerSrc, {
                unitLabel  = unit.label,
                unitSize   = unit.size,
                rent       = rentAmount,
                doorId     = unit.door_id,
            })
        end

        TriggerEvent('gc-section8:discord:log', 'approved', {
            name = playerName, citizenid = citizenid, unit = unit.label, rent = rentAmount, approvedBy = approvedBy,
        })
    end)
end)

-- ─────────────────────────────────────────────────
--  GET MY UNIT (for home blip)
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:getMyUnit', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    MySQL.query([[
        SELECT u.coords_x, u.coords_y, u.coords_z
        FROM gc_section8_units u
        INNER JOIN gc_section8_rent r ON r.unit_id = u.id
        WHERE r.citizenid = ?
        LIMIT 1
    ]], { Bridge_GetCitizenId(player) }, function(result)
        if result and result[1] then
            TriggerClientEvent('gc-section8:client:receiveMyUnit', src, {
                x = result[1].coords_x, y = result[1].coords_y, z = result[1].coords_z,
            })
        end
    end)
end)

-- ─────────────────────────────────────────────────
--  PAY RENT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:payRent', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    local citizenid = Bridge_GetCitizenId(player)

    MySQL.query('SELECT * FROM gc_section8_rent WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:notify', src, 'You do not have a Section 8 unit.', 'error')
            return
        end

        local record = result[1]
        local bank   = Bridge_GetBankMoney(player)

        if bank < record.rent_amount then
            TriggerClientEvent('gc-section8:client:notify', src, 'Insufficient bank funds. Rent is $' .. record.rent_amount, 'error')
            return
        end

        Bridge_RemoveMoney(player, record.rent_amount, 'section8-rent')

        local dueDate = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (Config.RentDueDays * 86400))
        MySQL.update('UPDATE gc_section8_rent SET last_paid = NOW(), due_date = ?, warned = 0, warn_date = NULL WHERE citizenid = ?',
            { dueDate, citizenid })

        TriggerClientEvent('gc-section8:client:notify', src, 'Rent of $' .. record.rent_amount .. ' paid.', 'success')
        TriggerEvent('gc-section8:discord:log', 'rent_paid', {
            name = Bridge_GetFullName(player), citizenid = citizenid,
            amount = record.rent_amount, unit = record.unit_id,
        })
    end)
end)

-- ─────────────────────────────────────────────────
--  CHECK APPLICATION STATUS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:checkStatus', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    MySQL.query(
        'SELECT a.*, u.label as unit_label FROM gc_section8_applications a LEFT JOIN gc_section8_units u ON a.assigned_unit = u.id WHERE a.citizenid = ? ORDER BY a.submitted_at DESC LIMIT 1',
        { Bridge_GetCitizenId(player) },
        function(result)
            if not result or not result[1] then
                TriggerClientEvent('gc-section8:client:notify', src, 'No application on file.', 'error')
                return
            end
            TriggerClientEvent('gc-section8:client:showStatus', src, result[1])
        end
    )
end)

-- ─────────────────────────────────────────────────
--  STAFF: GET APPLICATIONS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:getApplications', function()
    local src = source
    if not isSection8Staff(src) and not isAdmin(src) then
        TriggerClientEvent('gc-section8:client:notify', src, 'Unauthorized.', 'error')
        return
    end
    MySQL.query('SELECT * FROM gc_section8_applications WHERE status = ? ORDER BY submitted_at ASC', { 'pending' }, function(result)
        TriggerClientEvent('gc-section8:client:receiveApplications', src, result or {})
    end)
end)

-- ─────────────────────────────────────────────────
--  STAFF: APPROVE APPLICATION
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:staffApprove', function(appId)
    local src = source
    if not isSection8Staff(src) and not isAdmin(src) then return end

    local player    = Bridge_GetPlayer(src)
    local staffName = Bridge_GetFullName(player)

    MySQL.query('SELECT * FROM gc_section8_applications WHERE id = ? AND status = ?', { appId, 'pending' }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:notify', src, 'Application not found or already processed.', 'error')
            return
        end

        local app  = result[1]
        local rent = calculateRent(app.monthly_income)

        local targetSrc = nil
        for _, pid in ipairs(Bridge_GetAllPlayers()) do
            local p = Bridge_GetPlayer(pid)
            if p and Bridge_GetCitizenId(p) == app.citizenid then
                targetSrc = pid
                break
            end
        end

        TriggerEvent('gc-section8:server:processApplication', appId, targetSrc, app.citizenid, app.player_name, rent, staffName)
        TriggerClientEvent('gc-section8:client:notify', src, 'Application approved for ' .. app.player_name, 'success')
    end)
end)

-- ─────────────────────────────────────────────────
--  STAFF: DENY APPLICATION
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:staffDeny', function(appId, reason)
    local src = source
    if not isSection8Staff(src) and not isAdmin(src) then return end

    local player    = Bridge_GetPlayer(src)
    local staffName = Bridge_GetFullName(player)

    if not reason or #reason < 3 then reason = 'Does not meet requirements' end

    MySQL.query('SELECT * FROM gc_section8_applications WHERE id = ? AND status = ?', { appId, 'pending' }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:notify', src, 'Application not found.', 'error')
            return
        end

        local app = result[1]
        MySQL.update('UPDATE gc_section8_applications SET status = ?, approved_by = ?, reviewed_at = NOW() WHERE id = ?',
            { 'denied', staffName, appId })

        TriggerClientEvent('gc-section8:client:notify', src, 'Application denied for ' .. app.player_name, 'success')

        for _, pid in ipairs(Bridge_GetAllPlayers()) do
            local p = Bridge_GetPlayer(pid)
            if p and Bridge_GetCitizenId(p) == app.citizenid then
                TriggerClientEvent('gc-section8:client:notify', pid, 'Your Section 8 application was denied: ' .. reason, 'error')
                break
            end
        end

        TriggerEvent('gc-section8:discord:log', 'denied', {
            name = app.player_name, citizenid = app.citizenid, reason = reason, staffName = staffName,
        })
    end)
end)

-- ─────────────────────────────────────────────────
--  STAFF: EVICT TENANT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:evictTenant', function(citizenid)
    local src = source
    if not isSection8Staff(src) and not isAdmin(src) then return end

    local player    = Bridge_GetPlayer(src)
    local staffName = Bridge_GetFullName(player)

    MySQL.query('SELECT * FROM gc_section8_rent WHERE citizenid = ?', { citizenid }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('gc-section8:client:notify', src, 'No active tenant found.', 'error')
            return
        end
        local record = result[1]
        TriggerEvent('gc-section8:server:doEviction', citizenid, record.unit_id, staffName)
        TriggerEvent('gc-section8:server:evictionClearDecor', record.unit_id)
        TriggerClientEvent('gc-section8:client:notify', src, 'Eviction processed.', 'success')
    end)
end)

-- ─────────────────────────────────────────────────
--  INTERNAL: EVICTION
-- ─────────────────────────────────────────────────

AddEventHandler('gc-section8:server:doEviction', function(citizenid, unitId, reason)
    MySQL.query('SELECT door_id FROM gc_section8_units WHERE id = ?', { unitId }, function(result)
        if result and result[1] and result[1].door_id then
            DoorlockRevoke(result[1].door_id, citizenid)
        end
    end)

    MySQL.update('UPDATE gc_section8_units SET occupied = 0, tenant_citizenid = NULL, tenant_name = NULL WHERE id = ?', { unitId })
    MySQL.update('DELETE FROM gc_section8_rent WHERE citizenid = ?', { citizenid })

    TriggerEvent('gc-section8:snap:revoke', citizenid)

    MySQL.update('UPDATE gc_section8_applications SET status = ? WHERE citizenid = ? AND status = ?',
        { 'denied', citizenid, 'approved' })

    for _, pid in ipairs(Bridge_GetAllPlayers()) do
        local p = Bridge_GetPlayer(pid)
        if p and Bridge_GetCitizenId(p) == citizenid then
            TriggerClientEvent('gc-section8:client:evicted', pid)
            break
        end
    end

    TriggerEvent('gc-section8:discord:log', 'evicted', {
        citizenid = citizenid, unit = unitId, reason = reason or 'Non-payment',
    })
end)

-- ─────────────────────────────────────────────────
--  RENT DUE CHECK (every 30 min)
-- ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1800000)
        local now = os.date('!%Y-%m-%d %H:%M:%S', os.time())

        MySQL.query([[
            SELECT r.*, a.player_name FROM gc_section8_rent r
            LEFT JOIN gc_section8_applications a ON r.citizenid = a.citizenid AND a.status = 'approved'
            WHERE r.due_date < ? AND r.warned = 0
        ]], { now }, function(overdue)
            if not overdue then return end
            for _, record in ipairs(overdue) do
                local warnExpiry = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (Config.WarningDays * 86400))
                MySQL.update('UPDATE gc_section8_rent SET warned = 1, warn_date = ? WHERE citizenid = ?',
                    { warnExpiry, record.citizenid })
                TriggerEvent('gc-section8:discord:log', 'rent_warning', {
                    name = record.player_name or record.citizenid,
                    citizenid = record.citizenid, unit = record.unit_id, daysLeft = Config.WarningDays,
                })
            end
        end)

        MySQL.query([[
            SELECT r.*, a.player_name FROM gc_section8_rent r
            LEFT JOIN gc_section8_applications a ON r.citizenid = a.citizenid AND a.status = 'approved'
            WHERE r.warned = 1 AND r.warn_date < ?
        ]], { now }, function(evictions)
            if not evictions then return end
            for _, record in ipairs(evictions) do
                TriggerEvent('gc-section8:server:doEviction', record.citizenid, record.unit_id, 'Non-payment of rent')
            end
        end)
    end
end)

-- ─────────────────────────────────────────────────
--  LOGIN RENT CHECK
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:loginRentCheck', function()
    local src    = source
    local player = Bridge_GetPlayer(src)
    if not player then return end

    local citizenid = Bridge_GetCitizenId(player)
    local now       = os.date('!%Y-%m-%d %H:%M:%S', os.time())

    MySQL.query('SELECT * FROM gc_section8_rent WHERE citizenid = ? AND due_date < ?', { citizenid, now }, function(result)
        if not result or not result[1] then return end
        TriggerClientEvent('gc-section8:client:rentWarning', src, Config.WarningDays)
    end)
end)

-- ─────────────────────────────────────────────────
--  ADMIN: TOGGLE NPC MODE
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:toggleNPCMode', function()
    local src = source
    if not isAdmin(src) then return end

    npcMode = not npcMode
    local val = npcMode and '1' or '0'
    MySQL.update('UPDATE gc_section8_settings SET value = ? WHERE `key` = ?', { val, 'npc_mode' })
    TriggerClientEvent('gc-section8:client:syncNPCMode', -1, npcMode)
    TriggerClientEvent('gc-section8:client:notify', src, 'NPC Mode: ' .. (npcMode and 'ON' or 'OFF'), 'success')
end)

-- ─────────────────────────────────────────────────
--  ADMIN: SAVE UNIT
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:saveUnit', function(unitData)
    local src = source
    if not isAdmin(src) then return end

    if not unitData or not unitData.id or not unitData.label then
        TriggerClientEvent('gc-section8:client:notify', src, 'Invalid unit data.', 'error')
        return
    end

    MySQL.insert(
        'INSERT INTO gc_section8_units (id, label, size, max_occupants, door_id, coords_x, coords_y, coords_z, rent_base) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label=?, size=?, max_occupants=?, door_id=?, coords_x=?, coords_y=?, coords_z=?, rent_base=?',
        {
            unitData.id, unitData.label, unitData.size, unitData.maxOccupants, unitData.doorId,
            unitData.coords.x, unitData.coords.y, unitData.coords.z, unitData.rentBase,
            unitData.label, unitData.size, unitData.maxOccupants, unitData.doorId,
            unitData.coords.x, unitData.coords.y, unitData.coords.z, unitData.rentBase,
        },
        function()
            TriggerClientEvent('gc-section8:client:notify', src, 'Unit ' .. unitData.label .. ' saved.', 'success')
        end
    )
end)

-- ─────────────────────────────────────────────────
--  ADMIN: GET ALL UNITS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:getUnits', function()
    local src = source
    if not isAdmin(src) and not isSection8Staff(src) then return end
    MySQL.query('SELECT * FROM gc_section8_units ORDER BY id ASC', {}, function(result)
        TriggerClientEvent('gc-section8:client:receiveUnits', src, result or {})
    end)
end)

-- ─────────────────────────────────────────────────
--  STAFF: GET ALL TENANTS
-- ─────────────────────────────────────────────────

RegisterNetEvent('gc-section8:server:getTenants', function()
    local src = source
    if not isSection8Staff(src) and not isAdmin(src) then return end
    MySQL.query([[
        SELECT u.id as unit_id, u.label, u.size, u.tenant_name, u.tenant_citizenid,
               r.rent_amount, r.last_paid, r.due_date, r.warned
        FROM gc_section8_units u
        LEFT JOIN gc_section8_rent r ON u.tenant_citizenid = r.citizenid
        WHERE u.occupied = 1
    ]], {}, function(result)
        TriggerClientEvent('gc-section8:client:receiveTenants', src, result or {})
    end)
end)
