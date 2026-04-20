--[[
    gc-section8 | client/bridge.lua
    Client-side wrappers for multi-target and multi-notify support
]]

local _target = GCBridge.Target()
local _hasOxLib = GetResourceState('ox_lib') == 'started'
local _fw = GCBridge.Framework()

-- ─────────────────────────────────────────────────
--  NOTIFY
-- ─────────────────────────────────────────────────

function Bridge_Notify(title, description, notifyType, duration)
    notifyType = notifyType or 'inform'
    duration = duration or 5000

    if _hasOxLib then
        lib.notify({ title = title, description = description, type = notifyType, duration = duration })
    elseif _fw == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()
        QBCore.Functions.Notify(description, notifyType, duration)
    else
        -- Fallback: chat message
        TriggerEvent('chat:addMessage', { args = { '[' .. title .. '] ' .. description } })
    end
end

-- ─────────────────────────────────────────────────
--  INPUT DIALOG
-- Uses ox_lib if available, falls back to basic input
-- ─────────────────────────────────────────────────

function Bridge_InputDialog(title, fields)
    if _hasOxLib then
        return lib.inputDialog(title, fields)
    end
    -- Basic fallback: return nil so callers skip gracefully
    return nil
end

function Bridge_ShowContext(id)
    if _hasOxLib then
        lib.showContext(id)
    end
end

function Bridge_RegisterContext(data)
    if _hasOxLib then
        lib.registerContext(data)
        return true
    end
    return false
end

-- ─────────────────────────────────────────────────
--  TARGET — Add options to a local entity
-- ─────────────────────────────────────────────────

function Bridge_AddTargetEntity(entity, options)
    if _target == 'ox_target' then
        exports['ox_target']:addLocalEntity(entity, options)

    elseif _target == 'qb-target' or _target == 'qtarget' then
        local qbOptions = {}
        for _, opt in ipairs(options) do
            qbOptions[#qbOptions + 1] = {
                type    = 'client',
                event   = '__gc_target_cb_' .. (opt.name or 'action'),
                icon    = opt.icon or 'fas fa-hand-paper',
                label   = opt.label or 'Interact',
                -- store callback so we can fire it
                _cb     = opt.onSelect,
                distance = opt.distance or 2.5,
            }
        end
        -- Register temporary events for qb-target callbacks
        for _, opt in ipairs(options) do
            if opt.onSelect then
                local evName = '__gc_target_cb_' .. (opt.name or 'action')
                if not _registeredTargetEvents then _registeredTargetEvents = {} end
                if not _registeredTargetEvents[evName] then
                    _registeredTargetEvents[evName] = true
                    AddEventHandler(evName, function()
                        opt.onSelect()
                    end)
                end
            end
        end
        exports[_target]:AddTargetEntity(entity, { options = qbOptions, distance = 2.5 })
    end
end

-- ─────────────────────────────────────────────────
--  TARGET — Remove options from a local entity
-- ─────────────────────────────────────────────────

function Bridge_RemoveTargetEntity(entity, names)
    if _target == 'ox_target' then
        exports['ox_target']:removeLocalEntity(entity, names)
    elseif _target == 'qb-target' or _target == 'qtarget' then
        exports[_target]:RemoveTargetEntity(entity)
    end
end

-- ─────────────────────────────────────────────────
--  PLAYER LOADED EVENT
-- ─────────────────────────────────────────────────

function Bridge_OnPlayerLoaded(cb)
    if _fw == 'qbcore' then
        AddEventHandler('QBCore:Client:OnPlayerLoaded', cb)
    elseif _fw == 'esx' then
        AddEventHandler('esx:playerLoaded', cb)
    end
end

function Bridge_IsLoggedIn()
    if _fw == 'qbcore' then
        return LocalPlayer.state.isLoggedIn
    elseif _fw == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        return ESX.GetPlayerData() ~= nil
    end
    return false
end
