--[[
    gc-section8 | client/snap.lua
    SNAP / Link Card client-side notifications.
]]

RegisterNetEvent('gc-section8:client:snapBalance', function(balance)
    Bridge_Notify('💳 Link Card Balance', ('Current SNAP balance: $%s'):format(balance), 'inform', 6000)
end)

RegisterNetEvent('gc-section8:client:snapReloaded', function(amount, newBalance)
    Bridge_Notify('💳 SNAP Benefits Loaded',
        ('$%s added to your Link Card.\nNew balance: $%s'):format(amount, newBalance),
        'success', 8000)
end)

RegisterNetEvent('gc-section8:client:snapDenied', function(reason)
    Bridge_Notify('💳 Link Card', reason or 'Unable to process.', 'error', 6000)
end)
