local colors = {
    application = 3447003,  -- blue
    approved    = 3066993,  -- green
    denied      = 15158332, -- red
    denied_no_unit = 15105570,
    evicted     = 10038562, -- dark red
    snap_stolen_use = 16711680, -- bright red
    rent_paid   = 3066993,  -- green
    rent_warning = 15844367, -- orange
}

local function sendWebhook(eventType, fields)
    if not Config.Webhook or Config.Webhook == 'YOUR_WEBHOOK_URL_HERE' then return end

    local color = colors[eventType] or 16777215

    local embed = {
        {
            title = '🏢 Section 8 Housing — ' .. eventType:upper():gsub('_', ' '),
            color = color,
            fields = fields,
            footer = { text = 'City RP • Section 8' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }
    }

    PerformHttpRequest(Config.Webhook, function(err, text, headers) end, 'POST',
        json.encode({ username = Config.WebhookName, embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

AddEventHandler('gc-section8:discord:log', function(eventType, data)
    if eventType == 'application' then
        sendWebhook('application', {
            { name = 'Applicant',  value = data.name,            inline = true },
            { name = 'CitizenID',  value = data.citizenid,       inline = true },
            { name = 'Job',        value = data.job,             inline = true },
            { name = 'Income',     value = '$' .. data.income,   inline = true },
            { name = 'Est. Rent',  value = '$' .. data.rent,     inline = true },
            { name = 'Has Kids',   value = data.kids and 'Yes' or 'No', inline = true },
            { name = 'App ID',     value = tostring(data.appId), inline = true },
        })

    elseif eventType == 'approved' then
        sendWebhook('approved', {
            { name = 'Tenant',      value = data.name,        inline = true },
            { name = 'CitizenID',   value = data.citizenid,   inline = true },
            { name = 'Unit',        value = data.unit,        inline = true },
            { name = 'Rent',        value = '$' .. data.rent, inline = true },
            { name = 'Approved By', value = data.approvedBy,  inline = true },
        })

    elseif eventType == 'denied' or eventType == 'denied_no_unit' then
        sendWebhook(eventType, {
            { name = 'Applicant',   value = data.name,                           inline = true },
            { name = 'CitizenID',   value = data.citizenid,                      inline = true },
            { name = 'Reason',      value = data.reason or 'No units available', inline = true },
            { name = 'Staff',       value = data.staffName or 'System',          inline = true },
        })

    elseif eventType == 'evicted' then
        sendWebhook('evicted', {
            { name = 'CitizenID', value = data.citizenid,           inline = true },
            { name = 'Unit',      value = data.unit,                inline = true },
            { name = 'Reason',    value = data.reason or 'Unknown', inline = true },
        })

    elseif eventType == 'rent_paid' then
        sendWebhook('rent_paid', {
            { name = 'Tenant',    value = data.name,        inline = true },
            { name = 'CitizenID', value = data.citizenid,   inline = true },
            { name = 'Amount',    value = '$' .. data.amount, inline = true },
            { name = 'Unit',      value = data.unit,        inline = true },
        })

    elseif eventType == 'rent_warning' then
        sendWebhook('rent_warning', {
            { name = 'Tenant',     value = data.name,                          inline = true },
            { name = 'CitizenID',  value = data.citizenid,                     inline = true },
            { name = 'Unit',       value = data.unit,                          inline = true },
            { name = 'Days Left',  value = tostring(data.daysLeft) .. ' days', inline = true },
        })

    elseif eventType == 'snap_granted' then
        sendWebhook('snap_granted', {
            { name = 'CitizenID', value = data.citizenid,          inline = true },
            { name = 'Amount',    value = '$' .. data.amount .. '/mo', inline = true },
        })

    elseif eventType == 'snap_reload' then
        sendWebhook('snap_reload', {
            { name = 'CitizenID', value = data.citizenid,       inline = true },
            { name = 'Reloaded',  value = '$' .. data.amount,   inline = true },
        })

    elseif eventType == 'snap_stolen_use' then
        sendWebhook('snap_stolen_use', {
            { name = '🚨 Thief CitizenID', value = data.thief,                   inline = true },
            { name = '💳 Card Owner',      value = data.owner,                   inline = true },
            { name = 'Item',               value = data.item .. ' x' .. data.qty, inline = true },
            { name = 'Cost',               value = '$' .. data.cost,             inline = true },
            { name = 'Owner Balance Left', value = '$' .. data.balance,          inline = true },
        })

    elseif eventType == 'snap_purchase' then
        sendWebhook('snap_purchase', {
            { name = 'CitizenID',  value = data.citizenid,                inline = true },
            { name = 'Item',       value = data.item .. ' x' .. data.qty, inline = true },
            { name = 'Cost',       value = '$' .. data.cost,              inline = true },
            { name = 'Balance',    value = '$' .. data.balance,           inline = true },
        })
    end
end)
