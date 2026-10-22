local draft = { ped = nil, cam = nil, props = {} }

local function rotToDir(r)
    local z, x = math.rad(r.z), math.rad(r.x)
    local n = math.abs(math.cos(x))
    return vec3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function notify(msg) lib.notify({ title = 'KT Scene Creator', description = msg, type = 'success' }) end

local openMenu

local function exportLua()
    if not draft.ped or not draft.cam then
        return lib.notify({ description = 'Capture ped + camera first', type = 'error' })
    end
    local d = draft
    local out = {
        '{',
        "    name = 'my_scene', enabled = true, season = nil,",
        ('    ped = vec4(%.2f, %.2f, %.2f, %.2f),'):format(d.ped.x, d.ped.y, d.ped.z, d.ped.w),
        ('    cam = { coords = vec3(%.2f, %.2f, %.2f), lookAt = vec3(%.2f, %.2f, %.2f), fov = %.1f },')
            :format(d.cam.coords.x, d.cam.coords.y, d.cam.coords.z, d.cam.lookAt.x, d.cam.lookAt.y, d.cam.lookAt.z, d.cam.fov),
        "    time = { 18, 0 }, weather = 'EXTRASUNNY',",
        '    props = {',
    }
    for _, p in ipairs(d.props) do
        out[#out + 1] = ("        { model = '%s', coords = vec3(%.2f, %.2f, %.2f), heading = %.1f },")
            :format(p.model, p.coords.x, p.coords.y, p.coords.z, p.heading)
    end
    out[#out + 1] = '    }, vehicles = {}, npcs = {},'
    out[#out + 1] = '},'
    local txt = table.concat(out, '\n')
    lib.setClipboard(txt)
    print(txt)
    notify('Scene copied to clipboard (also printed in F8)')
end

openMenu = function()
    lib.registerContext({
        id = 'kt_mc_creator', title = 'KT Scene Creator',
        options = {
            { title = 'Capture ped position', icon = 'person', onSelect = function()
                local p = GetEntityCoords(cache.ped)
                draft.ped = vec4(p.x, p.y, p.z, GetEntityHeading(cache.ped))
                notify('Ped position saved'); lib.showContext('kt_mc_creator')
            end },
            { title = 'Capture camera (current view)', icon = 'camera', onSelect = function()
                local c, r = GetGameplayCamCoord(), GetGameplayCamRot(2)
                draft.cam = { coords = c, lookAt = c + rotToDir(r) * 3.0, fov = GetGameplayCamFov() }
                notify('Camera saved'); lib.showContext('kt_mc_creator')
            end },
            { title = 'Add prop at my feet', icon = 'cube', onSelect = function()
                local input = lib.inputDialog('Add prop', { { type = 'input', label = 'Model name', required = true } })
                if input then
                    local pos = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 1.0
                    local h = joaat(input[1])
                    if IsModelInCdimage(h) then
                        lib.requestModel(h, 3000)
                        local o = CreateObjectNoOffset(h, pos.x, pos.y, pos.z - 1.0, false, false, false)
                        FreezeEntityPosition(o, true)
                        draft.props[#draft.props + 1] = { model = input[1], coords = vec3(pos.x, pos.y, pos.z - 1.0), heading = GetEntityHeading(cache.ped), obj = o }
                        notify('Prop added')
                    else
                        lib.notify({ description = 'Invalid model', type = 'error' })
                    end
                end
                lib.showContext('kt_mc_creator')
            end },
            { title = 'Clear props', icon = 'trash', onSelect = function()
                for _, p in ipairs(draft.props) do if p.obj and DoesEntityExist(p.obj) then DeleteEntity(p.obj) end end
                draft.props = {}; lib.showContext('kt_mc_creator')
            end },
            { title = 'Export to Lua (clipboard)', icon = 'copy', onSelect = exportLua },
        },
    })
    lib.showContext('kt_mc_creator')
end

-- server.cfg:  add_ace group.admin command.ktscene allow
RegisterCommand('ktscene', openMenu, true)