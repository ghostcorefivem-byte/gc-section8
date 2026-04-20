-- =============================================
-- gc-section8 | sv_doorlock.lua
-- Handles ox_doorlock citizenid access
-- Persists across restarts via ox_doorlock DB
-- =============================================

-- =============================================
-- GRANT ACCESS
-- Adds citizenid to the door's character list
-- =============================================
function DoorlockGrant(doorId, citizenid)
    if not doorId or not citizenid then return end

    local door = exports.ox_doorlock:getDoor(doorId)
    if not door then
        print('^1[gc-section8] Door ID ' .. tostring(doorId) .. ' not found in ox_doorlock^7')
        return
    end

    local chars = door.characters or {}
    for _, c in ipairs(chars) do
        if c == citizenid then
            -- Already in list but make sure passcode is cleared
            exports.ox_doorlock:editDoor(doorId, { characters = chars, passcode = '' })
            return
        end
    end

    chars[#chars + 1] = citizenid

    -- IMPORTANT: clear passcode so player is NOT prompted for PIN
    -- citizenid access bypasses passcode only if passcode is nil/empty
    exports.ox_doorlock:editDoor(doorId, { characters = chars, passcode = '' })
    print('^2[gc-section8] Door ' .. doorId .. ' access GRANTED to ' .. citizenid .. '^7')
end

-- =============================================
-- REVOKE ACCESS
-- Removes citizenid from the door's character list
-- =============================================
function DoorlockRevoke(doorId, citizenid)
    if not doorId or not citizenid then return end

    local door = exports.ox_doorlock:getDoor(doorId)
    if not door then
        print('^1[gc-section8] Door ID ' .. tostring(doorId) .. ' not found in ox_doorlock^7')
        return
    end

    local chars = door.characters or {}
    local updated = {}
    for _, c in ipairs(chars) do
        if c ~= citizenid then
            updated[#updated + 1] = c
        end
    end

    -- If no tenants left on this door, lock it back down
    -- Restore passcode so it's not accessible to anyone
    local passcode = #updated == 0 and 'section8' or ''
    exports.ox_doorlock:editDoor(doorId, { characters = updated, passcode = passcode })
    print('^3[gc-section8] Door ' .. doorId .. ' access REVOKED for ' .. citizenid .. '^7')
end

-- =============================================
-- RESTORE ALL ON RESOURCE START
-- In case server restarted — re-grants access
-- for all current tenants from DB
-- =============================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Small delay to let ox_doorlock finish loading
    SetTimeout(5000, function()
        MySQL.query('SELECT tenant_citizenid, door_id FROM gc_section8_units WHERE occupied = 1 AND door_id IS NOT NULL', {}, function(result)
            if not result then return end
            local count = 0
            for _, row in ipairs(result) do
                if row.tenant_citizenid and row.door_id then
                    DoorlockGrant(row.door_id, row.tenant_citizenid)
                    count = count + 1
                end
            end
            if count > 0 then
                print('^2[gc-section8] Restored door access for ' .. count .. ' tenant(s)^7')
            end
        end)
    end)
end)
