-- Force close from server
RegisterNetEvent('gc-section8:client:forceCloseNUI', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

-- Emergency command to unstick NUI (anyone can use on themselves)
RegisterCommand('closenui', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end, false)

-- NUI key close handler
CreateThread(function()
    while true do
        Wait(0)
        if IsNuiFocused() and IsControlJustPressed(0, 200) then -- Backspace/Escape
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
        end
    end
end)

-- Force close NUI on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
