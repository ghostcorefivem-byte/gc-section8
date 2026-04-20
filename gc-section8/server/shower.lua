-- server/shower.lua

-- ─────────────────────────────────────────
--  Ensure the shower_usage table exists
-- ─────────────────────────────────────────
CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `shower_usage` (
            `citizenid`  VARCHAR(50)  NOT NULL,
            `uses_today` INT          NOT NULL DEFAULT 0,
            `first_use`  BIGINT       NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

-- ─────────────────────────────────────────
--  Helper — fetch or create row
-- ─────────────────────────────────────────
local function GetShowerData(citizenid, cb)
    exports.oxmysql:single(
        "SELECT uses_today, first_use FROM shower_usage WHERE citizenid = ?",
        { citizenid },
        function(row)
            if row then
                cb(row.uses_today, row.first_use)
            else
                cb(0, 0)
            end
        end
    )
end

local function UpsertShowerData(citizenid, uses, firstUse)
    exports.oxmysql:execute(
        [[INSERT INTO shower_usage (citizenid, uses_today, first_use)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE uses_today = ?, first_use = ?]],
        { citizenid, uses, firstUse, uses, firstUse }
    )
end

-- ─────────────────────────────────────────
--  Request shower — validates limit, triggers grant or deny
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:server:requestShower", function()
    local src       = source
    local Player = Bridge_GetPlayer(src)

    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local now       = os.time()
    local window    = Config.Shower.ResetHours * 3600  -- seconds in the reset window
    local maxUses   = Config.Shower.MaxUsesPerDay

    GetShowerData(citizenid, function(uses, firstUse)
        -- If outside the 24-hour window, reset
        if (now - firstUse) >= window then
            uses     = 0
            firstUse = 0
        end

        if uses >= maxUses then
            local remaining = math.ceil(((firstUse + window) - now) / 60)
            TriggerClientEvent("gc-section8:client:showerDenied", src, remaining)
            return
        end

        -- Increment and save
        local newUses     = uses + 1
        local newFirstUse = (firstUse == 0) and now or firstUse
        UpsertShowerData(citizenid, newUses, newFirstUse)
        TriggerClientEvent("gc-section8:client:showerGranted", src)
        print(string.format("[gc-Shower] %s used shower (%d/%d)", citizenid, newUses, maxUses))
    end)
end)

-- ─────────────────────────────────────────
--  Broadcast particle FX to nearby players
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:server:startShower", function(netId)
    local src = source
    TriggerClientEvent("gc-section8:client:playShower", -1, netId)
end)

-- ─────────────────────────────────────────
--  Deny event handled client-side
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:client:showerDenied") 
AddEventHandler("gc-section8:client:showerDenied", function() end) 


