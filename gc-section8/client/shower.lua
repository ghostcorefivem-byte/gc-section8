-- cl_shower.lua
-- gc-section8 Shower System (Client)
-- Drop into client/ folder

local isShowering = false

-- ─────────────────────────────────────────
--  Particle dict loader
-- ─────────────────────────────────────────
local function LoadParticleFx(dict)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local t = 0
        while not HasNamedPtfxAssetLoaded(dict) and t < 40 do
            Wait(100)
            t = t + 1
        end
    end
    return HasNamedPtfxAssetLoaded(dict)
end

-- ─────────────────────────────────────────
--  Play shower FX on a ped (called for ALL nearby players)
-- ─────────────────────────────────────────
local function PlayShowerOnPed(netId)
    local ped = NetToPed(netId)
    if not DoesEntityExist(ped) then return end

    local duration = Config.Shower.Duration * 1000
    local fxList   = {}

-- ── Water stream from showerhead (rains down on ped) ──
if LoadParticleFx("core") then
    SetPtfxAssetNextCall("core")
    local fx = StartParticleFxLoopedOnEntity(
        "ent_amb_water_spray",
        ped,
        0.0, 0.0, 0.9,
        -90.0, 0.0, 0.0,
        1.2,
        false, false, false
    )
    if DoesParticleFxLoopedExist(fx) then fxList[#fxList+1] = fx end
end

-- ── Water splashing at feet ──
if LoadParticleFx("core") then
    SetPtfxAssetNextCall("core")
    local fx = StartParticleFxLoopedOnEntity(
        "ent_amb_waterfall_base",
        ped,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        0.5,
        false, false, false
    )
    if DoesParticleFxLoopedExist(fx) then fxList[#fxList+1] = fx end
end

-- ── Steam / mist ──
if LoadParticleFx("core") then
    SetPtfxAssetNextCall("core")
    local fx = StartParticleFxLoopedOnEntity(
        "ent_amb_waterfall_mist",
        ped,
        0.0, 0.0, 0.5,
        0.0, 0.0, 0.0,
        0.35,
        false, false, false
    )
    if DoesParticleFxLoopedExist(fx) then fxList[#fxList+1] = fx end
end

    -- Stop all FX after duration
    CreateThread(function()
        Wait(duration)
        for _, fx in ipairs(fxList) do
            if DoesParticleFxLoopedExist(fx) then
                StopParticleFxLooped(fx, false)
            end
        end
    end)
end

-- ─────────────────────────────────────────
--  Play animation + sound (only for the showering player)
-- ─────────────────────────────────────────
local function PlayShowerLocal()
    local ped      = PlayerPedId()
    local duration = Config.Shower.Duration * 1000

    local dict = "mp_safehouseshower@male@"
    local anim = "male_shower_idle_c"

    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 40 do
        Wait(100)
        t = t + 1
    end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 2.0, -2.0, duration, 1, 0, false, false, false)
    end

    -- Native shower water sound (Bunker facility shower loop)
    local soundId = GetSoundId()
    PlaySoundFromEntity(soundId, "DLC_BTL_FACILITY_SHOWER_LOOP", ped, "DLC_BATTLE_SOUNDS", true, 0)

    CreateThread(function()
        Wait(duration)
        StopSound(soundId)
        ReleaseSoundId(soundId)
        if HasAnimDictLoaded(dict) then
            StopAnimTask(ped, dict, anim, 2.0)
            RemoveAnimDict(dict)
        end
    end)
end

-- ─────────────────────────────────────────
--  Net event — server fans out to nearby clients
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:client:playShower", function(netId)
    -- Everyone sees the particles
    CreateThread(function()
        PlayShowerOnPed(netId)
    end)
    -- Only the showering player gets anim + sound
    if netId == PedToNet(PlayerPedId()) then
        CreateThread(function()
            PlayShowerLocal()
        end)
    end
end)

-- ─────────────────────────────────────────
--  Server confirmed — cleared to shower
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:client:showerGranted", function()
    if isShowering then return end
    isShowering = true

    local netId = PedToNet(PlayerPedId())
    TriggerServerEvent("gc-section8:server:startShower", netId)

    CreateThread(function()
        Wait(Config.Shower.Duration * 1000)
        SetEntityHealth(PlayerPedId(), 200)
        Bridge_Notify("Shower", "You feel clean and refreshed!", "success")
        isShowering = false
    end)
end)

-- ─────────────────────────────────────────
--  Denied — tell player how long to wait
-- ─────────────────────────────────────────
RegisterNetEvent("gc-section8:client:showerDenied", function(minutesLeft)
    lib.notify({
        title       = "Shower",
        description = "You already showered today. Try again in " .. minutesLeft .. " min.",
        type        = "error"
    })
end)

-- ─────────────────────────────────────────
--  ox_target helper — call from house-enter logic
--  e.g. AddShowerTarget(vec3(x, y, z))
-- ─────────────────────────────────────────
function AddShowerTarget(showerCoords)
    exports.ox_target:addBoxZone({
        coords   = showerCoords,
        size     = vec3(1.2, 1.2, 2.0),
        rotation = 0,
        debug    = false,
        options  = {
            {
                name     = "gc_section8_shower",
                label    = "Take a Shower",
                icon     = "fas fa-shower",
                onSelect = function()
                    if isShowering then
                        lib.notify({ title = "Shower", description = "You are already showering.", type = "error" })
                        return
                    end
                    TriggerServerEvent("gc-section8:server:requestShower")
                end,
            },
        },
    })
end

-- ─────────────────────────────────────────
--  /shower command
-- ─────────────────────────────────────────
RegisterCommand(Config.Shower.Command, function()
    if isShowering then
        lib.notify({ title = "Shower", description = "You are already showering.", type = "error" })
        return
    end
    TriggerServerEvent("gc-section8:server:requestShower")
end, false)
