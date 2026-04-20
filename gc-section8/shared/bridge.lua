--[[
    gc-section8 | bridge.lua
    Auto-detects: Framework, Inventory, Target, Notify
    Supported:
        Framework  — QBCore, ESX
        Inventory  — ox_inventory, qb-inventory
        Target     — ox_target, qb-target, qtarget
        Notify     — ox_lib, qb-core native
]]

GCBridge = {}

-- ─────────────────────────────────────────────────
--  FRAMEWORK
-- ─────────────────────────────────────────────────
local _framework = nil

function GCBridge.Framework()
    if _framework then return _framework end

    if GetResourceState('qb-core') == 'started' then
        _framework = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        _framework = 'esx'
    else
        error('[gc-section8] No supported framework found. Requires qb-core or es_extended.')
    end

    return _framework
end

-- ─────────────────────────────────────────────────
--  INVENTORY
-- ─────────────────────────────────────────────────
local _inventory = nil

function GCBridge.Inventory()
    if _inventory then return _inventory end

    if GetResourceState('ox_inventory') == 'started' then
        _inventory = 'ox_inventory'
    elseif GetResourceState('qb-inventory') == 'started' then
        _inventory = 'qb-inventory'
    else
        -- Default to ox_inventory and warn
        _inventory = 'ox_inventory'
        print('^3[gc-section8] No inventory resource detected — defaulting to ox_inventory^7')
    end

    return _inventory
end

-- ─────────────────────────────────────────────────
--  TARGET
-- ─────────────────────────────────────────────────
local _target = nil

function GCBridge.Target()
    if _target then return _target end

    if GetResourceState('ox_target') == 'started' then
        _target = 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        _target = 'qb-target'
    elseif GetResourceState('qtarget') == 'started' then
        _target = 'qtarget'
    else
        error('[gc-section8] No supported target resource found. Requires ox_target, qb-target, or qtarget.')
    end

    return _target
end
