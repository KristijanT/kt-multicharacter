local S = { active = false, cams = {}, curCam = nil, ents = {}, ped = nil, scene = nil,
            chars = {}, spawnList = {}, spawn = nil, loaded = false, selected = nil }
local L = Config.Lang[Config.Locale] or Config.Lang.en

local function nui(action, data) SendNUIMessage({ action = action, data = data }) end

local function loadModel(m)
    local h = type(m) == 'number' and m or joaat(m)
    lib.requestModel(h, 5000)
    return h
end

---------------------------------------------------------------- Framework loaded flag
RegisterNetEvent('esx:playerLoaded', function() S.loaded = true end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() S.loaded = true end)
RegisterNetEvent('qbx_core:client:playerLoaded', function() S.loaded = true end)

---------------------------------------------------------------- Scenes
local function currentSeason()
    if Config.Season ~= 'auto' then return Config.Season end
    local _, month = GetLocalTime()
    return Config.SeasonMonths[month]
end

local function pickScene()
    local season, pool = currentSeason(), {}
    for _, sc in ipairs(Config.Scenes) do
        if sc.enabled and (not sc.season or sc.season == season) then pool[#pool + 1] = sc end
    end
    -- sezonska scena ima prioritet ako postoji
    local seasonal = {}
    for _, sc in ipairs(pool) do if sc.season then seasonal[#seasonal + 1] = sc end end
    if #seasonal > 0 then pool = seasonal end
    return pool[GetRandomIntInRange(1, #pool + 1)] or pool[1]
end

local function track(e) S.ents[#S.ents + 1] = e return e end

local function buildScene(sc)
    for _, p in ipairs(sc.props or {}) do
        local h = loadModel(p.model)
        local o = track(CreateObjectNoOffset(h, p.coords.x, p.coords.y, p.coords.z, false, false, false))
        SetEntityHeading(o, p.heading or 0.0)
        FreezeEntityPosition(o, true)
        SetModelAsNoLongerNeeded(h)
    end
    for _, v in ipairs(sc.vehicles or {}) do
        local h = loadModel(v.model)
        local e = track(CreateVehicle(h, v.coords.x, v.coords.y, v.coords.z, v.heading or 0.0, false, false))
        SetVehicleOnGroundProperly(e)
        SetVehicleDoorsLocked(e, 2)
        FreezeEntityPosition(e, true)
        SetModelAsNoLongerNeeded(h)
    end
    for _, n in ipairs(sc.npcs or {}) do
        local h = loadModel(n.model)
        local e = track(CreatePed(4, h, n.coords.x, n.coords.y, n.coords.z - 1.0, n.heading or 0.0, false, false))
        SetEntityInvincible(e, true)
        SetBlockingOfNonTemporaryEvents(e, true)
        FreezeEntityPosition(e, true)
        if n.scenario then TaskStartScenarioInPlace(e, n.scenario, 0, true) end
        SetModelAsNoLongerNeeded(h)
    end
    if sc.weather then
        SetWeatherTypeNowPersist(sc.weather)
        if sc.weather == 'XMAS' then SetForceVehicleTrails(true) SetForcePedFootstepsTracks(true) end
    end
    if sc.time then NetworkOverrideClockTime(sc.time[1], sc.time[2], 0) end
end

local function makeCam(c)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.coords.x, c.coords.y, c.coords.z, 0.0, 0.0, 0.0, c.fov or 40.0, false, 2)
    PointCamAtCoord(cam, c.lookAt.x, c.lookAt.y, c.lookAt.z)
    S.cams[#S.cams + 1] = cam
    return cam
end

local function moveCamTo(c)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
    local new = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x + 14.0, c.y + 14.0, c.z + 9.0, 0.0, 0.0, 0.0, 50.0, false, 2)
    PointCamAtCoord(new, c.x, c.y, c.z + 1.0)
    SetCamActiveWithInterp(new, S.curCam, 1200, 1, 1)
    S.curCam = new
    S.cams[#S.cams + 1] = new
end

---------------------------------------------------------------- Preview ped
local function clearPed()
    if S.ped and DoesEntityExist(S.ped) then DeleteEntity(S.ped) end
    S.ped = nil
end

local function showPed(ch)
    clearPed()
    local p = S.scene.ped
    local default = ch.gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local okSkin, app = pcall(json.decode, ch.skin or '{}')
    local modelName = (okSkin and type(app) == 'table' and app.model) or default
    local ok, h = pcall(loadModel, modelName)
    if not ok then h = loadModel(default) end

    local ped = CreatePed(4, h, p.x, p.y, p.z - 1.0, p.w, false, false)
    SetModelAsNoLongerNeeded(h)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    Hooks.ApplyAppearance(ped, ch)
    if S.scene.pedScenario then TaskStartScenarioInPlace(ped, S.scene.pedScenario, 0, true) end
    S.ped = ped
end

---------------------------------------------------------------- Cleanup
local function cleanup()
    clearPed()
    for _, e in ipairs(S.ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
    S.ents = {}
    RenderScriptCams(false, false, 0, true, true)
    for _, c in ipairs(S.cams) do if DoesCamExist(c) then DestroyCam(c, false) end end
    S.cams, S.curCam = {}, nil
    ClearFocus()
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
    S.active = false
end

local function restorePlayer()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
    DisplayHud(true)
    if Config.PauseWeatherSync then Hooks.PauseWeather(false) end
end

---------------------------------------------------------------- UI
local function trimChars(list)
    local out = {}
    for _, c in ipairs(list) do
        out[#out + 1] = { id = c.id, slot = c.slot, firstname = c.firstname, lastname = c.lastname,
                          dob = c.dob, gender = c.gender, job = c.job, cash = c.cash, bank = c.bank }
    end
    return out
end

local function uiConfig(data)
    return {
        preset = Config.Preset, accent = Config.Accent, currency = Config.Currency, storeUrl = Config.StoreURL,
        lang = L, maxSlots = Config.MaxSlots, slots = data.slots, canDelete = data.canDelete,
        birth = Config.Birth, nationalities = Config.Nationalities,
        items = Config.StartingItems.enabled and Config.StartingItems.items or {},
        budget = Config.StartingItems.budget,
    }
end

local function startSelection()
    DoScreenFadeOut(0)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    S.active = true

    S.scene = pickScene()
    local ped = PlayerPedId()
    local p = S.scene.ped
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z, false, false, false)
    SetFocusPosAndVel(p.x, p.y, p.z, 0.0, 0.0, 0.0)
    DisplayRadar(false)
    DisplayHud(false)
    if Config.PauseWeatherSync then Hooks.PauseWeather(true) end

    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 5000 do Wait(50) end

    buildScene(S.scene)

    local main = makeCam(S.scene.cam)
    local wait = 0
    if S.scene.intro then
        local intro = makeCam(S.scene.intro)
        SetCamActive(intro, true)
        RenderScriptCams(true, false, 0, true, true)
        DoScreenFadeIn(800)
        wait = S.scene.intro.time or 5000
        SetCamActiveWithInterp(main, intro, wait, 1, 1)
    else
        SetCamActive(main, true)
        RenderScriptCams(true, false, 0, true, true)
        DoScreenFadeIn(800)
    end
    S.curCam = main

    local data = lib.callback.await('kt-mc:data', false)
    S.chars = data.chars
    Wait(wait)
    SetNuiFocus(true, true)
    nui('open', { cfg = uiConfig(data), chars = trimChars(S.chars) })
end

local function findChar(id)
    for _, c in ipairs(S.chars) do if c.id == id then return c end end
end

local function buildSpawnList(ch)
    local list = {}
    if ch.pos then list[#list + 1] = { label = L.last_location, coords = vec4(ch.pos.x, ch.pos.y, ch.pos.z, ch.pos.w) } end
    for _, s in ipairs(Config.Spawns) do list[#list + 1] = s end
    return list
end

local function doLogin(ch)
    SetNuiFocus(false, false)
    nui('close')
    DoScreenFadeOut(500)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 2000 do Wait(0) end
    clearPed()
    S.loaded = false
    if not lib.callback.await('kt-mc:play', false, ch.id) then
        DoScreenFadeIn(500)
        SetNuiFocus(true, true)
        nui('open', { cfg = uiConfig({ slots = 1, canDelete = true }), chars = trimChars(S.chars) })
    end
end

---------------------------------------------------------------- NUI callbacks
RegisterNUICallback('select', function(d, cb)
    local ch = findChar(d.id)
    if ch then showPed(ch) end
    cb(1)
end)

RegisterNUICallback('empty', function(_, cb) clearPed() cb(1) end)

RegisterNUICallback('play', function(d, cb)
    local ch = findChar(d.id)
    if not ch then return cb(0) end
    S.selected, S.spawn = ch, nil
    if Config.Spawn.mode == 'classic' then
        S.spawnList = buildSpawnList(ch)
        clearPed()
        local view = {}
        for _, s in ipairs(S.spawnList) do view[#view + 1] = { label = s.label } end
        nui('spawnStage', view)
        moveCamTo(S.spawnList[1].coords)
    else
        doLogin(ch)
    end
    cb(1)
end)

RegisterNUICallback('previewSpawn', function(d, cb)
    local sp = S.spawnList[(d.index or 0) + 1]
    if sp then moveCamTo(sp.coords) end
    cb(1)
end)

RegisterNUICallback('spawn', function(d, cb)
    local sp = S.spawnList[(d.index or 0) + 1]
    if sp and S.selected then
        S.spawn = sp.coords
        doLogin(S.selected)
    end
    cb(1)
end)

RegisterNUICallback('create', function(d, cb)
    DoScreenFadeOut(300)
    S.spawn = Config.Spawn.newCharacter
    S.loaded = false
    local ok, err = lib.callback.await('kt-mc:create', false, d.data, d.items)
    if not ok then
        DoScreenFadeIn(300)
        return cb({ ok = false, err = err })
    end
    SetNuiFocus(false, false)
    nui('close')
    clearPed()
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(d, cb)
    if lib.callback.await('kt-mc:delete', false, d.id) then
        local data = lib.callback.await('kt-mc:data', false)
        S.chars = data.chars
        clearPed()
        nui('refresh', { cfg = uiConfig(data), chars = trimChars(S.chars) })
        return cb({ ok = true })
    end
    cb({ ok = false })
end)

---------------------------------------------------------------- Finish (after login)
local function wakeUp(ped)
    local dict = 'missfinale_c1@'
    lib.requestAnimDict(dict)
    local pos = GetEntityCoords(ped)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, dict, 'lying_dead_player0', 8.0, -8.0, -1, 1, 0, false, false, false)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x + 0.9, pos.y + 0.9, pos.z + 0.7, 0.0, 0.0, 0.0, 50.0, false, 2)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.2, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    DoScreenFadeIn(1200)
    Wait(3500)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    RenderScriptCams(false, true, 2500, true, true)
    Wait(2600)
    DestroyCam(cam, false)
    RemoveAnimDict(dict)
end

RegisterNetEvent('kt-mc:client:finish', function(isNew)
    local t = GetGameTimer()
    while not S.loaded and GetGameTimer() - t < 15000 do Wait(100) end
    Wait(500)

    cleanup()
    restorePlayer()

    local ped = PlayerPedId()
    local c = S.spawn
    if c then
        FreezeEntityPosition(ped, true)
        RequestCollisionAtCoord(c.x, c.y, c.z)
        SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(ped, c.w or 0.0)
        local w = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - w < 5000 do Wait(50) end
        FreezeEntityPosition(ped, false)
    end
    S.spawn = nil

    if Config.Spawn.wakeUp and not isNew then
        wakeUp(ped)
    else
        DoScreenFadeIn(800)
    end
    if isNew then Hooks.OpenAppearance() end
end)

---------------------------------------------------------------- Boot
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    if lib.callback.await('kt-mc:ready', false) then startSelection() end
end)

if not GetResourceMetadata then end -- (no-op, kept for readability)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if S.active then cleanup() restorePlayer() SetNuiFocus(false, false) end
end)